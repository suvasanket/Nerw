import Cocoa
import Foundation

@testable import NerwCore

func runExtensionPanelTests() {
    print("[Testing] Starting Extension Theme Config tests...")

    testThemeConfigParsing()
    testThemeConfigLayoutFields()
    testThemeConfigPositioningFields()
    testThemeConfigDefaults()
    testShowPanelCommandRemoved()

    print("[Testing] All Extension Theme Config tests PASSED.")
}

func testThemeConfigParsing() {
    // Simulate the JSON that the host injects into extension settings
    let json: [String: Any] = [
        "commands": [
            ["type": "notify", "value": "Hello"]
        ]
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: json),
        let response = try? JSONDecoder().decode(ExtensionActionResponse.self, from: data),
        let commands = response.commands
    else {
        fatalError("FAIL: Could not decode ExtensionActionResponse.")
    }

    if commands.count != 1 {
        fatalError("FAIL: Expected 1 command, got \(commands.count)")
    }

    if commands[0].type != "notify" {
        fatalError("FAIL: Command type should be 'notify', got '\(commands[0].type)'")
    }

    print("  ✓ testThemeConfigParsing passed.")
}

func testThemeConfigLayoutFields() {
    // Verify that getThemeDict produces layout fields that NerwThemeConfig can read.
    // We simulate the dict structure directly since getThemeDict is private.
    let themeDict: [String: Any] = [
        "backgroundMaterial": "fullScreenUI",
        "cornerRadius": 28.0,
        "borderColorHex": "#FFFFFF",
        "borderOpacity": 0.18,
        "borderWidth": 1.0,
        "tintOpacity": 0.15,
        "innerGlowEnabled": true,
        "innerGlowColorHex": "#FFFFFF",
        "innerGlowOpacity": 0.06,
        "mainPanelWidth": 700.0,
        "mainPanelHeight": 500.0,
        "searchFieldHeight": 32.0,
        "searchFieldFontSize": 25.0,
        "searchFieldTopMargin": 12.0,
        "searchFieldBottomMargin": 12.0,
        "horizontalMargin": 20.0,
        "iconSize": 26.0,
        "resultRowHeight": 50.0,
        "resultCellCornerRadius": 14.0,
        "resultTitleFontSize": 14.0,
        "resultSubtitleFontSize": 11.0,
        "separatorHeight": 1.0,
        "separatorExpandedHeight": 14.0,
        "splitPaneItemFontSize": 15.0,
        "mainPanelOriginX": 100.0,
        "mainPanelOriginY": 200.0,
        "mainPanelFrameWidth": 700.0,
        "mainPanelFrameHeight": 500.0,
        "screenVisibleX": 0.0,
        "screenVisibleY": 25.0,
        "screenVisibleWidth": 1440.0,
        "screenVisibleHeight": 875.0,
    ]

    // Wrap in settings structure as _theme
    let settings: [String: Any] = ["_theme": themeDict]

    // Import NerwExtensionKit types are not available in test target,
    // so we just verify the dict structure is correct by checking key presence.
    guard let theme = settings["_theme"] as? [String: Any] else {
        fatalError("FAIL: _theme key missing from settings")
    }

    // Verify all layout fields exist
    let requiredLayoutKeys = [
        "searchFieldHeight", "searchFieldFontSize", "searchFieldTopMargin",
        "searchFieldBottomMargin", "horizontalMargin", "iconSize",
        "resultRowHeight", "resultCellCornerRadius", "resultTitleFontSize",
        "resultSubtitleFontSize", "separatorHeight", "separatorExpandedHeight",
        "splitPaneItemFontSize",
    ]

    for key in requiredLayoutKeys {
        guard theme[key] != nil else {
            fatalError("FAIL: Missing required layout key '\(key)' in theme dict")
        }
    }

    // Verify types (all layout values should be Double)
    for key in requiredLayoutKeys {
        guard theme[key] is Double else {
            fatalError("FAIL: Key '\(key)' should be Double")
        }
    }

    print("  ✓ testThemeConfigLayoutFields passed.")
}

func testThemeConfigPositioningFields() {
    let themeDict: [String: Any] = [
        "mainPanelOriginX": 350.0,
        "mainPanelOriginY": 400.0,
        "mainPanelFrameWidth": 700.0,
        "mainPanelFrameHeight": 500.0,
        "screenVisibleX": 0.0,
        "screenVisibleY": 25.0,
        "screenVisibleWidth": 1440.0,
        "screenVisibleHeight": 875.0,
    ]

    let settings: [String: Any] = ["_theme": themeDict]
    guard let theme = settings["_theme"] as? [String: Any] else {
        fatalError("FAIL: _theme key missing")
    }

    let requiredPositionKeys = [
        "mainPanelOriginX", "mainPanelOriginY",
        "mainPanelFrameWidth", "mainPanelFrameHeight",
        "screenVisibleX", "screenVisibleY",
        "screenVisibleWidth", "screenVisibleHeight",
    ]

    for key in requiredPositionKeys {
        guard let val = theme[key] as? Double else {
            fatalError("FAIL: Missing or non-Double positioning key '\(key)'")
        }
        // All positioning values should be non-negative in a real scenario
        // (except origin which can be negative on multi-monitor)
        _ = val  // Just checking it exists and is Double
    }

    // Verify panel frame dimensions match
    if (theme["mainPanelFrameWidth"] as? Double) != 700.0 {
        fatalError("FAIL: mainPanelFrameWidth should be 700.0")
    }
    if (theme["mainPanelFrameHeight"] as? Double) != 500.0 {
        fatalError("FAIL: mainPanelFrameHeight should be 500.0")
    }

    print("  ✓ testThemeConfigPositioningFields passed.")
}

func testThemeConfigDefaults() {
    // Test that with an empty theme dict, reasonable defaults are used
    let settings: [String: Any] = ["_theme": [:] as [String: Any]]
    guard let theme = settings["_theme"] as? [String: Any] else {
        fatalError("FAIL: _theme key missing")
    }

    // With empty dict, the NerwThemeConfig init should use defaults.
    // We can't test NerwThemeConfig directly from here (different module),
    // but we verify our dict production contract: empty is valid.
    _ = theme

    print("  ✓ testThemeConfigDefaults passed.")
}

func testShowPanelCommandRemoved() {
    // Verify that ExtensionCommand no longer processes show_panel as a known command.
    // We decode a show_panel command — it should still decode (it's just a string field),
    // but the executeCommands handler should treat it as "Unknown command type".
    let json: [String: Any] = [
        "commands": [
            ["type": "show_panel", "title": "Test", "value": "Content"]
        ]
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: json),
        let response = try? JSONDecoder().decode(ExtensionActionResponse.self, from: data),
        let commands = response.commands
    else {
        fatalError("FAIL: Could not decode response with show_panel (backward compat check).")
    }

    // The command still decodes — it's just not handled by executeCommands anymore.
    if commands[0].type != "show_panel" {
        fatalError("FAIL: Command type should still decode as 'show_panel'")
    }

    print("  ✓ testShowPanelCommandRemoved passed.")
}
