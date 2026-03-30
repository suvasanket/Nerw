import Foundation

public enum ExtensionMode: String, Codable {
    case script  // Compile main.swift on install
    case binary  // Pre-compiled main binary
}

public enum SettingType: String, Codable {
    case string
    case boolean
    case number
}

public struct ExtensionSetting: Codable {
    public let id: String
    public let title: String
    public let description: String?
    public let type: SettingType
    public let defaultValue: AnyCodable

    public init(
        id: String, title: String, description: String?, type: SettingType, defaultValue: AnyCodable
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
    }
}

public struct ExtensionManifest: Codable {
    public let id: String
    public let name: String
    public let trigger: String
    public let triggers: [String]?
    public let description: String
    public let icon: String?
    public let mode: String?
    public let settings: [ExtensionSetting]?

    // Set by the engine if the extension is symlinked for testing
    public var isSmokeTest: Bool = false

    public var extensionMode: ExtensionMode {
        if let mode = mode, let parsed = ExtensionMode(rawValue: mode) {
            return parsed
        }
        return .script
    }

    public var allTriggers: [String] {
        var all = [trigger]
        if let extras = triggers {
            all.append(contentsOf: extras)
        }
        return all
    }

    enum CodingKeys: String, CodingKey {
        case id, name, trigger, triggers, description, icon, mode, settings
    }
}

/// A simple wrapper to handle Any in Codable
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        }
    }
}

public struct ExtensionResult: Codable {
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let action: String?

    public init(title: String, subtitle: String? = nil, icon: String? = nil, action: String? = nil)
    {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
}
