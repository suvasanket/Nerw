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
            case .args, .arg, .form:
                // For args/form, we probably want to open the UI and focus that action
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
                            id: "triggers", title: "Triggers",
                            placeholder: "e.g. gh g (space separated)"),
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
                            let triggersStr = values["triggers"],
                            let url = values["url"],
                            !name.isEmpty, !triggersStr.isEmpty, !url.isEmpty
                        else { return }

                        let triggers = triggersStr.components(separatedBy: .whitespaces).filter {
                            !$0.isEmpty
                        }
                        let icon = values["icon"]?.isEmpty == false ? values["icon"] : nil

                        SearchEngine.shared.addEngine(
                            name: name, url: url, triggers: triggers, icon: icon)
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
            let candidates = self.getCandidates()

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

    private let directSearchSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(
            configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }()

    private func performDirectSearch(query: String) {
        // 1. Check Cache
        if let cachedURL = DirectSearchCache.shared.get(for: query),
            let url = URL(string: cachedURL)
        {
            NSWorkspace.shared.open(url)
            return
        }

        let engine = ConfigManager.shared.config.directSearchEngine
        let engineName = engine == .google ? "Google" : "DuckDuckGo"
        let notificationID = NerwSystem.shared.ui?.showNotification(
            content: "Getting direct result from \(engineName)...",
            level: .info,
            progressive: true,
            id: nil
        )

        Task {
            let result: String?

            switch engine {
            case .google:
                result = await searchGoogleFirstResult(query: query)
            case .duckDuckGo:
                result = await searchDuckDuckGoFirstResult(query: query)
            }

            DispatchQueue.main.async {
                if let notifID = notificationID {
                    NerwSystem.shared.ui?.dismissNotification(id: notifID)
                }

                if let result = result, let url = URL(string: result) {
                    // Success: Cache and Open
                    DirectSearchCache.shared.set(url: result, for: query)
                    NSWorkspace.shared.open(url)
                } else {
                    // Fallback to normal search
                    let encodedQuery =
                        query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let fallbackURL =
                        engine == .google
                        ? "https://www.google.com/search?q=\(encodedQuery)"
                        : "https://duckduckgo.com/?q=\(encodedQuery)"
                    if let url = URL(string: fallbackURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    // MARK: - Direct Search Helpers (from websearch.swift)

    private func searchGoogleFirstResult(query: String) async -> String? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://www.google.com/search?q=\(encoded)&btnI=1")
        else { return nil }

        return await fetchRedirectLocation(
            url: url, method: "GET", acceptGoogleStyleExtraction: true)
    }

    private func searchDuckDuckGoFirstResult(query: String) async -> String? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }

        guard let url = URL(string: "https://duckduckgo.com/?q=\\\(encoded)") else {
            return nil
        }

        if let result = await fetchRedirectLocation(
            url: url, method: "HEAD", acceptGoogleStyleExtraction: false)
        {
            return result
        }

        if let result = await fetchRedirectLocation(
            url: url, method: "GET", acceptGoogleStyleExtraction: false)
        {
            return result
        }

        return await searchDuckDuckGoLite(query: query)
    }

    private func searchDuckDuckGoLite(query: String) async -> String? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://lite.duckduckgo.com/lite/?q=\(encoded)")
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await directSearchSession.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            if let range = html.range(of: "uddg=") {
                let after = html[range.upperBound...]
                if let end = after.range(of: "&amp;") ?? after.range(of: "&")
                    ?? after.range(of: "\"")
                {
                    let encodedURL = String(after[..<end.lowerBound])
                    if let decoded = encodedURL.removingPercentEncoding, decoded.hasPrefix("http") {
                        return decoded
                    }
                }
            }

            // Additional fallback patterns
            if let href = firstMatch(in: html, pattern: #"href="(https?://[^"]+)""#) {
                return href
            }

            return nil
        } catch {
            return nil
        }
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let r = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[r])
    }

    private func fetchRedirectLocation(
        url: URL, method: String, acceptGoogleStyleExtraction: Bool
    ) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await directSearchSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if let location = http.value(forHTTPHeaderField: "Location") {
                if location.hasPrefix("http") {
                    if acceptGoogleStyleExtraction && location.contains("google.") {
                        if let u = extractURLParameter(from: location, param: "url") { return u }
                        if let u = extractURLParameter(from: location, param: "q") { return u }
                    }
                    return location
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    private func extractURLParameter(from urlString: String, param: String) -> String? {
        guard let components = URLComponents(string: urlString),
            let value = components.queryItems?.first(where: { $0.name == param })?.value,
            value.hasPrefix("http")
        else {
            return nil
        }
        return value
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
