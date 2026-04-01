import XCTest

@testable import NerwCore

final class ExtensionTests: XCTestCase {

    private let fileManager = FileManager.default

    private var extensionsDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/extensions")
    }

    /// Helper to create a Swift extension for testing
    func createTestExtension(
        id: String, trigger: String = "test", script: String, settings: String? = nil
    ) -> URL? {
        let extDir = extensionsDir.appendingPathComponent(id)

        do {
            if fileManager.fileExists(atPath: extDir.path) {
                try fileManager.removeItem(at: extDir)
            }
            try fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)

            let settingsPart = settings != nil ? ",\"settings\": \(settings!)" : ""
            let manifest = """
                {
                    "id": "\(id)",
                    "name": "Test \(id)",
                    "description": "Test extension",
                    "actions": [
                        {
                            "name": "Test \(id)",
                            "triggers": ["\(trigger)"],
                            "description": "Test extension"
                        }
                    ]\(settingsPart)
                }
                """

            try manifest.write(
                to: extDir.appendingPathComponent("manifest.json"), atomically: true,
                encoding: .utf8)
            try script.write(
                to: extDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

            // Compile via the engine
            let result = ExtensionEngine.shared.compileExtension(at: extDir)
            XCTAssertNotNil(result, "Compilation should succeed for \(id)")

            return extDir
        } catch {
            print("Failed to create test extension: \(error)")
            return nil
        }
    }

    func testExtensionSettingsPassing() {
        let settingsJSON = """
            [
                {
                    "id": "apiKey",
                    "title": "API Key",
                    "type": "string",
                    "defaultValue": "initial-key"
                },
                {
                    "id": "enabled",
                    "title": "Enabled",
                    "type": "boolean",
                    "defaultValue": true
                }
            ]
            """

        let script = """
            import Foundation
            let inputLine = readLine() ?? "{}"
            let inputData = inputLine.data(using: .utf8)!
            let input = try! JSONSerialization.jsonObject(with: inputData) as! [String: Any]
            let settings = input["settings"] as? [String: Any] ?? [:]

            let apiKey = settings["apiKey"] as? String ?? "missing"
            let enabled = settings["enabled"] as? Bool ?? false

            let results: [[String: Any]] = [
                ["title": "Key: \\(apiKey)", "subtitle": "Enabled: \\(enabled)"]
            ]
            let output = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: output, encoding: .utf8)!)
            """

        _ = createTestExtension(id: "com.test.settings", script: script, settings: settingsJSON)

        let engine = ExtensionEngine.shared
        engine.reload()

        let expectation = expectation(description: "Extension settings query")
        engine.runExtension(id: "com.test.settings", query: "") { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.title, "Key: initial-key")
            XCTAssertEqual(results.first?.subtitle, "Enabled: true")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        removeTestExtension(id: "com.test.settings")
    }

    func testSwiftExtensionCompilation() {
        let script = """
            import Foundation
            let input = readLine() ?? "{}"
            let results = [["title": "Hello", "subtitle": "World"]]
            let data = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: data, encoding: .utf8)!)
            """

        let extDir = createTestExtension(id: "com.test.compile", script: script)
        XCTAssertNotNil(extDir)

        // Check binary exists
        let binaryPath = extDir!.appendingPathComponent(".build/main")
        XCTAssertTrue(fileManager.fileExists(atPath: binaryPath.path), "Binary should exist")

        removeTestExtension(id: "com.test.compile")
    }

    func testQueryResultsParsing() {
        let script = """
            import Foundation
            let input = readLine() ?? "{}"
            let data = input.data(using: .utf8)!
            let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            let query = json["query"] as? String ?? ""
            let results: [[String: Any]] = [
                ["title": "Hello \\(query)", "subtitle": "Swift result", "type": "instant"]
            ]
            let output = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: output, encoding: .utf8)!)
            """

        _ = createTestExtension(id: "com.test.query", script: script)

        let engine = ExtensionEngine.shared
        engine.reload()

        let expectation = expectation(description: "Extension query")
        engine.runExtension(id: "com.test.query", query: "World") { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first?.title, "Hello World")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        removeTestExtension(id: "com.test.query")
    }

    func testExtensionIsolation() {
        // Extension A sets a "global" — but since each is a separate process, B cannot see it
        let scriptA = """
            import Foundation
            let input = readLine() ?? "{}"
            let results: [[String: String]] = [["title": "Extension A"]]
            let data = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: data, encoding: .utf8)!)
            """

        let scriptB = """
            import Foundation
            let input = readLine() ?? "{}"
            let results: [[String: String]] = [["title": "Extension B"]]
            let data = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: data, encoding: .utf8)!)
            """

        _ = createTestExtension(id: "com.test.iso.a", trigger: "isoa", script: scriptA)
        _ = createTestExtension(id: "com.test.iso.b", trigger: "isob", script: scriptB)

        let engine = ExtensionEngine.shared
        engine.reload()

        let expA = expectation(description: "Extension A")
        engine.runExtension(id: "com.test.iso.a", query: "") { results in
            XCTAssertEqual(results.first?.title, "Extension A")
            expA.fulfill()
        }

        let expB = expectation(description: "Extension B")
        engine.runExtension(id: "com.test.iso.b", query: "") { results in
            XCTAssertEqual(results.first?.title, "Extension B")
            expB.fulfill()
        }

        wait(for: [expA, expB], timeout: 10.0)

        removeTestExtension(id: "com.test.iso.a")
        removeTestExtension(id: "com.test.iso.b")
    }

    func testModifiersParsing() {
        let script = """
            import Foundation
            let input = readLine() ?? "{}"
            let results: [[String: Any]] = [
                [
                    "title": "Main Action",
                    "subtitle": "Press Enter",
                    "type": "instant",
                    "modifiers": [
                        "cmd": [
                            "title": "Cmd Override",
                            "subtitle": "Cmd Pressed",
                            "action": "handleCmd"
                        ],
                        "shift": [
                            "action": "handleShift"
                        ]
                    ]
                }
            ]
            let output = try! JSONSerialization.data(withJSONObject: results)
            print(String(data: output, encoding: .utf8)!)
            """

        _ = createTestExtension(id: "com.test.modifiers", script: script)

        let engine = ExtensionEngine.shared
        engine.reload()

        let expectation = expectation(description: "Extension modifiers query")
        engine.runExtension(id: "com.test.modifiers", query: "") { results in
            XCTAssertEqual(results.count, 1)
            let action = results.first!
            XCTAssertEqual(action.title, "Main Action")
            XCTAssertEqual(action.modifiers.count, 2)

            let cmdMod = action.modifiers[.command]
            XCTAssertNotNil(cmdMod)
            XCTAssertEqual(cmdMod?.title, "Cmd Override")
            XCTAssertEqual(cmdMod?.subtitle, "Cmd Pressed")

            let shiftMod = action.modifiers[.shift]
            XCTAssertNotNil(shiftMod)
            XCTAssertNil(shiftMod?.title)

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        removeTestExtension(id: "com.test.modifiers")
    }
}
