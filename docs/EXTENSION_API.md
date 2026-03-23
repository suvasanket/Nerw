# Nerw Extension API Documentation

Nerw extensions are written in **Swift** and run as compiled executables. By importing `NerwExtensionKit`, you get a clean, type-safe builder API to create search results and handle actions.

You have full access to all macOS frameworks (EventKit, Contacts, URLSession, AppleScript, etc.).

## Extension Structure

An extension is a `.nerw` package (a renamed `.zip` file) containing:
1.  `manifest.json`: Metadata about the extension.
2.  `main.swift`: Your Swift source code.

When a user opens a `.nerw` file, the app automatically extracts it to `~/.nerw/extensions/` and compiles the `main.swift` file against the `NerwExtensionKit` SDK. **No app restart required.**

### 1. `manifest.json`

```json
{
  "id": "com.example.search",
  "name": "Example Search",
  "description": "Searches an example API",
  "trigger": "example",
  "icon": "magnifyingglass"
}
```

-   **id**: A unique identifier (reverse domain notation recommended).
-   **name**: Display name of the extension.
-   **trigger**: The keyword that activates your extension (e.g., typing "example query" runs this).
-   **triggers**: (Optional) Array of additional trigger keywords.
-   **icon**: SF Symbol name (e.g., "star", "gear", "cloud").

### 2. `main.swift`

Your Swift script must import `NerwExtensionKit`, conform to the `NerwExtension` protocol, and call `Nerw.run()` at the end.

```swift
import Foundation
import NerwExtensionKit

struct MyExtension: NerwExtension {
    
    // 1. Return search results based on the query
    func query(input: QueryInput) -> [NerwResult] {
        return [
            NerwResult("Hello \(input.query)")
                .subtitle("Click to search Google")
                .icon(.system("magnifyingglass"))
                .instant(action: "https://www.google.com/search?q=\(input.query)")
        ]
    }

    // 2. Handle function-based actions (optional)
    func perform(action: ActionInput) {
        if action.function == "handleCustomClick" {
            Nerw.open("https://github.com")
        }
    }
}

// 3. Start the extension
Nerw.run(MyExtension())
```

---

## The `NerwResult` Builder API

`NerwResult` uses a fluent builder pattern to configure your search results.

```swift
NerwResult("Main Title")
    .subtitle("Secondary Text")
    .icon(.system("star.fill"))
    // Action configurators (choose ONE):
    // .instant(action: ...)
    // .arg(...)
    // .hybrid(...)
    // .form(...)
    // Optional extras:
    // .peek(...)
```

### 1. Instant Action
Executes immediately when the user presses Enter.
```swift
.instant(action: "https://google.com") // Opens URL
// OR
.instant(action: "handleAction")       // Calls your perform(action:) method
```

### 2. Argument Action
Prompts the user to type additional query steps before executing.
```swift
.arg(names: ["Search Term"], action: "handleSearch")
```

### 3. Hybrid Action
Provides two actions: `Enter` executes the primary action, `Tab` executes the quick action.
```swift
.hybrid(
    action: "https://google.com",
    quickAction: NerwResult("Quick Action")
                    .subtitle("You pressed Tab!")
                    .icon(.system("bolt.fill"))
                    .instant(action: "handleQuickAction")
)
```

### 4. Form Action
Shows a multi-field input sheet.
```swift
.form(
    fields: [
        NerwField("username", title: "Username"),
        NerwField("password", title: "Password", secure: true)
    ],
    submitLabel: "Log In",
    action: "handleLogin"
)
```

### 5. Peek (Expanded Preview)
Adds an inline preview pane to the right of the result.
```swift
.peek(
    title: "Detailed View", 
    text: "Here is a much longer description...",
    icon: .system("info.circle")
)
```

---

## Host Commands (`Nerw.` API)

Inside your `perform(action:)` method, you can instruct the Nerw host application to do things on your behalf using the static `Nerw` API:

```swift
func perform(action: ActionInput) {
    // 1. Open URLs or local file paths
    Nerw.open("https://github.com")
    Nerw.open("/System/Applications/Calculator.app")
    
    // 2. Copy text to the clipboard
    Nerw.copy("Secret Token: 12345")
    
    // 3. Log debug messages (visible in the terminal if you run Nerw manually)
    Nerw.log("User clicked the button!")
}
```

---

## Action Input Data

When `perform(action:)` is called, the `ActionInput` struct provides the data you need:

```swift
func perform(action: ActionInput) {
    // The function name you specified in the builder
    print(action.function) 
    
    // For .arg() actions: The text the user typed
    let searchTerm = action.args.first ?? "" 
    
    // For .form() actions: Dictionary mapping Field IDs to typed values
    let user = action.formValues["username"] ?? ""
    let pass = action.formValues["password"] ?? ""
}
```

---

## Example: Complex Extension

```swift
import NerwExtensionKit

struct ComplexDemo: NerwExtension {
    func query(input: QueryInput) -> [NerwResult] {
        return [
            NerwResult("Hybrid Form Demo")
                .subtitle("Enter for Form, Tab for Google")
                .icon(.system("gear"))
                .hybrid(
                    action: "show_form", // Handled below? No, hybrid action must be URL if form is inside? 
                    // Actually, you can't nest form inside hybrid easily like this, 
                    // but you CAN put functions everywhere!
                    quickAction: NerwResult("Quick Search")
                        .instant(action: "https://google.com")
                )
        ]
    }
    
    func perform(action: ActionInput) {
        // ... handle actions ...
    }
}
Nerw.run(ComplexDemo())
```

*(For working complete examples, check the `/examples` folder in the repository!)*
