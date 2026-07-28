# Nerw Codebase Context for Agents

This file provides a comprehensive overview of the Nerw codebase to assist AI agents in understanding the project structure, core components, and development conventions.

**Usage:** Agents should consult this file first when navigating the codebase to understand where logic resides and how components interact.
**Maintenance:** Agents are responsible for updating this file when structural changes, new modules, or significant architectural shifts occur.

---

## 1. Project Overview
**Nerw** is a native macOS popup utility (Spotlight alternative) written in Swift using AppKit/Cocoa.
- **UI Architecture**: Programmatic Auto Layout (No Storyboards/XIBs).
- **Core Philosophy**: Extreme efficiency, low resource usage (minimal process spawning), and instant responsiveness.
- **Entry Point**: `main.swift` -> `AppDelegate.swift`.

## 2. Directory Structure & Modules
The source code is organized into modular targets within `Sources/`:

### `Nerw` (App Target)
- **Role**: Application shell and lifecycle management.
- **Key Files**:
    - `main.swift`: Entry point.
    - `AppDelegate.swift`: Sets up the global hotkey (`Cmd+Shift+Space` by default), accessory mode (no Dock icon), and handles URL schemes/file openings.
    - `HotKeyManager.swift`: Carbon-based global hotkey registration.

### `NerwCLI` (CLI Target)
- **Role**: Command-line interface for Nerw.
- **Key Files**:
    - `main.swift`: CLI entry point and command dispatcher.

### `NerwUI` (User Interface)
- **Role**: Contains all View Controllers, Views, and UI logic.
- **Key Components**:
    - `MainPanel.swift`: The floating, borderless `NSPanel` subclass.
    - `NerwPanelView.swift` & `NerwPanelFactory.swift`: Central framework for frosted glass, theming, and shared panel construction. Replaces duplicated background setups across UI.
    - `MainPanelWindowController.swift`: Manages the lifecycle and positioning of the main search panel.
    - `MainPanelContentViewController.swift`: The central UI controller. Manages:
        - **InputState Machine**: `.search`, `.argument`, `.form`.
        - Results navigation and selection logic.
        - **Action Context**: Opens an inline overlay panel for the selected result (`Cmd+K` or 3-dot button on selected row). The overlay appears centered over the trigger point with a liquid glass effect and pop animation. Routes per-action operations such as primary execution, hybrid secondary actions, modifier actions, aliases, and hotkeys.
        - Dynamic layout updates for "Peek" mode (expanded result view).
    - `ActionContextViewController.swift`: Lightweight popover content for browsing and executing the current action's context operations, including inline alias/hotkey editing and the ability to enable/disable specific actions. Supports `isInlineMode` for rendering inside the parent panel (no connector line or gap). It owns popup-local selection state, menu-style type-select, and popup-root keyboard routing.
    - `ResultCellView.swift`: Custom table cell rendering search results with async icon loading, "Peek" support, and a 3-dot vertical context button visible on the selected row.
    - **Notification System**: `NotificationManager.swift`, `NotificationPanel.swift`, `NotificationItemView.swift`. Handles glassmorphic, stacked alerts.
    - **Specialized Views**: `ExtensionCardView.swift` (Settings list), `FormView.swift` (Multi-field inputs), `IconDropView.swift` (Drag & Drop support), `KeybindRecorder.swift` (Hotkey input).
    - **Settings**: `GeneralSettingsViewController`, `AppearanceSettingsViewController`, `FeaturesSettingsViewController`, `SearchEnginesSettingsViewController` (WebSearch - includes a dropdown to configure the fallback modifier key), `ExtensionSettingsViewController`, `ActionsSettingsViewController` (renders lightweight row models with aliases, hotkeys, and enable/disable toggles).
    - `SettingsWindowController.swift`: Manages the tabbed settings interface.
    - `ExtensionInstallWindowController.swift`: Manages the `.nerw` extension installation flow and confirmation UI.
    - **Conversation UI**: `ConversationViewController.swift` and `ConversationWindowController.swift`. A custom, premium card-based interface for AI chat, featuring history segments, translucent text cards, and dynamic UI elements like `PromptTextField` and context menus for chat clearing and navigation.
    - **UI Helpers**: `ColorExtensions.swift`, `NSColor+Hex.swift`, `SettingsSection.swift`, `GlobalLayout.swift` (Centralized UI Dimensions & Typography).

