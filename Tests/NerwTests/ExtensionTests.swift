import XCTest

@testable import NerwCore

final class NerwTests: XCTestCase {

    // Helper to create a dummy extension structure
    func createTestExtension(id: String, script: String) -> URL? {
        let fileManager = FileManager.default
        let extDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".nerw/extensions")
            .appendingPathComponent(id)

        do {
            if fileManager.fileExists(atPath: extDir.path) {
                try fileManager.removeItem(at: extDir)
            }
            try fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)

            let manifest = """
                {
                    "id": "\(id)",
                    "name": "Test \(id)",
                    "trigger": "test",
                    "description": "Test extension"
                }
                """

            try manifest.write(
                to: extDir.appendingPathComponent("manifest.json"), atomically: true,
                encoding: .utf8)
            try script.write(
                to: extDir.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)

            return extDir
        } catch {
            print("Failed to create test extension: \(error)")
            return nil
        }
    }

    func testExtensionIsolation() {
        // Setup Extension A: sets a global var
        let scriptA = """
            global.testVar = "Extension A";
            function main(query) { return [{title: global.testVar}]; }
            """
        _ = createTestExtension(id: "com.test.a", script: scriptA)

        // Setup Extension B: checks the global var
        let scriptB = """
            function main(query) {
                return [{title: global.testVar || "Undefined"}];
            }
            """
        _ = createTestExtension(id: "com.test.b", script: scriptB)

        let engine = ExtensionEngine.shared
        engine.reload()

        // Run A
        let expectationA = expectation(description: "Extension A finished")
        engine.runExtension(id: "com.test.a", query: "") { results in
            XCTAssertEqual(results.first?.title, "Extension A")
            expectationA.fulfill()
        }
        wait(for: [expectationA], timeout: 2.0)

        // Run B
        let expectationB = expectation(description: "Extension B finished")
        engine.runExtension(id: "com.test.b", query: "") { results in
            // Should be "Undefined" if isolated, "Extension A" if polluted
            XCTAssertEqual(results.first?.title, "Undefined", "Global namespace is polluted!")
            expectationB.fulfill()
        }
        wait(for: [expectationB], timeout: 2.0)
    }

    func testConstRedeclarationFix() {
        // Setup Extension C: uses const
        let scriptC = """
            const MY_CONST = "Constant";
            function main(query) { return [{title: MY_CONST}]; }
            """
        _ = createTestExtension(id: "com.test.c", script: scriptC)

        let engine = ExtensionEngine.shared
        engine.reload()

        // Run C First Time
        let exp1 = expectation(description: "Run 1")
        engine.runExtension(id: "com.test.c", query: "") { results in
            XCTAssertEqual(results.first?.title, "Constant")
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 2.0)

        // Run C Second Time (Should crash if context is reused w/ re-evaluation, or fail if new context w/o re-eval)
        // With our fix (Reuse context + Eval ONCE), it should succeed.
        let exp2 = expectation(description: "Run 2")
        engine.runExtension(id: "com.test.c", query: "") { results in
            XCTAssertEqual(results.first?.title, "Constant")
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 2.0)
    }

}
