import Foundation

public struct NerwActionHidden {
    public static func get(for actionID: String) -> Bool {
        NerwActionPreferenceManager.shared.preferences.hiddenActions.contains(actionID)
    }

    public static func set(_ hidden: Bool, for actionID: String) {
        if hidden {
            if !NerwActionPreferenceManager.shared.preferences.hiddenActions.contains(actionID) {
                NerwActionPreferenceManager.shared.preferences.hiddenActions.append(actionID)
            }
        } else {
            NerwActionPreferenceManager.shared.preferences.hiddenActions.removeAll(where: {
                $0 == actionID
            })
        }
        NerwActionPreferenceManager.shared.save()
    }
}
