# Nerw Features Guide

Nerw is a Keyboard-First Spotlight replacement for macOS, designed for speed and extensibility.

## 🚀 Core Features

### Global Hotkey
- **Toggle**: `Cmd + Shift + Space`
- Activates the popup instantly from anywhere in macOS.

### Smart Search
Nerw intelligently routes your query to the best provider:
1.  **Applications**: Fuzzy search installed apps (e.g., "xcode" -> Xcode).
2.  **Web Search**: Direct integration with:
    - Google (`google [query]`)
    - Bing (`bing [query]`)
    - DuckDuckGo (`duck [query]`)
    - Yahoo (`yahoo [query]`)
3.  **Calculator**: (Planned/Upcoming) Basic math operations.
4.  **Files**: searching for files `find [query]`

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

### Multi-Argument Navigation
For actions requiring multiple inputs (like adding a search engine):
- **Tab**: Advance to the next argument step.
- **Shift + Tab / Backspace**: Go back to the previous step.
- **Enter**: Submit the current step or execute the final action.

### ⌨️ Keyboard Navigation
Designed for mouse-free usage:
- **Navigation**:
  - `Ctrl + N` or `Down Arrow`: Next Result
  - `Ctrl + P` or `Up Arrow`: Previous Result
- **Actions**:
  - `Enter`: Open/Execute selected result.
  - `Tab`: Enter Argument Mode (if supported) or Auto-complete.
  - `Esc`: Close Nerw.

## ⚡ Performance
- **Native Swift**: Built with AppKit for maximum performance.
- **Low Footprint**: Minimal resource usage (`.accessory` activation policy).
- **Fast Fuzzy Search**: Uses the integrated `Ifrit` search library (Fuse implementation).
