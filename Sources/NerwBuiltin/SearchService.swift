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
            newActions.append(NerwAction(
                id: "nerw.builtin.addengine",
                title: "Add Search Engine",
                subtitle: "Add a custom search engine",
                icon: .system("plus.circle"),
                triggers: ["add search engine", "add"],
                arguments: ["Search URL (use %s)", "Trigger Keyword"],
                handler: { _ in },
                searcher: nil
            ))
        }

        guard !query.isEmpty else {
            completion(newActions)
            return
        }

        // 2. Built-in Extensions & Search Engines
        if let find = FindFile.shared.check(query: query) {
            newActions.append(find)
        }
        if let result = Nerw.shared.check(query: query) {
            newActions.append(result)
        }
        if let system = System.shared.check(query: query) {
            newActions.append(system)
        }
        if let engineResult = SearchEngine.shared.check(query: query) {
            newActions.append(engineResult)
        }

        // 3. Check for Extension Triggers
        let components = query.split(separator: " ", maxSplits: 1)
        if let firstWord = components.first,
           let extensionManifest = ExtensionEngine.shared.extensions.first(where: { $0.trigger == String(firstWord) }) {

            let arg = components.count > 1 ? String(components[1]) : ""

            // Run Extension
            ExtensionEngine.shared.runExtension(id: extensionManifest.id, query: arg) { extResults in
                // Extensions return async, but usually fast. Combine and return.
                // Note: This pattern might return BEFORE app search if app search is slow,
                // but here we return immediately for extensions and don't do app search?
                // The original code returned immediately if extension matched.
                // Preserving original behavior:
                DispatchQueue.main.async {
                    completion(newActions + extResults)
                }
            }
            return
        }

        // 4. Default App Search (Fallback) - Async
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
                        arguments: ["Process Name"],
                        handler: { _ in }, // Searcher handles selection logic mostly
                        searcher: { query, completion in
                            QuickAction.shared.searchProcesses(query: query, completion: completion)
                        }
                    )
                } else if app.name.lowercased() == "finder" {
                     quickAction = NerwAction(
                        id: "nerw.quick.findfile",
                        title: "Find File",
                        subtitle: "Search or open finder",
                        icon: .system("bolt.fill"),
                        triggers: [],
                        arguments: ["Search"],
                        handler: { _ in },
                        searcher: { query, completion in
                            FindFile.shared.search(query: query, completion: completion)
                        }
                     )
                }
                // -----------------------------

                return NerwAction(
                    id: "nerw.app." + app.path,
                    title: app.name,
                    subtitle: "Application",
                    icon: .image(NSWorkspace.shared.icon(forFile: app.path)),
                    triggers: [app.name],
                    arguments: nil,
                    handler: { _ in
                        DispatchQueue.global(qos: .userInitiated).async {
                            NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
                        }
                    },
                    quickAction: quickAction
                )
            }

            // Smart Suggestions
            let suggestions = SearchEngine.shared.getSuggestions(for: currentQuery)

            // Combine ALL actions
            let allActions = newActions + finalAppActions + suggestions

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
    public func delegateSearch(action: NerwAction, query: String, completion: @escaping ([NerwAction]) -> Void) {
        if let searcher = action.searcher {
            searcher(query, completion)
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
                matchText: action.title, // Pass title for prefix matching condition
                querySensitivity: .moderate,
                globalSensitivity: .low
            )

            let isExact = action.title.lowercased() == normalizedQuery

            if isExact {
                // Keep exact matches high, but if there's a Smart Suggestion involved, it might have a higher score.
                // We'll treat Exact matching as a "base score" boost if needed, but let's see.
                // Usually Exact Match is purely textual.
                // We will add it to 'exactMatches' bucket which is sorted by score.
                // If it ALSO has a high frecency score, it will be at top of that bucket.
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

        var sortedActions = exactMatches.map({$0.action}) + frecencyBoosted.map({$0.action}) + otherActions

        // Smart Suggestions Logic (Bubbling)
        let config = ConfigManager.shared.config
        let wordCount = normalizedQuery.split(separator: " ").count

        // Condition 1: Word Count >= Threshold
        if wordCount >= config.SearchEngineSuggestThreshold {
            // Condition 2: Top result is NOT an exact match
            if let first = sortedActions.first, first.title.lowercased() != normalizedQuery {
                // Extract Search Suggestions from the list and move to top
                let suggestionActions = sortedActions.filter { action in
                    return action.id.hasSuffix(".suggestion")
                }

                if !suggestionActions.isEmpty {
                    let withoutSuggestions = sortedActions.filter { action in !suggestionActions.contains(where: { s in s.id == action.id }) }
                    // Prepend to top
                    sortedActions = suggestionActions + withoutSuggestions
                }
            }
        }

        return sortedActions
    }
}
