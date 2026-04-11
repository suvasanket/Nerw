import Foundation

public struct NerwActionAlias {
    public static func get(for actionID: String) -> [String] {
        NerwActionPreferenceManager.shared.preferences.actionAliases[actionID] ?? []
    }

    public static func getString(for actionID: String) -> String {
        get(for: actionID).joined(separator: " ")
    }

    public static func parse(from rawValue: String) -> [String] {
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

    public static func set(rawValue: String, for actionID: String) {
        let aliases = parse(from: rawValue)
        if aliases.isEmpty {
            NerwActionPreferenceManager.shared.preferences.actionAliases.removeValue(
                forKey: actionID)
        } else {
            NerwActionPreferenceManager.shared.preferences.actionAliases[actionID] = aliases
        }
        NerwActionPreferenceManager.shared.save()
    }
}
