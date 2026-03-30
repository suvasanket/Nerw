# Nerw Extension API Documentation

Nerw extensions are written in **Swift** and run as compiled executables. By importing `NerwExtensionKit`, you get a clean, type-safe builder API to create search results and handle actions.

You have full access to all macOS frameworks (EventKit, Contacts, URLSession, AppleScript, etc.).

---

## Table of Contents

1. [Extension Structure](#extension-structure)
2. [NerwExtension Protocol](#nerwextension-protocol)
3. [QueryInput Struct](#queryinput-struct)
4. [ActionInput Struct](#actioninput-struct)
5. [NerwResult Struct](#nerwresult-struct)
6. [NerwIcon Enum](#nerwicon-enum)
7. [NerwField Struct](#nerwfield-struct)
8. [NerwPeek Struct](#nerwpeek-struct)
9. [Nerw API (Host Commands)](#nerw-api-host-commands)
10. [Example Extensions](#example-extensions)

---

## Extension Structure

An extension is a `.nerw` package (a renamed `.zip` file) containing:
1. `manifest.json`: Metadata about the extension.
2. `main.swift`: Your Swift source code.

When a user opens a `.nerw` file, the app automatically extracts it to `~/.nerw/extensions/` and compiles the `main.swift` file against the `NerwExtensionKit` SDK. **No app restart required.**

### manifest.json

```json
{
  "id": "com.example.search",
  "name": "Example Search",
  "description": "Searches an example API",
  "trigger": "example",
  "icon": "magnifyingglass"
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (reverse domain notation recommended) |
| `name` | string | Yes | Display name shown in the UI |
| `description` | string | No | Brief description of the extension |
| `trigger` | string | Yes | Primary keyword that activates this extension |
| `triggers` | array | No | Additional trigger keywords |
| `icon` | string | No | SF Symbol name (e.g., "star", "gear", "cloud") |

---

## NerwExtension Protocol

**What it does:** The main protocol your extension must conform to. It defines two lifecycle methods that Nerw calls when handling user queries and actions.

**Signature:**
```swift
public protocol NerwExtension {
    func query(input: QueryInput) -> [NerwResult]
    func perform(action: ActionInput)
}
```

**Implementation details:**
- `query(input:)`: Called when the user types a query with your extension's trigger keyword. Return an array of `NerwResult` items to display.
- `perform(action:)`: Called when the user triggers a function-based action (from `.instant(action:)`, `.arg()`, `.form()`, or `.hybrid()`). The default implementation is empty, so you only need to implement it if you use function-based actions.

**Example:**
```swift
struct MyExtension: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] {
        return [
            NerwResult("Search Google")
                .subtitle("Search the web")
                .icon(.system("magnifyingglass"))
                .instant(action: "https://google.com")
        ]
    }

    func perform(action: ActionInput) {
        // Handle function-based actions here
    }
}
```

---

## QueryInput Struct

**What it does:** Provides the input data when your extension's `query(input:)` method is called.

**Signature:**
```swift
public struct QueryInput {
    public let query: String
    public let trigger: String?

    public init(query: String, trigger: String? = nil)
}
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `query` | String | The full text the user typed after the trigger |
| `trigger` | String? | The trigger keyword that activated this extension (useful when using multiple triggers) |

**Implementation:**
```swift
public init(query: String, trigger: String? = nil) {
    self.query = query
    self.trigger = trigger
}
```

**Example:**
```swift
func query(input: QueryInput) -> [NerwResult] {
    // If user types "example hello world"
    // input.trigger = "example"
    // input.query = "hello world"
    
    return searchDatabase(query: input.query)
}
```

---

## ActionInput Struct

**What it does:** Provides the input data when your extension's `perform(action:)` method is called. Contains the action identifier and any data collected from the user.

**Signature:**
```swift
public struct ActionInput {
    public let function: String
    public let args: [String]
    public let formValues: [String: String]

    public init(
        function: String,
        args: [String] = [],
        formValues: [String: String] = [:]
    )
}
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `function` | String | The function name specified in the builder (e.g., "handleSearch") |
| `args` | [String] | Array of arguments collected via `.arg()` action |
| `formValues` | [String: String] | Dictionary mapping field IDs to submitted values from `.form()` action |

**Implementation:**
```swift
public init(function: String, args: [String] = [], formValues: [String: String] = [:]) {
    self.function = function
    self.args = args
    self.formValues = formValues
}
```

**Example:**
```swift
func perform(action: ActionInput) {
    switch action.function {
    case "handleSearch":
        // For .arg() actions: get user input
        let searchTerm = action.args.first ?? ""
        Nerw.open("https://google.com/search?q=\(searchTerm)")
        
    case "handleLogin":
        // For .form() actions: get form values by field ID
        let username = action.formValues["username"] ?? ""
        let password = action.formValues["password"] ?? ""
        authenticate(username: username, password: password)
    }
}
```

---

## NerwResult Struct

**What it does:** Represents a single search result item. Uses a fluent builder pattern to configure its appearance and behavior.

**Signature:**
```swift
public struct NerwResult {
    public var title: String
    public var subtitleText: String
    public var resultIcon: NerwIcon

    public init(_ title: String)

    // Builder methods
    public func subtitle(_ text: String) -> NerwResult
    public func icon(_ icon: NerwIcon) -> NerwResult
    public func instant(action: String) -> NerwResult
    public func arg(names: [String], action: String) -> NerwResult
    public func hybrid(action: String, quickAction: NerwResult) -> NerwResult
    public func form(fields: [NerwField], submitLabel: String?, action: String) -> NerwResult
    public func peek(_ peek: NerwPeek) -> NerwResult
    public func peek(title: String, text: String, icon: NerwIcon?, primaryAction: String?, secondaryAction: String?) -> NerwResult
}
```

**Constructor:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `title` | String | The main text displayed for this result |

**Builder Methods:**

### `.subtitle(_:)`

**What it does:** Sets the secondary text line displayed below the title.

```swift
public func subtitle(_ text: String) -> NerwResult
```

**Implementation:**
```swift
public func subtitle(_ text: String) -> NerwResult {
    var copy = self
    copy.subtitleText = text
    return copy
}
```

**Example:**
```swift
NerwResult("Google")
    .subtitle("Search the web")
```

### `.icon(_:)`

**What it does:** Sets the icon displayed next to the result.

```swift
public func icon(_ icon: NerwIcon) -> NerwResult
```

**Implementation:**
```swift
public func icon(_ icon: NerwIcon) -> NerwResult {
    var copy = self
    copy.resultIcon = icon
    return copy
}
```

**Example:**
```swift
NerwResult("Settings")
    .icon(.system("gear"))           // SF Symbol
    .icon(.file("/path/to/icon.png")) // Custom image file
```

### `.instant(action:)`

**What it does:** Configures the result for immediate execution. When the user presses Enter, the action is triggered immediately.

```swift
public func instant(action: String) -> NerwResult
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | String | Either a URL (opened in browser) or a function name (calls your `perform(action:)`) |

**Implementation:**
```swift
public func instant(action: String) -> NerwResult {
    var copy = self
    copy.actionType = "instant"
    copy.actionValue = action
    return copy
}
```

**Example:**
```swift
// URL action - opens in browser
NerwResult("Open GitHub")
    .instant(action: "https://github.com")

// Function action - calls perform(action:)
NerwResult("Custom Action")
    .instant(action: "handleCustom")
```

### `.arg(names:action:)`

**What it does:** Configures a multi-step argument action. The user types additional input after pressing Enter, and the collected arguments are passed to your `perform(action:)` method.

```swift
public func arg(names: [String] = ["Query"], action: String) -> NerwResult
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `names` | [String] | Placeholder names for each argument step (default: ["Query"]) |
| `action` | String | Function name called with collected args |

**Implementation:**
```swift
public func arg(names: [String], action: String) -> NerwResult {
    var copy = self
    copy.actionType = "arg"
    copy.actionValue = action
    copy.argNamesList = names
    return copy
}
```

**Example:**
```swift
// Single argument
NerwResult("Search")
    .arg(action: "handleSearch")

// Multiple arguments
NerwResult("Calculate")
    .arg(names: ["Number 1", "Operator", "Number 2"], action: "calculate")
```

### `.hybrid(action:quickAction:)`

**What it does:** Provides two parallel actions: Enter executes the primary action, Tab shows and executes a quick action.

```swift
public func hybrid(action: String, quickAction: NerwResult) -> NerwResult
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | String | Primary action (URL or function name) executed on Enter |
| `quickAction` | NerwResult | Secondary action shown and executed on Tab |

**Implementation:**
```swift
public func hybrid(action: String, quickAction: NerwResult) -> NerwResult {
    var copy = self
    copy.actionType = "hybrid"
    copy.actionValue = action
    copy.quickActionResult = NerwResultBox(quickAction)
    return copy
}
```

**Example:**
```swift
NerwResult("Search")
    .hybrid(
        action: "https://google.com",  // Enter: open Google
        quickAction: NerwResult("Quick Search")
            .subtitle("Tab to quick search")
            .icon(.system("bolt.fill"))
            .instant(action: "handleQuick")  // Tab: custom handler
    )
```

### `.form(fields:submitLabel:action:)`

**What it does:** Shows a multi-field input form. When the user submits, the form values are passed to your `perform(action:)` method.

```swift
public func form(
    fields: [NerwField],
    submitLabel: String? = nil,
    action: String
) -> NerwResult
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fields` | [NerwField] | Array of form field definitions |
| `submitLabel` | String? | Custom text for the submit button |
| `action` | String | Function name called with form values |

**Implementation:**
```swift
public func form(
    fields: [NerwField],
    submitLabel: String?,
    action: String
) -> NerwResult {
    var copy = self
    copy.actionType = "form"
    copy.actionValue = action
    copy.formFieldsList = fields
    copy.formSubmitLabelText = submitLabel
    return copy
}
```

**Example:**
```swift
NerwResult("Login")
    .form(
        fields: [
            NerwField("username", title: "Username"),
            NerwField("password", title: "Password", secure: true),
        ],
        submitLabel: "Sign In",
        action: "handleLogin"
    )
```

### `.peek(_:)`

**What it does:** Adds an expanded inline preview pane shown to the right of the result.

```swift
public func peek(_ peek: NerwPeek) -> NerwResult
public func peek(
    title: String,
    text: String,
    icon: NerwIcon? = nil,
    primaryAction: String? = nil,
    secondaryAction: String? = nil
) -> NerwResult
```

**Parameters (convenience form):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `title` | String | Preview pane title |
| `text` | String | Content text |
| `icon` | NerwIcon? | Optional icon |
| `primaryAction` | String? | Optional function called by primary button |
| `secondaryAction` | String? | Optional function called by secondary button |

**Example:**
```swift
NerwResult("Movie: Inception")
    .peek(
        title: "Inception (2010)",
        text: "A thief who steals corporate secrets through dream-sharing technology...",
        icon: .system("film"),
        primaryAction: "playMovie"
    )
```

---

## NerwIcon Enum

**What it does:** Represents an icon for a search result. Supports SF Symbols and custom file paths.

**Signature:**
```swift
public enum NerwIcon {
    case system(String)
    case file(String)

    func serialize() -> String
}
```

**Cases:**

| Case | Description |
|------|-------------|
| `.system(String)` | SF Symbol name (e.g., "star.fill", "magnifyingglass") |
| `.file(String)` | Absolute path to an image file |

**Implementation:**
```swift
public enum NerwIcon {
    case system(String)
    case file(String)

    func serialize() -> String {
        switch self {
        case .system(let name): return name
        case .file(let path): return path
        }
    }
}
```

**Example:**
```swift
NerwResult("Settings")
    .icon(.system("gear"))

NerwResult("Custom")
    .icon(.file("/Users/me/icons/custom.png"))
```

---

## NerwField Struct

**What it does:** Defines a single input field in a form action.

**Signature:**
```swift
public struct NerwField {
    public let id: String
    public let title: String
    public let placeholder: String?
    public let isSecure: Bool

    public init(
        _ id: String,
        title: String,
        placeholder: String? = nil,
        secure: Bool = false
    )
}
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier for accessing the field value |
| `title` | String | Label displayed above the field |
| `placeholder` | String? | Placeholder text shown when empty |
| `isSecure` | Bool | Whether the field is a password field |

**Implementation:**
```swift
public init(_ id: String, title: String, placeholder: String? = nil, secure: Bool = false) {
    self.id = id
    self.title = title
    self.placeholder = placeholder
    self.isSecure = secure
}
```

**Example:**
```swift
NerwField("email", title: "Email Address", placeholder: "user@example.com")
NerwField("password", title: "Password", secure: true)
```

---

## NerwPeek Struct

**What it does:** Configuration for an expanded inline preview (Peek) shown beside a result.

**Signature:**
```swift
public struct NerwPeek {
    public let title: String
    public let text: String
    public let icon: NerwIcon?
    public let primaryActionName: String?
    public let secondaryActionName: String?

    public init(
        title: String,
        text: String,
        icon: NerwIcon? = nil,
        primaryAction: String? = nil,
        secondaryAction: String? = nil
    )
}
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `title` | String | Preview pane title |
| `text` | String | Main content text |
| `icon` | NerwIcon? | Optional icon |
| `primaryActionName` | String? | Function called when primary button clicked |
| `secondaryActionName` | String? | Function called when secondary button clicked |

**Implementation:**
```swift
public init(
    title: String,
    text: String,
    icon: NerwIcon? = nil,
    primaryAction: String? = nil,
    secondaryAction: String? = nil
) {
    self.title = title
    self.text = text
    self.icon = icon
    self.primaryActionName = primaryAction
    self.secondaryActionName = secondaryAction
}
```

**Example:**
```swift
let peek = NerwPeek(
    title: "Weather Today",
    text: "Sunny, 72°F",
    icon: .system("sun.max.fill"),
    primaryAction: "viewWeek"
)

NerwResult("Weather")
    .peek(peek)
```

---

## Nerw API (Host Commands)

**What it does:** Static API for instructing the Nerw host application to perform actions. Use inside your `perform(action:)` method.

**Signature:**
```swift
public enum Nerw {
    public static func open(_ url: String)
    public static func copy(_ text: String)
    public static func log(_ message: String)
    public static func notify(_ content: String, level: String, progressive: Bool, id: String?)
    public static func dismissNotify(id: String)
    public static func run(_ ext: NerwExtension)
}
```

### Nerw.open(_:)

**What it does:** Opens a URL in the default browser or a file path in Finder.

```swift
public static func open(_ url: String)
```

**Implementation:**
```swift
public static func open(_ url: String) {
    pendingCommands.append(["type": "open", "value": url])
}
```

**Example:**
```swift
Nerw.open("https://github.com")
Nerw.open("/System/Applications/Calculator.app")
Nerw.open("file:///Users/me/Documents")
```

### Nerw.copy(_:)

**What it does:** Copies text to the system clipboard.

```swift
public static func copy(_ text: String)
```

**Implementation:**
```swift
public static func copy(_ text: String) {
    pendingCommands.append(["type": "copy", "value": text])
}
```

**Example:**
```swift
Nerw.copy("Secret Token: 12345")
Nerw.copy(action.formValues["username"] ?? "")
```

### Nerw.log(_:)

**What it does:** Logs a debug message to stderr (visible in terminal if running Nerw manually).

```swift
public static func log(_ message: String)
```

**Implementation:**
```swift
public static func log(_ message: String) {
    FileHandle.standardError.write(
        "[Extension] \(message)\n".data(using: .utf8) ?? Data())
}
```

**Example:**
```swift
Nerw.log("User clicked the button!")
Nerw.log("Search results: \(results.count)")
```

### Nerw.notify(_:level:progressive:id:)

**What it does:** Displays a system notification panel.

```swift
public static func notify(
    _ content: String,
    level: String = "info",
    progressive: Bool = false,
    id: String? = nil
)
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | String | - | Message text |
| `level` | String | "info" | Severity: "info", "warn", or "error" |
| `progressive` | Bool | false | Shows spinner; prevents auto-dismiss |
| `id` | String? | nil | Identifier for later dismissal |

**Implementation:**
```swift
public static func notify(
    _ content: String,
    level: String = "info",
    progressive: Bool = false,
    id: String? = nil
) {
    var cmd: [String: Any] = [
        "type": "notify",
        "value": content,
        "level": level,
        "progressive": progressive,
    ]
    if let id = id { cmd["id"] = id }
    pendingCommands.append(cmd)
}
```

**Example:**
```swift
Nerw.notify("Download started", level: "info")
Nerw.notify("File not found", level: "error")
Nerw.notify("Processing...", level: "warn", progressive: true, id: "loader-1")
```

### Nerw.dismissNotify(id:)

**What it does:** Dismisses a previously shown progressive notification.

```swift
public static func dismissNotify(id: String)
```

**Implementation:**
```swift
public static func dismissNotify(id: String) {
    pendingCommands.append([
        "type": "dismiss_notify",
        "id": id,
    ])
}
```

**Example:**
```swift
Nerw.notify("Downloading...", progressive: true, id: "download-1")
// ... later when done ...
Nerw.dismissNotify(id: "download-1")
```

### Nerw.run(_:)

**What it does:** Bootstraps and runs the extension. Call this **exactly once** at the end of your `main.swift`. Handles reading input from stdin, dispatching to `query()` or `perform()`, and writing results to stdout.

```swift
public static func run(_ ext: NerwExtension)
```

**Implementation flow:**
1. Reads JSON input from stdin
2. Parses the `type` field ("query" or "action")
3. For "query": calls `ext.query(input:)` and prints serialized results
4. For "action": calls `ext.perform(action:)` and prints pending commands
5. If invalid input, logs error and exits with code 1

**Example:**
```swift
import NerwExtensionKit

struct MyExtension: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] { ... }
    func perform(action: ActionInput) { ... }
}

Nerw.run(MyExtension())
```

## Development Tools

The `nerw` CLI provides tools to streamline extension development.

### Initializing a New Extension

To create a new extension template:
```bash
nerw extension init
```
This will prompt you for the extension name, ID, and trigger, then create a directory with `manifest.json` and a boilerplate `main.swift`.

### Testing Extensions (Smoke Test)

You can test your extension without installing it into the main app:
```bash
cd your-extension-dir
nerw extension smoke-test "your test query"
```
The `smoke-test` command:
1.  Compiles your `main.swift` into a temporary binary.
2.  Runs the binary with a mock `query` input.
3.  Prints the JSON output (results) to the terminal.

This is the fastest way to debug your extension's logic and ensure it returns the expected results.

---

## Example Extensions

### Basic Extension (Single Trigger)

```swift
import Foundation
import NerwExtensionKit

struct GoogleSearch: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] {
        let query = input.query
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        return [
            NerwResult("Search Google for '\(query)'")
                .subtitle("Open in browser")
                .icon(.system("magnifyingglass"))
                .instant(action: "https://www.google.com/search?q=\(encoded)")
        ]
    }

    func perform(action: ActionInput) {
        // URL actions execute automatically without needing this
    }
}

Nerw.run(GoogleSearch())
```

### Dual Trigger Extension

```swift
import NerwExtensionKit

struct DualExtension: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] {
        switch input.trigger {
        case "gh":
            return [
                NerwResult("GitHub")
                    .subtitle("Open GitHub")
                    .icon(.system("chevron.left.forwardslash.chevron.right"))
                    .instant(action: "https://github.com")
            ]
        case "gl":
            return [
                NerwResult("GitLab")
                    .subtitle("Open GitLab")
                    .icon(.system("t.square"))
                    .instant(action: "https://gitlab.com")
            ]
        default:
            return []
        }
    }

    func perform(action: ActionInput) {}
}

Nerw.run(DualExtension())
```

### Full Featured Extension

```swift
import NerwExtensionKit

struct FullFeaturedExtension: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] {
        return [
            // Instant action (URL)
            NerwResult("Open Documentation")
                .subtitle("Apple Developer Docs")
                .icon(.system("book"))
                .instant(action: "https://developer.apple.com/documentation"),

            // Instant action (function)
            NerwResult("Copy API Key")
                .subtitle("Copy to clipboard")
                .icon(.system("key"))
                .instant(action: "copyApiKey"),

            // Argument action
            NerwResult("Search NPM")
                .subtitle("Search npm registry")
                .icon(.system("cube.box"))
                .arg(names: ["Package Name"], action: "searchNpm"),

            // Hybrid action
            NerwResult("Quick Actions Demo")
                .subtitle("Enter for URL, Tab for function")
                .icon(.system("bolt"))
                .hybrid(
                    action: "https://example.com",
                    quickAction: NerwResult("Run Script")
                        .subtitle("Execute shell command")
                        .icon(.system("terminal"))
                        .instant(action: "runScript")
                ),

            // Form action
            NerwResult("SSH Connection")
                .subtitle("Connect to server")
                .icon(.system("network"))
                .form(
                    fields: [
                        NerwField("host", title: "Host", placeholder: "server.com"),
                        NerwField("user", title: "Username"),
                        NerwField("pass", title: "Password", secure: true),
                    ],
                    submitLabel: "Connect",
                    action: "sshConnect"
                ),

            // With peek preview
            NerwResult("Weather: San Francisco")
                .subtitle("72°F, Partly Cloudy")
                .icon(.system("cloud.sun"))
                .peek(
                    title: "San Francisco, CA",
                    text: "Currently: 72°F, Partly Cloudy\nHigh: 78°F, Low: 62°F\nHumidity: 65%",
                    icon: .system("cloud.sun.fill")
                ),
        ]
    }

    func perform(action: ActionInput) {
        switch action.function {
        case "copyApiKey":
            Nerw.copy("sk-api-key-1234567890")
            Nerw.notify("API key copied!", level: "info")

        case "searchNpm":
            let package = action.args.first ?? ""
            let encoded = package.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? package
            Nerw.open("https://www.npmjs.com/search?q=\(encoded)")

        case "runScript":
            Nerw.log("Running script...")
            Nerw.notify("Script completed", level: "info")

        case "sshConnect":
            let host = action.formValues["host"] ?? ""
            let user = action.formValues["user"] ?? ""
            Nerw.open("ssh://\(user)@\(host)")
            Nerw.notify("Connecting to \(host)...", level: "info")

        default:
            break
        }
    }
}

Nerw.run(FullFeaturedExtension())
```

---

*(For additional examples, check the `/examples` folder in the repository)*
