import Cocoa
import NerwAction
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

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(configDidUpdate),
            name: Notification.Name("NerwConfigDidUpdate"),
            object: nil)
    }

    @objc private func configDidUpdate() {
        clearCache()
    }

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
            case .inlineArg, .args, .arg, .form:
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
        var cache = cachedCandidates
        if !loaded {
            cache = buildCandidates()
            cachedCandidates = cache
            isCacheLoaded = true
            cacheLock.unlock()
        } else {
            cacheLock.unlock()
        }
        return cache
    }

    private func buildCandidates() -> [NerwAction] {
        return autoreleasepool {
            var candidates: [NerwAction] = []

            // Builtin
            candidates.append(contentsOf: Nerw.shared.getAllActions())
            candidates.append(contentsOf: System.shared.getAllActions())
            if ConfigManager.shared.config.clipboardEnabled {
                candidates.append(contentsOf: ClipboardManager.builtinActions())
            }
            if ConfigManager.shared.config.snippetExpansionEnabled {
                candidates.append(contentsOf: SnippetManager.builtinActions())
            }
            if ConfigManager.shared.config.bookmarksEnabled {
                candidates.append(contentsOf: BookmarkManager.builtinActions())
            }
            candidates.append(contentsOf: MenubarSearch.builtinActions())
            candidates.append(contentsOf: SearchEngine.builtinActions())
            candidates.append(FindFile.shared.getTriggerAction())

            // Shortcuts
            if ConfigManager.shared.config.showShortcutsInMain {
                candidates.append(contentsOf: ShortcutsEngine.shared.getAllActions())
            }

            // Extensions
            candidates.append(contentsOf: ExtensionEngine.shared.getAllEntryActions())

            // Apps
            let allApps = AppSearch.shared.getAllApps()
            let appActions = allApps.map { self.createAction(for: $0) }
            candidates.append(contentsOf: appActions)

            // Filter disabled actions
            candidates = candidates.filter { action in
                NerwActionEnabled.get(for: action.id)
            }

            return candidates
        }
    }

    public func search(query: String, completion: @escaping ([NerwAction], [NerwAction]) -> Void) {
        // 0. Cancel previous pending search
        searchWorkItem?.cancel()

        // 1. Unified Search Entry
        let lowerQuery = query.lowercased()
        var allCandidates = self.getCandidates()

        // Filter out hidden actions from search results
        allCandidates = allCandidates.filter { action in
            let isHidden = NerwActionHidden.get(for: action.id)
            let hasHotkey = !NerwActionHotkey.get(for: action.id).isEmpty
            return !(isHidden && hasHotkey)
        }

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

                                // Append all fallbacks
                                let fallbacks = FallbackSearchService.shared.getFallbackActions(
                                    for: query, allCandidates: allCandidates)

                                for fallback in fallbacks {
                                    if !results.contains(where: { $0.id == fallback.id }) {
                                        results.append(fallback)
                                    }
                                }
                                completion(results, fallbacks)
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
                        completion([inlineAction], [])
                        return
                    }
                }
            }
        }

        // 3. Bang Search Detection
        if let (engineName, urlTemplate, cleanedQuery) = SearchEngine.shared.resolveBang(
            query: query)
        {
            let bangAction = WebSearchService.shared.createWebSearchAction(
                query: cleanedQuery,
                engine: Engine(
                    name: engineName, triggers: [], urlTemplate: urlTemplate))
            completion([bangAction], [])
            return
        }

        guard !query.isEmpty else {
            completion([], [])
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

                // Fallbacks
                var fallbacks: [NerwAction] = []

                // If Frecency suggests a specific top web search, we can include it or rely on the configured fallbacks.
                // To keep it simple and powerful, we just fetch all user-configured fallbacks.
                let configuredFallbacks = FallbackSearchService.shared.getFallbackActions(
                    for: query, allCandidates: allCandidates)

                // We'll append all configured fallbacks that aren't already in matchedActions
                for fb in configuredFallbacks {
                    if !matchedActions.contains(where: { $0.id == fb.id }) {
                        fallbacks.append(fb)
                    }
                }

                // NLP Rank
                let catResult = QueryCategorizer.shared.classifySync(query)
                var allActions = matchedActions
                allActions.append(contentsOf: fallbacks)

                var ranked = self.rankResults(
                    actions: allActions, query: query,
                    categoryResult: catResult.category)

                Task {
                    if catResult.category == .mathConversion
                        || MathConversionDetector.shared.detect(query: query) != nil
                    {
                        if let mathAction = await MathConversionService.shared.evaluate(
                            query: query)
                        {
                            ranked.insert(mathAction, at: 0)
                        }
                    }

                    DispatchQueue.main.async {
                        if self.searchWorkItem?.isCancelled == false {
                            completion(ranked, configuredFallbacks)
                        }
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
                icon: ShortcutsEngine.shared.icon,
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
                                        icon: ShortcutsEngine.shared.icon,
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
            subtitle: "",
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

}
