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

        // 1. "Add Search Engine" Special Command
        if query.lowercased() == "add search engine" || query.lowercased() == "add" {
            newActions.append(
                NerwAction(
                    id: "nerw.builtin.addengine",
                    title: "Add Search Engine",
                    subtitle: "Add a custom search engine",
                    icon: .system("plus.circle"),
                    triggers: ["add search engine", "add"],
                    type: .arg(
                        placeholders: ["Search URL (use %s)", "Trigger Keyword"],
                        perform: { _, args in
                            if args.count >= 2 {
                                SearchEngine.shared.addEngine(url: args[0], trigger: args[1])
                            }
                        }
                    )
                ))
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

            bangAction = NerwAction(
                id: "nerw.web.search",  // Singular Action ID
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
                })
            )

            // If bang is detected, we return JUST this (or prioritize it).
            // Requirement implies: "make it google" as fallback.
            // If explicit bang is used, we probably want only that.
            completion([bangAction!])
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

        // 4. Check for Extension Triggers
        let components = query.split(separator: " ", maxSplits: 1)
        if let firstWord = components.first,
            let extensionManifest = ExtensionEngine.shared.extensions.first(where: {
                $0.trigger == String(firstWord)
            })
        {

            let arg = components.count > 1 ? String(components[1]) : ""

            // Run Extension
            ExtensionEngine.shared.runExtension(id: extensionManifest.id, query: arg) {
                extResults in
                DispatchQueue.main.async {
                    completion(newActions + extResults)
                }
            }
            return
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
                        icon: .system("xmark.circle"),
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
                        icon: .system("bolt.fill"),
                        triggers: [],
                        type: .args(
                            placeholder: "Search",
                            searcher: { _, query, completion in
                                FindFile.shared.search(query: query, completion: completion)
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

            // 6. DEFAULT FALLBACK: Google Search
            // If we are here, no bang was used. Add Google as a generic fallback.
            let defaultEngine = SearchEngine.shared.getDefaultEngine()
            let domain =
                URL(string: defaultEngine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?
                .host ?? defaultEngine.name
            let icon = IconManager.shared.icon(for: domain)
            if icon == nil { IconManager.shared.fetchIcon(for: domain) { _ in } }

            let fallbackAction = NerwAction(
                id: "nerw.web.search",  // Singular Action ID
                title: "Search \(defaultEngine.name)",
                subtitle: "Search for '\(currentQuery)' on \(defaultEngine.name)",
                icon: icon != nil ? .image(icon!) : .system("globe"),  // TODO: Use dynamic icon
                triggers: [],
                type: .instant(perform: { _ in
                    let encodedQuery =
                        currentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        ?? ""
                    let urlString = String(format: defaultEngine.urlTemplate, encodedQuery)
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                })
            )

            // Combine ALL actions (Apps + Fallback)
            let allActions = newActions + finalAppActions + [fallbackAction]

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

        if wordCount >= config.SearchEngineSuggestThreshold {
            // Check if top result is an exact match
            let topIsExact = sortedActions.first?.title.lowercased() == normalizedQuery

            if !topIsExact {
                // Find the fallback action
                if let fallbackIndex = sortedActions.firstIndex(where: {
                    $0.id == "nerw.web.search"
                }) {
                    let fallbackAction = sortedActions.remove(at: fallbackIndex)
                    // Move to top
                    sortedActions.insert(fallbackAction, at: 0)
                }
            }
        }

        return sortedActions
    }
}
