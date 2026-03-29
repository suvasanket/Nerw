import Cocoa
import Foundation

public enum CLIStatus {
    case notInstalled
    case symlinked
    case inPath
}

public class CLIUtils {
    public static let shared = CLIUtils()
    private let nerwBinDir = NSString(string: "~/.nerw/bin").expandingTildeInPath
    private let nerwBinPath = NSString(string: "~/.nerw/bin/nerw").expandingTildeInPath

    public func isInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: nerwBinPath)
    }

    public func uninstallCLI(completion: @escaping (Bool, String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Disable Nerw CLI"
        alert.informativeText =
            "This will remove the symlink from ~/.nerw/bin/nerw. Your shell configuration will remain unchanged but the command will no longer work."
        alert.addButton(withTitle: "Disable")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: nerwBinPath) {
                    try fileManager.removeItem(atPath: nerwBinPath)
                }
                // Optionally remove the directory if empty
                let contents = try fileManager.contentsOfDirectory(atPath: nerwBinDir)
                if contents.isEmpty {
                    try fileManager.removeItem(atPath: nerwBinDir)
                }
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }

    public func setupCLI(completion: @escaping (Bool, String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Enable Nerw CLI"
        alert.informativeText =
            "This will create a symlink of the nerw CLI to ~/.nerw/bin and attempt to add it to your shell's PATH."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                try performSetup()
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }

    private func performSetup() throws {
        let fileManager = FileManager.default

        // 1. Create ~/.nerw/bin if it doesn't exist
        if !fileManager.fileExists(atPath: nerwBinDir) {
            try fileManager.createDirectory(atPath: nerwBinDir, withIntermediateDirectories: true)
        }

        // 2. Get path to CLI in app bundle
        guard
            let bundlePath = Bundle.main.path(
                forResource: "nerw", ofType: nil, inDirectory: "cli_bin")
        else {
            // If we're running from the built app, it might be in Contents/cli_bin
            let contentsPath = Bundle.main.bundleURL.appendingPathComponent("Contents/cli_bin/nerw")
                .path
            if fileManager.fileExists(atPath: contentsPath) {
                try setupSymlink(from: contentsPath)
            } else {
                throw NSError(
                    domain: "NerwCLI", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "CLI binary not found in bundle."])
            }
            return
        }
        try setupSymlink(from: bundlePath)
    }

    private func setupSymlink(from sourcePath: String) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: nerwBinPath) {
            try fileManager.removeItem(atPath: nerwBinPath)
        }
        try fileManager.createSymbolicLink(atPath: nerwBinPath, withDestinationPath: sourcePath)
        try updateShellConfig()
    }

    private func updateShellConfig() throws {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        var configFile: URL?

        if shell.contains("zsh") {
            configFile = homeDir.appendingPathComponent(".zshrc")
        } else if shell.contains("bash") {
            let bashProfile = homeDir.appendingPathComponent(".bash_profile")
            if FileManager.default.fileExists(atPath: bashProfile.path) {
                configFile = bashProfile
            } else {
                configFile = homeDir.appendingPathComponent(".bashrc")
            }
        }

        let exportCommand = "\n# Nerw CLI\nexport PATH=\"$HOME/.nerw/bin:$PATH\"\n"

        if let configURL = configFile {
            if FileManager.default.fileExists(atPath: configURL.path) {
                let content = try String(contentsOf: configURL)
                if !content.contains(".nerw/bin") {
                    let fileHandle = try FileHandle(forWritingTo: configURL)
                    fileHandle.seekToEndOfFile()
                    if let data = exportCommand.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }
            } else {
                try exportCommand.write(to: configURL, atomically: true, encoding: .utf8)
            }
        } else {
            showManualConfigAlert()
        }
    }

    private func showManualConfigAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Shell Configuration Not Found"
            alert.informativeText =
                "We couldn't automatically detect your shell configuration file. Please manually add ~/.nerw/bin to your PATH.\n\nPath: ~/.nerw/bin"
            alert.addButton(withTitle: "Copy Path")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    "export PATH=\"$HOME/.nerw/bin:$PATH\"", forType: .string)
            }
        }
    }
}
