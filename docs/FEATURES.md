# Nerw Features Guide

Nerw is a Keyboard-First Spotlight replacement for macOS, designed for speed and extensibility.

## 🚀 Core Features

### Global Hotkey
- **Toggle**: `Cmd + Shift + Space` (Configurable in `config.json`)
- Activates the Main Panel instantly from anywhere in macOS.

### Unified Search
Nerw intelligently routes your query to the best provider via the `SearchService`:
1.  **Applications**: Fuzzy search installed apps (e.g., "xcode" -> Xcode).
2.  **Web Search (Bang Search)**:
    -   **Explicit Trigger**: Use "bangs" to search specific engines instantly (e.g., `!g swift` for Google, `!yt cat videos` for YouTube).
    -   **Supported Bangs**:
        -  `!g` or `!google` : Google
        -  `!ddg` or `!duckduckgo` : DuckDuckGo
        - More can added by user.
    -   **Smart History**: Nerw remembers your preference. If you type `!yt swift`, the next time you type `swift`, Nerw will suggest **YouTube** automatically.
    -   **Strict Recency**: The suggestion always tracks your *last used* engine for a query, allowing you to switch preferences instantly.
    -   **Default Fallback**: If no bang is used and no history exists, a **Google Search** fallback is added to the bottom of the results.
    -   **Smart Categorizer**: Nerw uses Apple's NaturalLanguage framework to classify your query in real-time. If the query looks like a web search (e.g., "how to install docker", "best restaurants near me") or a URL (e.g., "github.com"), the web search result is automatically boosted to the top. If the query matches an app name or trigger, the real match always stays on top (trigger-match guard).
3.  **Native File Search**:
    - **Trigger**: `find [query]`, `file [query]`.
    - **Engine**: Native Spotlight index access via `MDQuery` for near-instant results with zero process spawning.
    - **Filtering**: Automatically excludes developer artifacts like `node_modules`, `.git`, and `build` folders for cleaner results.
4.  **Dictionary Lookup**:
    - **Trigger**: `define [word]` or `def [word]`.
    - **Engine**: Uses native macOS Dictionary index (`CoreServices.DCSCopyTextDefinition`).
    - **Action**: Opens the native Dictionary app to the exact word.
5.  **Wikipedia Search**:
    - **Trigger**: `wiki [query]`.
    - **Engine**: Real-time fetching from `en.wikipedia.org/api/rest_v1/page/summary`.
    - **Action**: Opens the article in your default browser.
6.  **System Commands**: Quick access to common macOS actions:
    - `empty downloads` - Move Downloads folder contents to Trash
    - `eject [volume]` - Eject a specific volume (shows available volumes)
    - `eject all` - Eject all external volumes
    - `wifi` - Toggle WiFi or connect to known networks.
    - `bluetooth` - Toggle Bluetooth or connect to devices.
7.  **Inline Arguments (Alfred-style)**:
    - **Behavior**: Some actions allow you to type an argument directly in the main search field after the trigger word (e.g., `map London`).
    - **Discovery**: When you type a trigger word exactly (like `map`), the corresponding action is pinned to the top of the results.
    - **Execution**: Pressing Enter executes the pinned action with the currently typed argument.
    - **Integrated**: Other search results (apps, files, web) continue to appear below the pinned inline action.
8.  **Peek (Inline Previews)**: Provides rich, dynamic, multi-line expanded previews for selected results without leaving the search bar. Supported actions (like Dictionary definitions and Wikipedia summaries) can show extended titles, long typography-aware text blocks, custom icons, and interactive buttons right inside the list window that seamlessly scales vertically to fit exactly what you need.
9.  **Calculator**: (Planned/Upcoming) Basic math operations.
10. **Notification System**:
    - **Glassmorphic Alerts**: Native pill-shaped frosted-glass notifications stack at the top center of the screen.
    - **Dynamic Elements**: Supports various tint types (`warn`, `error`, `info`) and optional unbounded progressive spinners.
    - **3D Stacking**: When multiple notifications overlap elegantly natively mirroring macOS "deck of cards" behaviors.
    - **Extensions Integration**: Can be triggered seamlessly via custom Extensions using the `Nerw.notify` hook.
11. **App Menubar Search**:
    - **Action**: Dedicated `.args` action ("Search Menubar", icon: `menubar.dock.rectangle`) that dynamically fetches and searches menubar items of the active frontmost application on demand.
    - **Execution**: Searching and pressing Enter on a menu item action triggers it directly in the active app. Each menu item displays the target application's icon.
    - **Control**: Configurable in Settings > Actions > Features. Requires Accessibility permissions.

