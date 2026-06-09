import Cocoa
import Foundation
import NerwAction
import NerwCore
import NerwSearchBackend
import NerwUtils

struct LoadedExtension {
    let manifest: ExtensionManifest
    let path: URL
    let binaryPath: URL?
}

/// Represents a message sent to the extension process via stdin.
public struct ExtensionInput: Codable {
    public let type: String  // "query" or "action"
    public let query: String?
    public let triggers: [String]?
    public let function: String?
    public let args: [String]?
    public let formValues: [String: String]?
    public let settings: [String: AnyCodable]?
}

/// Represents a command returned by the extension process via stdout for action execution.
public struct ExtensionCommand: Codable {
    public let type: String  // "open", "copy", "log", "notify", "dismiss_notify", "show_panel", "hide_host"
    public let value: String?
    public let level: String?
    public let progressive: Bool?
    public let id: String?
    public let title: String?
    public let width: Double?
    public let height: Double?
}

/// Wrapper for command responses from action execution.
public struct ExtensionActionResponse: Codable {
    public let commands: [ExtensionCommand]?
}

public class ExtensionEngine {
    public static let shared = ExtensionEngine()

    var loadedExtensions: [LoadedExtension] = []

    // Public getter for UI
    public var extensions: [ExtensionManifest] {
        loadedExtensions.map { $0.manifest }
    }

    public func getAllEntryActions() -> [NerwAction] {
        var actions: [NerwAction] = []
        for ext in loadedExtensions {
            let manifest = ext.manifest
            for actionManifest in manifest.actions {
                let action = createAction(
                    manifest: manifest, path: ext.path, actionManifest: actionManifest)
                actions.append(action)
            }
        }
        return actions
    }

    private func createAction(
        manifest: ExtensionManifest, path: URL, actionManifest: ExtensionActionManifest,
        overrideTrigger: String? = nil
    ) -> NerwAction {
        let triggers = actionManifest.triggers
        let primaryTrigger = overrideTrigger ?? triggers.first ?? ""

        let actionType: NerwAction.ActionType
        if actionManifest.type == "inlineArg" {
            actionType = .inlineArg(
                perform: { [weak self] _, arg in
                    self?.performAction(
                        actionManifest.function ?? actionManifest.name, extensionId: manifest.id,
                        args: [arg])
                },
                searcher: { [weak self] _, arg, completion in
                    self?.runExtension(
                        id: manifest.id, query: arg, trigger: primaryTrigger,
                        functionName: actionManifest.function ?? actionManifest.name,
                        completion: completion)
                }
            )
        } else if actionManifest.type == "noArg" {
            actionType = .instant(
                perform: { [weak self] _ in
                    self?.performAction(
                        actionManifest.function ?? actionManifest.name, extensionId: manifest.id,
                        args: [])
                }
            )
        } else {
            actionType = .args(
                placeholder: "Query...",
                searcher: { [weak self] _, query, completion in
                    self?.runExtension(
                        id: manifest.id, query: query, trigger: primaryTrigger,
                        functionName: actionManifest.function ?? actionManifest.name,
                        completion: completion)
                },
                perform: { [weak self] _, query in
                    self?.performAction(
                        actionManifest.function ?? actionManifest.name, extensionId: manifest.id,
                        args: [query])
                }
            )
        }

        let rawIconName = actionManifest.icon ?? manifest.icon
        let resolvedIcon: NerwAction.IconType?
        if let name = rawIconName {
            if name.hasPrefix("/") {
                resolvedIcon = NSImage(contentsOfFile: name).map { .image($0) }
            } else {
                let localUrl = path.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: localUrl.path),
                    let img = NSImage(contentsOfFile: localUrl.path)
                {
                    resolvedIcon = .image(img)
                } else {
                    resolvedIcon = .system(name)
                }
            }
        } else {
            resolvedIcon = nil
        }

