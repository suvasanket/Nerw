import Foundation
import JavaScriptCore

struct LoadedExtension {
    let manifest: ExtensionManifest
    let path: URL
}

public class ExtensionEngine {
    public static let shared = ExtensionEngine()
    
    var context: JSContext?
    var loadedExtensions: [LoadedExtension] = []
    
    // Public getter for UI
    public var extensions: [ExtensionManifest] {
        loadedExtensions.map { $0.manifest }
    }
    
    private let fileManager = FileManager.default
    
    private var userExtensionsPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/extensions")
    }
    
    private init() {
        setupContext()
        loadExtensions()
    }
    
    private func setupContext() {
        context = JSContext()
        
        context?.exceptionHandler = { context, exception in
            // Log error silently or to file if needed, but avoiding console spam
        }
        
        let bridge = NerwAPI(context: context)
        context?.setObject(bridge, forKeyedSubscript: "nerw" as NSString)
        
        let log: @convention(block) (String) -> Void = { message in
            // System log if needed
        }
        context?.setObject(log, forKeyedSubscript: "syslog" as NSString)
    }
    
    public func reload() {
        setupContext()
        loadExtensions()
    }
    
    private func loadExtensions() {
        loadedExtensions.removeAll()
        
        // 1. User Extensions
        loadExtensions(from: userExtensionsPath)
        
        // 2. Built-in Extensions

        
        if let resourcePath = Bundle.main.resourcePath {
             let potentialPaths = [
                 URL(fileURLWithPath: resourcePath).appendingPathComponent("extensions"),
                 // Check for flat bundle structure (debug builds)
                 URL(fileURLWithPath: resourcePath).appendingPathComponent("Nerw_Nerw.bundle/extensions"),
                 // Check for nested bundle structure (release/Xcode builds)
                 URL(fileURLWithPath: resourcePath).appendingPathComponent("Nerw_Nerw.bundle/Contents/Resources/extensions")
             ]
             
             for path in potentialPaths {

                 loadExtensions(from: path)
             }
        }
    }
    
    private func loadExtensions(from directory: URL) {
        // Warning: if directory doesn't exist, this throws/returns nil
        guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        
        for item in items {
            // Assume item is a directory "extension_id/"
            let manifestPath = item.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestPath),
               let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data) {
                 let loaded = LoadedExtension(manifest: manifest, path: item)
                 loadedExtensions.append(loaded)
            }
        }
    }
    
    public func runExtension(id: String, query: String, completion: @escaping ([ExtensionResult]) -> Void) {
        guard let ext = loadedExtensions.first(where: { $0.manifest.id == id }) else {
            completion([])
            return
        }
        
        let scriptPath = ext.path.appendingPathComponent("index.js")
        guard let script = try? String(contentsOf: scriptPath, encoding: .utf8) else {
            print("Could not load script at \(scriptPath)")
            completion([])
            return
        }
        
        // Eval script
        context?.evaluateScript(script)
        
        // Call main()
        guard let mainFunc = context?.objectForKeyedSubscript("main") else {
            print("No 'main' function found in extension")
            completion([])
            return
        }
        
        // main(query)
        let result = mainFunc.call(withArguments: [query])
        
        // Check Promise
        if let isPromise = result?.isInstance(of: context?.objectForKeyedSubscript("Promise")), isPromise {
             let completionCallback: @convention(block) (JSValue) -> Void = { val in
                 let results = self.parseResults(val)
                 completion(results)
             }
             
             let callback = JSValue(object: completionCallback, in: context)
             result?.invokeMethod("then", withArguments: [callback as Any])
        } else {
            let finalResults = parseResults(result)
            completion(finalResults)
        }
    }
    
    private func parseResults(_ value: JSValue?) -> [ExtensionResult] {
        guard let value = value, value.isArray else { return [] }
        
        var results: [ExtensionResult] = []
        let count = Int(value.forProperty("length").toInt32())
        
        for i in 0..<count {
            if let item = value.atIndex(i),
               let dict = item.toDictionary() as? [String: Any] {
                
                let title = dict["title"] as? String ?? "No Title"
                let subtitle = dict["subtitle"] as? String
                let icon = dict["icon"] as? String
                let action = dict["action"] as? String
                
                results.append(ExtensionResult(title: title, subtitle: subtitle, icon: icon, action: action))
            }
        }
        return results
    }
}
