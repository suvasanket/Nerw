import Foundation

public struct NerwActionHotkey {
    public static func get(for actionID: String) -> String {
        NerwActionPreferenceManager.shared.preferences.actionHotkeys[actionID] ?? ""
    }

    public static func set(_ hotkey: String, for actionID: String) {
        let trimmed = hotkey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            NerwActionPreferenceManager.shared.preferences.actionHotkeys.removeValue(
                forKey: actionID)
        } else {
            NerwActionPreferenceManager.shared.preferences.actionHotkeys[actionID] = trimmed
        }
        NerwActionPreferenceManager.shared.save()
    }
}
