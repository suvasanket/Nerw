import Foundation
import NerwUtils

public struct ActionPreferences: Codable {
    public var actionAliases: [String: [String]] = [:]
    public var actionHotkeys: [String: String] = [:]
    public var disabledActions: [String] = []

    public init() {}
}

public class NerwActionPreferenceManager {
    public static let shared = NerwActionPreferenceManager()

    public var preferences: ActionPreferences

    private let configDirectory: URL
    private let preferencesFile: URL

    private init() {
        self.configDirectory = NerwPaths.configDirectory
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
        NerwActionAlias.get(for: actionID)
    }

    public func aliasesString(for actionID: String) -> String {
        NerwActionAlias.getString(for: actionID)
    }

    public func hotkey(for actionID: String) -> String {
        NerwActionHotkey.get(for: actionID)
    }

    public func parsedAliases(from rawValue: String) -> [String] {
        NerwActionAlias.parse(from: rawValue)
    }

    public func updateAliases(rawValue: String, for actionID: String) {
        NerwActionAlias.set(rawValue: rawValue, for: actionID)
    }

    public func updateHotkey(_ hotkey: String, for actionID: String) {
        NerwActionHotkey.set(hotkey, for: actionID)
    }

    public func isActionEnabled(for actionID: String) -> Bool {
        NerwActionEnabled.get(for: actionID)
    }

    public func updateActionEnabled(_ enabled: Bool, for actionID: String) {
        NerwActionEnabled.set(enabled, for: actionID)
    }
}
