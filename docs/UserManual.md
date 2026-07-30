# Nerw User Manual

Welcome to the **Nerw User Manual**. This document is the comprehensive guide to installing, configuring, and mastering Nerw—a native, keyboard-first macOS popup utility and Spotlight replacement built for speed, automation, and AI-powered productivity.

---

## Table of Contents
1. [Overview & Core Philosophy](#1-overview--core-philosophy)
2. [Quick Start & Keyboard Navigation](#2-quick-start--keyboard-navigation)
3. [Unified Search & Core Capabilities](#3-unified-search--core-capabilities)
   - [Application Search](#31-application-search)
   - [Bang Web Search & Recency](#32-bang-web-search--recency)
   - [Native Spotlight File Search](#33-native-spotlight-file-search)
   - [Dictionary, Wikipedia & Peek Previews](#34-dictionary-wikipedia--peek-previews)
   - [System Commands & Connectivity](#35-system-commands--connectivity)
   - [Active App Menubar Search](#36-active-app-menubar-search)
4. [Advanced Interactive Workflows](#4-advanced-interactive-workflows)
   - [Action Context Panel (`Cmd + K`)](#41-action-context-panel-cmd--k)
   - [Custom Aliases, Hotkeys & Hiding Actions](#42-custom-aliases-hotkeys--hiding-actions)
   - [Inline Arguments (Alfred-style)](#43-inline-arguments-alfred-style)
   - [Multi-Field Structured Forms](#44-multi-field-structured-forms)
   - [Quick Actions (Secondary Actions via `Tab`)](#45-quick-actions-secondary-actions-via-tab)
   - [Clipboard History Manager](#46-clipboard-history-manager)
   - [Snippet Manager & Text Expansion](#47-snippet-manager--text-expansion)
   - [Custom Search Engine Modifiers (Feeling Lucky)](#48-custom-search-engine-modifiers-feeling-lucky)
5. [Nerw AI Assistant](#5-nerw-ai-assistant)
   - [Invoking AI Chat](#51-invoking-ai-chat)
   - [Conversation UI & Interactive Markdown Nodes](#52-conversation-ui--interactive-markdown-nodes)
   - [Precise Context Injection (PCI)](#53-precise-context-injection-pci)
   - [Semantic Memory & Action Hooks](#54-semantic-memory--action-hooks)
   - [Configuring AI Providers (Apple Intelligence & BYOK)](#55-configuring-ai-providers-apple-intelligence--byok)
6. [Extensions System & CLI](#6-extensions-system--cli)
7. [Customization, Settings & Theming](#7-customization-settings--theming)
8. [Performance & Architecture](#8-performance--architecture)

---

## 1. Overview & Core Philosophy

Nerw is a native macOS application written in Swift using AppKit and Core Graphics. It runs as an **accessory utility**, meaning it does not clutter your Dock and is always accessible via a global hotkey or the menu bar status icon.

- **Keyboard-First**: Every action, menu, form, and AI conversation can be navigated entirely without a mouse.
- **Low Footprint**: Nerw minimizes background process spawning and uses native Apple frameworks (`MDQuery`, `CoreServices`, `EventKit`, `NaturalLanguage`) to deliver microsecond responses.
- **Extensible & Adaptable**: Whether running built-in actions, custom Swift extensions, or AI models, Nerw adapts to your workflow through usage-based ranking (Frecency) and custom shortcuts.

---

## 2. Quick Start & Keyboard Navigation

### Activating Nerw
- **Global Hotkey**: Press `Cmd + Shift + Space` from anywhere in macOS to open or hide the main search panel (configurable in `~/.nerw/config.json`).
- **Menu Bar Icon**: Click the Nerw icon in the macOS menu bar to toggle the panel or open **Settings** (`Cmd + ,`).

### Core Keyboard Navigation
| Key / Combination | Action |
|---|---|
| `↓` / `Ctrl + N` / `Ctrl + J` | Move selection down to the next result |
| `↑` / `Ctrl + P` / `Ctrl + K` | Move selection up to the previous result |
| `Enter` | Execute the selected action (hold `Cmd` on files to Reveal in Finder) |
| `Tab` | Enter Argument Mode (advance multi-step inputs) or trigger a **Quick Action** |
| `Shift + Tab` / `Backspace` | Step backward in argument mode or return to previous form field |
| `Cmd + K` | Toggle the inline **Action Context** overlay for the selected result |
| `Esc` | Clear search input, close an active overlay/form, or dismiss Nerw |
| `Cmd + ,` | Open the Nerw Settings window |

---

## 3. Unified Search & Core Capabilities

Nerw intelligently routes your search queries across multiple specialized providers via `SearchService`:

### 3.1 Application Search
- Type any part of an installed macOS app's name (e.g., `xcode` or `safari`) to fuzzy-match and launch it immediately.
- Uses focused `NSMetadataQuery` scopes (`/Applications`, `/System/Applications`, `~/Applications`, and `CoreServices`) for instant indexing.

### 3.2 Bang Web Search & Recency
- **Bang Prefixes**: Type a bang trigger followed by your query to search a specific web engine directly (e.g., `!g swift` for Google, `!yt cat videos` for YouTube, `!ddg privacy` for DuckDuckGo).
- **Smart Recency**: When you search without a bang prefix (e.g., `swift`), Nerw remembers your last-used search engine for that term and automatically suggests it at the top of web results.
- **Smart NLP Categorizer**: Nerw uses Apple's `NaturalLanguage` framework to inspect queries in real-time. Natural language questions (e.g., `"how to configure docker"`) or URLs (`"github.com"`) automatically elevate web search actions without overriding exact keyword triggers.

### 3.3 Native Spotlight File Search
- **Trigger**: Type `find [filename]` or `file [filename]`.
- **Engine**: Queries Spotlight's native index (`MDQuery`) for instant results without spawning slow terminal search commands.
- **Smart Exclusions**: Automatically excludes developer clutter such as `node_modules`, `.git`, and `build` directories.
- **Action**: Press `Enter` to open the file with its default app, or hold `Cmd + Enter` to reveal it in Finder.

### 3.4 Dictionary, Wikipedia & Peek Previews
- **Dictionary Lookup**: Type `define [word]` or `def [word]` to fetch definitions via macOS `CoreServices`. Pressing `Enter` opens the native Dictionary app.
- **Wikipedia Search**: Type `wiki [topic]` to fetch real-time article summaries from Wikipedia. Pressing `Enter` opens the full article in your default browser.
- **Peek (Inline Previews)**: Selected results such as Dictionary definitions and Wikipedia summaries expand automatically in-place, showing rich multi-line typography, custom icons, and extended text inside the list view without leaving the search bar.

### 3.5 System Commands & Connectivity
- **Storage Cleanup**: Type `empty downloads` to move all files from your Downloads folder to the Trash.
- **Volume Ejection**: Type `eject [name]` to unmount a specific external drive, or `eject all` to unmount all external volumes safely.
- **Wi-Fi & Bluetooth**: Type `wifi` or `bluetooth` to toggle connectivity or connect to known wireless networks and devices directly.
- **Process Control**: Search `quit` or `kill` followed by an app name to terminate running macOS processes.

### 3.6 Active App Menubar Search
- **Trigger**: Select the **Search Menubar** action (icon: `menubar.dock.rectangle`).
- **Behavior**: Dynamically indexes every clickable menu item in your active frontmost application using Accessibility APIs.
- **Execution**: Type to filter menu options and press `Enter` to trigger the menu command instantly in the target application.

---

## 4. Advanced Interactive Workflows

### 4.1 Action Context Panel (`Cmd + K`)
When you select any action in Nerw, press `Cmd + K` (or click the 3-dot icon on the highlighted row) to open the **Action Context** panel.
- **Inline Glass Overlay**: Appears centered over the selected row with a liquid glass pop-in animation.
- **Action-Specific Operations**: Lists primary execution commands, hybrid secondary actions, and modifier searches available for that specific item.
- **Inline Configuration**: Select **Set Alias** or **Set Hotkey** directly within the popup to assign custom shortcuts without opening Settings.

### 4.2 Custom Aliases, Hotkeys & Hiding Actions
- **Aliases**: Assign custom space-separated shortcut words to any action. For example, assign `gh` to your favorite GitHub search or extension.
- **Global Hotkeys**: Record custom keybinds in the Action Context panel or in **Settings > Actions** to trigger specific actions from anywhere in macOS.
- **Hide Actions**: If an action has an assigned hotkey, you can toggle **Hide Action** (`Cmd + K` or the Eye icon in Settings). Hidden actions vanish from search results to keep your panel clean, but remain instantly executable via their hotkey.

### 4.3 Inline Arguments (Alfred-style)
- **Behavior**: Actions that accept parameters (such as `map London` or `define resilience`) pin themselves to the top of search results the moment you type their trigger word.
- **Execution**: Continue typing your argument after the space and press `Enter` to execute immediately.

### 4.4 Multi-Field Structured Forms
Some complex commands or extensions require multiple inputs (such as usernames, passwords, or multi-line text). Nerw renders these as native vertical forms inside the panel:
- `Tab` / `Shift + Tab`: Move focus between form fields.
- `Enter` (on the last field): Submit the form.
- `Esc`: Cancel form input and return to the main search view.

### 4.5 Quick Actions (Secondary Actions via `Tab`)
Results with a **lightning bolt icon** support secondary sub-scopes:
- **System Settings**: Search `System Settings`, press `Tab`, and filter through individual macOS settings panes (`Sound`, `Appearance`, `Network`) to jump directly to a specific pane.
- **Finder Search**: Search `Finder`, press `Tab`, and type a filename to restrict file searching within Finder's active scope.

### 4.6 Clipboard History Manager
- **Trigger**: Search `clipboard`, `clip`, or `paste`.
- **History Limit**: Efficiently tracks your last 200 clipboard items in memory, saving copied PNG images to `~/Library/Application Support/Nerw/ClipboardImages/`.
- **Pinning**: Press `Cmd + P` on any clipboard entry to pin or unpin it. Pinned items stay permanently locked at the top of your history.
- **Pasting & Deleting**: Press `Enter` to paste the selected item directly into your previous foreground app via simulated `Cmd + V`. Press `Cmd + Backspace` to delete an entry.

### 4.7 Snippet Manager & Text Expansion
Nerw includes a system-wide text expansion engine that replaces short trigger codes with full text templates anywhere in macOS (requires Accessibility permission):
- **Creating Snippets**: Search `addsnippet` to open the snippet creation form (requires **Name**, **Trigger**, and **Content**).
- **Dynamic Placeholders**:
  - `{{clipboard}}`: Inserts the most recent clipboard text.
  - `{{time}}`: Inserts current time in `HH:mm` format.
  - `{{yyyy-MM-dd}}`: Inserts the date or custom `DateFormatter` string.
- **Expanding Snippets**: Type your trigger word (e.g., `;sig`) in any macOS app; Nerw automatically backspaces the trigger and types out your expanded template.
- **Managing Snippets**: Search `snippet` to browse, preview, edit (`Cmd + K`), or delete existing snippets. Toggle text expansion globally in **Settings > General**.

### 4.8 Custom Search Engine Modifiers (Feeling Lucky)
In **Settings > Search Engines**, you can map keyboard modifier keys (`Shift`, `Command`, `Option`, `Control`) to specific search providers:
- **Default Mapping**: `Shift + Enter` is mapped to **Google Lucky Search**, bypassing search result pages and jumping directly to the first website.
- **Custom Modifiers**: Bind any modifier to your preferred search engine or bang so holding that modifier while pressing `Enter` executes an alternative search instantly.

---

## 5. Nerw AI Assistant

Nerw features an integrated conversational AI assistant designed around privacy, local environment awareness, and keyboard speed.

### 5.1 Invoking AI Chat
- **Trigger**: Search for `ai`, `chat`, `ask`, or `assistant`, or select the **AI Chat** built-in action.
- **Window Layout**: The search panel transforms into a floating, borderless card-based conversation window positioned over the same frame.

### 5.2 Conversation UI & Interactive Markdown Nodes
- **Timeline Paging (`SegmentBarView`)**: The vertical stack of bars on the right side of the card represents your chat history turns. Click any bar to swap the display to that conversation turn.
- **Interactive Markdown Nodes**: As AI responses stream, Nerw parses bold text, code blocks, and links into selectable **Nodes**.
  - **Keyboard Selection**: Press `Tab` and `Shift + Tab` from the prompt input box to cycle through interactive nodes in the response. A floating liquid glass pill highlights the active node.
  - **Executing Nodes**: Press `Enter` on an active link node to open it in your browser. Press `Enter` on a code block or bold node to copy the content, hide Nerw, and paste it directly into your foreground app. Press `Esc` to clear node selection.
- **Chat Context Menu**: Click the 3-dot button on the prompt field (or press `Cmd + K`) to open the chat context menu for options like **Clear Chat** (`⌥⌘⌫`) or **Previous/Next Message**.

### 5.3 Precise Context Injection (PCI)
Nerw AI understands what you are working on without manual copy-pasting. Using Apple's `NaturalLanguage` framework (`NLTagger`), Nerw classifies your query's intent and dynamically injects local context into the system prompt:
- **Active App & Web Page**: Reads the title of your foreground app or fetches the raw text of your active Safari/Chrome browser tab.
- **Screen Capture**: Asynchronously captures an instant screenshot of your primary display the moment you open AI Chat to provide visual context to multimodal models.
- **Clipboard Context**: Injects your most recent clipboard items.
- **Calendar & Reminders**: Fetches upcoming appointments or incomplete reminders filtered by natural language timeframes mentioned in your prompt (`"today"`, `"this week"`).
- **Notes & Files**: Fuzzy-matches filenames in your configured Notes directory (`~/.nerw/config.json` -> `notesDirectoryPath`) and injects file contents (up to 10,000 characters).

### 5.4 Semantic Memory & Action Hooks
- **Long-Term Memory**: When you share personal preferences or facts, Nerw AI files a memory action (`~/.nerw/memory.json`). Using Apple `NaturalLanguage` sentence embeddings (`NLEmbedding`), it deduplicates facts and updates importance scores. A translucent `brain.fill` badge on the chat card signals when a memory has been stored.
- **Native Action Hooks**: The AI can perform system actions directly from conversation, such as setting notification timers, scheduling Calendar events (`EventKit`), and creating Apple Reminders.

### 5.5 Configuring AI Providers (Apple Intelligence & BYOK)
Open **Settings > AI** (`Cmd + ,` -> AI tab) to configure your intelligence backends:
- **Apple Intelligence (FoundationModels)**: Run natively on macOS 15.0+ Apple Silicon using on-device Apple language models.
- **BYOK (Bring Your Own Key)**: Add custom cloud or local providers that support OpenAI-compatible chat completion endpoints:
  - **OpenRouter / Cloud APIs**: Input your endpoint URL, API key, and model name (e.g., `google/gemini-2.5-flash:free` or Claude models) and enable vision support if applicable.
  - **Local Ollama**: Connect to `http://localhost:11434/v1/chat/completions` with model names like `llama3.1` for completely offline, zero-cost AI assistance.

---

## 6. Extensions System & CLI

### 6.1 Native Swift Extensions
Nerw can be extended using native Swift packages located in `~/.nerw/extensions/`. Each extension folder contains a `manifest.json` and a `main.swift` source file:
- **Compilation on Install**: Extensions are compiled via `swiftc` when installed. No application restart is required.
- **Full macOS Framework Access**: Extensions can import `AppKit`, `EventKit`, `Contacts`, `CoreServices`, `URLSession`, and more.
- **Execution Modes**:
  - **Standard Process Mode**: Runs as a lightweight child process communicating with Nerw via JSON stdin/stdout.
  - **Daemon Mode**: Approved extensions can run as background daemons (`~/.nerw/run/<id>.sock`), maintaining persistent socket servers for continuous tasks, background monitoring, and zero-latency execution.
- **UI & Form Integration**: Extensions inherit Nerw's design tokens and theme settings automatically, allowing them to render native forms, notifications (`Nerw.notify`), and split-pane lists.

### 6.2 The Nerw CLI (`nerw`)
Nerw includes a command-line interface executable at `Nerw.app/Contents/cli_bin/nerw`.
- **Activation**: Toggle CLI integration in **Settings > General** or via the menu bar status icon to symlink `nerw` into `~/.nerw/bin/nerw` and add it to your `$PATH`.
- **Commands**:
  - `nerw help`: Display available commands and flags.
  - `nerw extension`: Install, test, and manage extensions from your terminal.

---

## 7. Customization, Settings & Theming

### 7.1 Settings Tabs Overview
Open Settings with `Cmd + ,`:
- **General**: Toggle launch at login, snippet expansion, and CLI `$PATH` integration.
- **Appearance**: Adjust UI theming, font sizes, and window transparency.
- **Features**: Toggle core built-ins like Menubar Search, Dictionary, and Wikipedia.
- **Search Engines**: Manage web bang triggers and configure modifier key shortcuts (Lucky Search).
- **Extensions**: Inspect installed extensions, review daemon permissions, and configure extension preferences.
- **Actions**: View all registered actions, enable/disable individual items, assign aliases, record hotkeys, and toggle visibility.
- **AI**: Configure AI backends, manage BYOK API keys, and set Notes directory paths.

### 7.2 UI Theming via `config.json`
Nerw's design system can be customized in `~/.nerw/config.json` under `uiConfig`:
```json
{
  "uiConfig": {
    "font": "Inter",
    "mainBackgroundColor": "#1E1E1E",
    "selectionBackgroundColor": "#3A3A3A",
    "mainForegroundColor": "#FFFFFF",
    "selectionForegroundColor": "#FFFFFF",
    "hintColor": "#888888"
  }
}
```

---

## 8. Performance & Architecture

- **Native AppKit & Core Graphics**: Built without heavy web views or Electron runtimes, Nerw uses programmatic Auto Layout and native rendering for instant startup and fluid animations.
- **Frecency Scoring (`FrecencyManager`)**: Search candidates are ranked using a combined Frequency + Recency algorithm, ensuring that your most frequently and recently used commands always appear at the top.
- **Async Asset Thumbnailing**: All application icons, file previews, and extension graphics are loaded asynchronously via `QuickLookThumbnailing` and cached in `~/Library/Application Support/Nerw/Icons/` to prevent UI stuttering.
- **Daemon Resource Monitoring**: Background extension daemons are polled continuously; any extension exceeding memory limits or sustaining >25% CPU usage is automatically terminated and safely reset.
