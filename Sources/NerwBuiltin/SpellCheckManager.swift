import ApplicationServices
import Cocoa
import CoreGraphics
import Foundation
import NerwAction
import NerwCore
import NerwSearchBackend
import NerwUtils

public class SpellCheckManager {
    public static let shared = SpellCheckManager()

    private let spellChecker = NSSpellChecker.shared
    private var currentLanguage: String {
        spellChecker.language()
    }

    private init() {}

    public static func builtinActions() -> [NerwAction] {
        return [shared.getSpellAction()]
    }

    public func getSpellAction() -> NerwAction {
        return NerwAction(
            id: "builtin.spell",
            title: "Spell",
            subtitle: "Check spelling and paste correction into front app",
            icon: .system("quote.bubble.fill"),
            triggers: ["spell"],
            type: .args(
                placeholder: "Word",
                searcher: { [weak self] _, query, completion in
                    guard let self = self else {
                        completion([])
                        return
                    }
                    self.suggestions(for: query, completion: completion)
                },
                perform: { [weak self] _, rawQuery in
                    guard let self = self else { return }
                    self.performDefaultPaste(for: rawQuery)
                }
            )
        )
    }

    // MARK: - Dynamic Suggestions Generation

    public func suggestions(for query: String, completion: @escaping ([NerwAction]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

            // When entering argument mode or query is empty, show nothing
            if trimmed.isEmpty {
                completion([])
                return
            }

            let results: [NerwAction]
            if trimmed.contains(" ") {
                results = self.buildMultiWordSuggestions(for: trimmed)
            } else {
                results = self.buildSingleWordSuggestions(for: trimmed)
            }

            completion(results)
        }
    }

    // MARK: - Single Word Processing

    public func buildSingleWordSuggestions(for word: String) -> [NerwAction] {
        let nsString = word as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let misRange = spellChecker.checkSpelling(of: word, startingAt: 0)
        let isMisspelled = (misRange.location != NSNotFound && misRange.length > 0)

        var actions: [NerwAction] = []
        var seenTexts = Set<String>()

        func addAction(
            text: String,
            title: String,
            subtitle: String,
            idSuffix: String
        ) {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seenTexts.contains(normalized) else { return }
            seenTexts.insert(normalized)

            actions.append(
                NerwAction(
                    id: "builtin.spell.\(idSuffix).\(normalized.hashValue)",
                    title: title,
                    subtitle: subtitle,
                    icon: .system("quote.bubble.fill"),
                    category: nil,
                    triggers: [],
                    modifiers: [
                        .command: NerwAction.ModifierAction(
                            title: "Copy to Clipboard",
                            subtitle: "Copy without pasting",
                            icon: .system("doc.on.doc"),
                            perform: { _ in
                                SpellCheckManager.shared.copyToClipboard(text: normalized)
                            }
                        )
                    ],
                    type: .instant(perform: { _ in
                        SpellCheckManager.shared.pasteIntoFrontApp(text: normalized)
                    })
                )
            )
        }

        if isMisspelled {
            // 1. Top Correction
            if let correction = spellChecker.correction(
                forWordRange: misRange,
                in: word,
                language: currentLanguage,
                inSpellDocumentWithTag: 0
            ) {
                let casedCorrection = matchCasing(source: word, target: correction)
                addAction(
                    text: casedCorrection,
                    title: casedCorrection,
                    subtitle: "Enter to paste",
                    idSuffix: "top"
                )
            }

            // 2. Guesses
            let guesses =
                spellChecker.guesses(
                    forWordRange: misRange,
                    in: word,
                    language: currentLanguage,
                    inSpellDocumentWithTag: 0
                ) ?? []

            for (idx, guess) in guesses.prefix(8).enumerated() {
                let casedGuess = matchCasing(source: word, target: guess)
                addAction(
                    text: casedGuess,
                    title: casedGuess,
                    subtitle: "Enter to paste",
                    idSuffix: "guess.\(idx)"
                )
            }

            // 3. Completions if few suggestions
            if actions.count < 3 {
                let completions =
                    spellChecker.completions(
                        forPartialWordRange: fullRange,
                        in: word,
                        language: currentLanguage,
                        inSpellDocumentWithTag: 0
                    ) ?? []

                for (idx, completion) in completions.prefix(4).enumerated() {
                    let casedComp = matchCasing(source: word, target: completion)
                    addAction(
                        text: casedComp,
                        title: casedComp,
                        subtitle: "Enter to paste",
                        idSuffix: "comp.\(idx)"
                    )
                }
            }
        } else {
            // Already correctly spelled
            addAction(
                text: word,
                title: word,
                subtitle: "Enter to paste",
                idSuffix: "correct"
            )

            // Provide word completions if user is still typing
            let completions =
                spellChecker.completions(
                    forPartialWordRange: fullRange,
                    in: word,
                    language: currentLanguage,
                    inSpellDocumentWithTag: 0
                ) ?? []

            for (idx, completion) in completions.prefix(5).enumerated() {
                let casedComp = matchCasing(source: word, target: completion)
                addAction(
                    text: casedComp,
                    title: casedComp,
                    subtitle: "Enter to paste",
                    idSuffix: "comp.\(idx)"
                )
            }
        }

        return actions
    }

    // MARK: - Multi-Word Phrase / Sentence Processing

