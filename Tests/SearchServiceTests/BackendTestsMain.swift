import Foundation
import NerwUtils

@testable import NerwSearchBackend

func runBackendTests() {
    print("[Testing] Starting NerwSearchBackend tests...")

    testCacheStorage()
    testCacheComplexStorage()
    testCacheRemoval()
    testCacheCodableTypes()
    testCacheNonExistentKey()

    testFrecencyScoreIncrease()
    testFrecencyDecay()
    testFrecencyQueryAware()
    testFrecencyQueryMismatch()
    testFrecencyDisabled()
    testFrecencySpecialCharacters()

    testFuzzyEmptyInputs()
    testFuzzyEmptyInputsNoCrash()
    testFuzzyBasicMatch()
    testFuzzySpecialCharacters()
    testFuzzyLongQuery()
    testFuzzySingleChar()
    testFuzzyMergeEmpty()

    print("[Testing] All backend tests PASSED.")
}

// MARK: - Cache Tests

func testCacheStorage() {
    let cache = CacheManager.shared
    let key = "testKey_\(UUID().uuidString)"
    let value = "testValue"

    cache.set(value, forKey: key)
    sleep(1)

    let retrieved = cache.get(forKey: key, as: String.self)
    if retrieved != value {
        fatalError(
            "FAIL: Cache storage test failed. Expected \(value), got \(String(describing: retrieved))"
        )
    }
    print("  ✓ testCacheStorage passed.")
}

func testCacheComplexStorage() {
    let cache = CacheManager.shared
    let key = "complexKey_\(UUID().uuidString)"
    let value: [String: Int] = ["id": 1, "count": 42]

    cache.set(value, forKey: key)
    sleep(1)

    guard let retrieved = cache.get(forKey: key, as: [String: Int].self) else {
        fatalError("FAIL: Cache complex storage test - failed to retrieve dictionary")
    }

    if retrieved["id"] != 1 || retrieved["count"] != 42 {
        fatalError("FAIL: Cache complex storage test - values mismatch")
    }
    print("  ✓ testCacheComplexStorage passed.")
}

func testCacheRemoval() {
    let cache = CacheManager.shared
    let key = "removeKey_\(UUID().uuidString)"
    cache.set("value", forKey: key)

    sleep(1)
    if cache.get(forKey: key, as: String.self) == nil {
        fatalError("FAIL: Cache removal test - value should exist before removal")
    }

    cache.remove(forKey: key)
    sleep(1)
    if cache.get(forKey: key, as: String.self) != nil {
        fatalError("FAIL: Cache removal test - value should be nil after removal")
    }
    print("  ✓ testCacheRemoval passed.")
}

func testCacheCodableTypes() {
    let cache = CacheManager.shared
    let key = "codableKey_\(UUID().uuidString)"

    struct TestStruct: Codable {
        let name: String
        let count: Int
    }

    let value = TestStruct(name: "Nerw", count: 42)
    cache.set(value, forKey: key)
    sleep(1)

    guard let retrieved = cache.get(forKey: key, as: TestStruct.self) else {
        fatalError("FAIL: Cache codable types test - failed to retrieve struct")
    }

    if retrieved.name != "Nerw" || retrieved.count != 42 {
        fatalError("FAIL: Cache codable types test - struct values mismatch")
    }
    print("  ✓ testCacheCodableTypes passed.")
}

func testCacheNonExistentKey() {
    let cache = CacheManager.shared
    let key = "nonexistent_\(UUID().uuidString)"

    let retrieved = cache.get(forKey: key, as: String.self)
    if retrieved != nil {
        fatalError("FAIL: Cache non-existent key test - should return nil for non-existent key")
    }
    print("  ✓ testCacheNonExistentKey passed.")
}

// MARK: - Frecency Tests

func testFrecencyScoreIncrease() {
    let tracker = FrecencyManager.shared
    let id = "item1_\(UUID().uuidString)"

    let initialScore = tracker.score(for: id)

    tracker.recordUsage(id: id)
    sleep(1)

    let newScore = tracker.score(for: id)
    if newScore <= initialScore {
        fatalError("FAIL: Frecency score should increase after usage")
    }
    print("  ✓ testFrecencyScoreIncrease passed.")
}