### Trigger Rules
- **Prefix Only**: Action triggers (like `find`, `google`, `add`) must be typed at the **start** of your query (e.g. `find report.pdf`).
- **No Suffix**: Typing triggers at the end (e.g. `report.pdf find`) is treated as literal text to prevent accidental activation.

### 🔌 Extensions System
Extend Nerw with **Swift** extensions — compiled executables that communicate via JSON stdin/stdout.
- **Location**: `~/.nerw/extensions/`
- **Format**: Each extension is a folder with `manifest.json` + `main.swift`.
- **Compilation**: Extensions are compiled during installation. No app restart required.
- **Capabilities**: Full access to macOS frameworks (EventKit, Contacts, URLSession, AppleScript, etc.).
- **See**: [Extension API Documentation](EXTENSION_API.md) for full details.

### 🖥 Nerw CLI
Nerw includes a powerful command-line interface for advanced users.
- **Location**: `Nerw.app/Contents/cli_bin/nerw`.
- **Activation**: Toggle via the **bolt icon** in the macOS menu bar.
- **Setup**: Enabling the CLI creates a symlink at `~/.nerw/bin/nerw` and automatically adds it to your `$PATH` (supporting `zsh` and `bash`).
- **Commands**:
    - `help`: Show usage instructions.
    - `extension`: Manage Nerw extensions from the terminal.

### 🧠 Frecency Algorithm
Nerw learns from you. It uses a **Frecency** (Frequency + Recency) algorithm to rank results.
- **Bonus**: Items used recently and frequently float to the top.
- **Decay**: Scores decay over time to keep results fresh.
- **Storage**: Persistent cache using `CacheManager`.

## 🛠 Advanced Workflows

### Clipboard History
Search for `clipboard`, `clip`, or `paste` to open the clipboard history split pane.
- `Enter`: Paste the selected clipboard entry.
- `Cmd + Backspace`: Delete the selected clipboard entry.
- `Cmd + K`: Open the clipboard entry context popup with Paste, Delete, and Pin/Unpin operations.
- `Cmd + P`: Pin or unpin the selected entry. Pinned entries stay at the top of clipboard history.

### Custom Search Engine Modifiers
Map keyboard modifier keys to specific search engines for instant "Feeling Lucky" or alternative searches.
1.  **Default**: `Shift + Enter` is mapped to **Google Lucky Search** (skips the search results page and goes directly to the first result).
2.  **Customization**:
    -   Add or remove mappings in **Settings > Search Engines**.
    -   Map `Shift`, `Command`, `Option`, or `Control` to any of your added search engines or bangs.
3.  **Use**: Type a query and press the modifier key with `Enter` (e.g., `Shift + Enter`) to use the alternative engine.

### Action Context
Open a side popup for the currently selected action to inspect and trigger the operations available for that action.
1.  **Trigger**: Press `Cmd + K` while an action is selected in the main panel.
2.  **Scope**: The popup is always built from the currently selected action only.
3.  **Layout**:
    -   The popup opens as a compact, glassy menu-style operation list without a search field.
    -   The first operation is selected by default.
    -   The list uses grouped separators and concise trailing metadata instead of repeating section/subtitle text on every row.
    -   Alias and hotkey configuration open inline editors inside the same popup.
4.  **Contents**:
    -   Default action execution for the selected result.
    -   Secondary/quick actions for hybrid results.
    -   Modifier-backed actions, such as alternate search-engine actions.
    -   Global per-action configuration entries like **Set Alias** and **Set Hotkey**.
5.  **Navigation**:
    -   `Enter`: Execute the selected operation.
    -   `Esc` or `Cmd + K`: Close the popup.
    -   `Down Arrow` / `Ctrl + N`: Move selection down.
    -   `Up Arrow` / `Ctrl + P`: Move selection up.
    -   Typing letters or initials jumps selection to the matching operation, similar to a native macOS context menu.
6.  **Editing**:
    -   Aliases are saved as space-separated triggers for the selected action.
    -   Hotkeys are recorded directly from the popup and registered as action-specific global shortcuts.
7.  **Close**: Press `Esc` or execute/save an operation to close the popup.

### Hide Actions
You can hide actions from the main search results if you prefer to trigger them exclusively via hotkeys.
1.  **Requirement**: An action can only be hidden if it has a custom hotkey assigned to it.
2.  **Toggle**:
    - You can hide/unhide an action using the **Hide Action** toggle in the Action Context popup (`Cmd + K`).
    - Alternatively, you can use the **Eye** icon button in the **Settings > Actions** tab next to the enable toggle.
3.  **Behavior**: Hidden actions will not appear in search results but can still be executed instantly using their assigned hotkey. If the hotkey is removed, the action will automatically unhide itself to remain accessible.