### `NerwBuiltin` (Features)
- **Role**: Core search providers and internal capabilities.
- **Key Components**:
    - `SearchService.swift`: The central orchestrator. Aggregates results from Apps, Built-ins, and Extensions while filtering out disabled actions. Handles fuzzy matching and ranking. Delegates Web Search and Fallback Search to dedicated services. Also handles pinning **inlineArg** triggers to the top.
    - `WebSearchService.swift`: Handles generating web search actions and resolving icons for web search engines.
    - `FallbackSearchService.swift`: Handles generating fallback search actions (both web search engines and generic actions).
    - `SearchEngine.swift`: Manages custom search engines and bang matching (!g, !yt). Persists to `~/Library/Application Support/Nerw/Bangs.json`.
    - `FindFile.swift`: Native Spotlight integration using `NSMetadataQuery` for instant file search. Requests permission for protected folders (Downloads, Documents, Desktop) on-demand upon first search.
    - `AppSearch.swift`: Fast application indexing and launching. Uses focused `NSMetadataQuery` scopes (`/Applications`, `/System/Applications`, `~/Applications`, CoreServices) to avoid scanning the entire user directory tree.
    - `MenubarSearch.swift`: Active application menubar item search. Provides an on-demand `.args` action ("Search Menubar") using Accessibility APIs to search and trigger click-able menu actions for the frontmost app.
    - `System.swift`: System commands (Dictionary, Wikipedia, file cleanup, volume ejection, etc.), plus WiFi and Bluetooth integration.
    - `QuickAction.swift`: Real-time process management (Quit/Force Quit).
    - `ShortcutsManager.swift` & `ShortcutsEngine.swift`: Integration with macOS Shortcuts system. Features on-demand `stat()` file modification checking for zero-overhead background reindexing and `.hybrid` action generation (`Enter` for instant execution, `Tab` for piped stdin argument input).
    - `IconManager.swift`: Built-in component for icon lifecycle and resource management.
    - `MathConversionService.swift`: Handles `.mathConversion` category queries. Evaluates simple math expressions using `JavaScriptCore`, converts Foundation units via `MeasurementFormatter`, and fetches real-time currency conversions from Frankfurter API.
    - `Nerw.swift`: Global singleton for cross-module command execution. Exposes built-in actions (e.g. `quit`) and internal APIs such as:
        - `Nerw.notify(_ content: String, level: NerwNotificationLevel = .info, progressive: Bool = false, id: UUID? = nil)`
        - `Nerw.dismissNotify(id: UUID)`

### `NerwAction` (Action Domain & Preferences)
- **Role**: Standalone module defining core action models and user configurations, decoupled from central application logic.
- **Key Components**:
    - `NerwAction.swift`: The core result model. Defines icons, titles, and `ActionType` (`.instant`, `.arg`, `.inlineArg`, `.hybrid`, `.form`).
    - `NerwActionContext.swift`: Shared per-action context model and menu builder.
    - `NerwActionPreferenceManager.swift`: Manages global assignment of aliases, hotkeys, disabled, and hidden states locally in `~/.nerw/actions.json`.
    - `NerwActionHidden.swift` & `NerwActionEnabled.swift`: Interfaces for toggling action visibility.

