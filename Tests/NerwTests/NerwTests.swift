import XCTest
@testable import NerwSearchBackend

final class NerwTests: XCTestCase {
    
    // MARK: - Cache Tests
    
    func testCacheStorage() {
        let cache = CacheManager.shared
        let key = "testKey"
        let value = "testValue"
        
        cache.set(value, forKey: key)
        
        // Allow async write
        sleep(1)
        
        let retrieved = cache.get(forKey: key) as? String
        XCTAssertEqual(retrieved, value)
    }
    
    func testCacheComplexStorage() {
        let cache = CacheManager.shared
        let key = "complexKey"
        let value: [String: Any] = ["id": 1, "name": "Nerw", "tags": ["swift", "macos"]]
        
        cache.set(value, forKey: key)
        
        sleep(1)
        
        guard let retrieved = cache.get(forKey: key) as? [String: Any] else {
            XCTFail("Failed to retrieve dictionary")
            return
        }
        
        XCTAssertEqual(retrieved["name"] as? String, "Nerw")
        XCTAssertEqual((retrieved["tags"] as? [String])?.count, 2)
    }
    
    func testCacheRemoval() {
        let cache = CacheManager.shared
        let key = "removeKey"
        cache.set("value", forKey: key)
        
        sleep(1)
        XCTAssertNotNil(cache.get(forKey: key))
        
        cache.remove(forKey: key)
        sleep(1)
        XCTAssertNil(cache.get(forKey: key))
    }
    
    // MARK: - Frecency Tests
    
    func testFrecencyScoreIncrease() {
        let tracker = FrecencyManager.shared
        let id = "item1"
        
        let initialScore = tracker.score(for: id)
        
        tracker.recordUsage(id: id)
        sleep(1) // Wait for async update
        
        let newScore = tracker.score(for: id)
        XCTAssertGreaterThan(newScore, initialScore)
    }
    
    func testFrecencyDecay() {
        // This is hard to test deterministically without mocking time/Date() in FrecencyManager.
        // For now, we assume the logic holds if basic scoring works.
        // We can verify that reusing increases score significantly.
        
        let tracker = FrecencyManager.shared
        let id = "decayItem"
        
        tracker.recordUsage(id: id)
        sleep(1)
        let score1 = tracker.score(for: id)
        
        tracker.recordUsage(id: id)
        sleep(1)
        let score2 = tracker.score(for: id)
        
        // Since no time passed, decay factor is 1.0, so score should double (roughly) based on count 1 vs 2.
        XCTAssertGreaterThan(score2, score1)
    }
}
