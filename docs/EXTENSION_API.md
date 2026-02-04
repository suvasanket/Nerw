# Nerw Extension API Documentation

Nerw is designed to be extensible using JavaScript. Extensions can add new commands, search capabilities, and integrations. This guide details how to create extensions and use the available APIs.

## Extension Structure

An extension is a folder inside `~/.nerw/extensions/` containing at least two files:
1.  `manifest.json`: Metadata about the extension.
2.  `index.js`: The JavaScript logic.

### 1. `manifest.json`

This file defines your extension's identity and triggers.

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
-   **trigger**: The keyword that activates your extension (e.g., typing "example query" runs this extension).
-   **icon**: SF Symbol name (e.g., "star", "gear", "cloud").

### 2. `index.js`

This file must implement a `main` function that takes the user's query and returns results.

```javascript
function main(query) {
    // 1. Return static results
    return [
        {
            title: "Hello " + query,
            subtitle: "Static result",
            action: "copy"
        }
    ];
}
```

## The `main` Function

The `main(query)` function is the entry point.
-   **Argument**: `query` (String) - The text typed after the trigger.
-   **Return Value**:
    -   An **Array** of Result objects.
    -   A **Promise** that resolves to an Array of Result objects (for async operations).

### Result Object Structure

```javascript
{
    "title": "Main Title",
    "subtitle": "Secondary text",
    "icon": "star.fill", 
    
    // Explicit Action Type (Optional but recommended for complex actions)
    // Values: "instant" (default), "arg", "hybrid", "form"
    "type": "instant", 

    // Action Handler
    // Can be a URL (opens immediately) OR a Function Name (calls JS function)
    "action": "handleAction", 

    // For type: "arg"
    "argNames": ["Query", "Optional 2nd Step"],

    // For type: "hybrid"
    "quickAction": {
        "title": "Quick Action",
        "action": "handleQuick",
        "type": "instant"
    },

    // For type: "form"
    "form": {
        "fields": [
            { "id": "u", "title": "User" },
            { "id": "p", "title": "Pass", "secure": true }
        ],
        "submitLabel": "Log In"
    }
}
```

### JS Action Handlers

Instead of a URL, you can provide the name of a function to call when the action is triggered.

```javascript
function main(query) {
    return [{
        title: "Search via JS",
        type: "arg",
        argNames: ["Query"],
        action: "doSearch" // Calls doSearch(args)
    }];
}

// Function receives an Array of strings (for args) or Dictionary (for forms)
function doSearch(args) {
    const query = args[0];
    nerw.open("https://google.com/search?q=" + encodeURIComponent(query));
}

function handleForm(values) {
    // values = { "u": "...", "p": "..." }
    nerw.log("User: " + values["u"]);
}
```

### Argument Wizard
If `type` is `"arg"`, the user receives prompts defined in `argNames`. 
When completed, your action function is called with an array of inputs: `[step1, step2]`.

### Hybrid Actions
If `type` is `"hybrid"`, pressing Enter executes `action`. Pressing Tab reveals the `quickAction`.
The `quickAction` object structure matches a standard result object.

### Modifiers
Supported keys for `mods`: `cmd`, `ctrl`, `opt`.
These can also point to function names or URLs.

---

## Global API: `nerw`

The `nerw` object is available globally in your JavaScript environment and provides access to system features.

### HTTP Requests

#### `nerw.fetch(url)`
Fetches content from a URL.

-   **Returns**: A `Promise` that resolves to the response body (String).

```javascript
nerw.fetch("https://api.example.com/data")
    .then(response => {
        nerw.log("Got data: " + response);
    });
```

### System Actions

#### `nerw.open(url)`
Opens a URL in the default browser or a file path in Finder.

```javascript
nerw.open("https://www.google.com");
nerw.open("file:///Users/me/Documents");
```

#### `nerw.copyToClipboard(text)`
Copies the specified text to the system clipboard.

```javascript
nerw.copyToClipboard("Copied text!");
```

#### `nerw.log(message)`
Logs a message to the Nerw debug console or stdout.

```javascript
nerw.log("Debug message");
```

### Caching & Persistence

Store data persistently across sessions using the key-value cache.

#### `nerw.cache.set(key, value)`
Saves a value. The value can be a String, Number, Array, or Object.

```javascript
nerw.cache.set("api_token", "12345");
nerw.cache.set("recent_items", ["a", "b", "c"]);
```

#### `nerw.cache.get(key)`
Retrieves a value. Returns `undefined` if the key does not exist.

```javascript
let token = nerw.cache.get("api_token");
```

#### `nerw.cache.remove(key)`
Deletes a value from the cache.

```javascript
nerw.cache.remove("api_token");
```

---

## Example: Async Fetch Extension

Here is a complete example of an extension that fetches JSON data from an API.

**manifest.json**
```json
{
  "id": "com.nerw.todo",
  "name": "ToDo Search",
  "trigger": "todo",
  "icon": "checkmark.circle"
}
```

**index.js**
```javascript
function main(query) {
    // Return a Promise for async results
    return new Promise((resolve, reject) => {
        nerw.fetch("https://jsonplaceholder.typicode.com/todos")
            .then(jsonString => {
                const todos = JSON.parse(jsonString);

                // Filter by query
                const filtered = todos.filter(t => t.title.includes(query));

                // Map to Nerw results
                const results = filtered.map(t => ({
                    title: t.title,
                    subtitle: t.completed ? "Completed" : "Pending",
                    icon: t.completed ? "checkmark.circle.fill" : "circle",
                    action: "https://jsonplaceholder.typicode.com/todos/" + t.id
                }));

                resolve(results);
            })
            .catch(err => {
                nerw.log("Error: " + err);
                resolve([{ title: "Error fetching todos", subtitle: err.toString() }]);
            });
    });
}
```