### `NerwCore` (Core Logic & Extension System)
- **Role**: Fundamental data models and the extension engine.
- **Key Components**:
    - `ConfigManager.swift`: Manages global application settings and `~/.nerw/config.json`.
    - `AIProviderPreset.swift`: Central lookup table and registry for AI model provider presets (OpenAI, Google Gemini, Claude, OpenRouter, Custom). Defines default endpoint URLs, domain match patterns, default search tool names, and model placeholders.
    - `NerwTheme.swift`: Pure data struct representing a normalized snapshot of the UI state (e.g. colors, rounded corners) computed from `ConfigManager`.
    - `NerwPanelContext.swift`: Shared state for window positioning and font synchronization.
    - `ExtensionEngine.swift`: Process-based Swift extension engine. Compiles `main.swift` via `swiftc` at install time, executes extensions as child processes communicating via JSON stdin/stdout. Supports multiple actions per extension and smart trigger resolution. Automatically injects current `NerwThemeConfig` into extension runtime. Also tracks long-running extension processes and renames them using hardlinks for easy identification in Activity Monitor. **When a daemon is running, queries and actions are routed through `DaemonManager` instead of spawning a fresh process.**
    - `ExtensionInstaller.swift`: Handles `.nerw` package installation, compilation, and lifecycle. No app restart required. Posts `nerwDaemonApprovalRequired` notification when a daemon-capable extension is installed.
    - `ExtensionModel.swift`: Extension manifest model with `ExtensionMode` (script/binary), `ExtensionActionManifest` with explicit `type` support, and the new `DaemonConfig` struct (enables `daemon` field in `manifest.json`).
    - `DaemonRegistry.swift`: **[NEW]** Persists daemon approval state and crash history to `~/.nerw/daemon_registry.json`. Key: one entry per extension that has ever requested daemon mode. Provides: `approve/revoke/enable/disable`, `recordCrash` (5-crash/10-min budget), `resetCrashCount` (after 60s uptime), `isRunnable`.
    - `DaemonIPC.swift`: **[NEW]** Host-side Unix domain socket client (`DaemonConnection`). Uses NDJSON envelope (`DaemonMessage`) with Base64-encoded payloads and correlation IDs. Supports: `sendQuery` (with timeout + fallback), `sendAction` (fire-and-forget), `healthCheck`, `sendStop`. Forwards unsolicited `ext_command` pushes to `ExtensionEngine.executeCommands`.
    - `DaemonResourceMonitor.swift`: **[NEW]** Polls running daemons every 5s via `proc_pid_rusage`. Memory over limit → immediate SIGTERM→SIGKILL. CPU >25% sustained for 30s (6 samples) → same. Calls `onViolation` and auto-disables the extension in the registry.
    - `DaemonManager.swift`: **[NEW]** Central daemon lifecycle orchestrator. Starts all approved daemons on app launch, routes queries/actions, restarts crashes with exponential backoff (2→4→8→16→32s), stops all on app quit. Exposes `status()` for CLI.
    - `DaemonNotifications.swift`: **[NEW]** `Notification.Name.nerwDaemonApprovalRequired` constant.
    - `NerwUIInterface.swift`: Defines the interface and contract between core logic and the UI layer.

- **Role**: Pure search algorithms, ranking, and query classification.
- **Key Components**:
    - `Classes/Frecency/Frecency.swift`: \"Frequency + Recency\" scoring. Supports both Global and Query-Aware ranking.
    - `Fuse.swift`: Fuzzy search library integration.
    - `QueryCategory.swift`: Enum defining action categories (`webSearch`, `url`, `mathConversion`) for smart ranking.
    - `QueryCategorizer.swift`: NLP and regex-based query classifier. 
    - **Search Algorithms**:
        - `Levenstain/`: String similarity algorithms.
        - `FuzzyFind/`: Advanced fuzzy matching logic including scoring and result segmenting.

### `NerwExtensionKit` (Extension SDK)
- **Role**: The Swift SDK (Static Library) supplied to extension developers to build native Swift extensions for Nerw.
- **Key Components**:
    - `NerwAPI.swift`: Host commands (`Nerw.open`, `Nerw.copy`, `Nerw.log`) and the JSON bootstrap sequence. Now also contains `run(extension:daemon:)` overload and the daemon message loop (entered when the binary is launched with `--daemon --socket <path> --data-dir <path>`).
    - `NerwDaemon.swift`: **[NEW]** `NerwDaemon` protocol (`onStart/onQuery/onAction/onStop`) and `DaemonContext` struct.
    - `DaemonSocket.swift`: **[NEW]** Extension-side Unix domain socket server (`DaemonSocketServer`). Creates, binds, and accepts one connection; provides `readMessage/sendMessage` for NDJSON protocol.
    - `NerwPanel.swift`: Convenience `NSPanel` subclass that builds a fully themed window inside the extension process, matching the host's styling, layout, and positioning data (via `NerwThemeConfig`).
    - `NerwResult.swift`: The fluent builder pattern API allowing easy construction of Complex, Hybrid, Arg, InlineArg, and Form actions.

