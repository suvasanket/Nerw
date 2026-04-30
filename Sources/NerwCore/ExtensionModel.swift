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

public struct ExtensionActionManifest: Codable {
    public let name: String
    public let description: String?
    public let icon: String?
    public let triggers: [String]
    public let type: String?
    public let function: String?
    public let longRunning: Bool

    public init(
        name: String, description: String? = nil, icon: String? = nil, triggers: [String] = [],
        type: String? = nil, function: String? = nil, longRunning: Bool = false
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.triggers = triggers
        self.type = type
        self.function = function
        self.longRunning = longRunning
    }

    enum CodingKeys: String, CodingKey {
        case name, description, icon, triggers, type, function, longRunning
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        function = try container.decodeIfPresent(String.self, forKey: .function)
        longRunning = try container.decodeIfPresent(Bool.self, forKey: .longRunning) ?? false

        // Support both "trigger" (singular) and "triggers" (plural) if needed,
        // but prefer "triggers". Actually let's just use what's there.
        if let plural = try container.decodeIfPresent([String].self, forKey: .triggers) {
            triggers = plural
        } else {
            triggers = []
        }
    }
}

public struct ExtensionManifest: Codable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String?
    public let actions: [ExtensionActionManifest]
    public let mode: String?
    public let settings: [ExtensionSetting]?

    // Set by the engine to resolve local assets
    public var path: String?

    // Set by the engine if the extension is symlinked for testing
    public var isSmokeTest: Bool = false

    public var extensionMode: ExtensionMode {
        if let mode = mode, let parsed = ExtensionMode(rawValue: mode) {
            return parsed
        }
        return .script
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, actions, mode, settings, path
        // Legacy keys
        case trigger, triggers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        settings = try container.decodeIfPresent([ExtensionSetting].self, forKey: .settings)

        if let actionsArray = try container.decodeIfPresent(
            [ExtensionActionManifest].self, forKey: .actions)
        {
            actions = actionsArray
        } else {
            // Legacy support: convert top-level fields to a single action
            var allTriggers: [String] = []
            if let trigger = try container.decodeIfPresent(String.self, forKey: .trigger) {
                allTriggers.append(trigger)
            }
            if let triggers = try container.decodeIfPresent([String].self, forKey: .triggers) {
                allTriggers.append(contentsOf: triggers)
            }

            actions = [
                ExtensionActionManifest(
                    name: name,
                    description: description,
                    icon: icon,
                    triggers: allTriggers
                )
            ]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(actions, forKey: .actions)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(path, forKey: .path)
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
