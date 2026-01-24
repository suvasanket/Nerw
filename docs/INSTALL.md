# Installing Nerw

## Prerequisites
- **macOS**: Latest stable version recommended.
- **Xcode Command Line Tools**: Required for building.
  ```bash
  xcode-select --install
  ```

## Building from Source

Nerw is built using `make` and the Swift Package Manager.

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-username/Nerw.git
    cd Nerw
    ```

2.  **Build the application bundle**:
    This command compiles the Swift code and wraps it into a `Nerw.app` bundle with the application icon and Info.plist.
    ```bash
    make bundle
    ```

## Installation

Once built, you can "install" the app by moving it to your Applications folder.

```bash
mv Nerw.app /Applications/
```

## Running

1.  **Fastest way**: Run `make run` in the terminal. This rebuilds the app if needed, quits any running instance, and launches the updated `Nerw.app`.
2.  **Manual way**: Launch **Nerw** from your Applications folder or via Spotlight/Raycast.
3.  Grant any necessary permissions if prompted.
4.  Use the global hotkey **Cmd + Shift + Space** to toggle the Nerw Main Panel.

## Troubleshooting

### Hotkey not working?
- Ensure the app is running (check Activity Monitor).
- If you have other apps using `Cmd+Shift+Space`, you may need to change the keybinding in `~/.config/nerw/config.json`.
