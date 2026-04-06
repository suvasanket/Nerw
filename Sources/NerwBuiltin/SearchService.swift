import Cocoa
import NerwCore
import NerwSearchBackend
import NerwUtils

public class SearchService {
    public static let shared = SearchService()

    // Concurrency control for App Search
    private var searchWorkItem: DispatchWorkItem?

    // Action Cache
    private var cachedCandidates: [NerwAction] = []
    private var isCacheLoaded = false
    private let cacheLock = NSLock()
    private var cacheRefreshWorkItem: DispatchWorkItem?

    private init() {}

    public func loadCache(asyncUpdate: Bool = true) {
        cacheLock.lock()
        if !isCacheLoaded {
            cachedCandidates = buildCandidates()
            isCacheLoaded = true
        }
        cacheLock.unlock()

        if asyncUpdate {
            cacheRefreshWorkItem?.cancel()
            var workItem: DispatchWorkItem?
            workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let fresh = self.buildCandidates()
                self.cacheLock.lock()
                if self.isCacheLoaded, workItem?.isCancelled == false {
                    self.cachedCandidates = fresh
                }
                self.cacheLock.unlock()
            }
            cacheRefreshWorkItem = workItem
            if let workItem {
                DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            }
        }
    }

    public func clearCache() {
        searchWorkItem?.cancel()
        cacheRefreshWorkItem?.cancel()

        cacheLock.lock()
        cachedCandidates = []
        isCacheLoaded = false
        cacheLock.unlock()

        MemoryManager.shared.forceMemoryFree()
    }

    public func performAction(id: String) {
        // Find the action from all candidates
        let candidates = getCandidates()
        if let action = candidates.first(where: { $0.id == id }) {
            // Check if it's an instant action or needs more
            switch action.type {
            case .instant(let perform):
                perform(action)
            case .inlineArg(let perform, _):
                perform(action, "")
            case .args, .arg, .form:
                DispatchQueue.main.async {
                    if let ui = NerwSystem.shared.ui {
                        ui.openAction(action)
                    }
                }
            case .hybrid(let perform, _):
                perform(action)
            }
        }
    }

    public func getCandidates() -> [NerwAction] {
        cacheLock.lock()
        let loaded = isCacheLoaded
        let cache = cachedCandidates
        cacheLock.unlock()

        if loaded {
            return cache
        }
        return buildCandidates()
    }

    private func buildCandidates() -> [NerwAction] {
        return autoreleasepool {
            var candidates: [NerwAction] = []

            // Builtin
            candidates.append(contentsOf: Nerw.shared.getAllActions())
            candidates.append(contentsOf: System.shared.getAllActions())
            candidates.append(contentsOf: ClipboardManager.builtinActions())
            candidates.append(FindFile.shared.getTriggerAction())

            // Shortcuts
            candidates.append(contentsOf: ShortcutsEngine.shared.getAllActions())

            // Extensions
            candidates.append(contentsOf: ExtensionEngine.shared.getAllEntryActions())

            // Apps
            let allApps = AppSearch.shared.getAllApps()
            let appActions = allApps.map { self.createAction(for: $0) }
            candidates.append(contentsOf: appActions)

            return candidates
        }
    }

    public func search(query: String, completion: @escaping ([NerwAction]) -> Void) {
        // 0. Cancel previous pending search
        searchWorkItem?.cancel()

        // 1. Unified Search Entry
        let lowerQuery = query.lowercased()
        let allCandidates = self.getCandidates()

        // 2. Check for "Locked" Inline Action (Trigger + Space)
        for action in allCandidates {
            if case .inlineArg(let perform, let searcher) = action.type {
                for trigger in action.triggers {
                    let triggerLower = trigger.lowercased()
                    if lowerQuery.starts(with: triggerLower + " ") {
                        let arg = String(query.dropFirst(trigger.count + 1)).trimmingCharacters(
                            in: .whitespaces)

                        // If it has a searcher, use it and return immediately (Active Mode)
                        if let searcher = searcher {
                            searcher(action, arg) { [weak self] dynamicResults in
                                guard let self = self else { return }
                                var results = dynamicResults

                                // Append default Web Search fallback
                                let defaultEngine = SearchEngine.shared.getDefaultEngine()
                                let webSearchAction = self.createWebSearchAction(
                                    query: query, engine: defaultEngine)

                                if !results.contains(where: {
                                    $0.category == .webSearch && $0.title.contains("Search ")
                                }) {
                                    results.append(webSearchAction)
                                }
                                completion(results)
                            }
                            return
                        }

                        // Static Inline Fallback (if no searcher)
                        let inlineAction = NerwAction(
                            id: action.id + ".inline." + arg,
                            title: action.title,
                            subtitle: arg.isEmpty
                                ? action.subtitle.replacingOccurrences(of: "%s", with: "...")
                                : (action.subtitle.contains("%s")
                                    ? action.subtitle.replacingOccurrences(of: "%s", with: arg)
                                    : "Argument: \(arg)"),
                            icon: action.icon,
                            category: action.category,
                            triggers: [],
                            type: .instant(perform: { _ in perform(action, arg) })
                        )
                        completion([inlineAction])
                        return
                    }
                }
            }
        }

        // 3. Bang Search Detection
        if let (engineName, urlTemplate, cleanedQuery) = SearchEngine.shared.resolveBang(
            query: query)
        {
            let bangAction = self.createWebSearchAction(
                query: cleanedQuery,
                engine: Engine(
                    name: engineName, triggers: [], urlTemplate: urlTemplate))
            completion([bangAction])
            return
        }

        guard !query.isEmpty else {
            completion([])
            return
        }

        // 4. Standard Fuzzy Search (Background)
        let workItem = DispatchWorkItem { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                if self.searchWorkItem?.isCancelled == true { return }

                // Fuzzy Search Candidates
                let searchStrings = allCandidates.map { action in
                    if action.triggers.isEmpty { return action.title }
                    return action.title + " " + action.triggers.joined(separator: " ")
                }

                let fuse = Fuse()

                // Safety check: ensure query is not too long
                let safeQuery = String(query.prefix(100))

                let results = fuse.searchSync(safeQuery, in: searchStrings)

                if self.searchWorkItem?.isCancelled == true { return }

                // Safety check: filter out-of-bounds indices
                let validResults = results.filter { $0.index < allCandidates.count }
                let matchedActions = validResults.map { allCandidates[$0.index] }

                // Web Fallback
                var fallbackAction: NerwAction? = nil
                if let topMatch = FrecencyManager.shared.getMostRecentID(for: query),
                    topMatch.id.starts(with: "nerw.web.search.")
                {
                    let engineName = String(topMatch.id.dropFirst("nerw.web.search.".count))
                    if let engine = SearchEngine.shared.engines.first(where: {
                        $0.name == engineName
                    }) {
                        fallbackAction = self.createWebSearchAction(query: query, engine: engine)
                    }
                }

                if fallbackAction == nil {
                    fallbackAction = self.createWebSearchAction(
                        query: query, engine: SearchEngine.shared.getDefaultEngine())
                }

                // NLP Rank
                let catResult = QueryCategorizer.shared.classifySync(query)
                var allActions = matchedActions
                if let fallback = fallbackAction {
                    allActions.append(fallback)
                }
                let ranked = self.rankResults(
                    actions: allActions, query: query,
                    categoryResult: catResult.category)

                DispatchQueue.main.async {
                    if self.searchWorkItem?.isCancelled == false {
                        completion(ranked)
                    }
                }
            }
        }

        self.searchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    public func delegateSearch(
        action: NerwAction, query: String, completion: @escaping ([NerwAction]) -> Void
    ) {
        switch action.type {
        case .args(_, let searcher, _):
            searcher(action, query, completion)
        case .inlineArg(_, let searcher):
            searcher?(action, query, completion)
        default:
            completion([])
        }
    }

    public func createAction(for app: AppSearch.AppInfo) -> NerwAction {
        var quickAction: NerwAction? = nil

        if app.name == "Activity Monitor" {
            quickAction = NerwAction(
                id: "nerw.quick.process",
                title: "Quit Process",
                subtitle: "Search and terminate running processes",
                icon: .file(URL(fileURLWithPath: app.path)),
                triggers: [],
                type: .args(
                    placeholder: "Process Name",
                    searcher: { _, query, completion in
                        QuickAction.shared.searchProcesses(
                            query: query, completion: completion)
                    },
                    perform: nil
                )
            )
        } else if app.name.lowercased() == "finder" {
            quickAction = NerwAction(
                id: "nerw.quick.findfile",
                title: "Find File",
                subtitle: "Search or open finder",
                icon: .file(URL(fileURLWithPath: app.path)),
                triggers: [],
                type: .args(
                    placeholder: "Search",
                    searcher: { _, query, completion in
                        FindFile.shared.search(query: query, completion: completion)
                    },
                    perform: nil
                )
            )
        } else if app.name.lowercased() == "shortcuts" {
            quickAction = NerwAction(
                id: "nerw.quick.shortcuts",
                title: "Run Shortcut",
                subtitle: "Run a shortcut from your library",
                icon: .file(URL(fileURLWithPath: app.path)),
                triggers: [],
                type: .args(
                    placeholder: "Shortcut Name",
                    searcher: { _, query, completion in
                        Task {
                            do {
                                let allShortcuts = try await ShortcutsManager.shared
                                    .listShortcuts()
                                let lowerQuery = query.lowercased()
                                let filtered = allShortcuts.filter {
                                    query.isEmpty || $0.lowercased().contains(lowerQuery)
                                }

                                let actions = filtered.map { name in
                                    NerwAction(
                                        id: "nerw.shortcuts.run.\(name)",
                                        title: name,
                                        subtitle: "Run Shortcut",
                                        icon: .file(URL(fileURLWithPath: app.path)),
                                        triggers: [name],
                                        type: .instant(perform: { _ in
                                            Task {
                                                try? await ShortcutsManager.shared
                                                    .runShortcut(name)
                                            }
                                        })
                                    )
                                }
                                completion(actions)
                            } catch {
                                print("[SearchService] Shortcuts error: \(error)")
                                completion([])
                            }
                        }
                    },
                    perform: nil
                )
            )
        } else if app.name == "System Settings" {
            quickAction = NerwAction(
                id: "nerw.quick.systemsettings",
                title: "System Settings",
                subtitle: "Search preference panes",
                icon: .file(URL(fileURLWithPath: app.path)),
                triggers: [],
                type: .args(
                    placeholder: "Setting Name",
                    searcher: { _, query, completion in
                        System.shared.listSystemSettings(
                            query: query, completion: completion)
                    },
                    perform: nil
                )
            )
        }

        let performOpen: (NerwAction) -> Void = { _ in
            DispatchQueue.global(qos: .userInitiated).async {
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: app.path),
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }

        let actionType: NerwAction.ActionType
        if let qa = quickAction {
            actionType = .hybrid(perform: performOpen, action: NerwActionBox(qa))
        } else {
            actionType = .instant(perform: performOpen)
        }

        return NerwAction(
            id: "nerw.app.\(app.name)",
            title: app.name,
            subtitle: "Application",
            icon: .file(URL(fileURLWithPath: app.path)),
            triggers: [app.name.lowercased()],
            type: actionType
        )
    }

    private func rankResults(actions: [NerwAction], query: String, categoryResult: QueryCategory?)
        -> [NerwAction]
    {
        // 1. Separate by relevance/category
        var high: [NerwAction] = []
        var normal: [NerwAction] = []

        for action in actions {
            // Boost exact trigger matches
            let isExactTrigger = action.triggers.contains(where: {
                $0.lowercased() == query.lowercased()
            })

            if isExactTrigger {
                high.append(action)
                continue
            }

            if let cat = categoryResult, action.category == cat {
                high.append(action)
            } else {
                normal.append(action)
            }
        }

        // 2. Frecency sort within groups
        let sortedHigh = high.sorted { a, b in
            let scoreA = FrecencyManager.shared.score(
                for: a.id, query: query, sensitivity: .moderate)
            let scoreB = FrecencyManager.shared.score(
                for: b.id, query: query, sensitivity: .moderate)
            return scoreA > scoreB
        }

        let sortedNormal = normal.sorted { a, b in
            let scoreA = FrecencyManager.shared.score(
                for: a.id, query: query, sensitivity: .moderate)
            let scoreB = FrecencyManager.shared.score(
                for: b.id, query: query, sensitivity: .moderate)
            return scoreA > scoreB
        }

        return sortedHigh + sortedNormal
    }

    private func resolveIcon(for engine: Engine, domain: String) -> NerwAction.IconType? {
        if let iconStr = engine.icon {
            if let url = URL(string: iconStr), url.isFileURL {
                return .file(url)
            }
            if let icon = NSImage(named: NSImage.Name(iconStr)) {
                return .image(icon)
            }
            if let icon = IconManager.shared.icon(forKey: iconStr) {
                return .image(icon)
            }
        }

        if domain.contains("google.com") {
            if let icon = NSImage(named: "se_google") {
                return .image(icon)
            }
        }
        if domain.contains("duckduckgo.com") {
            if let icon = NSImage(named: "se_duckduckgo") {
                return .image(icon)
            }
        }
        if domain.contains("duck.ai") {
            if let icon = NSImage(named: "se_duckduckgo") {
                return .image(icon)
            }
        }

        if let icon = IconManager.shared.icon(for: domain) {
            return .image(icon)
        }

        return .system("globe")
    }

    private func createWebSearchAction(query: String, engine: Engine) -> NerwAction {
        let domain =
            URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
            ?? engine.name
        let iconType = self.resolveIcon(for: engine, domain: domain)

        // Add modifiers based on config
        var modifiers: [NerwAction.ModifierKey: NerwAction.ModifierAction] = [:]
        let configModifiers = ConfigManager.shared.config.searchEngineModifiers

        for (modStr, triggers) in configModifiers {
            if let modKey = NerwAction.ModifierKey(rawValue: modStr) {
                // Find engine for these triggers
                if let modEngine = SearchEngine.shared.engines.first(where: { e in
                    e.isEnabled && !Set(e.triggers).isDisjoint(with: triggers)
                }) {
                    let modDomain =
                        URL(string: modEngine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?
                        .host ?? modEngine.name
                    let modIcon = self.resolveIcon(for: modEngine, domain: modDomain)

                    modifiers[modKey] = NerwAction.ModifierAction(
                        title: "Search \(modEngine.name)",
                        subtitle: "Search for '\(query)' on \(modEngine.name)",
                        icon: modIcon,
                        perform: { _ in
                            let encodedQuery =
                                query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                                ?? ""
                            let urlString = String(format: modEngine.urlTemplate, encodedQuery)
                            if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }
        }

        return NerwAction(
            id: "nerw.web.search.\(engine.name)",
            title: "Search \(engine.name)",
            subtitle: "Search for '\(query)' on \(engine.name)",
            icon: iconType ?? .system("globe"),
            category: .webSearch,
            triggers: [],
            modifiers: modifiers,
            type: .instant(perform: { _ in
                let encodedQuery =
                    query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = String(format: engine.urlTemplate, encodedQuery)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            })
        )
    }
}
