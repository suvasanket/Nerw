import Cocoa
import NerwCore
import NerwSearchBackend

public class SearchService {
    public static let shared = SearchService()

    // Concurrency control for App Search
    private var searchWorkItem: DispatchWorkItem?

    private init() {}

    public func search(query: String, completion: @escaping ([NerwAction]) -> Void) {

        // 0. Cancel previous pending search
        searchWorkItem?.cancel()

        // 1. Special Command: Manage Bangs (!bang) - Keep Strict for now as it's a CLI-like feature
        let lowerQuery = query.lowercased()
        if lowerQuery == "!bang add" || lowerQuery == "add !bang" || lowerQuery == "!bang new"
            || lowerQuery == "!bang create" || lowerQuery == "create !bang"
        {
            // ... (Keep existing logic or refactor later. For now, preserving strictly to avoid regression)
            // Re-implementing explicitly here for clarity/safety based on previous file content
            let newAction = NerwAction(
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
            completion([newAction])
            return
        }

        // Delete Bangs
        if lowerQuery.starts(with: "!bang delete") || lowerQuery.starts(with: "delete !bang") {
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

                let iconType = self.resolveIcon(for: engine, domain: domain)

                return NerwAction(
                    id: "nerw.builtin.bang.setdefault.\(engine.name)",
                    title: "Set Default: \(engine.name)",
                    subtitle: "Current Default: \(currentDefault.name)",
                    icon: iconType ?? .system("star"),
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
            completion([])
            return
        }

        // 1.5 Dictionary Define Detection
        if lowerQuery.starts(with: "define ") || lowerQuery.starts(with: "def ") {
            let prefix = lowerQuery.starts(with: "define ") ? "define " : "def "
            let wordToDefine = String(query.dropFirst(prefix.count)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if !wordToDefine.isEmpty {
                System.shared.searchDictionary(query: wordToDefine) { [weak self] dictActions in
                    guard let self = self else { return }
                    var results = dictActions

                    // Also append the default Web Search engine so the user has standard fallbacks available
                    let defaultEngine = SearchEngine.shared.getDefaultEngine()
                    let webSearchAction = self.createWebSearchAction(
                        query: query, engine: defaultEngine)
                    results.append(webSearchAction)

                    completion(results)
                }
                return
            }
        }

        // 1.6 Wikipedia Detection
        if lowerQuery.starts(with: "wiki ") {
            let wordToWiki = String(query.dropFirst(5)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if !wordToWiki.isEmpty {
                System.shared.searchWikipedia(query: wordToWiki) { [weak self] wikiActions in
                    guard let self = self else { return }
                    var results = wikiActions

                    // Append default web search fallback
                    let defaultEngine = SearchEngine.shared.getDefaultEngine()
                    let webSearchAction = self.createWebSearchAction(
                        query: query, engine: defaultEngine)
                    results.append(webSearchAction)

                    completion(results)
                }
                return
            }
        }

        // 2. Bang Search Detection (Explicit)
        // If user typed "!yt swift", we still probably want that to take precedence immediately
        // BUT, if they type "yt", we want "YouTube" (Bang) or "YouTube" (App) to appear via Fuzzy.
        // So we keep the helper resolveBang check for EXPLICIT bangs starting with "!"

        if let (engineName, urlTemplate, cleanedQuery) = SearchEngine.shared.resolveBang(
            query: query)
        {
            // ... Preserve existing logic ...
            let domain =
                URL(string: urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
                ?? engineName

            var iconType: NerwAction.IconType? = nil
            if let engine = SearchEngine.shared.engines.first(where: {
                $0.urlTemplate == urlTemplate
            }) {
                iconType = self.resolveIcon(for: engine, domain: domain)
            }

            let actionID = "nerw.web.search.\(engineName)"
            let bangAction = NerwAction(
                id: actionID,
                title: "Search \(engineName)",
                subtitle: "Search for '\(cleanedQuery)' on \(engineName)",
                icon: iconType ?? .system("globe"),
                triggers: [],
                modifiers: [
                    .shift: NerwAction.ModifierAction(
                        title: "Direct Search",
                        subtitle: "Open the first result directly",
                        icon: .system("se_direct"),
                        perform: { [weak self] _ in
                            self?.performDirectSearch(query: cleanedQuery)
                        })
                ],
                type: .instant(perform: { _ in
                    let encodedQuery =
                        cleanedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        ?? ""

                    let urlString = String(format: urlTemplate, encodedQuery)
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                })
            )
            completion([bangAction])
            return
        }

        // 3. UNIFIED SEARCH
        // We do everything else async
        let currentQuery = query
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.searchWorkItem?.isCancelled == true { return }

            // A. Aggregate Candidates
            var candidates: [NerwAction] = []

            // Builtin
            candidates.append(contentsOf: Nerw.shared.getAllActions())
            candidates.append(contentsOf: System.shared.getAllActions())
            candidates.append(FindFile.shared.getTriggerAction())

            // Shortcuts
            if ConfigManager.shared.config.showShortcutsInMain {
                candidates.append(contentsOf: ShortcutsEngine.shared.getAllActions())
            }

            // Extensions
            candidates.append(contentsOf: ExtensionEngine.shared.getAllEntryActions())

            // Apps
            let allApps = AppSearch.shared.getAllApps()
            // Map Apps to Actions
            let appActions = allApps.map { self.createAction(for: $0) }
            candidates.append(contentsOf: appActions)

            // B. Fuzzy Search
            // We search against "title" mainly. Triggers should be searchable too?
            // Fuse normally searches properties.
            // Let's create a Searchable wrapper or just search titles/triggers.
            // Since Fuse() API in use seems to be: fuse.searchSync(query, in: [String]) for simple use
            // Or we check how Fuse handles objects.
            // Since I don't see the Fuse library code fully, but I see `fuse.searchSync(currentQuery, in: appNames)` usage.
            // Assuming we want to match Titles AND Triggers.
            // Simplest way: Map candidates to a list of strings? No, that loses index mapping if multiple strings per item.
            // Better: Fuse usually supports searching objects with keys.
            // checking usage: `fuse.searchSync(currentQuery, in: appNames)` returns `(index, score, ranges)`.
            // So we can pass `candidates.map { $0.searchableString }` where searchableString = "Title" (or "Title Trigger")

            let searchStrings = candidates.map { action in
                // Combine Title and Triggers for broader matching
                // e.g. "GitHub gh"
                if action.triggers.isEmpty { return action.title }
                return action.title + " " + action.triggers.joined(separator: " ")
            }

            let fuse = Fuse()
            let results = fuse.searchSync(currentQuery, in: searchStrings)

            if self.searchWorkItem?.isCancelled == true { return }

            let matchedActions = results.map { candidates[$0.index] }

            // C. Fallback (Web Search)
            // Logic similar to before: if no good match, or if suggestion threshold met, add web search.
            // We'll create the fallback action regardless and let rankResults sort it.

            var fallbackAction: NerwAction? = nil
            if let topMatch = FrecencyManager.shared.getMostRecentID(for: currentQuery),
                topMatch.id.starts(with: "nerw.web.search.")
            {
                let prefix = "nerw.web.search."
                let engineName = String(topMatch.id.dropFirst(prefix.count))
                if let engine = SearchEngine.shared.engines.first(where: { $0.name == engineName })
                {
                    let domain =
                        URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?
                        .host ?? engine.name
                    let iconType = self.resolveIcon(for: engine, domain: domain)

                    fallbackAction = NerwAction(
                        id: topMatch.id,
                        title: "Search \(engine.name)",
                        subtitle: "Search for '\(currentQuery)' on \(engine.name)",
                        icon: iconType ?? .system("globe"),
                        triggers: [],
                        modifiers: [
                            .shift: NerwAction.ModifierAction(
                                title: "Direct Search",
                                subtitle: "Open the first result directly",
                                icon: .system("se_direct"),
                                perform: { [weak self] _ in
                                    self?.performDirectSearch(query: currentQuery)
                                })
                        ],
                        type: .instant(perform: { _ in
                            let encodedQuery =
                                currentQuery.addingPercentEncoding(
                                    withAllowedCharacters: .urlQueryAllowed) ?? ""

                            let urlString = String(format: engine.urlTemplate, encodedQuery)
                            if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
                        })
                    )
                }
            }

            if fallbackAction == nil {
                let defaultEngine = SearchEngine.shared.getDefaultEngine()
                fallbackAction = self.createWebSearchAction(
                    query: currentQuery, engine: defaultEngine)
            }

            // D. Combine & Rank
            let finalResults = matchedActions + [fallbackAction!]
            let ranked = self.rankResults(actions: finalResults, query: currentQuery)

            DispatchQueue.main.async {
                completion(ranked)
            }
        }

        searchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func createAction(for app: AppSearch.AppInfo) -> NerwAction {
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
        let iconType = resolveIcon(for: engine, domain: domain)

        let actionID = "nerw.web.search.\(engine.name)"

        return NerwAction(
            id: actionID,
            title: "Search \(engine.name)",
            subtitle: "Search for '\(query)' on \(engine.name)",
            icon: iconType ?? .system("globe"),
            triggers: [],
            modifiers: [
                .shift: NerwAction.ModifierAction(
                    title: "Direct Search",
                    subtitle: "Open the first result directly",
                    icon: .system("se_direct"),
                    perform: { [weak self] _ in
                        self?.performDirectSearch(query: query)
                    })
            ],
            type: .instant(perform: { _ in
                let encodedQuery =
                    query.addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed) ?? ""

                let urlString = String(format: engine.urlTemplate, encodedQuery)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            })
        )
    }

    private func resolveIcon(for engine: Engine, domain: String) -> NerwAction.IconType? {
        // 1. Custom icon set by user via drag-and-drop (stored in IconManager by key)
        if let key = engine.icon, let image = IconManager.shared.icon(forKey: key) {
            return .image(image)
        }

        // 2. Built-in asset name (e.g. "smart")
        if let key = engine.icon, let image = NSImage(named: NSImage.Name(key)) {
            return .image(image)
        }

        // 3. Try to resolve by domain (favicons)
        if let image = IconManager.shared.icon(for: domain) {
            return .image(image)
        } else {
            // Trigger background fetch for next time
            IconManager.shared.fetchIcon(for: domain) { _ in }
        }

        // 4. No icon — caller provides fallback
        return nil
    }

    private func performDirectSearch(query: String) {
        let encodedQuery =
            query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Google's I'm Feeling Lucky
        let urlString = "https://www.google.com/search?q=\(encodedQuery)&btnI=1"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
