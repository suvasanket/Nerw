import XCTest

@testable import NerwCore

final class NerwTests: XCTestCase {

    private let fileManager = FileManager.default

    private var extensionsDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nerw/extensions")
    }

    /// Helper to create a Swift extension for testing
    func createTestExtension(
        id: String, trigger: String = "test", script: String
    ) -> URL? {
        let extDir = extensionsDir.appendingPathComponent(id)

        do {
            if fileManager.fileExists(atPath: extDir.path) {
                try fileManager.removeItem(at: extDir)
            }
            try fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)

            let manifest = """
                {
                    "id": "\(id)",
                    "name": "Test \(id)",
                    "trigger": "\(trigger)",
                    "description": "Test extension"
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

    /// Cleanup helper
    func removeTestExtension(id: String) {
        let extDir = extensionsDir.appendingPathComponent(id)
        try? fileManager.removeItem(at: extDir)
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
}
