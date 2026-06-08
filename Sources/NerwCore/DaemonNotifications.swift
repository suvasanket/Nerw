import Foundation

extension Notification.Name {
    /// Posted when a newly installed extension requests daemon mode approval.
    /// userInfo keys:
    ///   - "extensionId": String — the extension's reverse-domain ID
    ///   - "daemonDescription": String — human-readable reason from the manifest
    public static let nerwDaemonApprovalRequired = Notification.Name("NerwDaemonApprovalRequired")
}
