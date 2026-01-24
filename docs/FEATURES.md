# Nerw Features Guide

Nerw is a Keyboard-First Spotlight replacement for macOS, designed for speed and extensibility.

## 🚀 Core Features

### Global Hotkey
- **Toggle**: `Cmd + Shift + Space` (Configurable in `config.json`)
- Activates the Main Panel instantly from anywhere in macOS.

### Smart Search
Nerw intelligently routes your query to the best provider via the `SearchService`:
1.  **Applications**: Fuzzy search installed apps (e.g., "xcode" -> Xcode).
2.  **Web Search**: Direct integration with:
    - Google (`google [query]`)
    - Bing (`bing [query]`)
    - DuckDuckGo (`duck [query]`)
    - Yahoo (`yahoo [query]`)
    - **Adaptive Defaults**: If you have multiple default engines, Nerw learns your preference per query (e.g. preferring GitHub for code queries).
3.  **Smart File Search**:
    - **Trigger**: `find [query]`, `file [query]`.
    - **Engine**: Native Spotlight index access via `MDQuery` for near-instant results with zero process spawning.
    - **Filtering**: Automatically excludes developer artifacts like `node_modules`, `.git`, and `build` folders for cleaner results.
4.  **System Commands**: Quick access to common macOS actions:
    - `sleep` - Put your Mac to sleep  
    - `empty downloads` - Move Downloads folder contents to Trash
    - `eject [volume]` - Eject a specific volume (shows available volumes)
    - `eject all` - Eject all external volumes
    - `wifi` - Toggle WiFi or connect to known networks.
    - `bluetooth` - Toggle Bluetooth or connect to devices.
5.  **Calculator**: (Planned/Upcoming) Basic math operations.

### Trigger Rules
- **Prefix Only**: Action triggers (like `find`, `google`, `add`) must be typed at the **start** of your query (e.g. `find report.pdf`).
- **No Suffix**: Typing triggers at the end (e.g. `report.pdf find`) is treated as literal text to prevent accidental activation.

### 🔌 Extensions System
Extend Nerw with any executable (Script, Binary) that outputs JSON.
- **Location**: `~/.nerw/extensions/`
- **Output Format**:
  ```json
  {
    "items": [
      {
        "title": "Title",
        "subtitle": "Subtitle",
        "arg": "argument_to_pass",
        "icon": "icon_name"
      }
    ]
  }
  ```
- **See**: [Extension API Documentation](EXTENSION_API.md) for full details.

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
Nerw supports custom theming via `config.json` located at `~/.config/nerw/config.json`.
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

### Quick Actions (Secondary Actions)
Some results offer a secondary action, indicated by a **lightning bolt icon** when selected.
1.  **Trigger**: Press `Tab` on a supported result.
2.  **Behavior**: The search bar transforms to the secondary action mode.
3.  **Example**:
    -   Search for **Finder**.
    -   Press `Tab` -> Enters "Find File" mode.
    -   Type a filename to search within Finder's scope.

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
- **Async Icons**: Icons are loaded asynchronously to prevent UI stalling.
