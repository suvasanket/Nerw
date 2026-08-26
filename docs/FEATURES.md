# Quick Start

To use Nerw, activate the main panel with your global hotkey (default: `Cmd + Shift + Space`) and start typing. As you type, Nerw dynamically filters and ranks results called **Actions**. An action can be executed directly by pressing `Enter`, or it may accept input—either by typing arguments inline after a trigger word, pressing `Tab` to enter a secondary Quick Action mode, or filling out a structured form. Every action also features a dedicated **Action Context** panel (accessible via `Cmd + K` or the 3-dot row button), which opens a compact inline overlay where you can run secondary operations, configure custom aliases, record global hotkeys, or toggle action visibility.

# 🤖 Nerw AI

Nerw integrates a powerful, privacy-aware AI assistant that can be invoked on demand or directly from search. Rather than requiring manual copy-pasting, Nerw AI intelligently interacts with your live macOS environment.
- **tip**: press `tab` in the very first main panel to quickly launch NerwAI panel.

## ⭐️ Perform Actions
- Performs real macOS actions directly from chat, such as scheduling calendar events, executing menubar action of an app, composing email, writing notes, setting timer, creating reminders and asking to remember things.
- Can also perform multiple actions in-series.

## Precise Context Injection (PCI)
- Automatically detects what you are asking about and injects relevant context for efficient token usage.
- Supported context: your active browser tab, foreground application, clipboard history, calendar events, reminders, local notes/files, menubar, and an instant screen capture.

## Semantic Long-Term Memory
- Automatically identifies and remembers key user facts, preferences, and personal details across conversations.

## Dual Backend Support
- Run locally with Apple Intelligence on Apple Silicon, or connect custom Bring-Your-Own-Key (BYOK) providers including OpenAI-compatible APIs, OpenRouter, Claude, and local Ollama.


# 🛠 Built-in Actions

Nerw comes equipped with a comprehensive suite of native built-in actions, covering system control, file search, knowledge lookup, clipboard management, and automation.

## Applications
- Search and launch installed applications on your system.
- **Hybrid App Actions (via `Tab`)**: Certain applications offer powerful secondary modes when you press `Tab`.(eg. Activity Monitor has `process quit` as secondary action)

## ⭐️ Clipboard History
- **Clipboard Management (`clipboard`)**: Automatically tracks your last copied text items and images. Search your history, pin important entries (`Cmd + P`), and paste directly into your active app (`Enter`).
- **Clear Clipboard History (`clearclipboard`)**: Supports natural language time range for clearing the clipboard history.

## ⭐️ Text Snippets
- System-wide text expansion that replaces short trigger words (e.g., `;sig`) with full templates in any macOS app. Supports dynamic placeholders like `{{clipboard}}`, `{{time}}`, and custom dates (`{{yyyy-MM-dd}}`).

## ⭐️ Bookmark Website
- **Add Bookmark (`add bookmark`)**: Universally save website as bookmarks directly into nerw. Automatically detects the active browser's URL and title to pre-fill the form.
- **Bookmark Management**: Search saved bookmarks instantly and open them in your browser.
- **Quick Actions**: Use the Action Context (`Cmd + K`) on any bookmark to easily **Edit** or **Delete** it.

## ⭐️ Finder related actions
- **Find File**: Near-instant file and document lookup without indexing lag, automatically excluding developer clutter like `node_modules` and `.git`.
- Supports nested file or directory name matching using space-separated search terms.
- **empty downloads**: Instantly moves all contents of your Downloads folder to the Trash.
- **eject [volume] / eject all**: Safely unmounts a specific external disk or all connected external drives.

## ⭐️ Quick Wikipedia Search
- Get instant Wikipedia article summaries right inside the search list with **Peek** cards; press `Enter` to open the full article in your browser.

## Dictionary & Menubar Search
- **Dictionary Lookup (`define`)**: Look up word definitions instantly with rich **Peek** expandable previews; press `Enter` to open the Dictionary app.
- **Menubar Search (`menubar`)**: Search and trigger any clickable menu command for your currently active frontmost application without reaching for the mouse.

## System Commands
- **shut down (`shutdown` / `poweroff`)**: Safely shut down your computer.
- **restart (`restart` / `reboot`)**: Safely restart your Mac.
- **sleep (`sleep`)**: Put your computer to sleep immediately.
- **lock screen (`lock` / `lockscreen`)**: Lock your display instantly.
- **log out (`logout` / `log off`)**: Log out of your current user session.

## macOS Shortcuts Integration
- Search, run, and pass input into your native macOS Shortcuts instantly.

