import AppKit
import Foundation

public class BrowserURLFetcher {
    public static let shared = BrowserURLFetcher()

    private init() {}

    private func isBrowser(app: NSRunningApplication) -> Bool {
        guard let bundleURL = app.bundleURL,
            let bundle = Bundle(url: bundleURL),
            let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes")
                as? [[String: Any]]
        else {
            return false
        }

        for type in urlTypes {
            if let schemes = type["CFBundleURLSchemes"] as? [String] {
                if schemes.contains("http") || schemes.contains("https") {
                    return true
                }
            }
        }
        return false
    }

    private func appleScriptForURL(appName: String) -> String {
        return """
            tell application "\(appName)"
                if it is running then
                    try
                        return URL of active tab of front window
                    end try
                    try
                        return URL of front document
                    end try
                end if
            end tell
            """
    }

    private func appleScriptForURLAndTitle(appName: String) -> String {
        return """
            tell application "\(appName)"
                if it is running then
                    try
                        set tabURL to URL of active tab of front window
                        set tabTitle to title of active tab of front window
                        return tabURL & "|||" & tabTitle
                    end try
                    try
                        set tabURL to URL of front document
                        set tabTitle to name of front document
                        return tabURL & "|||" & tabTitle
                    end try
                end if
            end tell
            """
    }

    public func getFrontBrowserURL() -> String? {
        guard let frontApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication,
            isBrowser(app: frontApp),
            let appName = frontApp.localizedName
        else {
            return nil
        }

        return executeAppleScript(appleScriptForURL(appName: appName))
    }

    // Get URL + Title together
    public func getBrowserInfo() -> (url: String?, title: String?)? {
        guard let frontApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication,
            isBrowser(app: frontApp),
            let appName = frontApp.localizedName
        else {
            return nil
        }

        if let result = executeAppleScript(appleScriptForURLAndTitle(appName: appName)) {
            let parts = result.components(separatedBy: "|||")
            return (url: parts.first, title: parts.last)
        }
        return nil
    }

    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)

        if let errorInfo = error {
            let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNumber == -1743 {
                // errAEEventNotPermitted: User hasn't granted permission
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Apple Events Permission Required"
                    alert.informativeText =
                        "Nerw needs permission to control your web browser. Please enable it in System Settings > Privacy & Security > Automation, then RESTART Nerw for the changes to take effect."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Cancel")

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        if let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            print("AppleScript Error: \(errorInfo)")
            return nil
        }

        return result?.stringValue
    }
}
