import AppKit
import Foundation
import JavaScriptCore
import NerwSearchBackend

@objc protocol NerwAPIExports: JSExport {
    func fetch(_ url: String) -> JSValue
    func copyToClipboard(_ text: String)
    func open(_ url: String)
    func log(_ message: String)
    var cache: CacheBridge { get }
}

@objc class NerwAPI: NSObject, NerwAPIExports {
    weak var context: JSContext?

    init(context: JSContext?) {
        self.context = context
    }

    func fetch(_ url: String) -> JSValue {
        guard let urlObj = URL(string: url) else {
            return JSValue(newErrorFromMessage: "Invalid URL", in: context)
        }

        // We create a new Promise via the JS Context
        // This assumes 'Promise' is available in the global scope (Standard in JSC on modern macOS)
        let promiseFunction = context?.objectForKeyedSubscript("Promise")

        let promiseHandler: @convention(block) (JSValue, JSValue) -> Void = {
            [weak self] resolve, reject in
            guard let self = self else { return }

            let task = URLSession.shared.dataTask(with: urlObj) { data, response, error in
                if let error = error {
                    // Jump back to JS thread if needed? JSC is generally thread-safe if using virtualMachine,
                    // but usually callbacks should happen on the context's thread.
                    // For now, we execute simply. If concurrency issues arise, we'll dispatch.
                    let errStr = error.localizedDescription
                    let errVal = JSValue(newErrorFromMessage: errStr, in: self.context)
                    reject.call(withArguments: [errVal as Any])
                    return
                }

                if let data = data, let str = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [str])
                } else {
                    resolve.call(withArguments: [""])
                }
            }
            task.resume()
        }

        // Construct new Promise((resolve, reject) => { ... })
        return promiseFunction?.construct(withArguments: [
            JSValue(object: promiseHandler, in: context) as Any
        ]) ?? JSValue(undefinedIn: context)
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func open(_ url: String) {
        if let urlObj = URL(string: url) {
            NSWorkspace.shared.open(urlObj)
        }
    }

    func log(_ message: String) {
        print("[Extension Log] \(message)")
    }

    var cache: CacheBridge {
        return CacheBridge(context: context)
    }
}

@objc protocol CacheExports: JSExport {
    func set(_ key: String, _ value: JSValue)
    func get(_ key: String) -> JSValue
    func remove(_ key: String)
}

@objc class CacheBridge: NSObject, CacheExports {
    weak var context: JSContext?

    init(context: JSContext?) {
        self.context = context
    }

    func set(_ key: String, _ value: JSValue) {
        if let object = value.toObject() {
            NerwSearchBackend.CacheManager.shared.set(object, forKey: key)
        }
    }

    func get(_ key: String) -> JSValue {
        if let value = NerwSearchBackend.CacheManager.shared.get(forKey: key) {
            return JSValue(object: value, in: context)
        }
        return JSValue(undefinedIn: context)
    }

    func remove(_ key: String) {
        NerwSearchBackend.CacheManager.shared.remove(forKey: key)
    }
}