- **Role**: Shared helpers and core low-level utilities.
- **Key Components**:
    - `Cache/Cache.swift`: Lightweight JSON persistence utility.
    - `HotkeyParser.swift`: Carbon hotkey string parser.
    - `IconUtils.swift`: Asynchronous icon loading/generation using `QuickLookThumbnailing`.
    - `CLIUtils.swift`: CLI installation, symlinking, and shell configuration (`PATH`) management.
    - `MemoryManager.swift`: Efficient memory cleanup and pool management.

---

## 3. Key Concepts & Conventions

### UI & Layout
- **No Interface Builder**: All UI is built in code using Auto Layout anchors.
- **Theming & NerwTheme**: Colors and fonts are dynamic, driven by `ConfigManager.shared.config.uiConfig` and computed into a `NerwTheme` snapshot. `NerwPanelView` automatically applies this theme and listens for `NerwConfigDidUpdate`.
- **Navigation**: Uses `doCommandBy` selectors for robust keyboard handling (Arrows, Tab, Esc, Enter).
    - Note: `ActionContextViewController` focuses its search field as the primary responder when browsing context operations. Keyboard navigation commands are routed from the search field delegate to the table view selection.

### Search & Execution Flow
1. **Input**: User types in `MainPanelContentViewController`.
2. **Aggregation**: `SearchService` gathers candidates from all modules and filters out actions disabled in preferences.
3. **Trigger Matching**: `SearchService` checks for exact matches on `inlineArg` trigger words and pins dynamic actions to the top.
4. **Fuzzy Match**: `Fuse` matches query against titles/triggers for remaining candidates.
5. **Query Classification**: `QueryCategorizer` classifies the query (URL, web search, or none) using NLP.
6. **Ranking**: `FrecencyManager` boosts results based on historical usage. `QueryCategorizer` boosts category-tagged actions when the query matches that category — but a **trigger-match guard** ensures real matches always outrank NLP-boosted results.
7. **Selection**: User selects a result.
8. **Action Context (Optional)**: `Cmd+K` or clicking the 3-dot icon on the selected row opens an inline overlay panel centered on the trigger point. The overlay uses liquid glass styling and appears with a pop-in spring animation. It enumerates operations for the selected action only, including modifier actions and global action configuration like alias/hotkey assignment. Clicking outside the overlay dismisses it.
    - UI shape: compact, glassy menu list with grouped separators, rendered inline over the parent panel (not in a separate window).
    - Intended keyboard behavior: first row selected by default, `↑ / ↓` or `Ctrl-P / Ctrl-N` (Unix Style) / `Ctrl-J / Ctrl-K` (Vim Style) move selection, typing characters into the search field filters operations fuzzily using Fuse, `Enter` executes, `Esc` and `Cmd+K` close.
9. **Execution**: `NerwAction.type` determines the next step (Execute instantly, ask for arguments, open a form, or drill into a hybrid secondary action).
10. **Fallback Modifier**: When the configured modifier (default: `⌘ Cmd`) is held, search results are swapped with fallback searches. Pressing `Enter` while holding the modifier executes the selected fallback search. Releasing the modifier restores the original search results list.

