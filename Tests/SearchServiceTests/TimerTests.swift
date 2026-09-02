import Foundation
import NerwAction
import NerwBuiltin

public func runTimerTests() {
    print("[Testing] Starting Timer & Natural Language Parser tests...")

    testRelativeDurationParsing()
    testClockTimeParsing()
    testUntilNextHourParsing()
    testTypoAndGrammarMistakeResilience()
    testNaturalWordDurations()
    testLabelExtractionPositions()
    testTimerManagerLifecycle()

    print("[Testing] All Timer tests PASSED.")
}

func testRelativeDurationParsing() {
    let parser = TimerParser.shared
    let baseDate = Date(timeIntervalSince1970: 1_700_000_000)  // Fixed reference timestamp

    // 1. Standard units
    guard let r1 = parser.parse(query: "2min", referenceDate: baseDate) else {
        fatalError("FAIL: Failed to parse '2min'")
    }
    assert(r1.duration == 120, "2min should be 120s, got \(r1.duration)")
    assert(r1.label == "Timer", "Default label should be Timer, got \(r1.label)")

    guard let r2 = parser.parse(query: "30s", referenceDate: baseDate) else {
        fatalError("FAIL: Failed to parse '30s'")
    }
    assert(r2.duration == 30, "30s should be 30s")

    guard let r3 = parser.parse(query: "1h 30m", referenceDate: baseDate) else {
        fatalError("FAIL: Failed to parse '1h 30m'")
    }
    assert(r3.duration == 5400, "1h 30m should be 5400s, got \(r3.duration)")

    guard let r4 = parser.parse(query: "1.5 hours", referenceDate: baseDate) else {
        fatalError("FAIL: Failed to parse '1.5 hours'")
    }
    assert(r4.duration == 5400, "1.5 hours should be 5400s, got \(r4.duration)")

    guard let r5 = parser.parse(query: "settimer for 2min", referenceDate: baseDate) else {
        fatalError("FAIL: Failed to parse 'settimer for 2min'")
    }
    assert(r5.duration == 120, "'settimer for 2min' should be 120s, got \(r5.duration)")

    print("  ✓ testRelativeDurationParsing passed.")
}

func testClockTimeParsing() {
    let parser = TimerParser.shared
    let now = Date()

    // 1. Clock time: 7pm
    guard let r1 = parser.parse(query: "settimer 7pm", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'settimer 7pm'")
    }
    assert(r1.isTargetClockTime, "Should be clock target")
    assert(r1.duration > 0, "Duration should be positive")

    // 2. Until 19:00
    guard let r2 = parser.parse(query: "until 19:00", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'until 19:00'")
    }
    assert(r2.duration > 0, "Duration should be positive")

    // 3. Half past 7
    guard let r3 = parser.parse(query: "half past 7", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'half past 7'")
    }
    assert(r3.duration > 0, "Duration should be positive")

    print("  ✓ testClockTimeParsing passed.")
}

func testUntilNextHourParsing() {
    let parser = TimerParser.shared
    let calendar = Calendar.current

    // Set a known fixed time: 6:45 PM (18:45)
    var comps = calendar.dateComponents([.year, .month, .day], from: Date())
    comps.hour = 18
    comps.minute = 45
    comps.second = 0
    guard let fixedDate = calendar.date(from: comps) else { return }

    // "until next 7" from 18:45 should target 19:00 (15 minutes / 900 seconds)
    guard let r1 = parser.parse(query: "settimer until next 7", referenceDate: fixedDate) else {
        fatalError("FAIL: Failed to parse 'settimer until next 7'")
    }
    assert(
        abs(r1.duration - 900) < 5,
        "settimer until next 7 from 18:45 should be ~900s, got \(r1.duration)")

    // "next 7" with label: "next 7 dinner"
    guard let r2 = parser.parse(query: "next 7 dinner", referenceDate: fixedDate) else {
        fatalError("FAIL: Failed to parse 'next 7 dinner'")
    }
    assert(r2.label == "Dinner", "Label should be Dinner, got '\(r2.label)'")
    assert(abs(r2.duration - 900) < 5, "Duration should be ~900s")

    print("  ✓ testUntilNextHourParsing passed.")
}

func testTypoAndGrammarMistakeResilience() {
    let parser = TimerParser.shared
    let now = Date()

    // Typo in preposition: "fo 2min", "fro 2min"
    guard let r1 = parser.parse(query: "fo 2min", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'fo 2min'")
    }
    assert(r1.duration == 120, "fo 2min should be 120s, got \(r1.duration)")

    // Typo in unit: "5 minuts"
    guard let r2 = parser.parse(query: "5 minuts", referenceDate: now) else {
        fatalError("FAIL: Failed to parse '5 minuts'")
    }
    assert(r2.duration == 300, "5 minuts should be 300s, got \(r2.duration)")

    // Typo in unit: "10 secnds"
    guard let r3 = parser.parse(query: "10 secnds", referenceDate: now) else {
        fatalError("FAIL: Failed to parse '10 secnds'")
    }
    assert(r3.duration == 10, "10 secnds should be 10s, got \(r3.duration)")

    // Typo in until: "untill 7pm"
    guard let r4 = parser.parse(query: "untill 7pm", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'untill 7pm'")
    }
    assert(r4.isTargetClockTime, "untill 7pm should be target clock time")

    // Typo in hour: "2 hoours"
    guard let r5 = parser.parse(query: "2 hoours", referenceDate: now) else {
        fatalError("FAIL: Failed to parse '2 hoours'")
    }
    assert(r5.duration == 7200, "2 hoours should be 7200s, got \(r5.duration)")

    print("  ✓ testTypoAndGrammarMistakeResilience passed.")
}

