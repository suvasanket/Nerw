import Cocoa
import Foundation
import JavaScriptCore

struct LoadedExtension {
    let manifest: ExtensionManifest
    let path: URL
}

public class ExtensionEngine {
    public static let shared = ExtensionEngine()

    var contexts: [String: JSContext] = [:]
    var loadedExtensions: [LoadedExtension] = []

    // Public getter for UI
    public var extensions: [ExtensionManifest] {
        loadedExtensions.map { $0.manifest }
    }

    public func getAllEntryActions() -> [NerwAction] {
        var actions: [NerwAction] = []
        for ext in loadedExtensions {
            let manifest = ext.manifest
            for trigger in manifest.allTriggers {
                // Create an action for each trigger
                // We use type .arg because extensions usually expect args, or if they are instant
                // they will ignore the empty arg. However, strictly most extensions are "search scripts".
                // We need to know if it's instant or not?
                // The manifest doesn't strictly say. It assumes everything is a script runner "index.js".
                // So treating it as .args with the Extension Name is safest.

                let action = NerwAction(
                    id: "nerw.ext.\(manifest.id).\(trigger)",
                    title: manifest.name,  // Or trigger? Spotlight usually matches trigger and shows App Name.
                    subtitle: manifest.description,
                    icon: .system("puzzlepiece.extension"),  // Todo: Use manifest icon if available
                    triggers: [trigger],
                    type: .args(
                        placeholder: "Query...",
                        searcher: { _, query, completion in
                            self.runExtension(
                                id: manifest.id, query: query, trigger: trigger,
                                completion: completion)
                        },
                        perform: nil
                    )
                )
                actions.append(action)
            }
        }
        return actions
    }

    private let fileManager = FileManager.default