### Extension Daemon Flow (new)
1. Manifest declares `"daemon": { "enabled": true, "description": "...", "memoryLimit": 128 }`.
2. On install, `ExtensionInstaller` posts `nerwDaemonApprovalRequired` notification.
3. `AppDelegate` shows a system alert. If approved, `DaemonRegistry.approve()` is called.
4. `DaemonManager.startDaemon()` launches the binary with `--daemon --socket <path> --data-dir <path>`.
5. Extension binary detects `--daemon` and enters `runDaemonMode()`, creating a Unix socket server.
6. Host connects, performs health check, registers with `DaemonResourceMonitor`.
7. Queries/actions are routed via `DaemonConnection` (bypassing process-spawn path).
8. Crashes trigger exponential backoff restarts; 5 crashes in 10 minutes auto-disables.
9. On app quit, `DaemonManager.stopAll()` sends `stop` message, waits 2s, then terminates.

### State Management
- **InputState**:
    - `.search`: Filtering results.
    - `.argument`: Multi-step command execution (e.g. `Kill -> ProcessName`).
    - `.form`: Structural data input via custom fields.

### Persistence Locations (managed by NerwPaths)
- **Config**: `~/.nerw/config.json`.
- **Action Preferences**: `~/.nerw/actions.json`.
- **Extensions**: `~/.nerw/extensions/`.
- **Daemon Registry**: `~/.nerw/daemon_registry.json`. **[NEW]**
- **Daemon Sockets**: `~/.nerw/run/<extension-id>.sock`. **[NEW]**
- **Daemon Data Dir**: `~/.nerw/extensions/<id>/data/`. **[NEW]**
- **Web Search Sites**: `~/Library/Application Support/Nerw/WebSearch.json`.
- **Cache**: `~/Library/Application Support/Nerw/Data/cache.json`.
- **Frecency**: `~/Library/Application Support/Nerw/Data/frecency.json`.
- **Clipboard History**: `~/Library/Application Support/Nerw/Data/clipboard.json`.
- **Clipboard Images**: `~/Library/Application Support/Nerw/Data/ClipboardImages/`.
- **Icons**: `~/Library/Application Support/Nerw/Icons/`.
- **Logs**: `~/.nerw/log/`.

---


---

## 4. Build System & Tooling
- **Makefile**: For building

## 5. Agent Instructions
- **Consistency**: Adhere to the programmatic Auto Layout pattern.
- **Performance**: Favor native macOS APIs (like `NSMetadataQuery`) over process spawning (`find`, `grep`).
- **Updates**: Update this file if you introduce new modules or significantly change data persistence or flow.

## 6. Future Work / Reminders
- **Extension UI Packager**: We need to build a UI tool within the app (or externally) that allows extension developers to package their source folders into `.nerw` zip files easily. (Currently done manually via `zip`).

---

## 7. SplitPane Layout System (`NerwUI/SplitPane/`)

A reusable **Raycast-style split-pane layout** exposed as a public API for any current or future feature (including extensions).

### Files
| File | Purpose |
|---|---|
| `SplitPaneItem.swift` | Lightweight display struct + `SplitPaneDataSource` / `SplitPaneDelegate` protocols |
| `SplitPaneCellView.swift` | Left-pane row cell (icon + title + subtitle + time badge) |
| `SplitPanePreviewView.swift` | Right-pane adaptive preview (text, image, metadata strip) |
| `SplitPaneViewController.swift` | Host controller — left list + right preview, keyboard-first nav |

### Usage
```swift
SplitPaneManager.shared.show(title: "My Feature", icon: myIcon, dataSource: ds, delegate: del)
SplitPaneManager.shared.hide()
```

### Memory Design
- `NSTableView` cell reuse (64-entry bounded `NSCache` for icons in `SplitPaneCellView`).
- Images in the preview are loaded lazily from disk on selection change and `nil`'d on deselection.
- The controller tears down fully on close; ARC reclaims all views.

### Keyboard Navigation
- `↑ / ↓` or `Ctrl-P / Ctrl-N` (Unix Style) / `Ctrl-J / Ctrl-K` (Vim Style) — move selection (matches main Nerw panel convention)
- `Enter` — primary action
- `⌫ / Delete` — secondary action (e.g. delete entry)
- `Cmd-K` or 3-dot icon — opens the same inline `NerwActionContext` overlay used by the main panel when the selected split-pane item exposes context operations.
- `Esc` — dismiss

---