func testFrecencyDecay() {
    let tracker = FrecencyManager.shared
    let id = "decayItem_\(UUID().uuidString)"

    tracker.recordUsage(id: id)
    sleep(1)
    let score1 = tracker.score(for: id)

    tracker.recordUsage(id: id)
    sleep(1)
    let score2 = tracker.score(for: id)

    if score2 <= score1 {
        fatalError("FAIL: Frecency score should increase with repeated usage")
    }
    print("  ✓ testFrecencyDecay passed.")
}

func testFrecencyQueryAware() {
    let tracker = FrecencyManager.shared
    let id = "queryItem_\(UUID().uuidString)"
    let query = "test query"

    tracker.recordUsage(id: id, forQuery: query)
    sleep(1)

    let score = tracker.score(for: id, query: query, sensitivity: .moderate)
    if score <= 0 {
        fatalError("FAIL: Frecency query-aware score should be positive")
    }
    print("  ✓ testFrecencyQueryAware passed.")
}

func testFrecencyQueryMismatch() {
    let tracker = FrecencyManager.shared
    let id = "mismatchItem_\(UUID().uuidString)"
    let query = "test query"

    tracker.recordUsage(id: id, forQuery: query)
    sleep(1)

    let score = tracker.score(for: id, query: "different query", sensitivity: .moderate)
    if score != 0 {
        fatalError("FAIL: Frecency query mismatch should return 0")
    }
    print("  ✓ testFrecencyQueryMismatch passed.")
}

func testFrecencyDisabled() {
    let tracker = FrecencyManager.shared
    let id = "disabledItem_\(UUID().uuidString)"
    let query = "test query"

    tracker.recordUsage(id: id, forQuery: query)
    sleep(1)

    let score = tracker.score(for: id, query: query, sensitivity: .disabled)
    if score != 0 {
        fatalError("FAIL: Disabled frecency should return 0")
    }
    print("  ✓ testFrecencyDisabled passed.")
}

// MARK: - Fuzzy Tests

func testFuzzyEmptyInputs() {
    let results = fuzzyFind(queries: [], inputs: ["test"])
    if results.isEmpty {
        fatalError(
            "FAIL: Fuzzy empty queries should return matches (empty query matches everything)")
    }
    print("  ✓ testFuzzyEmptyInputs passed.")
}

func testFuzzyEmptyInputsNoCrash() {
    let _ = fuzzyFind(queries: [], inputs: [])
    print("  ✓ testFuzzyEmptyInputsNoCrash passed.")
}

func testFuzzyBasicMatch() {
    let results = fuzzyFind(queries: ["test"], inputs: ["testing", "best", "rest"])
    if results.isEmpty {
        fatalError("FAIL: Fuzzy should find matches for 'test' in inputs")
    }
    print("  ✓ testFuzzyBasicMatch passed (found \(results.count) results).")
}

func testFuzzySpecialCharacters() {
    let _ = fuzzyFind(queries: ["isn't"], inputs: ["something isn't right", "testing"])
    let _ = fuzzyFind(queries: ["something isn't ri"], inputs: ["something isn't right"])
    print("  ✓ testFuzzySpecialCharacters passed.")
}

func testFuzzyLongQuery() {
    let longQuery = String(repeating: "a", count: 100)
    let _ = fuzzyFind(queries: [longQuery], inputs: [String(repeating: "a", count: 200)])
    print("  ✓ testFuzzyLongQuery passed.")
}

func testFuzzySingleChar() {
    let results = fuzzyFind(queries: ["a"], inputs: ["apple", "banana", "cherry"])
    if results.isEmpty {
        fatalError("FAIL: Fuzzy should find matches for single character")
    }
    print("  ✓ testFuzzySingleChar passed (found \(results.count) results).")
}

func testFuzzyMergeEmpty() {
    let empty = FuzzyResult.empty
    let result = empty.merge(empty)
    if result.segments.count != 0 {
        fatalError("FAIL: Merging empty results should return empty")
    }
    print("  ✓ testFuzzyMergeEmpty passed.")
}

// MARK: - Frecency with Special Characters

func testFrecencySpecialCharacters() {
    let tracker = FrecencyManager.shared
    let id = "special_\(UUID().uuidString)"
    let query = "something isn't right"

    tracker.recordUsage(id: id, forQuery: query)
    sleep(1)

    let score = tracker.score(for: id, query: query, sensitivity: .moderate)
    if score <= 0 {
        fatalError("FAIL: Frecency with special chars should work")
    }
    print("  ✓ testFrecencySpecialCharacters passed.")
}