## ⭐️ Quick Math, Comprehensive Unit Conversion & Currency Exchange
- **Quick Math**: Evaluate arithmetic expressions (`2 + 2`, `100 * (15 + 5)`), mathematical functions (`sqrt`, `cbrt`, `sin`, `cos`, `tan`, `log`, `abs`, `round`, `ceil`, `floor`), degree/radian trigonometry (`sin(90 deg)`), factorials (`5!`), percentages (`50% of 200`, `20% off 80`, `100 + 20%`), and word operators (`10 plus 20`, `half of 80`).
- **Number Base Conversions**: Instant conversion between Hexadecimal, Binary, Octal, and Decimal (`0xFF in dec`, `255 in hex`, `0b1010 in dec`, `10 in bin`, `0o77 in dec`).
- **13 Physical & Digital Unit Dimensions**: Full support for Length, Mass/Weight, Temperature, Volume/Liquid, Area, Data Storage/Digital Information, Speed, Time/Duration, Energy, Power, Pressure, Angle, and Fuel Efficiency. Supports both singular and plural names, standard symbols, abbreviations, compact expressions (`100km to miles`, `50kg in lbs`, `32f to c`), fractions (`1/2 cup to ml`), and compound units (`5 ft 10 in to cm`, `1 hr 30 min to sec`).
- **Real-time & Cached Currency Exchange**: Convert between currencies using ISO codes (`100 USD to EUR`), currency symbols (`$100 to eur`, `€50 in usd`, `₹500 to usd`, `100$ in €`), or currency names (`100 dollars to euros`, `50 pounds in dollars`). Features instant local caching via `CacheManager` with 12h freshness and European Central Bank exchange rates.
- **Intelligent Intent Recognition**: Automatically normalizes natural language queries (`what is 100 km in miles?`, `how many miles in 100 km`, `convert $50 to inr`, `calculate 12 * 45`) directly to conversion and calculation actions without falling through to generic web searches.


# 🔍 Search Engines

Nerw provides a dedicated web search and search-engine routing system designed for speed and flexibility.

## Web Search and Bangs
- Instant searches across your favorite web engines using short prefixes (e.g., `!g` for Google, `!yt` for YouTube, `!ddg` for DuckDuckGo).
- Add custom search engines on the fly by searching for `addsearch` in Nerw. Simply paste or type a website URL, and Nerw's **auto URL detect** automatically formats the query link for you. You can also add, edit, or remove custom engines anytime in **Settings > Search**.

## ⭐️ Search Modifier Mapper
- Map keyboard modifier keys (`Shift`, `Command`, `Option`, `Control`) to specific search providers in **Settings > Search**. By default, `Shift + Enter` triggers **Google Lucky Search**.

## Fallback Search Engines
- When your search doesn't match an application or local command, Nerw automatically provides your configured fallback search engines at the bottom of the list so you can launch a web search instantly.

## Smart Recency & Suggestions
- When searching without a bang prefix (e.g., `swift`), Nerw remembers your preferred search engine for that term and automatically suggests it at the top of results.

## Natural Language Query Categorizer
- Intelligently recognizes questions (`"how to install docker"`) or URLs (`"github.com"`) and automatically elevates web search results without overriding exact keyword triggers.


# 🔌 Extensions

Nerw is designed for unlimited extensibility via **native Swift extensions**.

## ⭐️ Native Speed & Access
- Built as native macOS extensions that run with lightning speed and integrate smoothly with macOS apps and services.

## Process & Daemon Modes
- Extensions can run on-demand or as background daemons for continuous monitoring and instant execution.

## Unified UI Theming
- Extensions automatically adopt Nerw's design themes, rendering native panels, forms, and lists that look and feel right at home.

## CLI Control
- Includes a terminal command (`nerw`) to manage extensions directly from your shell.


# ⚙️ Search Backend & Performance

At the core of Nerw is **`NerwSearchBackend`**, an ultra-efficient search engine built specifically for macOS.

## Fuzzy Matching
- Smart typo-tolerant searching ensures you find the right application, file, or command even if you misspell a word.

## Frecency Ranking Algorithm
- Automatically adapts to your habits by ranking search results based on how frequently and recently you use them.

## Natural Language Query Categorizer
- Under-the-hood language intelligence that instantly identifies questions and URLs to show the most relevant actions first.

## Async Icon & Thumbnail Rendering
- Previews and application icons load asynchronously in the background so your search panel never stutters or lags.

## Daemon Resource Monitoring
- Background extensions are monitored continuously to keep CPU and memory usage minimal.