        return NerwAction(
            id: "nerw.ext.\(manifest.id).\(actionManifest.name)",
            title: actionManifest.name,
            subtitle: actionManifest.description ?? "",
            icon: resolvedIcon ?? .system("puzzlepiece.extension"),
            triggers: triggers,
            type: actionType,
            isPersistent: actionManifest.longRunning ?? false
        )
    }

    private let fileManager = FileManager.default

    private var userExtensionsPath: URL {
        NerwPaths.extensionsDirectory
    }

    private init() {
        loadExtensions()
        setupNotificationListener()
    }

    private func setupNotificationListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.nerw.reloadExtensions"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[ExtensionEngine] Received reload notification")
            self?.reload()
        }
    }

    // MARK: - Compilation

    /// Compiles a Swift extension source file to a binary.
    /// Returns the URL of the compiled binary, or nil on failure.
    @discardableResult
    public func compileExtension(at extensionDir: URL) -> URL? {
        let mainSwift = extensionDir.appendingPathComponent("main.swift")

        guard fileManager.fileExists(atPath: mainSwift.path) else {
            print("[ExtensionEngine] No main.swift found at \(mainSwift.path)")
            return nil
        }

        let buildDir = extensionDir.appendingPathComponent(".build")
        try? fileManager.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let binaryPath = buildDir.appendingPathComponent("main")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

        // Build arguments — link against NerwExtensionKit if available
        var args = [String]()
        if let (modulesPath, libPath) = findExtensionKitPaths() {
            args += ["-I", modulesPath, "-L", libPath, "-lNerwExtensionKit"]
        }
        args += [mainSwift.path, "-o", binaryPath.path]
        process.arguments = args

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("[ExtensionEngine] Compiled extension at \(extensionDir.lastPathComponent)")
                return binaryPath
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print(
                    "[ExtensionEngine] Compilation failed for \(extensionDir.lastPathComponent): \(errorStr)"
                )
                return nil
            }
        } catch {
            print("[ExtensionEngine] Failed to run swiftc: \(error)")
            return nil
        }
    }

    /// Finds the NerwExtensionKit module and library paths.
    private func findExtensionKitPaths() -> (String, String)? {
        // 1. Check app bundle Resources
        if let resourcePath = Bundle.main.resourcePath {
            let modulesPath = resourcePath + "/Modules"
            let libPath = resourcePath + "/lib"
            let swiftmodule = modulesPath + "/NerwExtensionKit.swiftmodule"
            if fileManager.fileExists(atPath: swiftmodule) {
                return (modulesPath, libPath)
            }
        }

        // 2. Fallback: SPM .build directory (development)
        if let projectRoot = findProjectRoot() {
            let arch = "arm64-apple-macosx"
            let modulesPath = projectRoot + "/.build/\(arch)/debug/Modules"
            let libPath = projectRoot + "/.build/\(arch)/debug"
            let swiftmodule = modulesPath + "/NerwExtensionKit.swiftmodule"
            if fileManager.fileExists(atPath: swiftmodule) {
                return (modulesPath, libPath)
            }
        }

        return nil
    }

    /// Attempts to find the project root by walking up from the executable path.
    private func findProjectRoot() -> String? {
        var path = URL(fileURLWithPath: Bundle.main.executablePath ?? "")
        for _ in 0..<10 {
            path = path.deletingLastPathComponent()
            let packageSwift = path.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwift.path) {
                return path.path
            }
        }
        return nil
    }

    // MARK: - Loading

    public func reload() {
        loadExtensions()
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("NerwExtensionsDidUpdate"), object: nil)
        }
    }

    private func loadExtensions() {
        loadedExtensions.removeAll()

        // 1. User Extensions
        loadExtensions(from: userExtensionsPath)

        // 2. Built-in Extensions
        if let resourcePath = Bundle.main.resourcePath {
            let potentialPaths = [
                URL(fileURLWithPath: resourcePath).appendingPathComponent("extensions"),
                URL(fileURLWithPath: resourcePath).appendingPathComponent(
                    "Nerw_Nerw.bundle/extensions"),
                URL(fileURLWithPath: resourcePath).appendingPathComponent(
                    "Nerw_Nerw.bundle/Contents/Resources/extensions"),
            ]

            for path in potentialPaths {
                loadExtensions(from: path)
            }
        }

        // Sync daemons with the newly loaded list (stops removed daemons and cleans registry)
        DaemonManager.shared.syncWithLoadedExtensions(loadedExtensions)
    }

    private func loadExtensions(from directory: URL) {
        print("[ExtensionEngine] Loading extensions from: \(directory.path)")
        guard
            let items = try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey])
        else {
            print("[ExtensionEngine] Directory not found or empty: \(directory.path)")
            return
        }

        print("[ExtensionEngine] Found \(items.count) items in directory.")

        for item in items {
            let manifestPath = item.appendingPathComponent("manifest.json")

            guard let data = try? Data(contentsOf: manifestPath) else {
                continue
            }

            do {
                var manifest = try JSONDecoder().decode(ExtensionManifest.self, from: data)

                // Check if it's a symbolic link (for Smoke Test)
                if let resourceValues = try? item.resourceValues(forKeys: [.isSymbolicLinkKey]),
                    resourceValues.isSymbolicLink == true
                {
                    manifest.isSmokeTest = true
                }

                // Determine binary path
                let binaryPath: URL?
                if manifest.extensionMode == .binary {
                    // Pre-compiled binary
                    let directBinary = item.appendingPathComponent("main")
                    if fileManager.fileExists(atPath: directBinary.path) {
                        binaryPath = directBinary
                    } else {
                        binaryPath = nil
                    }
                } else {
                    // Script mode — look for pre-compiled binary in .build/
                    let compiledBinary = item.appendingPathComponent(".build/main")
                    if fileManager.fileExists(atPath: compiledBinary.path) {
                        binaryPath = compiledBinary
                    } else {
                        // Not compiled yet, try to compile now
                        binaryPath = compileExtension(at: item)
                    }
                }

                manifest.path = item.path
                let loaded = LoadedExtension(
                    manifest: manifest, path: item, binaryPath: binaryPath)
                loadedExtensions.append(loaded)
                let allTriggers = manifest.actions.flatMap { $0.triggers }

                if let daemonCfg = manifest.daemon, daemonCfg.enabled {
                    DaemonRegistry.shared.register(manifest.id)
                }
                print(
                    "[ExtensionEngine] Loaded extension: \(manifest.id) (Triggers: \(allTriggers.joined(separator: ", "))) [binary: \(binaryPath != nil ? "yes" : "no")]"
                )
            } catch {
                print(
                    "[ExtensionEngine] Failed to decode manifest at \(manifestPath.path): \(error)")
            }
        }
    }

    // MARK: - Execution

    private func getSettingsValues(for extensionId: String, manifest: ExtensionManifest) -> [String:
        AnyCodable]
    {
        var values: [String: AnyCodable] = [:]

        // 1. Fill with defaults from manifest
        if let settings = manifest.settings {
            for setting in settings {
                values[setting.id] = setting.defaultValue
            }
        }

        // 2. Override with saved values from CacheManager
        let cacheKey = "ext_settings_\(extensionId)"
        if let saved = NerwUtils.CacheManager.shared.get(
            forKey: cacheKey, as: [String: AnyCodable].self)
        {
            for (id, value) in saved {
                values[id] = value
            }
        }

        // 3. Inject Theme Configuration
        values["_theme"] = AnyCodable(getThemeDict())

        return values
    }

    private func getThemeDict() -> [String: Any] {
        let theme = NerwTheme.current()
        let layout = ConfigManager.shared.config.layoutConfig
        let panelFrame = NerwPanelContext.shared.mainPanelFrame

        // Screen visible frame for positioning
        let screenVisible = NSScreen.main?.visibleFrame ?? .zero

        var dict: [String: Any] = [
            // Appearance
            "backgroundMaterial": theme.backgroundMaterial,
            "tintOpacity": theme.tintOpacity,
            "cornerRadius": theme.cornerRadius,
            "borderColorHex": theme.borderColorHex,
            "borderOpacity": theme.borderOpacity,
            "borderWidth": theme.borderWidth,
            "innerGlowEnabled": theme.innerGlowEnabled,
            "innerGlowColorHex": theme.innerGlowColorHex,
            "innerGlowOpacity": theme.innerGlowOpacity,

            // Layout — Panel Dimensions
            "mainPanelWidth": layout.mainWidth,
            "mainPanelHeight": layout.mainHeight,

            // Layout — Search Field
            "searchFieldHeight": 32.0,
            "searchFieldFontSize": layout.fontSizeSearch,
            "searchFieldTopMargin": 12.0,
            "searchFieldBottomMargin": 12.0,

            // Layout — Margins & Spacing
            "horizontalMargin": layout.horizontalMargin,
            "iconSize": layout.iconSizeMain,

            // Layout — Results
            "resultRowHeight": 50.0,
            "resultCellCornerRadius": layout.cornerRadius / 2,
            "resultTitleFontSize": layout.fontSizeResultTitle,
            "resultSubtitleFontSize": layout.fontSizeResultSubtitle,

            // Layout — Separator
            "separatorHeight": 1.0,
            "separatorExpandedHeight": 14.0,

            // Layout — Split Pane
            "splitPaneItemFontSize": layout.fontSizeSplitPaneItem,

            // Positioning — Main Panel
            "mainPanelOriginX": Double(panelFrame.origin.x),
            "mainPanelOriginY": Double(panelFrame.origin.y),
            "mainPanelFrameWidth": Double(panelFrame.width),
            "mainPanelFrameHeight": Double(panelFrame.height),

            // Positioning — Screen
            "screenVisibleX": Double(screenVisible.origin.x),
            "screenVisibleY": Double(screenVisible.origin.y),
            "screenVisibleWidth": Double(screenVisible.width),
            "screenVisibleHeight": Double(screenVisible.height),
        ]

        if let tint = theme.tintColorHex { dict["tintColorHex"] = tint }
        if let font = theme.fontName { dict["fontName"] = font }
        if let fg = theme.foregroundColorHex { dict["foregroundColorHex"] = fg }
        if let sbg = theme.selectionBackgroundColorHex { dict["selectionBackgroundColorHex"] = sbg }
        if let sfg = theme.selectionForegroundColorHex { dict["selectionForegroundColorHex"] = sfg }
        if let hint = theme.hintColorHex { dict["hintColorHex"] = hint }

        return dict
    }

    public func runExtension(
        id: String, query: String, trigger: String? = nil, functionName: String? = nil,
        completion: @escaping ([NerwAction]) -> Void
    ) {
        guard let ext = loadedExtensions.first(where: { $0.manifest.id == id }),
            let binaryPath = ext.binaryPath
        else {
            completion([])
            return
        }

        let input = ExtensionInput(
            type: "query",
            query: query,
            triggers: trigger.map { [$0] } ?? [],
            function: nil,
            args: nil,
            formValues: nil,
            settings: getSettingsValues(for: id, manifest: ext.manifest)
        )

        // Route through daemon when running
        if DaemonManager.shared.isRunning(id) {
            DaemonManager.shared.sendQuery(extensionId: id, input: input) { [weak self] data in
                guard let self = self else {
                    completion([])
                    return
                }
                guard let data = data else {
                    // Daemon query failed — fall back to one-shot process
                    self.runExtensionViaProcess(
                        ext: ext, binaryPath: binaryPath, input: input,
                        trigger: trigger, functionName: functionName, completion: completion)
                    return
                }
                let actionManifest = ext.manifest.actions.first { action in
                    if let fn = functionName {
                        return (action.function ?? action.name) == fn
                    } else if let tr = trigger {
                        return action.triggers.contains(tr)
                    }
                    return false
                }
                let fallbackIcon = actionManifest?.icon ?? ext.manifest.icon
                let results = self.parseResults(
                    data, extensionId: id, extensionPath: ext.path,
                    fallbackIcon: fallbackIcon, functionName: functionName)
                DispatchQueue.main.async { completion(results) }
            }
            return
        }

        runExtensionViaProcess(
            ext: ext, binaryPath: binaryPath, input: input,
            trigger: trigger, functionName: functionName, completion: completion)
    }

    private func runExtensionViaProcess(
        ext: LoadedExtension, binaryPath: URL, input: ExtensionInput,
        trigger: String?, functionName: String?,
        completion: @escaping ([NerwAction]) -> Void
    ) {
        executeProcess(binaryPath: binaryPath, input: input) { [weak self] outputData in
            guard let self = self else {
                completion([])
                return
            }
            guard let data = outputData else {
                completion([])
                return
            }
            let actionManifest = ext.manifest.actions.first { action in
                if let fn = functionName {
                    return (action.function ?? action.name) == fn
                } else if let tr = trigger {
                    return action.triggers.contains(tr)
                }
                return false
            }
            let fallbackIcon = actionManifest?.icon ?? ext.manifest.icon
            let results = self.parseResults(
                data, extensionId: ext.manifest.id, extensionPath: ext.path,
                fallbackIcon: fallbackIcon, functionName: functionName)
            DispatchQueue.main.async { completion(results) }
        }
    }

    // Track long-running extension processes for cleanup
    private var runningLongProcesses: [pid_t: Process] = [:]
    private let processLock = NSLock()

    private func executeProcess(
        binaryPath: URL, input: ExtensionInput,
        longRunning: Bool = false,
        processName: String? = nil,
        completion: @escaping (Data?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            var execURL = binaryPath

            if let customName = processName {
                let newURL = binaryPath.deletingLastPathComponent().appendingPathComponent(
                    customName)
                // Remove existing if any, then hardlink
                try? FileManager.default.removeItem(at: newURL)
                if (try? FileManager.default.linkItem(at: binaryPath, to: newURL)) != nil {
                    execURL = newURL
                }
            }

            process.executableURL = execURL

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                print("[ExtensionEngine] Failed to launch process: \(error)")
                completion(nil)
                return
            }

            // Write input JSON to stdin
            if let inputData = try? JSONEncoder().encode(input) {
                inputPipe.fileHandleForWriting.write(inputData)
                inputPipe.fileHandleForWriting.write("\n".data(using: .utf8)!)
            }
            inputPipe.fileHandleForWriting.closeFile()

            // Timeout: kill after 30 seconds (allows time for OS prompts)
            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    print("[ExtensionEngine] Killing process due to timeout")
                    process.terminate()
                }
            }

            if longRunning {
                // Track process, no timeout
                self.processLock.lock()
                self.runningLongProcesses[process.processIdentifier] = process
                self.processLock.unlock()

                // Progressive output reading for long-running processes
                let outHandle = outputPipe.fileHandleForReading
                outHandle.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    // Split data by lines and try to parse as commands
                    if let str = String(data: data, encoding: .utf8) {
                        let lines = str.components(separatedBy: "\n")
                        for line in lines where !line.isEmpty {
                            if let lineData = line.data(using: .utf8),
                                let response = try? JSONDecoder().decode(
                                    ExtensionActionResponse.self, from: lineData)
                            {
                                DispatchQueue.main.async {
                                    self?.executeCommands(response.commands ?? [])
                                }
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutItem)
            }

            process.waitUntilExit()

            if longRunning {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                self.processLock.lock()
                self.runningLongProcesses.removeValue(forKey: process.processIdentifier)
                self.processLock.unlock()
            } else {
                timeoutItem.cancel()
            }

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                if !errorStr.isEmpty {
                    print("[ExtensionEngine] Process error: \(errorStr)")
                }
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            completion(outputData.isEmpty ? nil : outputData)

            // Cleanup hardlink
            if let customName = processName, execURL != binaryPath {
                try? FileManager.default.removeItem(at: execURL)
            }
        }
    }

    /// Gracefully terminate all tracked long-running extension processes.
    public func terminateAllLongRunning() {
        processLock.lock()
        let processes = runningLongProcesses
        runningLongProcesses.removeAll()
        processLock.unlock()
        for (_, proc) in processes where proc.isRunning {
            proc.terminate()
        }
    }

    // MARK: - Action Execution

    private func executeAction(
        functionName: String, extensionId: String, args: [String] = [],
        formValues: [String: String]? = nil
    ) {
        guard let ext = loadedExtensions.first(where: { $0.manifest.id == extensionId }),
            let binaryPath = ext.binaryPath
        else {
            return
        }

        let input = ExtensionInput(
            type: "action",
            query: nil,
            triggers: nil,
            function: functionName,
            args: args.isEmpty ? nil : args,
            formValues: formValues,
            settings: getSettingsValues(for: extensionId, manifest: ext.manifest)
        )

        // Route through daemon when running
        if DaemonManager.shared.isRunning(extensionId) {
            DaemonManager.shared.sendAction(extensionId: extensionId, input: input)
            return
        }

        let actionManifest = ext.manifest.actions.first {
            ($0.function ?? $0.name) == functionName
        }
        let isLongRunning = actionManifest?.longRunning ?? false

        // Safe name for process (alphanumeric)
        let safeExtId = extensionId.replacingOccurrences(of: ".", with: "_")
        let safeFunc = functionName.replacingOccurrences(
            of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        let processName = "nerw_ext_\(safeExtId)_\(safeFunc)"

        executeProcess(
            binaryPath: binaryPath, input: input, longRunning: isLongRunning,
            processName: processName
        ) { outputData in
            guard let data = outputData else { return }

            // Parse action response for host commands (handle multiple lines)
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: "\n")
                for line in lines where !line.isEmpty {
                    if let lineData = line.data(using: .utf8),
                        let response = try? JSONDecoder().decode(
                            ExtensionActionResponse.self, from: lineData)
                    {
                        DispatchQueue.main.async {
                            self.executeCommands(response.commands ?? [])
                        }
                    }
                }
            }
        }
    }

    /// Executes host commands received from an extension (one-shot or daemon push).
    /// Internal access allows DaemonConnection to forward unsolicited ext_command messages.
    func executeCommands(_ commands: [ExtensionCommand]) {
        for cmd in commands {
            switch cmd.type {
            case "open":
                if let value = cmd.value, let url = URL(string: value) {
                    NSWorkspace.shared.open(url)
                }
            case "copy":
                if let value = cmd.value {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(value, forType: .string)
                }
            case "log":
                if let value = cmd.value {
                    print("[Extension Log] \(value)")
                }
            case "notify":
                if let value = cmd.value {
                    let levelStr = cmd.level ?? "info"
                    let notifLevel: NerwNotificationLevel
                    switch levelStr {
                    case "warn": notifLevel = .warn
                    case "error": notifLevel = .error
                    default: notifLevel = .info
                    }
                    let isProgressive = cmd.progressive ?? false
                    let uuid = cmd.id.flatMap(UUID.init(uuidString:))
                    NerwSystem.shared.ui?.showNotification(
                        content: value, level: notifLevel, progressive: isProgressive, id: uuid)
                }
            case "dismiss_notify":
                if let idStr = cmd.id, let uuid = UUID(uuidString: idStr) {
                    NerwSystem.shared.ui?.dismissNotification(id: uuid)
                }
            case "hide_host":
                NerwSystem.shared.ui?.hideWindow()

            default:
                print("[ExtensionEngine] Unknown command type: \(cmd.type)")
            }
        }
    }

    private func performAction(
        _ actionValue: String?, extensionId: String, args: [String] = [],
        formValues: [String: String]? = nil
    ) {
        guard let actionValue = actionValue else { return }

        // 1. Check if it's a URL
        if let url = URL(string: actionValue), url.scheme != nil {
            if !args.isEmpty {
                var filled = actionValue
                for arg in args {
                    filled = filled.replacingOccurrences(
                        of: "%s",
                        with: arg.addingPercentEncoding(
                            withAllowedCharacters: .urlQueryAllowed) ?? "")
                }
                if let finalUrl = URL(string: filled) {
                    NSWorkspace.shared.open(finalUrl)
                }
            } else {
                NSWorkspace.shared.open(url)
            }
        } else {
            // 2. It's a function name — call the extension process
            executeAction(
                functionName: actionValue, extensionId: extensionId, args: args,
                formValues: formValues)
        }
    }

    // MARK: - Result Parsing

    func parseResults(
        _ data: Data, extensionId: String, extensionPath: URL, fallbackIcon: String?,
        functionName: String? = nil
    )
        -> [NerwAction]
    {
        guard
            let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }

        var results: [NerwAction] = []
        for dict in jsonArray {
            if let action = parseItem(
                dict, extensionId: extensionId, extensionPath: extensionPath,
                fallbackIcon: fallbackIcon, functionName: functionName)
            {
                results.append(action)
            }
        }
        return results
    }

    func parseItem(
        _ dict: [String: Any], extensionId: String, extensionPath: URL, fallbackIcon: String?,
        functionName: String? = nil
    )
        -> NerwAction?
    {
        let title = dict["title"] as? String ?? "No Title"
        let subtitle = dict["subtitle"] as? String ?? ""
        let actionValue = dict["action"] as? String
        let explicitType = dict["type"] as? String

        // Icon
        var rawIconName = dict["icon"] as? String
        if rawIconName == "puzzlepiece.extension" {
            rawIconName = nil
        }
        let resolvedIconName = rawIconName ?? fallbackIcon
        let icon: NerwAction.IconType?
        if let name = resolvedIconName {
            if name.hasPrefix("/") {
                if let img = NSImage(contentsOfFile: name) {
                    icon = .image(img)
                } else {
                    icon = nil
                }
            } else {
                let localUrl = extensionPath.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: localUrl.path),
                    let img = NSImage(contentsOfFile: localUrl.path)
                {
                    icon = .image(img)
                } else {
                    icon = .system(name)
                }
            }
        } else {
            icon = .system("puzzlepiece.extension")
        }

        // Parse Peek data
        var peek: NerwAction.PeekData? = nil
        if let peekDict = dict["peek"] as? [String: Any] {
            let peekTitle = peekDict["title"] as? String ?? ""
            let peekText = peekDict["text"] as? String ?? ""
            let peekIconName = peekDict["icon"] as? String
            let peekIcon: NerwAction.IconType? = peekIconName.map { .system($0) }
            peek = NerwAction.PeekData(
                title: peekTitle, text: peekText, icon: peekIcon,
                primaryActionName: peekDict["primaryActionName"] as? String,
                secondaryActionName: peekDict["secondaryActionName"] as? String
            )
        }

        // Parse Modifiers
        var modifiers: [NerwAction.ModifierKey: NerwAction.ModifierAction] = [:]
        if let modsDict = dict["modifiers"] as? [String: [String: Any]] {
            for (keyStr, modActionDict) in modsDict {
                guard let key = NerwAction.ModifierKey(rawValue: keyStr),
                    let actVal = modActionDict["action"] as? String
                else { continue }

                let modTitle = modActionDict["title"] as? String
                let modSubtitle = modActionDict["subtitle"] as? String

                modifiers[key] = NerwAction.ModifierAction(
                    title: modTitle,
                    subtitle: modSubtitle,
                    perform: { [weak self] _ in
                        self?.performAction(actVal, extensionId: extensionId)
                    }
                )
            }
        }

        // Determine Action Type
        let type: NerwAction.ActionType

        if explicitType == "hybrid" {
            guard let quickActionDict = dict["quickAction"] as? [String: Any],
                let qa = parseItem(
                    quickActionDict, extensionId: extensionId, extensionPath: extensionPath,
                    fallbackIcon: fallbackIcon, functionName: functionName)
            else {
                return nil
            }
            type = .hybrid(
                perform: { [weak self] _ in
                    self?.performAction(actionValue, extensionId: extensionId)
                },
                action: NerwActionBox(qa)
            )

        } else if explicitType == "inlineArg" {
            type = .inlineArg(
                perform: { [weak self] _, arg in
                    self?.performAction(actionValue, extensionId: extensionId, args: [arg])
                },
                searcher: { [weak self] _, arg, completion in
                    self?.runExtension(
                        id: extensionId, query: arg, trigger: nil,
                        completion: completion)
                }
            )

        } else if explicitType == "arg" {
            let placeholders = (dict["argNames"] as? [String]) ?? ["Query"]
            type = .arg(
                placeholders: placeholders,
                perform: { [weak self] _, args in
                    self?.performAction(actionValue, extensionId: extensionId, args: args)
                }
            )

        } else if explicitType == "form" {
            guard let formDict = dict["form"] as? [String: Any],
                let fieldsArray = formDict["fields"] as? [[String: Any]]
            else {
                return nil
            }

            let fields: [NerwAction.Field] = fieldsArray.compactMap { fd in
                guard let id = fd["id"] as? String,
                    let fdTitle = fd["title"] as? String
                else { return nil }
                return NerwAction.Field(
                    id: id,
                    title: fdTitle,
                    subtext: fd["subtext"] as? String,
                    placeholder: fd["placeholder"] as? String,
                    defaultValue: fd["defaultValue"] as? String,
                    isSecure: (fd["secure"] as? Bool) ?? false,
                    isMultiline: (fd["multiline"] as? Bool) ?? false
                )
            }
            let submitLabel = formDict["submitLabel"] as? String

            type = .form(
                fields: fields,
                submitLabel: submitLabel,
                perform: { [weak self] _, values in
                    self?.performAction(
                        actionValue, extensionId: extensionId, formValues: values)
                }
            )

        } else if explicitType == "instant" {
            type = .instant(
                perform: { [weak self] _ in
                    self?.performAction(actionValue, extensionId: extensionId)
                }
            )
        } else if explicitType == "option" {
            type = .instant(
                perform: { [weak self] _ in
                    if let fName = functionName, let val = actionValue {
                        self?.performAction(fName, extensionId: extensionId, args: [val])
                    } else {
                        self?.performAction(actionValue, extensionId: extensionId)
                    }
                }
            )
        } else {
            // INFERENCE (Backwards Compatibility)
            if let quickActionDict = dict["quickAction"] as? [String: Any],
                let qa = parseItem(
                    quickActionDict, extensionId: extensionId, extensionPath: extensionPath,
                    fallbackIcon: fallbackIcon)
            {
                type = .hybrid(
                    perform: { [weak self] _ in
                        self?.performAction(actionValue, extensionId: extensionId)
                    },
                    action: NerwActionBox(qa)
                )
            } else if let formDict = dict["form"] as? [String: Any],
                let fieldsArray = formDict["fields"] as? [[String: Any]]
            {
                let fields: [NerwAction.Field] = fieldsArray.compactMap { fd in
                    guard let id = fd["id"] as? String,
                        let fdTitle = fd["title"] as? String
                    else { return nil }
                    return NerwAction.Field(
                        id: id,
                        title: fdTitle,
                        subtext: fd["subtext"] as? String,
                        placeholder: fd["placeholder"] as? String,
                        defaultValue: fd["defaultValue"] as? String,
                        isSecure: (fd["secure"] as? Bool) ?? false,
                        isMultiline: (fd["multiline"] as? Bool) ?? false
                    )
                }
                let submitLabel = formDict["submitLabel"] as? String
                type = .form(
                    fields: fields,
                    submitLabel: submitLabel,
                    perform: { [weak self] _, values in
                        self?.performAction(
                            actionValue, extensionId: extensionId, formValues: values)
                    }
                )
            } else if let act = actionValue, act.contains("%s") {
                type = .arg(
                    placeholders: ["Query"],
                    perform: { [weak self] _, args in
                        self?.performAction(actionValue, extensionId: extensionId, args: args)
                    }
                )
            } else {
                type = .instant(
                    perform: { [weak self] _ in
                        self?.performAction(actionValue, extensionId: extensionId)
                    }
                )
            }
        }

        return NerwAction(
            id: "nerw.ext.\(extensionId).\(title)",
            title: title,
            subtitle: subtitle,
            icon: icon,
            peek: peek,
            triggers: [],
            modifiers: modifiers,
            type: type,
            isPersistent: dict["persistent"] as? Bool ?? false
        )
    }
}
