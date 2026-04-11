import Foundation

public struct NerwActionEnabled {
    public static func get(for actionID: String) -> Bool {
        !NerwActionPreferenceManager.shared.preferences.disabledActions.contains(actionID)
    }

    public static func set(_ enabled: Bool, for actionID: String) {
        if enabled {
            NerwActionPreferenceManager.shared.preferences.disabledActions.removeAll(where: {
                $0 == actionID
            })
        } else {
            if !NerwActionPreferenceManager.shared.preferences.disabledActions.contains(actionID) {
                NerwActionPreferenceManager.shared.preferences.disabledActions.append(actionID)
            }
        }
        NerwActionPreferenceManager.shared.save()
    }

    public static func toggle(for actionID: String) {
        set(!get(for: actionID), for: actionID)
    }
}
