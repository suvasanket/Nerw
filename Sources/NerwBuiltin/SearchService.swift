import Cocoa
import NerwCore
import NerwSearchBackend

public class SearchService {
    public static let shared = SearchService()

    // Concurrency control for App Search
    private var searchWorkItem: DispatchWorkItem?

    private init() {}

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
        var candidates: [NerwAction] = []

        // Builtin
        candidates.append(contentsOf: Nerw.shared.getAllActions())
        candidates.append(contentsOf: System.shared.getAllActions())
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
            guard let self = self else { return }
            if self.searchWorkItem?.isCancelled == true { return }

            // Fuzzy Search Candidates
            let searchStrings = allCandidates.map { action in
                if action.triggers.isEmpty { return action.title }
                return action.title + " " + action.triggers.joined(separator: " ")
            }

            let fuse = Fuse()
            let results = fuse.searchSync(query, in: searchStrings)
            if self.searchWorkItem?.isCancelled == true { return }

            let matchedActions = results.map { allCandidates[$0.index] }

            // Web Fallback
            var fallbackAction: NerwAction? = nil
            if let topMatch = FrecencyManager.shared.getMostRecentID(for: query),
                topMatch.id.starts(with: "nerw.web.search.")
            {
                let engineName = String(topMatch.id.dropFirst("nerw.web.search.".count))
                if let engine = SearchEngine.shared.engines.first(where: { $0.name == engineName })
                {
                    fallbackAction = self.createWebSearchAction(query: query, engine: engine)
                }
            }

            if fallbackAction == nil {
                fallbackAction = self.createWebSearchAction(
                    query: query, engine: SearchEngine.shared.getDefaultEngine())
            }

            // NLP Rank
            let catResult = QueryCategorizer.shared.classifySync(query)
            let ranked = self.rankResults(
                actions: matchedActions + [fallbackAction!], query: query,
                categoryResult: catResult.category)

            DispatchQueue.main.async {
                if self.searchWorkItem?.isCancelled == false {
                    completion(ranked)
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

    private func createAction(for app: AppSearch.AppInfo) -> NerwAction {
        return NerwAction(
            id: "nerw.app.\(app.name)",
            title: app.name,
            subtitle: "Application",
            icon: .file(URL(fileURLWithPath: app.path)),
            triggers: [app.name.lowercased()],
            type: .instant(perform: { _ in
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: app.path),
                    configuration: NSWorkspace.OpenConfiguration()
                )
            })
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
        if let iconStr = engine.icon, let url = URL(string: iconStr) {
            if url.isFileURL { return .file(url) }
        }

        if domain.contains("google.com") { return .image(NSImage(named: "se_google")!) }
        if domain.contains("duckduckgo.com") { return .image(NSImage(named: "se_duckduckgo")!) }

        return .system("globe")
    }

    private func createWebSearchAction(query: String, engine: Engine) -> NerwAction {
        let domain =
            URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host
            ?? engine.name
        let iconType = self.resolveIcon(for: engine, domain: domain)

        return NerwAction(
            id: "nerw.web.search.\(engine.name)",
            title: "Search \(engine.name)",
            subtitle: "Search for '\(query)' on \(engine.name)",
            icon: iconType ?? .system("globe"),
            category: .webSearch,
            triggers: [],
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
