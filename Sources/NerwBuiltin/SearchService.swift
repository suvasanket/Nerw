import Cocoa
import NerwCore
import NerwSearchBackend

public class SearchService {
    public static let shared = SearchService()

    // Concurrency control for App Search
    private var searchWorkItem: DispatchWorkItem?

    private init() {}

    public func search(query: String, completion: @escaping ([NerwAction]) -> Void) {

        var newActions: [NerwAction] = []

        // 1. Special Command: Manage Bangs (!bang)
        let lowerQuery = query.lowercased()
        if lowerQuery == "!bang add" || lowerQuery == "add !bang" || lowerQuery == "!bang new"
            || lowerQuery == "!bang create" || lowerQuery == "create !bang"
        {
            newActions.append(
                NerwAction(
                    id: "nerw.builtin.managebang.add",
                    title: "Add New Bang",
                    subtitle: "Create a new bang shortcut",
                    icon: .system("plus.circle"),
                    triggers: [],
                    type: .form(
                        fields: [
                            NerwAction.Field(id: "name", title: "Name", placeholder: "e.g. GitHub"),
                            NerwAction.Field(
                                id: "trigger", title: "Trigger", placeholder: "e.g. gh (without !)"),
                            NerwAction.Field(
                                id: "url", title: "URL Template",
                                placeholder: "https://site.com?q=%s"),
                            NerwAction.Field(
                                id: "icon", title: "Icon URL (Optional)",
                                placeholder: "e.g. https://site.com/icon.png"),
                        ],
                        submitLabel: "Add Bang",
                        perform: { _, values in
                            guard let name = values["name"],
                                let trigger = values["trigger"],
                                let url = values["url"],
                                !name.isEmpty, !trigger.isEmpty, !url.isEmpty
                            else { return }

                            let icon = values["icon"]?.isEmpty == false ? values["icon"] : nil

                            SearchEngine.shared.addEngine(
                                name: name, url: url, trigger: trigger, icon: icon)
                        }
                    )
                )
            )
            completion(newActions)
            return
        }

        // Delete Bangs
        if lowerQuery.starts(with: "!bang delete") || lowerQuery.starts(with: "delete !bang")
            || lowerQuery.starts(with: "!bang remove") || lowerQuery.starts(with: "remove !bang")
        {
            let engines = SearchEngine.shared.engines
            let deleteActions = engines.map { engine in
                NerwAction(
                    id: "nerw.builtin.bang.delete.\(engine.name)",
                    title: "Delete \(engine.name)",
                    subtitle: "Triggers: \(engine.triggers.joined(separator: ", "))",
                    icon: .system("trash"),
                    triggers: [],
                    type: .instant(perform: { _ in
                        SearchEngine.shared.removeEngine(name: engine.name)
                        // Ideally trigger a refresh or notify
                        // Since we can't easily toast, we just close session
                    })
                )
            }
            completion(deleteActions)
            return
        }

        // Set Default Bang
        if lowerQuery == "!bang default" || lowerQuery == "default !bang"
            || lowerQuery == "!default"
        {
            let currentDefault = SearchEngine.shared.getDefaultEngine()
            let engines = SearchEngine.shared.engines

            let defaultActions = engines.compactMap { engine -> NerwAction? in
                guard engine.name != currentDefault.name else { return nil }

                let domain =
                    URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
                    ?? engine.name
                let icon = IconManager.shared.icon(for: domain)
                if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

                return NerwAction(
                    id: "nerw.builtin.bang.setdefault.\(engine.name)",
                    title: "Set Default: \(engine.name)",
                    subtitle: "Current Default: \(currentDefault.name)",
                    icon: icon != nil ? .image(icon!) : .system("star"),
                    triggers: [],
                    type: .instant(perform: { _ in
                        SearchEngine.shared.setDefaultEngine(engine)
                    })
                )
            }
            completion(defaultActions)
            return
        }

        guard !query.isEmpty else {
            completion(newActions)
            return
        }

        // 2. Bang Search Detection
        // Capture bang result primarily
        var bangAction: NerwAction? = nil

        if let (engineName, urlTemplate, cleanedQuery) = SearchEngine.shared.resolveBang(
            query: query)
        {
            let domain =
                URL(string: urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
                ?? engineName
            let icon = IconManager.shared.icon(for: domain)
            if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

            let actionID = "nerw.web.search.\(engineName)"

            bangAction = NerwAction(
                id: actionID,  // Unique ID per engine
                title: "Search \(engineName)",
                subtitle: "Search for '\(cleanedQuery)' on \(engineName)",
                icon: icon != nil ? .image(icon!) : .system("globe"),
                triggers: [],
                type: .instant(perform: { _ in
                    let encodedQuery =
                        cleanedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        ?? ""
                    let urlString = String(format: urlTemplate, encodedQuery)
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                    // RECORD USAGE FOR CLEAN QUERY TOO
                    // This enables "suggest previously used bang search for the exact query"
                    // i.e. If I type "!yt swift", I record usage for "swift" -> YouTube.
                    // Next time I type "swift", I can suggest YouTube.
                    FrecencyManager.shared.recordUsage(id: actionID, forQuery: cleanedQuery)
                })
            )

            // If explicit bang is used, we probably want only that.
            completion([bangAction!])
            return
        }

        // 2.5 Strict Bang Guard
        if query.starts(with: "!") {
            // If we are here, resolveBang failed (invalid or partial bang).
            // Prevent App/System search leakage.
            let defaultEngine = SearchEngine.shared.getDefaultEngine()
            let fallback = createWebSearchAction(query: query, engine: defaultEngine)
            completion([fallback])
            return
        }

        // 3. Built-in Extensions
        if let find = FindFile.shared.check(query: query) {
            newActions.append(find)
        }
        if let result = Nerw.shared.check(query: query) {
            newActions.append(result)
        }
        if let system = System.shared.check(query: query) {
            newActions.append(system)
        }

        // 3.5 Shortcuts (If Enabled)
        if ConfigManager.shared.config.showShortcutsInMain {
            let shortcuts = ShortcutsEngine.shared.search(query: query)
            newActions.append(contentsOf: shortcuts)
        }

        // 4. Check for Extension Triggers
        let components = query.split(separator: " ", maxSplits: 1)
        if let firstWord = components.first {
            let extensions = ExtensionEngine.shared.extensions
            // print("[SearchService] Checking trigger '\(firstWord)' against \(extensions.count) extensions: \(extensions.map { $0.trigger })")

            if let extensionManifest = extensions.first(where: {
                $0.allTriggers.contains(where: { $0.lowercased() == String(firstWord).lowercased() }
                )
            }) {

                let arg = components.count > 1 ? String(components[1]) : ""

                // Run Extension
                ExtensionEngine.shared.runExtension(
                    id: extensionManifest.id, query: arg, trigger: String(firstWord)
                ) {
                    extResults in
                    DispatchQueue.main.async {
                        completion(newActions + extResults)
                    }
                }
                return
            }
        }

        // 5. Default App Search (Fallback) - Async
        let currentQuery = query
        // Cancel previous pending search
        searchWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            if self.searchWorkItem?.isCancelled == true { return }

            // fetch all apps - cached internally by AppSearch
            let allApps = AppSearch.shared.getAllApps()

            if self.searchWorkItem?.isCancelled == true { return }

            let fuse = Fuse()
            let appNames = allApps.map { $0.name }
            let searchResults = fuse.searchSync(currentQuery, in: appNames)

            if self.searchWorkItem?.isCancelled == true { return }

            let finalAppActions = searchResults.map { result -> NerwAction in
                let app = allApps[result.index]

                var quickAction: NerwAction? = nil

                // --- Quick Action Injection ---
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
                // -----------------------------

                let performOpen: (NerwAction) -> Void = { _ in
                    DispatchQueue.global(qos: .userInitiated).async {
                        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
                    }
                }

                let type: NerwAction.ActionType
                if let qa = quickAction {
                    type = .hybrid(perform: performOpen, action: NerwActionBox(qa))
                } else {
                    type = .instant(perform: performOpen)
                }

                return NerwAction(
                    id: "nerw.app." + app.path,
                    title: app.name,
                    subtitle: "Application",
                    icon: .file(URL(fileURLWithPath: app.path)),
                    triggers: [app.name],
                    type: type
                )
            }

            // 6. DEFAULT FALLBACK: Google Search OR History Suggestion
            // First check if we have a preferred engine for this query in history
            var fallbackAction: NerwAction? = nil

            // Use Strict Recency (Most Recent) instead of Frecency Score to allow immediate switching
            if let topMatch = FrecencyManager.shared.getMostRecentID(for: currentQuery),
                topMatch.id.starts(with: "nerw.web.search.")
            {

                // Extract Engine Name "nerw.web.search.YouTube" -> "YouTube"
                let prefix = "nerw.web.search."
                let engineName = String(topMatch.id.dropFirst(prefix.count))
                // Find matching engine info to rebuild action
                // Using SearchEngine.shared implies we need access to engines list or helper
                // SearchService doesn't have direct access, but SearchEngine does.
                // We'll iterate engines in SearchEngine (public access)

                if let engine = SearchEngine.shared.engines.first(where: { $0.name == engineName })
                {
                    let domain =
                        URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?
                        .host ?? engine.name
                    let icon = IconManager.shared.icon(for: domain)
                    if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

                    fallbackAction = NerwAction(
                        id: topMatch.id,
                        title: "Search \(engine.name)",
                        subtitle: "Search for '\(currentQuery)' on \(engine.name)",
                        icon: icon != nil ? .image(icon!) : .system("globe"),
                        triggers: [],
                        type: .instant(perform: { _ in
                            let encodedQuery =
                                currentQuery.addingPercentEncoding(
                                    withAllowedCharacters: .urlQueryAllowed) ?? ""
                            let urlString = String(format: engine.urlTemplate, encodedQuery)
                            if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                            FrecencyManager.shared.recordUsage(
                                id: topMatch.id, forQuery: currentQuery)
                        })
                    )
                }
            }

            // If no history match (or failed to rebuild), use Default Google
            if fallbackAction == nil {
                let defaultEngine = SearchEngine.shared.getDefaultEngine()
                fallbackAction = createWebSearchAction(query: currentQuery, engine: defaultEngine)
            }

            // Combine ALL actions
            // Fallback action is guaranteed to exist now (either history or default)
            let allActions = newActions + finalAppActions + [fallbackAction!]

            // Ranking
            let rankedActions = self.rankResults(actions: allActions, query: currentQuery)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.searchWorkItem?.isCancelled == false else { return }

                completion(rankedActions)
            }
        }

        searchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // Helper to allow delegation of sub-searchers (Argument Mode)
    public func delegateSearch(
        action: NerwAction, query: String, completion: @escaping ([NerwAction]) -> Void
    ) {
        if case .args(_, let searcher, _) = action.type {
            searcher(action, query, completion)
        } else {
            completion([])
        }
    }

    private func rankResults(actions: [NerwAction], query: String) -> [NerwAction] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        var exactMatches: [(action: NerwAction, score: Double)] = []
        var frecencyBoosted: [(action: NerwAction, score: Double)] = []
        var otherActions: [NerwAction] = []

        for action in actions {
            // Use combined score: Moderate for Smart Keys, Low for Global
            let totalScore = FrecencyManager.shared.combinedScore(
                for: action.id,
                query: query,
                matchText: action.title,  // Pass title for prefix matching condition
                querySensitivity: .moderate,
                globalSensitivity: .low
            )

            let isExact = action.title.lowercased() == normalizedQuery

            if isExact {
                exactMatches.append((action, totalScore))
            } else if totalScore > 0 {
                frecencyBoosted.append((action, totalScore))
            } else {
                otherActions.append(action)
            }
        }

        // Sort Exact Matches & Frecency Boosted by score (descending)
        exactMatches.sort { $0.score > $1.score }
        frecencyBoosted.sort { $0.score > $1.score }