func testNaturalWordDurations() {
    let parser = TimerParser.shared
    let now = Date()

    // "half an hour"
    guard let r1 = parser.parse(query: "half an hour quick nap", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'half an hour quick nap'")
    }
    assert(r1.duration == 1800, "half an hour should be 1800s, got \(r1.duration)")
    assert(r1.label == "Quick Nap", "Label should be Quick Nap, got '\(r1.label)'")

    // "quarter of an hour"
    guard let r2 = parser.parse(query: "quarter of an hour", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'quarter of an hour'")
    }
    assert(r2.duration == 900, "quarter of an hour should be 900s, got \(r2.duration)")

    // "five minutes"
    guard let r3 = parser.parse(query: "five minutes tea", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'five minutes tea'")
    }
    assert(r3.duration == 300, "five minutes should be 300s, got \(r3.duration)")
    assert(r3.label == "Tea", "Label should be Tea, got '\(r3.label)'")

    print("  ✓ testNaturalWordDurations passed.")
}

func testLabelExtractionPositions() {
    let parser = TimerParser.shared
    let now = Date()

    // 1. Trailing label: "2min tea"
    guard let r1 = parser.parse(query: "starttimer 2min tea", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'starttimer 2min tea'")
    }
    assert(r1.duration == 120, "Duration should be 120s")
    assert(r1.label == "Tea", "Label should be 'Tea', got '\(r1.label)'")

    // 2. Leading label: "tea for 2min"
    guard let r2 = parser.parse(query: "settimer tea for 2min", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'settimer tea for 2min'")
    }
    assert(r2.duration == 120, "Duration should be 120s")
    assert(r2.label == "Tea", "Label should be 'Tea', got '\(r2.label)'")

    // 3. Leading verb phrase: "boil eggs in 10 mins"
    guard let r3 = parser.parse(query: "boil eggs in 10 mins", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'boil eggs in 10 mins'")
    }
    assert(r3.duration == 600, "Duration should be 600s")
    assert(r3.label == "Boil Eggs", "Label should be 'Boil Eggs', got '\(r3.label)'")

    // 4. Target clock time with trailing label: "7pm meeting"
    guard let r4 = parser.parse(query: "settimer 7pm meeting", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'settimer 7pm meeting'")
    }
    assert(r4.label == "Meeting", "Label should be 'Meeting', got '\(r4.label)'")

    // 5. Target clock time with leading label: "call mom at 7pm"
    guard let r5 = parser.parse(query: "starttimer call mom at 7pm", referenceDate: now) else {
        fatalError("FAIL: Failed to parse 'starttimer call mom at 7pm'")
    }
    assert(r5.label == "Call Mom", "Label should be 'Call Mom', got '\(r5.label)'")

    // 6. Explicit label marker: "5m named focus"
    guard let r6 = parser.parse(query: "5m named focus", referenceDate: now) else {
        fatalError("FAIL: Failed to parse '5m named focus'")
    }
    assert(r6.duration == 300, "Duration should be 300s")
    assert(r6.label == "Focus", "Label should be 'Focus', got '\(r6.label)'")

    // 7. Quoted label: "Take a break" 15m
    guard let r7 = parser.parse(query: "\"Take a break\" 15m", referenceDate: now) else {
        fatalError("FAIL: Failed to parse '\"Take a break\" 15m'")
    }
    assert(r7.duration == 900, "Duration should be 900s")
    assert(r7.label == "Take a break", "Label should be 'Take a break', got '\(r7.label)'")

    print("  ✓ testLabelExtractionPositions passed.")
}

func testTimerManagerLifecycle() {
    let manager = TimerManager.shared
    let originalTimers = manager.allTimers

    defer {
        manager.reset()
        for t in originalTimers {
            manager.startTimer(targetDate: t.targetDate, label: t.label)
        }
    }

    manager.reset()

    // Start timer
    let timer = manager.startTimer(duration: 60, label: "Test Timer")
    assert(timer.label == "Test Timer", "Label should match")
    assert(manager.activeTimers.contains(where: { $0.id == timer.id }), "Timer should be active")

    // Snooze timer
    guard let snoozed = manager.snoozeTimer(id: timer.id, duration: 300) else {
        fatalError("FAIL: Snooze timer failed")
    }
    assert(snoozed.isSnoozed, "Timer should be marked snoozed")
    assert(snoozed.totalDuration == 300, "Duration should update to 300s")

    // Complete timer
    manager.completeTimer(id: timer.id)
    assert(
        !manager.activeTimers.contains(where: { $0.id == timer.id }),
        "Completed timer should not be in activeTimers")

    // Cancel timer
    let timer2 = manager.startTimer(duration: 120, label: "Cancel Test")
    manager.cancelTimer(id: timer2.id)
    assert(
        !manager.activeTimers.contains(where: { $0.id == timer2.id }),
        "Cancelled timer should be removed")
    assert(manager.activeTimers.isEmpty, "Active timers should be empty after test")

    print("  ✓ testTimerManagerLifecycle passed.")
}
