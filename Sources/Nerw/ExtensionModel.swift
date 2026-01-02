import Foundation

struct ExtensionManifest: Codable {
    let id: String
    let name: String
    let trigger: String
    let description: String
    let icon: String?
}

struct ExtensionResult: Codable {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: String?
}
