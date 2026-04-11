import Foundation

public struct ActionPreferences: Codable {
    public var actionAliases: [String: [String]] = [:]
    public var actionHotkeys: [String: String] = [:]

    public init() {}
}

public class NerwActionPreferenceManager {
    public static let shared = NerwActionPreferenceManager()

    public var preferences: ActionPreferences

    private let configDirectory: URL
    private let preferencesFile: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configDirectory = home.appendingPathComponent(".nerw")
        self.preferencesFile = configDirectory.appendingPathComponent("actions.json")

        self.preferences = ActionPreferences()
        load()
    }

    public func reload() {
        load()
        NotificationCenter.default.post(
            name: Notification.Name("NerwActionPreferencesDidUpdate"), object: nil)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: preferencesFile.path) else {
            save()
            return
        }

        do {
            let data = try Data(contentsOf: preferencesFile)
            let decoder = JSONDecoder()
            self.preferences = try decoder.decode(ActionPreferences.self, from: data)
        } catch {
            print("NerwAction: Failed to load actions.json: \(error). Using defaults.")
        }
    }

    public func save() {
        do {
            if !FileManager.default.fileExists(atPath: configDirectory.path) {
                try FileManager.default.createDirectory(
                    at: configDirectory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(preferences)
            try data.write(to: preferencesFile)
        } catch {
            print("NerwAction: Failed to save actions.json: \(error)")
        }

        NotificationCenter.default.post(
            name: Notification.Name("NerwActionPreferencesDidUpdate"), object: nil)
    }

    // MARK: - API

    public func aliases(for actionID: String) -> [String] {
        preferences.actionAliases[actionID] ?? []
    }

    public func aliasesString(for actionID: String) -> String {
        aliases(for: actionID).joined(separator: " ")
    }

    public func hotkey(for actionID: String) -> String {
        preferences.actionHotkeys[actionID] ?? ""
    }

    public func parsedAliases(from rawValue: String) -> [String] {
        var seen = Set<String>()
        var parsed: [String] = []

        for alias in rawValue.components(separatedBy: .whitespacesAndNewlines) {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            parsed.append(trimmed)
        }

        return parsed
    }

    public func updateAliases(rawValue: String, for actionID: String) {
        let aliases = parsedAliases(from: rawValue)
        if aliases.isEmpty {
            preferences.actionAliases.removeValue(forKey: actionID)
        } else {
            preferences.actionAliases[actionID] = aliases
        }
        save()
    }

    public func updateHotkey(_ hotkey: String, for actionID: String) {
        let trimmed = hotkey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            preferences.actionHotkeys.removeValue(forKey: actionID)
        } else {
            preferences.actionHotkeys[actionID] = trimmed
        }
        save()
    }
}