## 8. NerwPanelContext (`NerwCore/NerwPanelContext.swift`)

A **pure CoreGraphics/Foundation** singleton that publishes the main panel's screen frame and font configuration. Any module (NerwBuiltin, NerwUI, extensions) reads this to position and theme secondary windows consistently — without importing NerwUI.

### Key APIs
```swift
// Producer (called in MainPanelWindowController.show())
NerwPanelContext.shared.update(mainPanelFrame: panel.frame)
NerwPanelContext.shared.update(configFontName: config.uiConfig?.font)

// Consumer (used by ClipboardWindowController, extensions, etc.)
let origin = NerwPanelContext.shared.origin(forSize: mySize, in: screenVisibleFrame)
let fontName = NerwPanelContext.shared.configFontName
```

### Positioning Logic
Secondary windows are placed just **below** the main panel (12 pt gap) when vertical space allows; otherwise centred on screen. Horizontal: always centred.

---

## 9. Clipboard Manager (`NerwBuiltin/ClipboardManager.swift`)

Full-featured clipboard history manager.

### Key Points
- **Polling**: `Timer` fires every 1.5 s, checks `NSPasteboard.changeCount` (integer compare — near-zero cost when nothing changes).
- **History limit**: 200 entries (struct array in RAM, ~kilobytes).
- **Images**: Saved as PNGs to `~/Library/Application Support/Nerw/ClipboardImages/`. Only the path lives in `ClipboardEntry` — no `NSImage` held in RAM.
- **Pinning**: `ClipboardEntry.isPinned` persists in `clipboard.json`. Pinned entries stay above normal history; new captures insert after the pinned prefix.
- **Deduplication**: Skips re-inserting if the most recent non-pinned entry has identical content.
- **Action Context**: Clipboard rows expose Paste (`Enter`), Delete (`Cmd-Backspace`), and Pin/Unpin (`Cmd-P`) operations through `NerwActionContext`.
- **Pastes via**: `CGEvent` Cmd+V simulation after writing to `NSPasteboard`.
- **Decoupling**: `ClipboardManager` is in `NerwBuiltin` and knows nothing about `NerwUI`. It exposes `showWindowCallback: (() -> Void)?` which `AppDelegate` injects, keeping the dependency graph acyclic.

### Persistence
- History: `~/Library/Application Support/Nerw/Data/clipboard.json`
- Images: `~/Library/Application Support/Nerw/Data/ClipboardImages/*.png`

### Trigger
Search for `clipboard`, `clip`, or `paste` in the main panel.

---

## 10. Snippet Manager & Text Expansion Engine (`NerwBuiltin/SnippetManager.swift` & `NerwBuiltin/TextExpansionEngine.swift`)

A system-wide text expansion utility allowing users to define triggers that expand into longer text.

### Architecture

**1. Data Layer (`SnippetManager.swift`)**
- Manages `Snippet` models: `id`, `name`, `trigger`, `content`, `createdAt`.
- Persists to `~/Library/Application Support/Nerw/Data/snippets.json`.
- Exposes `addSnippet(name:trigger:content:)`, `updateSnippet(...)`, and `deleteSnippet(...)`.
- Resolves dynamic placeholders (`{{time}}`, `{{clipboard}}`, `{{yyyy-MM-dd}}`) during expansion.
- Registers `.instant` ("Snippet Manager") and `.form` ("Add Snippet") actions.

**2. Core Engine (`TextExpansionEngine.swift`)**
- Sets up a system-wide `CGEvent.tapCreate` for keystroke monitoring (requires Accessibility permissions).
- Maintains a small sliding window buffer of recent keystrokes.
- On trigger match:
  1. Stops the buffer.
  2. Synthesizes `CGEvent` backspaces to erase the typed trigger.
  3. Synthesizes `CGEvent.keyboardSetUnicodeString` to type the expanded text character-by-character.
- Respects the `snippetExpansionEnabled` config flag to toggle monitoring globally.

**3. UI Bridge (`Nerw/SnippetController.swift`)**
- Mirrors `ClipboardController` pattern.
- Uses `SplitPaneViewController` to display a searchable list of snippets.
- `Cmd+K` exposes Edit (re-opens form), Delete, and Type actions.