        var sortedActions =
            exactMatches.map({ $0.action }) + frecencyBoosted.map({ $0.action }) + otherActions

        // Fallback Boosting Logic
        // If word count is high enough and we don't have an exact match at the top,
        // assume the user might want to search the web (fallback).
        let config = ConfigManager.shared.config
        let wordCount = normalizedQuery.split(separator: " ").count

        if wordCount >= config.searchEngineSuggestThreshold {
            // Check if top result is an exact match
            let topIsExact = sortedActions.first?.title.lowercased() == normalizedQuery

            if !topIsExact {
                // Find the fallback action
                // Check prefix since IDs are now nerw.web.search.<engine>
                if let fallbackIndex = sortedActions.firstIndex(where: {
                    $0.id.hasPrefix("nerw.web.search.")
                }) {
                    let fallbackAction = sortedActions.remove(at: fallbackIndex)
                    // Move to top
                    sortedActions.insert(fallbackAction, at: 0)
                }
            }
        }

        return sortedActions
    }

    private func createWebSearchAction(query: String, engine: Engine) -> NerwAction {
        let domain =
            URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?
            .host ?? engine.name
        let icon = IconManager.shared.icon(for: domain)
        if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

        let actionID = "nerw.web.search.\(engine.name)"

        return NerwAction(
            id: actionID,
            title: "Search \(engine.name)",
            subtitle: "Search for '\(query)' on \(engine.name)",
            icon: icon != nil ? .image(icon!) : .system("globe"),
            triggers: [],
            type: .instant(perform: { _ in
                let encodedQuery =
                    query.addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = String(format: engine.urlTemplate, encodedQuery)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
                FrecencyManager.shared.recordUsage(id: actionID, forQuery: query)
            })
        )
    }
}
