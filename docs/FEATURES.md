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
    -   **Direct Search (Shift + Enter)**:
        - **Behavior**: Press `Shift + Enter` on any web search result (including bangs) to perform an optimized "I'm Feeling Lucky" style search.
        - **Speed**: Uses a dedicated, lightweight redirect-capture engine that bypasses standard search result pages to open the first result directly.
        - **Visual Feedback**: Shows a progressive notification ("Getting direct result...") while fetching.
        - **Caching**: Results are cached locally (query -> URL) with a hit-count-based eviction policy for near-instant repeat searches.
        - **Configuration**: Choose between **Google** or **DuckDuckGo** as the direct search provider in Settings.
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
    - `sleep` - Put your Mac to sleep
    - `empty downloads` - Move Downloads folder contents to Trash
    - `eject [volume]` - Eject a specific volume (shows available volumes)
    - `eject all` - Eject all external volumes
    - `wifi` - Toggle WiFi or connect to known networks.
    - `bluetooth` - Toggle Bluetooth or connect to devices.
7.  **Peek (Inline Previews)**: Provides rich, dynamic, multi-line expanded previews for selected results without leaving the search bar. Supported actions (like Dictionary definitions and Wikipedia summaries) can show extended titles, long typography-aware text blocks, custom icons, and interactive buttons right inside the list window that seamlessly scales vertically to fit exactly what you need.
8.  **Calculator**: (Planned/Upcoming) Basic math operations.
9.  **Notification System**:
    - **Glassmorphic Alerts**: Native pill-shaped frosted-glass notifications stack at the top center of the screen.
    - **Dynamic Elements**: Supports various tint types (`warn`, `error`, `info`) and optional unbounded progressive spinners.
    - **3D Stacking**: When multiple notifications overlap elegantly natively mirroring macOS "deck of cards" behaviors.
    - **Extensions Integration**: Can be triggered seamlessly via custom Extensions using the `Nerw.notify` hook.

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

### Custom Search Engines
Add your own search engines directly from the UI.
1.  **Trigger**: Type `add` or `add search engine`.
2.  **Step 1**: Enter the Search URL. Use `%s` for the query placeholder.
    - Example: `https://github.com/search?q=%s`
3.  **Step 2**: Enter a Keyword trigger.
    - Example: `gh`
4.  **Use**: Type `gh my-query` to search.

### UI Theming
Nerw supports custom theming via `config.json` located at `~/.nerw/config.json`.
You can customize:
- `font`: Custom font name.
- `mainBackgroundColor`: Hex color for the panel background.
- `selectionBackgroundColor`: Hex color for the selected item background.
- `mainForegroundColor`: Hex color for primary text.
- `selectionForegroundColor`: Hex color for selected item text.
- `hintColor`: Hex color for placeholder/hint text.

### Multi-Argument Navigation
For actions requiring multiple inputs (like adding a search engine):
- **Tab**: Advance to the next argument step.
- **Shift + Tab / Backspace**: Go back to the previous step.
- **Enter**: Submit the current step or execute the final action.

### Multi-Field Input (Forms)
Some complex actions require structured input. Nerw renders these as native forms directly in the main panel.
1.  **UI**: Displays multiple fields (e.g., Text, Secure Password) in a vertical stack.
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
  - `Esc`: Close Nerw.

## ⚡ Performance
- **Native Swift**: Built with AppKit/Core Graphics for maximum performance.
- **Low Footprint**: Minimal resource usage (`.accessory` activation policy).
- **Fast Fuzzy Search**: Uses the integrated `NerwSearchBackend` search library (Fuse implementation).
- **NLP Query Categorizer**: Uses Apple's NaturalLanguage framework with pre-compiled regex and reusable NLTagger for microsecond-speed query classification.
- **Async Icons**: Icons are loaded asynchronously to prevent UI stalling. Cached at `~/Library/Application Support/Nerw/Icons`.