---

## 11. AI Integration & Local Socket Server (`NerwCore/AI/` & `NerwUI/AISettingsViewController.swift`)

A modular backend AI subsystem orchestrating queries to foundation on-device models or custom Bring-Your-Own-Key (BYOK) endpoints over a line-delimited socket connection.

### Files
| File | Purpose |
|---|---|
| `AIService.swift` | The central router that reads the active config and delegates to model handlers |
| `FoundationModelHandler.swift` | Implements Apple Intelligence (`FoundationModels`) with runtime availability checks and simulated fallback |
| `BYOKModelHandler.swift` | Formats OpenAI-compatible chat completions JSON payloads (supporting base64 images) over URLSession |
| `AISocketServer.swift` | Unix Domain Socket server at `~/.nerw/run/ai.sock` that processes NDJSON requests/responses |
| `AISettingsViewController.swift` | Tabbed Settings UI controller utilizing `SettingsSection` to configure AI state and options |

### IPC & Socket Connection
Clients (e.g. frontends) communicate with Nerw's background server by connecting to `~/.nerw/run/ai.sock` and writing/reading JSON envelopes framed by `\n` characters.

### Precise Context Injection (PCI) & Conversation Continuation
The AI backend automatically detects intents (e.g., active website, clipboard, calendar, reminders, menubar actions, timer, memory, email) from the user's prompt and conversation history using `IntentClassifier` and dynamically injects the relevant local data using `ContextInjectionManager` before querying the model. `IntentClassifier` uses a 4-Stage Intent Evaluation Pipeline incorporating Apple's offline `NaturalLanguage` framework (`NLTagger` lemmatization/POS tagging and `NLEmbedding` semantic similarity) and `NerwSearchBackend`'s synchronous Levenshtein distance (`levenshteinDistanceScore`) for typo resilience and grammatical variation tolerance. When continuing a conversation with follow-up queries (e.g. "create another one", "do it again"), `IntentClassifier` inspects previous turns in history to inherit action schemas and context intents. `ConversationViewController` tracks `rawResponse` in `ChatTurn` so conversation history passed to `AIService` preserves exact `<action>JSON_PAYLOAD</action>` schemas instead of UI markdown badges, while `AIStreamParser` provides fallback execution for markdown action pills (`![action:type|detail]`).

---

## 12. AI Conversation Layout System (`NerwUI/Conversation/`)

A minimal, card-based chat layout utilizing `AIService` directly inside the app, with identical dimensions to the main panel and supporting live streaming.

### Files
| File | Purpose |
|---|---|
| `ConversationManager.swift` | Exposes the builtin search action triggers (`ai`, `chat`, `ask`, `assistant`). Provides both a direct launch action (`builtin.aichat`) and an inline query action (`builtin.aiquery`). The inline query action is automatically suggested as a high-relevance result when the query categorizer detects a natural language question (`.webSearch`). |
| `ConversationViewController.swift` | Builds the visual layout: left indicator timeline bars (`SegmentBarView`), center response card, user query capsule placed outside the card, scrollable text area, floating glassmorphic prompt input (containing an active generation spinner), floating circular trash button, large sparkles placeholder for empty chat history, streaming Task management, and **interactive markdown nodes with a floating selection pill** mapped to keyboard navigation (`Tab` / `Enter`). |
| `ConversationWindowController.swift` | Manages the floating, non-activating `NSPanel` (`ConversationPanel`) overlapping the main panel's exact position |

### Flow & Navigation
- **Opening**: User selects the "AI Chat" search result. The search panel hides, and the conversation panel is centered directly over the main panel frame.
- **Empty State**: Renders a large translucent sparkles symbol in the center.
- **Timeline Paging**: The vertical stack of bars on the left lets users click on past queries to swap the response card content dynamically.
- **Subsystem Disabled State**: Renders a custom warning view with a glassy "Configure AI..." button. Clicking this dismisses the panel and posts the settings notification targeting the AI configuration tab.

