# Nerw User Manual

Welcome to the **Nerw User Manual**. This document is the definitive guide to installing, configuring, and mastering Nerw—a native, keyboard-first macOS popup utility and Spotlight replacement built from the ground up for extreme speed, automation, rich conversions, and AI-powered productivity.

---

## Table of Contents
1. [Overview & Core Philosophy](#1-overview--core-philosophy)
2. [Quick Start & Keyboard Navigation](#2-quick-start--keyboard-navigation)
3. [Unified Search & Core Capabilities](#3-unified-search--core-capabilities)
   - [3.1 Application Search & Instant Launching](#31-application-search--instant-launching)
   - [3.2 Bang Web Search, Modifiers & Recency](#32-bang-web-search-modifiers--recency)
   - [3.3 Native Spotlight File Search](#33-native-spotlight-file-search)
   - [3.4 Dictionary, Wikipedia & Peek Previews](#34-dictionary-wikipedia--peek-previews)
   - [3.5 System Commands & Power Management](#35-system-commands--power-management)
   - [3.6 Active App Menubar Search](#36-active-app-menubar-search)
   - [3.7 Quick Actions (Secondary Modes via `Tab`)](#37-quick-actions-secondary-modes-via-tab)
   - [3.8 Clipboard History Manager](#38-clipboard-history-manager)
   - [3.9 Snippet Manager & Text Expansion](#39-snippet-manager--text-expansion)
   - [3.10 Website Bookmarks Manager](#310-website-bookmarks-manager)
4. [Unified Calculator, World Clock & Conversion Suite](#4-unified-calculator-world-clock--conversion-suite)
   - [4.1 Quick Math, Functions, Constants & Powers](#41-quick-math-functions-constants--powers)
   - [4.2 Complete Reciprocal & Hyperbolic Trigonometry Suite](#42-complete-reciprocal--hyperbolic-trigonometry-suite)
   - [4.3 Number Suffixes & Shorthands (`1K`, `2.5M`, `USD1K`)](#43-number-suffixes--shorthands-1k-25m-usd1k)
   - [4.4 Financial Calculations: Tips, Splitting & Percentage Changes](#44-financial-calculations-tips-splitting--percentage-changes)
   - [4.5 Ratios & Aspect Ratio Scaling](#45-ratios--aspect-ratio-scaling)
   - [4.6 13 Physical & Digital Unit Dimensions](#46-13-physical--digital-unit-dimensions)
   - [4.7 Human Timespan Formatting](#47-human-timespan-formatting)
   - [4.8 Work Planning: Working Days & Annual Hours](#48-work-planning-working-days--annual-hours)
   - [4.9 Design & Screen Typography Units (DPI/PPI, PX, REM, EM, PT)](#49-design--screen-typography-units-dpippi-px-rem-em-pt)
   - [4.10 World Clock, Timezones, Differentials & Time Projections](#410-world-clock-timezones-differentials--time-projections)
   - [4.11 Date Math, Natural Relative Dates & Multi-Format Countdowns](#411-date-math-natural-relative-dates--multi-format-countdowns)
   - [4.12 Real-Time & Offline Cached Currency Exchange (Frankfurter ECB)](#412-real-time--offline-cached-currency-exchange-frankfurter-ecb)
   - [4.13 Number Base Conversions (`hex`, `bin`, `oct`, `dec`)](#413-number-base-conversions-hex-bin-oct-dec)
5. [Nerw AI Assistant](#5-nerw-ai-assistant)
   - [5.1 Invoking AI Chat](#51-invoking-ai-chat)
   - [5.2 Conversation UI, Timeline Paging & Interactive Markdown Nodes](#52-conversation-ui-timeline-paging--interactive-markdown-nodes)
   - [5.3 Precise Context Injection (PCI)](#53-precise-context-injection-pci)
   - [5.4 Semantic Memory (`NLEmbedding`) & System Action Hooks](#54-semantic-memory-nlembedding--system-action-hooks)
   - [5.5 Configuring AI Providers (Apple Intelligence & BYOK)](#55-configuring-ai-providers-apple-intelligence--byok)
6. [NerwHub: Visual Workspace & Productivity Dashboard](#6-nerwhub-visual-workspace--productivity-dashboard)
   - [6.1 Invoking NerwHub & Tab Switching](#61-invoking-nerwhub--tab-switching)
   - [6.2 Semantic Memory Tab & Visual Inspector](#62-semantic-memory-tab--visual-inspector)
   - [6.3 Bookmarks Tab & Visual Browser](#63-bookmarks-tab--visual-browser)
   - [6.4 Conversations Tab & Chat History](#64-conversations-tab--chat-history)
   - [6.5 Hub Command Palette & Floating Inputs](#65-hub-command-palette--floating-inputs)
7. [Action Context Panel (`Cmd + K`), Customization & Preferences](#7-action-context-panel-cmd--k-customization--preferences)
   - [7.1 Inline Liquid Glass Action Context](#71-inline-liquid-glass-action-context)
   - [7.2 Custom Aliases & Global Hotkeys](#72-custom-aliases--global-hotkeys)
   - [7.3 Hiding Actions & Decluttering Search](#73-hiding-actions--decluttering-search)
   - [7.4 Multi-Field Structured Forms](#74-multi-field-structured-forms)
8. [Extensions System & CLI (`nerw`)](#8-extensions-system--cli-nerw)
   - [8.1 Native Swift Extensions & SDK](#81-native-swift-extensions--sdk)
   - [8.2 Standard Process Mode vs. Persistent Socket Daemons](#82-standard-process-mode-vs-persistent-socket-daemons)
   - [8.3 Daemon Governance, Resource Monitoring & Crash Limits](#83-daemon-governance-resource-monitoring--crash-limits)
   - [8.4 The Nerw CLI (`nerw`)](#84-the-nerw-cli-nerw)
9. [Settings, Preferences & Theming](#9-settings-preferences--theming)
   - [9.1 Tabbed Settings Walkthrough](#91-tabbed-settings-walkthrough)
   - [9.2 Customizing Themes via `config.json`](#92-customizing-themes-via-configjson)
10. [Performance, Security & Architecture](#10-performance-security--architecture)

---

## 1. Overview & Core Philosophy

**Nerw** is a native macOS application written strictly in Swift using AppKit, Core Graphics, and native system APIs. It runs as an **accessory utility**, meaning it leaves no permanent icon in your Dock and is invoked on demand via global hotkeys or the menu bar status item.

- **Zero-Latency Execution**: Critical search, math, timezone, and unit pipelines execute in under 0.05ms with zero process-spawning overhead.
- **Keyboard-First Design**: Every window, panel, list, dropdown, and conversational interaction can be controlled entirely from the keyboard.
- **Native Apple Technologies**: Uses native `MDQuery` (Spotlight), `EventKit`, `Accessibility`, `JavaScriptCore`, and `NaturalLanguage` frameworks instead of bloated web wrappers (Electron/Chromium).
- **Extensible & Adaptable**: Adapts continuously to your habits via intelligent Frequency + Recency (Frecency) ranking.

---

## 2. Quick Start & Keyboard Navigation

### Activating Nerw
- **Global Hotkey**: Press `Cmd + Shift + Space` anywhere in macOS to toggle the main search panel (configurable in `~/.nerw/config.json`).
- **Menu Bar Icon**: Click the Nerw icon in the status bar to open the panel or access **Settings** (`Cmd + ,`).

### Master Keyboard Shortcuts
| Key / Shortcut | Context | Action |
|---|---|---|
| `↓` / `Ctrl + N` / `Ctrl + J` | Search / Lists | Move selection down |
| `↑` / `Ctrl + P` / `Ctrl + K` | Search / Lists | Move selection up |
| `Enter` | Search Results | Execute primary action (on math/conversions: copies result to clipboard) |
| `Cmd + Enter` | File Results | Reveal selected file in Finder |
| `Shift + Enter` | Web Queries | Trigger **Google Lucky Search** (or configured search modifier) |
| `Tab` | Search Results | Enter Argument Mode, trigger **Quick Action**, or open AI Chat (on empty bar) |
| `Shift + Tab` / `Backspace` | Arguments / Forms | Step backward or return to previous input field |
| `Cmd + K` | Search Results | Open the inline **Action Context** overlay (aliases, hotkeys, secondary actions) |
| `Esc` | Anywhere | Clear text, dismiss overlays/forms, or close the Nerw window |
| `Cmd + 1`, `Cmd + 2`, `Cmd + 3` | NerwHub | Switch between Memory, Bookmarks, and Conversations tabs |
| `Cmd + ,` | Anywhere | Open Nerw Settings |

---

## 3. Unified Search & Core Capabilities

Nerw's orchestrator (`SearchService`) analyzes your query in real-time and routes it across specialized providers:

### 3.1 Application Search & Instant Launching
- Type any part of an installed macOS application name (e.g., `xcode`, `sublime`, or `slack`) to fuzzy-match and launch it immediately.
- Uses focused `NSMetadataQuery` scopes (`/Applications`, `/System/Applications`, `~/Applications`, and `CoreServices`) to guarantee microsecond indexing without freezing your drive.

### 3.2 Bang Web Search, Modifiers & Recency
- **Bang Prefixes**: Type a bang shortcut followed by a query to search directly on specific engines:
  - `!g [query]` ➔ Google Search
  - `!yt [query]` ➔ YouTube Search
  - `!ddg [query]` ➔ DuckDuckGo Search
  - `!gh [query]` ➔ GitHub Search
  - `!w [query]` ➔ Wikipedia Search
  - `!maps [query]` ➔ Google Maps
- **Add Custom Search Engines**: Type `addsearch` in Nerw to quickly register custom URL queries. Nerw includes automatic URL template recognition.
- **Smart Recency**: Searching a general term without a bang (e.g. `swift`) remembers your previously chosen engine and elevates it to the top.
- **Search Engine Modifier Mapping**: Holding `Shift + Enter` defaults to **Google Lucky Search**, jumping directly to the top website result. Modifiers can be reassigned in **Settings > Search**.

### 3.3 Native Spotlight File Search
- **Triggers**: Type `find [filename]` or `file [filename]`.
- **Spotlight Engine**: Directly queries Apple's native `MDQuery` metadata index.
- **Automatic Filters**: Ignores heavy development artifacts such as `node_modules`, `.git`, `.build`, and `DerivedData`.
- **Keybindings**: `Enter` opens the file in its default application; `Cmd + Enter` reveals it in Finder.

### 3.4 Dictionary, Wikipedia & Peek Previews
- **Dictionary Lookup**: Type `define [word]` or `def [word]` (e.g., `define resilience`) to view definitions directly in the result list. Press `Enter` to open macOS Dictionary.
- **Wikipedia Lookups**: Type `wiki [topic]` (e.g., `wiki quantum computing`) to fetch live Wikipedia article abstracts. Press `Enter` to read the full page.
- **Rich Peek Cards**: Selecting definitions, wiki pages, or conversion results expands an interactive **Peek Card** in the right-hand panel, rendering clean typography and metadata.

### 3.5 System Commands & Power Management
Type any of the following triggers to control your Mac immediately:
- **`empty downloads`**: Safely moves all files in `~/Downloads` to the macOS Trash.
- **`eject [name]` / `eject all`**: Safely unmounts external drives and disk images.
- **`quit [app]` / `kill [process]`**: Terminates background or foreground processes.
- **`shutdown` / `poweroff`**: Shuts down your Mac.
- **`restart` / `reboot`**: Restarts your Mac.
- **`sleep`**: Puts your Mac to sleep.
- **`lock` / `lockscreen`**: Locks your display immediately.
- **`logout`**: Logs out the current user session.
- **`wifi` / `bluetooth`**: Toggles wireless hardware or connects to paired devices.

### 3.6 Active App Menubar Search
- **Trigger**: Search `menubar` or select **Search Menubar** (`menubar.dock.rectangle`).
- **Functionality**: Dynamically introspects every nested menu item of the frontmost application via Accessibility APIs.
- **Usage**: Type keywords to find hidden commands (e.g. `Export as PDF`, `Show Inspector`) and press `Enter` to trigger the menu action without taking your hands off the keyboard.

### 3.7 Quick Actions (Secondary Modes via `Tab`)
Results displaying a **lightning bolt badge** feature secondary modes accessed by pressing `Tab`:
- **System Settings**: Type `System Settings`, press `Tab`, and filter directly to individual preference panes (e.g. `Sound`, `Network`, `Displays`).
- **Process Management**: Highlight an application (e.g. `Activity Monitor`), press `Tab`, and type arguments to quit or force-quit tasks.

### 3.8 Clipboard History Manager
- **Triggers**: Type `clipboard`, `clip`, or `paste`.
- **Capacity & Caching**: Retains your last 200 clipboard entries (text, snippets, code, and PNG images saved to `~/Library/Application Support/Nerw/ClipboardImages/`).
- **Pinning Entries**: Select any item and press `Cmd + P` to pin it to the top.
- **Direct Pasting**: Press `Enter` on any entry to automatically dismiss Nerw and paste the text directly into your previous active application.
- **Clearing History**: Type `clearclipboard` (with optional natural language timeframes like `clearclipboard last hour`).

### 3.9 Snippet Manager & Text Expansion
Nerw provides a system-wide text expander that replaces triggers with dynamic templates in any macOS app:
- **Creating a Snippet**: Type `addsnippet` to open the structured configuration form.
- **Dynamic Placeholders**:
  - `{{clipboard}}` ➔ Injects the latest copied text.
  - `{{time}}` ➔ Injects current time (`HH:mm`).
  - `{{yyyy-MM-dd}}` ➔ Injects current date using standard date format tokens.
- **Usage**: Type your trigger keyword (e.g., `;sig` or `;email`) in any text field across macOS; Nerw automatically simulates backspaces and types out the expanded content.

### 3.10 Website Bookmarks Manager
- **Add Bookmark (`add bookmark`)**: Detects your active browser tab (Safari, Chrome, Arc, Brave) and pre-fills the URL and page title into an instant save form.
- **Search Bookmarks**: Search saved bookmarks by name or domain and press `Enter` to open. Use `Cmd + K` on any bookmark to edit or delete it.

---

## 4. Unified Calculator, World Clock & Conversion Suite

All calculation, physical unit, currency, timezone, date, and design engines reside in a high-performance unified engine (`Sources/NerwBuiltin/MathAndConversions/`). Results evaluate instantly (<0.05ms) with zero UI lag. Pressing `Enter` on any calculation or conversion copies the clean formatted value directly to your clipboard and dismisses the window.

---

### 4.1 Quick Math, Functions, Constants & Powers
Nerw evaluates arithmetic expressions, powers, roots, and advanced mathematical functions:

| Expression Type | Syntax Examples | Evaluated Result |
|---|---|---|
| Basic Arithmetic | `2 + 2 * 10`, `(15 + 25) / 4`, `100 - 42.5` | `22`, `10`, `57.5` |
| Powers & Exponents | `2 power 10`, `2^10`, `5^3` | `1,024`, `1,024`, `125` |
| Square & Cube Roots | `square root of 625`, `sqrt(625)`, `cbrt(27)` | `25`, `25`, `3` |
| Mathematical Constants | `pi`, `e`, `tau`, `2 * pi * 5` | `3.14159...`, `2.71828...`, `31.4159` |
| Advanced Functions | `log(100)`, `ln(e)`, `abs(-42)`, `ceil(4.2)`, `floor(9.8)` | `4.605`, `1`, `42`, `5`, `9` |
| Factorials | `5!`, `7!` | `120`, `5,040` |
| Word Operators | `10 plus 20`, `half of 80`, `quarter of 200` | `30`, `40`, `50` |

---

### 4.2 Complete Reciprocal & Hyperbolic Trigonometry Suite
Full support for standard, reciprocal, hyperbolic, and inverse trigonometry in both **Degrees** (`deg`, `°`) and **Radians**:

- **Standard Trig**: `sin(90 deg)`, `cos(pi)`, `tan(45°)`
- **Reciprocal Trig**:
  - Cotangent: `cot(45 deg)` ➔ `1`
  - Secant: `sec(60 deg)` ➔ `2`
  - Cosecant: `csc(30 deg)` ➔ `2`
- **Inverse & Reciprocal Inverse**: `asin(1)`, `acos(0.5)`, `atan(1)`, `acot(1)`, `asec(2)`, `acsc(2)`
- **Hyperbolic & Inverse Hyperbolic**: `sinh(1)`, `cosh(0)`, `tanh(0.5)`, `coth(1)`, `sech(0)`, `csch(1)`, `asinh(1)`, `acosh(2)`, `atanh(0.5)`

---

### 4.3 Number Suffixes & Shorthands (`1K`, `2.5M`, `USD1K`)
Nerw recognizes standard multiplier suffixes (`K` = thousand, `M` = million, `B` = billion, `T` = trillion) across math expressions and currency conversions:

- `10K + 500` ➔ `10,500`
- `2.5M * 4` ➔ `10,000,000`
- `1.2B / 6` ➔ `200,000,000`
- `10K` ➔ `10,000`
- `USD1K in EUR` ➔ Converts `$1,000.00 USD` to Euros
- `10K in EUR` ➔ Converts `10,000 USD` to Euros

---

### 4.4 Financial Calculations: Tips, Splitting & Percentage Changes
- **Tip & Bill Splitter**:
  - `15% tip on 42` ➔ `Tip: $6.30 • Total: $48.30`
  - `20% tip on 85 with 4 people` ➔ `$25.50 / person ($102.00 total)`
- **Percentage Math**:
  - `52% of 900` ➔ `468`
  - `20% off 80` ➔ `64` (shows `$16.00 discount`)
  - `100 + 20%` ➔ `120`
  - `50 as % of 200` ➔ `25%`
- **Percentage Changes & Differences**:
  - `% increase from 50 to 75` ➔ `+50% change`
  - `% difference from 100 to 80` ➔ `-20% change`

---

### 4.5 Ratios & Aspect Ratio Scaling
- **Ratio Representation**:
  - `ratio of 3 to 5` ➔ `3:5 (37.5% : 62.5%)`
- **Aspect Ratio Resizing**:
  - `scale 16:9 to width 1920` ➔ `1920 × 1080`
  - `scale 4:3 to height 768` ➔ `1024 × 768`

---

### 4.6 13 Physical & Digital Unit Dimensions
Supports singular, plural, standard symbol, fractional, and compound inputs across 13 dimensions:

```text
Length • Mass • Temperature • Volume • Area • Digital Storage • Speed • Duration • Energy • Power • Pressure • Angle • Fuel Economy
```

| Dimension | Example Query | Converted Output |
|---|---|---|
| **Length** | `10ft in m`, `100 km to miles`, `5 ft 10 in to cm` | `3.048 m`, `62.137 mi`, `177.8 cm` |
| **Mass** | `50 kg in lbs`, `150 lbs to kg`, `8 oz to grams` | `110.231 lbs`, `68.039 kg`, `226.796 g` |
| **Temperature** | `32f to c`, `100c in f`, `0k to c` | `0 °C`, `212 °F`, `-273.15 °C` |
| **Volume / Cooking** | `1/2 cup to ml`, `2 gal in liters`, `1 tbsp to tsp` | `118.294 mL`, `7.571 L`, `3 tsp` |
| **Digital Storage** | `1 TB in GB`, `500 MB in KB`, `1024 MiB to GiB` | `1,000 GB`, `500,000 KB`, `1 GiB` |
| **Speed** | `60 mph in km/h`, `100 knots in mph` | `96.561 km/h`, `115.078 mph` |
| **Pressure** | `30 psi in bar`, `1 atm in kpa` | `2.068 bar`, `101.325 kPa` |
| **Energy & Power** | `500 kcal in kJ`, `100 hp to kw` | `2,093 kJ`, `74.57 kW` |
| **Area** | `1 acre in sq ft`, `100 sqm to sqft` | `43,560 sq ft`, `1,076.39 sq ft` |
| **Fuel Economy** | `30 mpg in l/100km` | `7.84 L/100km` |

---

### 4.7 Human Timespan Formatting
Converts raw time quantities into readable duration breakdowns:
- `145 mins to timespan` ➔ **`2h 25m`** (`2 hours, 25 minutes, 0 seconds`)
- `90000 seconds in timespan` ➔ **`1d 1h`** (`1 day, 1 hour, 0 minutes`)
- `350 hours to timespan` ➔ **`14d 14h`**

---

### 4.8 Work Planning: Working Days & Annual Hours
Calculate business days and annual billable work hours (calculated at 8 hours/workday, excluding weekends):
- `55h in workdays` ➔ **`6.875 workdays`**
- `10 workdays in hours` ➔ **`80 hours`**
- `workhours in 2026` ➔ **`2,088 work hours`** (`261 working days in 2026`)
- `workdays in 2026` ➔ **`261 workdays`**

---

### 4.9 Design & Screen Typography Units (DPI/PPI, PX, REM, EM, PT)
Convert physical dimensions to pixels at custom display densities, or convert web typography tokens:
- **Physical to Screen Pixels**:
  - `2 inches in px at 72 ppi` ➔ **`144 px`**
  - `2 inches in px at 144 ppi` ➔ **`288 px`**
  - `1920px in cm at 300 dpi` ➔ **`16.256 cm`**
- **Web Typography & CSS Units**:
  - `16px in rem` ➔ **`1 rem`** (based on standard 16px root)
  - `1.5rem in px` ➔ **`24 px`**
  - `24px in pt` ➔ **`18 pt`**
  - `32px in em` ➔ **`2 em`**

---

### 4.10 World Clock, Timezones, Differentials & Time Projections
Features an instant built-in dictionary covering **500+ global cities**, **top 100 airport IATA codes**, and all standard timezone abbreviations:

- **City & Airport Lookups**:
  - `time in tokyo` ➔ Shows current time in Tokyo, Japan (JST)
  - `time in JFK` ➔ Shows current time in New York (EDT/EST)
  - `time in São Paulo` ➔ Shows current time in São Paulo, Brazil (BRT)
  - `time in LHR` / `time in DXB` / `time in SFO`
- **Cross-City Conversions**:
  - `5pm ldn in sf` ➔ **`9:00 AM in San Francisco`**
  - `9am nyc in tokyo` ➔ **`10:00 PM in Tokyo`**
- **Time Differentials**:
  - `time diff Paris` ➔ **`Paris is 3h 30m behind your local time`**
  - `diff Tokyo` ➔ **`Tokyo is 3h 30m ahead of your local time`**
- **Time Projections**:
  - `time in 4 hours` ➔ Shows your local time after a 4-hour delay
  - `time in 4 hours in San Francisco` ➔ Shows projected San Francisco time after 4 hours

---

### 4.11 Date Math, Natural Relative Dates & Multi-Format Countdowns
A calendar calculation engine powered by Gregorian calendar logic:

- **Calendar & Time Arithmetic**:
  - `August 5 + 5` ➔ **`Monday, 10 August 2026`**
  - `today + 90 days` ➔ Future date 90 days from today
  - `3:45pm + 5 hours` ➔ **`8:45 PM`**
  - `10:30am - 45 min` ➔ **`9:45 AM`**
- **Relative Natural Language Dates**:
  - `monday in 3 weeks` ➔ Exact date 3 weeks from next Monday
  - `next friday` / `last tuesday`
  - `first day of next month` / `end of month` / `last day of this month`
  - `3 weeks from now` / `5 days ago`
- **Multi-Format Countdowns & Lookups**:
  - `days until next sunday` (or `days to sunday`) ➔ **`4 days`**
  - `days until november` (or `days to nov`) ➔ **`67 days`** (`9 wks 4 d`)
  - `weeks until november` ➔ **`9.6 weeks`**
  - `days until next month` ➔ **`6 days`**
  - `days until next weekend` ➔ **`3 days`**
  - `days until 31 Mar` ➔ **`217 days`**
  - `days left in quarter` ➔ **`35 days left`** (shows quarter end date)
  - `days left in year` / `days left in 2026` ➔ **`127 days left`**
  - `days in november` ➔ **`30 days`**
  - `how many days in february 2024` ➔ **`29 days (Leap Year)`**
  - `days in 2026` ➔ **`365 days`**
- **Elapsed Time ("Since")**:
  - `days since 1 Jan 2026` ➔ **`237 days ago`** (`33 wks 6 d`)
  - `days since August 5` ➔ **`21 days ago`**
- **Holiday Countdowns**:
  - `days until halloween` ➔ **`66 days`** (Oct 31)
  - `days until thanksgiving` ➔ **`92 days`** (4th Thursday of November)
  - `days until christmas` / `weeks until christmas` ➔ **`121 days`** / **`17.3 weeks`**
  - `days until new year` ➔ **`128 days`**
  - `days until valentines day` ➔ **`172 days`**
- **Timestamps & Epoch**:
  - `2024-03-15T14:30:00Z in local time` ➔ Converts ISO 8601 Zulu string to local time
  - `now in epoch` ➔ `1787758...` (current Unix seconds)
  - `1700000000 in date` ➔ Converts Unix epoch seconds to local and UTC date

---

### 4.12 Real-Time & Offline Cached Currency Exchange (Frankfurter ECB)
Converts currencies using symbols (`$`, `€`, `£`, `¥`, `₹`, `₩`, `₽`, `R$`, `zł`, `CHF`), 3-letter ISO codes, or currency names:
- **Queries**: `19usd to jpy`, `19usd jpy`, `100 USD to EUR`, `$100 to eur`, `€50 in usd`, `50 pounds in dollars`, `10K in EUR`
- **Exchange Backend**: Integrates the **Frankfurter API** backed by European Central Bank (ECB) reference rates.
- **Offline & Cache Resilience**: Rates are cached locally via `CacheManager` with a 12-hour freshness TTL and an offline baseline rate fallback table, guaranteeing instant conversion even during network outages.

---

### 4.13 Number Base Conversions (`hex`, `bin`, `oct`, `dec`)
Convert integer representations between binary, hexadecimal, octal, and decimal:
- `0xFF in dec` ➔ **`255`**
- `255 in hex` ➔ **`0xFF`**
- `0b1010 in dec` ➔ **`10`**
- `10 in bin` ➔ **`0b1010`**
- `0o77 in dec` ➔ **`63`**
- `hex 255` / `bin 42` / `oct 64`

---

## 5. Nerw AI Assistant

Nerw integrates a private, environment-aware conversational AI assistant that operates directly on your macOS workspace.

### 5.1 Invoking AI Chat
- **Triggers**: Search `ai`, `chat`, `ask`, or press `Tab` on an empty search bar.
- **Window Transformation**: The search panel smoothly morphs into a floating, card-based chat interface.

### 5.2 Conversation UI, Timeline Paging & Interactive Markdown Nodes
- **Timeline Segment Bars**: Vertical bars on the right edge of the card represent previous conversation turns. Click any bar or use keyboard navigation to jump between turns.
- **Interactive Markdown Nodes**: AI code blocks, links, and bold text are parsed into selectable visual nodes:
  - `Tab` / `Shift + Tab`: Cycle through interactive nodes in the streamed response.
  - `Enter` (on a Link): Opens the URL in your default browser.
  - `Enter` (on a Code Block / Text): Copies the snippet, hides Nerw, and pastes directly into your active editor.
  - `Esc`: Clears active node selection.
- **Chat Context Menu (`Cmd + K`)**: Provides options to clear chat history (`⌥⌘⌫`) or export conversations.

### 5.3 Precise Context Injection (PCI)
Using Apple's `NaturalLanguage` framework (`NLTagger`), Nerw classifies your prompt and automatically injects pertinent local context into the model's system prompt:
- **Foreground Application & Tab**: Injects the active application name and Safari/Chrome URL/content.
- **Display Screenshot**: Takes an instantaneous, asynchronous screen capture for multimodal models upon opening the AI panel.
- **Clipboard Context**: Reads recent text from your clipboard.
- **Calendar & Reminders**: Filters upcoming appointments and to-do items matching prompt dates (`"today"`, `"this weekend"`).
- **Notes Directory**: Scans your configured folder (`~/.nerw/config.json` -> `notesDirectoryPath`) for matching markdown notes.

### 5.4 Semantic Memory (`NLEmbedding`) & System Action Hooks
- **Long-Term Memory**: Automatically records facts, preferences, and personal details into `~/.nerw/memory.json`. Uses Apple's sentence embeddings (`NLEmbedding`) for real-time deduplication and cosine similarity scoring.
- **Native Action Execution**: The assistant can trigger real macOS tasks—such as scheduling calendar events, setting timers, creating reminders, and controlling system apps.

### 5.5 Configuring AI Providers (Apple Intelligence & BYOK)
Configure models in **Settings > AI** (`Cmd + ,` -> AI tab):
- **Apple Intelligence**: Runs natively on macOS 15.0+ Apple Silicon using on-device neural models.
- **BYOK (Bring Your Own Key)**: Connect any OpenAI-compatible API (OpenRouter, OpenAI, Claude via proxy, Google Gemini, Groq).
- **Local Ollama**: Connect offline to `http://localhost:11434/v1/chat/completions` with zero subscription fees.

---

## 6. NerwHub: Visual Workspace & Productivity Dashboard

**NerwHub** is a large-format floating workspace (`940 × 640`) for inspecting your AI memories, bookmarks, and past conversation threads.

### 6.1 Invoking NerwHub & Tab Switching
- **Trigger**: Search `hub` in Nerw, or invoke the NerwHub shortcut.
- **Quick Tab Navigation**:
  - `Cmd + 1` ➔ **Memory Tab** (`brain`)
  - `Cmd + 2` ➔ **Bookmarks Tab** (`bookmark`)
  - `Cmd + 3` ➔ **Conversations Tab** (`bubble.left.and.bubble.right`)

### 6.2 Semantic Memory Tab & Visual Inspector
- Displays all facts, preferences, and details remembered by Nerw AI.
- Inspect importance scores, timestamps, and image memory attachments.
- Add or delete memories directly with `Cmd + N` or `Cmd + Backspace`.

### 6.3 Bookmarks Tab & Visual Browser
- Visual tile layout of all saved web bookmarks with cached favicons and metadata.
- Filter instantly by typing; press `Enter` to open in your browser.

### 6.4 Conversations Tab & Chat History
- Browse, search, and reload previous AI conversations.

### 6.5 Hub Command Palette & Floating Inputs
- Press `Cmd + K` inside NerwHub to open the **Hub Command Palette** for rapid searching, filtering, and tab actions.
- Floating input cards appear centered for inline editing of notes, tags, and memory items.

---

## 7. Action Context Panel (`Cmd + K`), Customization & Preferences

### 7.1 Inline Liquid Glass Action Context
Press `Cmd + K` (or click the 3-dot row button) on any result to open the Action Context panel:
- Renders an inline frosted glass overlay with pop-in physics.
- Displays all secondary actions, modifier behaviors, and management controls.

### 7.2 Custom Aliases & Global Hotkeys
- **Set Alias**: Assign short trigger words (e.g. `g` for GitHub or `c` for Calculator).
- **Set Global Hotkey**: Assign dedicated macOS key combinations to launch specific actions directly from any application.

### 7.3 Hiding Actions & Decluttering Search
- If an action has an assigned global hotkey, you can toggle **Hide Action** in the `Cmd + K` menu or **Settings > Actions**.
- Hidden actions do not clutter search results, but remain instantly executable via their hotkey.

### 7.4 Multi-Field Structured Forms
Complex actions and extensions render native vertical forms:
- `Tab` / `Shift + Tab` to navigate fields.
- `Enter` on the final field to submit.
- `Esc` to cancel and return to search.

---

## 8. Extensions System & CLI (`nerw`)

### 8.1 Native Swift Extensions & SDK
Nerw extensions are native Swift packages residing in `~/.nerw/extensions/`:
- **Compiled on Install**: Compiled via `swiftc` into native binary executables.
- **Full macOS APIs**: Direct access to `AppKit`, `EventKit`, `CoreServices`, `Network`, and `URLSession`.
- **SDK (`NerwExtensionKit`)**: Provides high-level builders for search actions, forms, notifications, and themed panels.

### 8.2 Standard Process Mode vs. Persistent Socket Daemons
- **Process Mode**: Spawns a lightweight process on query, communicating via JSON stdin/stdout.
- **Daemon Mode**: Approved extensions run as persistent background daemons communicating over Unix domain sockets (`~/.nerw/run/<id>.sock`), enabling continuous monitoring and sub-millisecond query responses.

### 8.3 Daemon Governance, Resource Monitoring & Crash Limits
- **Resource Governance**: Polled every 5 seconds via `proc_pid_rusage`. Memory leaks or >25% sustained CPU usage triggers automatic SIGTERM/SIGKILL termination.
- **Crash Budgets**: Extensions experiencing 5 crashes within 10 minutes are auto-disabled in `~/.nerw/daemon_registry.json`.

### 8.4 The Nerw CLI (`nerw`)
The CLI binary is located at `Nerw.app/Contents/cli_bin/nerw`:
- **Install & Path**: Enable CLI integration in **Settings > General** to symlink `nerw` into `~/.nerw/bin/nerw` and add it to your shell `$PATH`.
- **Key Commands**:
  - `nerw help` ➔ Show CLI commands and flags.
  - `nerw extension list` ➔ List installed extensions and daemon statuses.
  - `nerw extension smoke-test -i` ➔ Test extension compilation and action schemas.

---

## 9. Settings, Preferences & Theming

### 9.1 Tabbed Settings Walkthrough
Access settings via `Cmd + ,`:
- **General**: Login item setup, Snippet text expansion toggle, CLI `$PATH` configuration.
- **Appearance**: Window themes, typography, background opacity, blur radius.
- **Features**: Toggle built-in modules (Menubar Search, Dictionary, Wikipedia).
- **Search Engines**: Manage bang triggers and keyboard search modifiers (`Shift + Enter`).
- **Extensions**: Manage extensions, approve daemon execution, and configure parameters.
- **Actions**: Global registry of all actions with alias editors, hotkey recorders, and enable/disable toggles.
- **AI**: Configure model presets, BYOK API endpoints, token keys, and Notes paths.

### 9.2 Customizing Themes via `config.json`
Themes can be configured in `~/.nerw/config.json`:
```json
{
  "uiConfig": {
    "font": "Inter",
    "mainBackgroundColor": "#1E1E1E",
    "selectionBackgroundColor": "#3A3A3A",
    "mainForegroundColor": "#FFFFFF",
    "selectionForegroundColor": "#FFFFFF",
    "hintColor": "#888888",
    "cornerRadius": 16.0
  }
}
```

---

## 10. Performance, Security & Architecture

- **Native AppKit Programmatic Layout**: No webviews, XIBs, or heavy runtimes.
- **Frecency Scoring Engine**: Dynamic rank computation based on frequency and recency of selection.
- **Async Icon & Preview Thumbnailing**: All file thumbnails and app icons load asynchronously via `QuickLookThumbnailing` and disk cache.
- **Sandboxed Evaluation**: Mathematical expressions run inside an isolated `JSContext` (`JavaScriptCore`) with disabled network and filesystem capabilities.
- **Zero Telemetry & Local Privacy**: All clipboard history, AI memories, search queries, and configuration files remain 100% on your local disk.