### Snippets & Text Expansion
Nerw includes a powerful system-wide text expansion utility. Define snippets that automatically expand into larger blocks of text anywhere in macOS.
1.  **Creation**: Search for `addsnippet` to create a new snippet. You must provide a **Name**, **Trigger**, and **Content**.
2.  **Dynamic Placeholders**: You can use placeholders in your snippet content:
    -   `{{clipboard}}`: Inserts the last copied text.
    -   `{{time}}`: Inserts the current time in the default format (HH:mm).
    -   `{{yyyy-MM-dd}}` (or any `DateFormatter` syntax): Inserts the current time in a custom format.
3.  **Expansion**: Type your trigger word (e.g., `;sig`) in any app, and Nerw will automatically erase the trigger and type out the expanded content. (Requires Accessibility permissions).
4.  **Management**: Search for `snippet` to open the Snippet Manager list view. From here you can search, preview, and manage your snippets.
    -   `Enter`: Type the snippet directly into the frontmost app.
    -   `Cmd + K`: Open the context menu to Edit or Delete the snippet.
5.  **Toggle**: You can temporarily disable text expansion globally in **Settings > General > Enable Snippet Expansion**.

### UI Theming & Typography
Nerw supports custom theming via `config.json` located at `~/.nerw/config.json`. Core dimensions and typography are centralized in `GlobalLayout.swift`.
You can customize:
- `font`: Custom font name (Global tokens in `GlobalLayout.swift` define sizes).
- `mainBackgroundColor`: Hex color for the panel background.
- `selectionBackgroundColor`: Hex color for the selected item background.
- `mainForegroundColor`: Hex color for primary text.
- `selectionForegroundColor`: Hex color for selected item text.
- `hintColor`: Hex color for placeholder/hint text.

Recent UI updates have increased the default font sizes (e.g., Search input to 24pt, Result titles to 16pt) for a more premium, high-readability experience.

### Multi-Argument Navigation
For actions requiring multiple inputs (like adding a search engine):
- **Tab**: Advance to the next argument step.
- **Shift + Tab / Backspace**: Go back to the previous step.
- **Enter**: Submit the current step or execute the final action.

### Multi-Field Input (Forms)
Some complex actions require structured input. Nerw renders these as native forms directly in the main panel.
1.  **UI**: Displays multiple fields (e.g., Text, Secure Password, Multiline Text) in a vertical stack. Fields can include helpful subtext beneath their titles.
2.  **Navigation**:
    -   `Tab`: Move focus to the next field.
    -   `Shift+Tab`: Move focus to the previous field.
    -   `Enter` (on last field): Submit the form.
    -   `Esc`: Return to main search (Clears previous input).
3.  **Extensions**: [Extensions](EXTENSION_API.md) can also trigger form inputs.

### Quick Actions (Secondary Actions)
Some results offer a secondary action, indicated by a **lightning bolt icon** when selected.
1.  **Trigger**: Press `Tab` on a supported result.
2.  **Behavior**: The search bar transforms to the secondary action mode.
3.  **Example**:
    -   Search for **Finder**.
    -   Press `Tab` -> Enters "Find File" mode.
    -   Type a filename to search within Finder's scope.
    -   **System Settings**:
        -   Search for **System Settings**.
        -   Press `Tab` -> Lists all individual settings panes (Appearance, Sound, Network, etc.).
        -   Type to filter (e.g. "Sound") and Enter to open directly.

### ⌨️ Keyboard Navigation
Designed for mouse-free usage:
- **Navigation**:
  - `Ctrl + N` or `Down Arrow`: Next Result
  - `Ctrl + P` or `Up Arrow`: Previous Result
- **Actions**:
  - `Enter`: Open/Execute selected result. (Hold `Cmd` to Reveal in Finder for files).
  - `Tab`: Enter Argument Mode (if supported) or trigger **Quick Action** (if available).
  - `Cmd + K`: Open or close **Action Context** for the selected action.
  - `Esc`: Close Nerw.

## ⚡ Performance
- **Native Swift**: Built with AppKit/Core Graphics for maximum performance.
- **Low Footprint**: Minimal resource usage (`.accessory` activation policy).
- **Fast Fuzzy Search**: Uses the integrated `NerwSearchBackend` search library (Fuse implementation).
- **NLP Query Categorizer**: Uses Apple's NaturalLanguage framework with pre-compiled regex and reusable NLTagger for microsecond-speed query classification.
- **Async Icons**: Icons are loaded asynchronously to prevent UI stalling. Cached at `~/Library/Application Support/Nerw/Icons`.