    public func buildMultiWordSuggestions(for phrase: String) -> [NerwAction] {
        let nsString = phrase as NSString
        var searchLocation = 0
        var correctionsFound:
            [(originalRange: NSRange, originalWord: String, replacement: String)] = []

        var wordCount: Int = 0
        while searchLocation < nsString.length {
            let misRange = spellChecker.checkSpelling(
                of: phrase,
                startingAt: searchLocation,
                language: currentLanguage,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: &wordCount
            )
            if misRange.location == NSNotFound || misRange.length == 0
                || misRange.location < searchLocation
            {
                break
            }

            let badWord = nsString.substring(with: misRange)
            let bestFix =
                spellChecker.correction(
                    forWordRange: misRange,
                    in: phrase,
                    language: currentLanguage,
                    inSpellDocumentWithTag: 0
                )
                ?? spellChecker.guesses(
                    forWordRange: misRange,
                    in: phrase,
                    language: currentLanguage,
                    inSpellDocumentWithTag: 0
                )?.first

            if let bestFix = bestFix {
                let casedFix = matchCasing(source: badWord, target: bestFix)
                correctionsFound.append((misRange, badWord, casedFix))
            }

            searchLocation = misRange.location + max(misRange.length, 1)
        }

        var actions: [NerwAction] = []
        var seenTexts = Set<String>()

        func addAction(
            text: String,
            title: String,
            subtitle: String,
            idSuffix: String
        ) {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seenTexts.contains(normalized) else { return }
            seenTexts.insert(normalized)

            actions.append(
                NerwAction(
                    id: "builtin.spell.\(idSuffix).\(normalized.hashValue)",
                    title: title,
                    subtitle: subtitle,
                    icon: .system("quote.bubble.fill"),
                    category: nil,
                    triggers: [],
                    modifiers: [
                        .command: NerwAction.ModifierAction(
                            title: "Copy to Clipboard",
                            subtitle: "Copy without pasting",
                            icon: .system("doc.on.doc"),
                            perform: { _ in
                                SpellCheckManager.shared.copyToClipboard(text: normalized)
                            }
                        )
                    ],
                    type: .instant(perform: { _ in
                        SpellCheckManager.shared.pasteIntoFrontApp(text: normalized)
                    })
                )
            )
        }

        if !correctionsFound.isEmpty {
            // 1. Synthesize full corrected phrase
            var fullCorrected = phrase
            for item in correctionsFound.reversed() {
                if let range = Range(item.originalRange, in: fullCorrected) {
                    fullCorrected.replaceSubrange(range, with: item.replacement)
                }
            }

            addAction(
                text: fullCorrected,
                title: fullCorrected,
                subtitle: "Enter to paste",
                idSuffix: "full"
            )

            // 2. Individual word corrections
            for (idx, item) in correctionsFound.enumerated() {
                addAction(
                    text: item.replacement,
                    title: item.replacement,
                    subtitle: "Enter to paste",
                    idSuffix: "word.\(idx)"
                )
            }
        } else {
            // No spelling errors in the phrase
            addAction(
                text: phrase,
                title: phrase,
                subtitle: "Enter to paste",
                idSuffix: "correct"
            )
        }

        return actions
    }

    // MARK: - Casing Helper

    public func matchCasing(source: String, target: String) -> String {
        guard !source.isEmpty, !target.isEmpty else { return target }

        // ALL CAPS
        if source.allSatisfy({ $0.isUppercase || !$0.isLetter })
            && source.contains(where: { $0.isLetter })
        {
            return target.uppercased()
        }

        // Title Case (Starts with uppercase, rest lowercase)
        if let first = source.first, first.isUppercase {
            let rest = source.dropFirst()
            if rest.allSatisfy({ $0.isLowercase || !$0.isLetter }) {
                return target.prefix(1).uppercased() + target.dropFirst()
            }
        }

        return target
    }

    // MARK: - Execution / Paste / Copy

    public func performDefaultPaste(for rawQuery: String) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let suggestions =
            trimmed.contains(" ")
            ? buildMultiWordSuggestions(for: trimmed) : buildSingleWordSuggestions(for: trimmed)
        if let topSuggestion = suggestions.first {
            switch topSuggestion.type {
            case .instant(let perform):
                perform(topSuggestion)
            default:
                pasteIntoFrontApp(text: topSuggestion.title)
            }
        } else {
            pasteIntoFrontApp(text: trimmed)
        }
    }

    public func pasteIntoFrontApp(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Activate frontmost application prior to Nerw
        let targetApp = System.shared.lastActiveApp ?? NSWorkspace.shared.frontmostApplication
        if let app = targetApp,
            app.processIdentifier != NSRunningApplication.current.processIdentifier, !app.isActive
        {
            app.activate(options: .activateIgnoringOtherApps)
        }

        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let source = CGEventSource(stateID: .hidSystemState)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                vDown?.flags = .maskCommand
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                vUp?.flags = .maskCommand

                vDown?.post(tap: .cghidEventTap)
                vUp?.post(tap: .cghidEventTap)
            }
        } else {
            Nerw.notify("Copied to clipboard (Enable Accessibility to auto-paste)", level: .info)
        }
    }

    public func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Nerw.notify("Copied \"\(text)\" to clipboard", level: .info)
    }
}
