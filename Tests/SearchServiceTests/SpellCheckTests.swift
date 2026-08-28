import Cocoa
import Foundation

@testable import NerwAction
@testable import NerwBuiltin
@testable import NerwUtils

func runSpellCheckTests() {
    print("[Testing] Starting SpellCheck tests...")
    testSpellActionMetadata()
    testCasingPreservation()
    testSingleWordCorrection()
    testCorrectlySpelledWord()
    testMultiWordPhraseCorrection()
    testEmptyQueryReturnsNothing()
    print("[Testing] All SpellCheck tests PASSED.")
}

func testSpellActionMetadata() {
    print("  - testSpellActionMetadata")

    let spellActions = SpellCheckManager.builtinActions()
    guard let spellAction = spellActions.first(where: { $0.id == "builtin.spell" }) else {
        fatalError(
            "FAIL: SpellCheckManager.builtinActions() must contain action with id 'builtin.spell'")
    }

    if spellAction.title != "Spell" {
        fatalError("FAIL: Expected title 'Spell', got '\(spellAction.title)'")
    }

    if spellAction.triggers != ["spell"] {
        fatalError("FAIL: Expected triggers ['spell'], got \(spellAction.triggers)")
    }

    guard case .args(let placeholder, _, _) = spellAction.type else {
        fatalError("FAIL: Spell action must be of type .args")
    }

    if placeholder != "Word" {
        fatalError("FAIL: Expected single-word placeholder 'Word', got '\(placeholder)'")
    }

    if case .system(let iconName)? = spellAction.icon {
        if iconName != "quote.bubble.fill" {
            fatalError("FAIL: Expected icon 'quote.bubble.fill', got '\(iconName)'")
        }
    } else {
        fatalError("FAIL: Expected system icon for spell action")
    }

    print("  ✓ testSpellActionMetadata passed.")
}

func testCasingPreservation() {
    print("  - testCasingPreservation")

    let manager = SpellCheckManager.shared

    let lower = manager.matchCasing(source: "recieve", target: "receive")
    if lower != "receive" {
        fatalError("FAIL: Expected 'receive', got '\(lower)'")
    }

    let titleCased = manager.matchCasing(source: "Recieve", target: "receive")
    if titleCased != "Receive" {
        fatalError("FAIL: Expected 'Receive', got '\(titleCased)'")
    }

    let allCaps = manager.matchCasing(source: "RECIEVE", target: "receive")
    if allCaps != "RECEIVE" {
        fatalError("FAIL: Expected 'RECEIVE', got '\(allCaps)'")
    }

    print("  ✓ testCasingPreservation passed.")
}

func testSingleWordCorrection() {
    print("  - testSingleWordCorrection")

    let manager = SpellCheckManager.shared
    let suggestions = manager.buildSingleWordSuggestions(for: "definately")

    if suggestions.isEmpty {
        fatalError("FAIL: Expected suggestions for misspelled word 'definately', got none")
    }

    // First suggestion should be the top correction or contains 'definitely'
    let topTitles = suggestions.map { $0.title.lowercased() }
    if !topTitles.contains(where: { $0.contains("definitely") }) {
        fatalError("FAIL: Expected suggestions to contain 'definitely', got: \(topTitles)")
    }

    // Verify icons are all quote.bubble.fill and modifiers exist for clipboard copy
    for item in suggestions {
        if case .system(let iconName)? = item.icon {
            if iconName != "quote.bubble.fill" {
                fatalError("FAIL: Result icon must be 'quote.bubble.fill', got '\(iconName)'")
            }
        } else {
            fatalError("FAIL: Result icon must be system icon 'quote.bubble.fill'")
        }

        if item.modifiers[.command] == nil {
            fatalError("FAIL: Suggestion '\(item.title)' is missing Command modifier action")
        }
    }

    print("  ✓ testSingleWordCorrection passed.")
}

func testCorrectlySpelledWord() {
    print("  - testCorrectlySpelledWord")

    let manager = SpellCheckManager.shared
    let suggestions = manager.buildSingleWordSuggestions(for: "apple")

    if suggestions.isEmpty {
        fatalError("FAIL: Expected suggestions for correctly spelled word 'apple'")
    }

    let first = suggestions[0]
    if !first.title.contains("apple") {
        fatalError(
            "FAIL: First suggestion for 'apple' should reference apple, got '\(first.title)'")
    }

    print("  ✓ testCorrectlySpelledWord passed.")
}

func testMultiWordPhraseCorrection() {
    print("  - testMultiWordPhraseCorrection")

    let manager = SpellCheckManager.shared
    let suggestions = manager.buildMultiWordSuggestions(for: "teh quick brwon fox")

    if suggestions.isEmpty {
        fatalError("FAIL: Expected suggestions for multi-word phrase with typos")
    }

    let first = suggestions[0]
    let lowerTitle = first.title.lowercased()
    if !lowerTitle.contains("the quick brown fox") && !lowerTitle.contains("brown") {
        fatalError("FAIL: Expected multi-word correction to fix typos, got: '\(first.title)'")
    }

    print("  ✓ testMultiWordPhraseCorrection passed.")
}

func testEmptyQueryReturnsNothing() {
    print("  - testEmptyQueryReturnsNothing")

    let manager = SpellCheckManager.shared
    let semaphore = DispatchSemaphore(value: 0)

    manager.suggestions(for: "") { results in
        if !results.isEmpty {
            fatalError("FAIL: Empty query must return empty results, got \(results.count) items")
        }
        semaphore.signal()
    }

    semaphore.wait()
    print("  ✓ testEmptyQueryReturnsNothing passed.")
}
