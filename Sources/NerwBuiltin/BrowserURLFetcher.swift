import AppKit
import Foundation

public class BrowserURLFetcher {
    public static let shared = BrowserURLFetcher()

    private init() {}

    public enum Browser: String {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case chromium = "Chromium"
        case edge = "Microsoft Edge"
        case brave = "Brave Browser"
        case firefox = "Firefox"
        case arc = "Arc"
        case opera = "Opera"
    }

    public func getFrontBrowserURL() -> String? {
        guard let frontApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication,
            let appName = frontApp.localizedName
        else {
            return nil
        }

        guard let browser = Browser(rawValue: appName) else {
            return nil
        }

        return getURL(for: browser)
    }

    public func getURL(for browser: Browser) -> String? {
        let script: String

        switch browser {
        case .safari, .arc:
            script = """
                tell application "\(browser.rawValue)"
                if it is running then
                    get URL of current tab of front window
                end if
                end tell
                """

        case .chrome, .chromium, .edge, .brave, .opera:
            script = """
                tell application "\(browser.rawValue)"
                if it is running then
                    get URL of active tab of front window
                end if
                end tell
                """

        case .firefox:
            script = """
                tell application "\(browser.rawValue)"
                get URL of active tab of front window
                end tell
                """
        }

        return executeAppleScript(script)
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

    // Get URL + Title together
    public func getBrowserInfo() -> (url: String?, title: String?)? {
        guard let frontApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication,
            let appName = frontApp.localizedName
        else {
            return nil
        }

        let isChromiumBased = [
            "Google Chrome", "Chromium", "Microsoft Edge", "Brave Browser", "Helium",
        ]
        .contains(appName)
        let isSafariBased = ["Safari", "Orion"].contains(appName)

        if isSafariBased {
            let script = """
                tell application "\(appName)"
                set tabURL to URL of current tab of front window
                set tabTitle to name of current tab of front window
                return tabURL & "|||" & tabTitle
                end tell
                """
            if let result = executeAppleScript(script) {
                let parts = result.components(separatedBy: "|||")
                return (url: parts.first, title: parts.last)
            }
        } else if isChromiumBased {
            let script = """
                tell application "\(appName)"
                set tabURL to URL of active tab of front window
                set tabTitle to title of active tab of front window
                return tabURL & "|||" & tabTitle
                end tell
                """
            if let result = executeAppleScript(script) {
                let parts = result.components(separatedBy: "|||")
                return (url: parts.first, title: parts.last)
            }
        }

        return nil
    }
}
