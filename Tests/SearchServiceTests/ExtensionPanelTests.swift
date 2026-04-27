import Cocoa
import Foundation

@testable import NerwCore
@testable import NerwUI

func runExtensionPanelTests() {
    print("[Testing] Starting Extension Panel tests...")

    testShowPanelCommandParsing()
    testExtensionCommandDecodingWithTitle()
    testExtensionPanelWindowControllerCreation()

    print("[Testing] All Extension Panel tests PASSED.")
}

func testShowPanelCommandParsing() {
    // Simulate the JSON that an extension would produce for show_panel
    let json: [String: Any] = [
        "commands": [
            [
                "type": "show_panel",
                "title": "Test Title",
                "value": "Hello World",
            ]
        ]
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: json),
        let response = try? JSONDecoder().decode(ExtensionActionResponse.self, from: data),
        let commands = response.commands
    else {
        fatalError("FAIL: Could not decode ExtensionActionResponse with show_panel command.")
    }

    if commands.count != 1 {
        fatalError("FAIL: Expected 1 command, got \(commands.count)")
    }

    let cmd = commands[0]
    if cmd.type != "show_panel" {
        fatalError("FAIL: Command type should be 'show_panel', got '\(cmd.type)'")
    }
    if cmd.title != "Test Title" {
        fatalError("FAIL: Command title should be 'Test Title', got '\(cmd.title ?? "nil")'")
    }
    if cmd.value != "Hello World" {
        fatalError("FAIL: Command value should be 'Hello World', got '\(cmd.value ?? "nil")'")
    }

    print("  ✓ testShowPanelCommandParsing passed.")
}

func testExtensionCommandDecodingWithTitle() {
    // Ensure backward compatibility: commands without title still decode fine
    let json: [String: Any] = [
        "commands": [
            ["type": "notify", "value": "Hello"],
            ["type": "show_panel", "title": "My Panel", "value": "Content here"],
        ]
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: json),
        let response = try? JSONDecoder().decode(ExtensionActionResponse.self, from: data),
        let commands = response.commands
    else {
        fatalError("FAIL: Could not decode ExtensionActionResponse with mixed commands.")
    }

    if commands.count != 2 {
        fatalError("FAIL: Expected 2 commands, got \(commands.count)")
    }

    // First command (notify) should have nil title
    if commands[0].title != nil {
        fatalError("FAIL: Notify command should have nil title, got '\(commands[0].title!)'")
    }

    // Second command (show_panel) should have title
    if commands[1].title != "My Panel" {
        fatalError(
            "FAIL: show_panel command should have title 'My Panel', got '\(commands[1].title ?? "nil")'"
        )
    }

    print("  ✓ testExtensionCommandDecodingWithTitle passed.")
}

func testExtensionPanelWindowControllerCreation() {
    _ = NSApplication.shared

    // Test that the controller can be instantiated without crashing
    let controller = ExtensionPanelWindowController()

    // Ensure the controller object is created (simple sanity check)
    // The actual panel showing requires a screen context, so we just verify construction
    _ = controller

    print("  ✓ testExtensionPanelWindowControllerCreation passed.")
}