    private var userExtensionsPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/extensions")
    }

    private init() {
        loadExtensions()
    }

    private func setupContext(_ context: JSContext) {
        context.exceptionHandler = { context, exception in
            // Log error silently or to file if needed, but avoiding console spam
            if let ex = exception {
                print("JS Error: \(ex)")
            }
        }

        let bridge = NerwAPI(context: context)
        context.setObject(bridge, forKeyedSubscript: "nerw" as NSString)

        // Inject 'global' and 'window' pointing to the global object
        context.setObject(context.globalObject, forKeyedSubscript: "global" as NSString)
        context.setObject(context.globalObject, forKeyedSubscript: "window" as NSString)

        let log: @convention(block) (String) -> Void = { message in
            print("[JS Log]: \(message)")
        }
        context.setObject(log, forKeyedSubscript: "syslog" as NSString)
    }

    public func reload() {
        contexts.removeAll()
        loadExtensions()
    }

    private func loadExtensions() {
        loadedExtensions.removeAll()
        // Contexts will be lazily created or recreated on execution to ensure fresh start if needed,
        // but for now we clear them on reload.
        contexts.removeAll()

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
    }

    private func loadExtensions(from directory: URL) {
        print("[ExtensionEngine] Loading extensions from: \(directory.path)")
        // Warning: if directory doesn't exist, this throws/returns nil
        guard
            let items = try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
        else {
            print("[ExtensionEngine] Directory not found or empty: \(directory.path)")
            return
        }

        print("[ExtensionEngine] Found \(items.count) items in directory.")

        for item in items {
            // Assume item is a directory "extension_id/"
            let manifestPath = item.appendingPathComponent("manifest.json")
            print("[ExtensionEngine] Checking manifest at: \(manifestPath.path)")

            guard let data = try? Data(contentsOf: manifestPath) else {
                print("[ExtensionEngine] Failed to read manifest data at: \(manifestPath.path)")
                continue
            }

            do {
                let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: data)
                let loaded = LoadedExtension(manifest: manifest, path: item)
                loadedExtensions.append(loaded)
                print(
                    "[ExtensionEngine] Successfully loaded extension: \(manifest.id) (Triggers: \(manifest.allTriggers.joined(separator: ", ")))"
                )
            } catch {
                print(
                    "[ExtensionEngine] Failed to decode manifest at \(manifestPath.path): \(error)")
            }
        }
    }

    private func getOrCreateContext(for extensionId: String) -> JSContext? {
        if let existing = contexts[extensionId] {
            return existing
        }

        guard let ext = loadedExtensions.first(where: { $0.manifest.id == extensionId }) else {
            return nil
        }

        let scriptPath = ext.path.appendingPathComponent("index.js")
        guard let script = try? String(contentsOf: scriptPath, encoding: .utf8) else {
            print("Could not load script at \(scriptPath)")
            return nil
        }

        let context = JSContext()!
        setupContext(context)

        // Evaluate script once
        context.evaluateScript(script)

        contexts[extensionId] = context
        return context
    }

    public func runExtension(
        id: String, query: String, trigger: String? = nil,
        completion: @escaping ([NerwAction]) -> Void
    ) {
        guard let context = getOrCreateContext(for: id) else {
            completion([])
            return
        }

        // Call main()
        guard let mainFunc = context.objectForKeyedSubscript("main") else {
            print("No 'main' function found in extension \(id)")
            completion([])
            return
        }

        // main(query, trigger)
        // JS function signature: function main(query, trigger) { ... }
        // Existing extensions (main(query)) will ignore the 2nd arg.
        let args: [Any] = [query, trigger as Any]
        let result = mainFunc.call(withArguments: args)

        // Check Promise
        if let isPromise = result?.isInstance(of: context.objectForKeyedSubscript("Promise")),
            isPromise
        {
            let completionCallback: @convention(block) (JSValue) -> Void = { val in
                let results = self.parseResults(val, extensionId: id)
                completion(results)
            }

            let callback = JSValue(object: completionCallback, in: context)
            result?.invokeMethod("then", withArguments: [callback as Any])
        } else {
            let finalResults = parseResults(result, extensionId: id)
            completion(finalResults)
        }
    }

    private func parseResults(_ value: JSValue?, extensionId: String) -> [NerwAction] {
        guard let value = value, value.isArray else { return [] }

        var results: [NerwAction] = []
        let count = Int(value.forProperty("length").toInt32())

        for i in 0..<count {
            if let item = value.atIndex(i),
                let dict = item.toDictionary() as? [String: Any],
                let action = parseItem(dict, extensionId: extensionId)
            {
                results.append(action)
            }
        }
        return results
    }

    private func executeJS(
        functionName: String, extensionId: String, arguments: [Any]
    ) {
        guard let context = contexts[extensionId] else { return }
        guard let function = context.objectForKeyedSubscript(functionName), !function.isUndefined
        else {
            print("JS Function not found: \(functionName)")
            return
        }
        function.call(withArguments: arguments)
    }

    private func performAction(
        _ actionValue: String?, extensionId: String, args: [Any] = []
    ) {
        guard let actionValue = actionValue else { return }

        // 1. Check if it's a URL
        if let url = URL(string: actionValue), url.scheme != nil {
            // It's a URL, open it (performing generic substitution if needed)
            // For simple URLs, we just open them.
            // If args were passed, we might need substitution.
            if !args.isEmpty {
                var filled = actionValue
                // Simple substitution for string args
                for arg in args {
                    if let strArg = arg as? String {
                        filled = filled.replacingOccurrences(
                            of: "%s",
                            with: strArg.addingPercentEncoding(
                                withAllowedCharacters: .urlQueryAllowed) ?? "")
                    }
                }
                if let finalUrl = URL(string: filled) {
                    NSWorkspace.shared.open(finalUrl)
                }
            } else {
                NSWorkspace.shared.open(url)
            }
        } else {
            // 2. Assume it's a JS function name
            executeJS(functionName: actionValue, extensionId: extensionId, arguments: args)
        }
    }

    private func parseItem(_ dict: [String: Any], extensionId: String) -> NerwAction? {
        let title = dict["title"] as? String ?? "No Title"
        let subtitle = dict["subtitle"] as? String ?? ""
        let iconName = dict["icon"] as? String
        let actionValue = dict["action"] as? String
        let explicitType = dict["type"] as? String

        // Icon
        let icon: NerwAction.IconType?
        if let name = iconName {
            if name.hasPrefix("/") {
                if let img = NSImage(contentsOfFile: name) {
                    icon = .image(img)
                } else {
                    icon = nil
                }
            } else {
                icon = .system(name)
            }
        } else {
            icon = .system("puzzlepiece.extension")
        }

        // Determine Action Type
        let type: NerwAction.ActionType

        if explicitType == "hybrid" {
            // Hybrid Action
            guard let quickActionDict = dict["quickAction"] as? [String: Any],
                let qa = parseItem(quickActionDict, extensionId: extensionId)
            else {
                return nil
            }
            type = .hybrid(
                perform: { [weak self] _ in
                    self?.performAction(actionValue, extensionId: extensionId)
                },
                action: NerwActionBox(qa)
            )

        } else if explicitType == "arg" {
            // Argument Action
            let placeholders = (dict["argNames"] as? [String]) ?? ["Query"]
            type = .arg(
                placeholders: placeholders,
                perform: { [weak self] _, args in
                    self?.performAction(actionValue, extensionId: extensionId, args: args)
                }
            )

        } else if explicitType == "form" {
            // Form Action
            guard let formDict = dict["form"] as? [String: Any],
                let fieldsArray = formDict["fields"] as? [[String: Any]]
            else {
                return nil
            }

            let fields: [NerwAction.Field] = fieldsArray.compactMap { fd in
                guard let id = fd["id"] as? String,
                    let title = fd["title"] as? String
                else { return nil }
                return NerwAction.Field(
                    id: id,
                    title: title,
                    placeholder: fd["placeholder"] as? String,
                    isSecure: (fd["secure"] as? Bool) ?? false
                )
            }
            let submitLabel = formDict["submitLabel"] as? String

            type = .form(
                fields: fields,
                submitLabel: submitLabel,
                perform: { [weak self] _, values in
                    // Pass dictionary as JSON string or object? JSContext handles dicts.
                    self?.performAction(actionValue, extensionId: extensionId, args: [values])
                }
            )

        } else if explicitType == "instant" {
            type = .instant(
                perform: { [weak self] _ in
                    self?.performAction(actionValue, extensionId: extensionId)
                }
            )
        } else {
            // INFERENCE (Backwards Compatibility)
            if let quickActionDict = dict["quickAction"] as? [String: Any],
                let qa = parseItem(quickActionDict, extensionId: extensionId)
            {
                // Inferred Hybrid
                type = .hybrid(
                    perform: { [weak self] _ in
                        self?.performAction(actionValue, extensionId: extensionId)
                    },
                    action: NerwActionBox(qa)
                )
            } else if let formDict = dict["form"] as? [String: Any],
                let fieldsArray = formDict["fields"] as? [[String: Any]]
            {
                // Inferred Form
                let fields: [NerwAction.Field] = fieldsArray.compactMap { fd in
                    guard let id = fd["id"] as? String,
                        let title = fd["title"] as? String
                    else { return nil }
                    return NerwAction.Field(
                        id: id,
                        title: title,
                        placeholder: fd["placeholder"] as? String,
                        isSecure: (fd["secure"] as? Bool) ?? false
                    )
                }
                let submitLabel = formDict["submitLabel"] as? String
                type = .form(
                    fields: fields,
                    submitLabel: submitLabel,
                    perform: { [weak self] _, values in
                        // For legacy inference, we do the manual URL replacement here
                        // OR we reuse the performAction which supports it if it matches URL
                        // But legacy form support strictly did URL replacement.
                        // Let's use performAction it handles both URL replacement and JS function
                        self?.performAction(actionValue, extensionId: extensionId, args: [values])
                    }
                )

            } else if let act = actionValue, act.contains("%s") {
                // Inferred Arg
                type = .arg(
                    placeholders: ["Query"],
                    perform: { [weak self] _, args in
                        self?.performAction(actionValue, extensionId: extensionId, args: args)
                    }
                )
            } else {
                // Inferred Instant
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
            triggers: [],
            type: type
        )
    }
}
