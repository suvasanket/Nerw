import Foundation

public struct TimerParseResult: Equatable {
    public let duration: TimeInterval
    public let targetDate: Date
    public let label: String
    public let originalQuery: String
    public let displayDuration: String
    public let displayTarget: String
    public let isTargetClockTime: Bool

    public init(
        duration: TimeInterval,
        targetDate: Date,
        label: String,
        originalQuery: String,
        displayDuration: String,
        displayTarget: String,
        isTargetClockTime: Bool
    ) {
        self.duration = duration
        self.targetDate = targetDate
        self.label = label
        self.originalQuery = originalQuery
        self.displayDuration = displayDuration
        self.displayTarget = displayTarget
        self.isTargetClockTime = isTargetClockTime
    }
}

public final class TimerParser {
    public static let shared = TimerParser()

    private let calendar = Calendar.current

    private let numberWords: [String: Double] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "twenty-five": 25, "twenty five": 25,
        "thirty": 30, "thirty-five": 35, "thirty five": 35,
        "forty": 40, "forty-five": 45, "forty five": 45,
        "fifty": 50, "fifty-five": 55, "fifty five": 55,
        "sixty": 60, "ninety": 90, "hundred": 100,
        "a": 1, "an": 1, "half": 0.5, "quarter": 0.25,
    ]

    public init() {}

    // MARK: - Public Parse API

    public func parse(query: String, referenceDate: Date = Date()) -> TimerParseResult? {
        var clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // 1. Strip redundant leading trigger keywords if user passed full command string
        clean = stripLeadingTrigger(clean)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let originalQuery = clean

        // 2. Check for explicit quoted label: e.g. "Tea Break" 5m or 5m "Tea Break"
        var explicitLabel: String? = nil
        if let quoteMatch = extractQuotedString(from: clean) {
            explicitLabel = quoteMatch.quoted
            clean = quoteMatch.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 3. Check for explicit label markers: e.g. "named tea", "called tea", "label: tea", "title: tea"
        if explicitLabel == nil {
            if let markerMatch = extractLabelByMarker(from: clean) {
                explicitLabel = markerMatch.label
                clean = markerMatch.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 4. Try parsing "next <number>" / "until next <number>" e.g. "until next 7", "next 7", "next 7:30"
        if let nextResult = parseNextTime(
            query: clean, explicitLabel: explicitLabel, originalQuery: originalQuery,
            now: referenceDate)
        {
            return nextResult
        }

        // 5. Try parsing Natural Words Duration: e.g. "half an hour", "an hour and a half", "quarter of an hour"
        if let wordResult = parseNaturalWordDurations(
            query: clean, explicitLabel: explicitLabel, originalQuery: originalQuery,
            now: referenceDate)
        {
            return wordResult
        }

        // 6. Try parsing Relative Durations: e.g. "2min", "for 2min", "1h 30m", "10s", "45 minuts"
        if let durationResult = parseRelativeDuration(
            query: clean, explicitLabel: explicitLabel, originalQuery: originalQuery,
            now: referenceDate)
        {
            return durationResult
        }

        // 7. Try parsing Absolute Clock Time: e.g. "7pm", "until 7pm", "at 19:00", "half past 7"
        if let clockResult = parseClockTime(
            query: clean, explicitLabel: explicitLabel, originalQuery: originalQuery,
            now: referenceDate)
        {
            return clockResult
        }

        // 8. Try parsing Plain Number Fallback: e.g. "5", "5 tea", "tea 5" (defaults to minutes)
        if let numberResult = parsePlainNumber(
            query: clean, explicitLabel: explicitLabel, originalQuery: originalQuery,
            now: referenceDate)
        {
            return numberResult
        }

        return nil
    }

    // MARK: - 1. Helper: Strip Triggers

    private func stripLeadingTrigger(_ text: String) -> String {
        let triggers = [
            "starttimer", "settimer", "set timer", "start timer",
            "timer", "countdown", "stimer", "new timer",
        ]
        let lower = text.lowercased()
        for trig in triggers {
            if lower == trig {
                return ""
            }
            if lower.starts(with: trig + " ") {
                let dropped = text.dropFirst(trig.count + 1)
                return String(dropped)
            }
            if lower.starts(with: trig + ":") {
                let dropped = text.dropFirst(trig.count + 1)
                return String(dropped)
            }
        }
        return text
    }

    // MARK: - 2. Helper: Quoted Strings & Label Markers

    private func extractQuotedString(from text: String) -> (quoted: String, remaining: String)? {
        let pattern = #"["'“]([^"'“”]+)["'”]"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }

        let ns = text as NSString
        let quoted = ns.substring(with: match.range(at: 1)).trimmingCharacters(
            in: .whitespacesAndNewlines)
        let remaining = ns.replacingCharacters(in: match.range, with: " ")
        return (quoted, remaining)
    }

    private func extractLabelByMarker(from text: String) -> (label: String, remaining: String)? {
        let pattern = #"(?i)\b(?:named|called|labeled|label:|title:)\s+([^\d\n]+?)$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }

        let ns = text as NSString
        let label = ns.substring(with: match.range(at: 1)).trimmingCharacters(
            in: .whitespacesAndNewlines)
        let remaining = ns.replacingCharacters(in: match.range, with: " ")
        return (cleanLabel(label), remaining)
    }

    // MARK: - 3. "Next <number>" / "Until next <number>" Parser

    private func parseNextTime(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        let pattern =
            #"(?i)^(?:(?:for|until|untill|unti|untl|till|til|at|to|by)\s+)?next\s+(\d{1,2}(?::\d{2})?(?:\s*(?:am|pm))?)(?:\s*(?:o'?clock))?(?:\s+(.*))?$"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        else {
            return nil
        }

        let ns = query as NSString
        let timeStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(
            in: .whitespacesAndNewlines)
        var labelStr: String? = nil
        if match.range(at: 2).location != NSNotFound {
            let extracted = ns.substring(with: match.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                labelStr = cleanLabel(extracted)
            }
        }

        guard let targetDate = resolveNextClockTarget(timeStr: timeStr, now: now) else {
            return nil
        }

        let duration = targetDate.timeIntervalSince(now)
        guard duration > 0 else { return nil }

        let finalLabel = explicitLabel ?? labelStr ?? "Timer"
        let displayTarget = formatTargetTime(targetDate)
        let displayDuration = formatDuration(duration)

        return TimerParseResult(
            duration: duration,
            targetDate: targetDate,
            label: finalLabel,
            originalQuery: originalQuery,
            displayDuration: displayDuration,
            displayTarget: displayTarget,
            isTargetClockTime: true
        )
    }

    private func resolveNextClockTarget(timeStr: String, now: Date) -> Date? {
        let lower = timeStr.lowercased()
        let isPM = lower.contains("pm")
        let isAM = lower.contains("am")
        let cleanTime =
            lower
            .replacingOccurrences(of: "pm", with: "")
            .replacingOccurrences(of: "am", with: "")
            .trimmingCharacters(in: .whitespaces)

        var hour = 0
        var minute = 0

        if cleanTime.contains(":") {
            let parts = cleanTime.components(separatedBy: ":")
            guard let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            hour = h
            minute = m
        } else {
            guard let h = Int(cleanTime) else { return nil }
            hour = h
            minute = 0
        }

        guard hour >= 0, hour <= 23, minute >= 0, minute <= 59 else { return nil }

        // If AM/PM was explicitly provided:
        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }

        if isAM || isPM || hour > 12 {
            // Unambiguous 24-hour time
            return nextOccurrence(hour: hour, minute: minute, now: now)
        }

        // Ambiguous 12-hour hour (e.g. "next 7"): could be 7 (07:00) or 19 (19:00).
        // Find the soonest future occurrence between AM and PM!
        let hour1 = hour == 12 ? 0 : hour
        let hour2 = hour == 12 ? 12 : hour + 12

        let candidate1 = nextOccurrence(hour: hour1, minute: minute, now: now)
        let candidate2 = nextOccurrence(hour: hour2, minute: minute, now: now)

        let candidates = [candidate1, candidate2].compactMap { $0 }.sorted()
        return candidates.first
    }

    private func nextOccurrence(hour: Int, minute: Int, now: Date) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        guard let todayDate = calendar.date(from: comps) else { return nil }

        // If todayDate is at least 15 seconds in the future, return todayDate
        if todayDate.timeIntervalSince(now) >= 15 {
            return todayDate
        }

        // Otherwise return tomorrow at the same time
        return calendar.date(byAdding: .day, value: 1, to: todayDate)
    }

    // MARK: - 4. Clock Time Parser ("7pm", "until 7pm", "at 19:00", "meeting until 7pm")

    private func parseClockTime(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Case A: Natural clock keywords: "noon" (12:00 PM), "midnight" (12:00 AM)
        if lower.contains("noon") || lower.contains("midnight") {
            let isNoon = lower.contains("noon")
            let targetHour = isNoon ? 12 : 0
            if let targetDate = nextOccurrence(hour: targetHour, minute: 0, now: now) {
                let duration = targetDate.timeIntervalSince(now)
                let remaining =
                    query
                    .replacingOccurrences(of: "noon", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "midnight", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "until", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "untill", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "till", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "at", with: "", options: .caseInsensitive)
                let label = explicitLabel ?? cleanLabel(remaining)
                return TimerParseResult(
                    duration: duration,
                    targetDate: targetDate,
                    label: label.isEmpty ? "Timer" : label,
                    originalQuery: originalQuery,
                    displayDuration: formatDuration(duration),
                    displayTarget: formatTargetTime(targetDate),
                    isTargetClockTime: true
                )
            }
        }

        // Case B: "half past 7", "quarter past 6", "quarter to 8", "20 past 7", "10 to 8"
        if let relativeClockResult = parseRelativeClockPhrases(
            query: query, explicitLabel: explicitLabel, originalQuery: originalQuery, now: now)
        {
            return relativeClockResult
        }

        // Case C: Standard clock time: e.g. "until 7pm", "7:30pm", "19:00", "at 7pm", "7pm meeting", "until 7"
        // Pattern 1: With explicit clock preposition: (until/at/till/by/to) <time> [label]
        let prepTimePattern =
            #"(?i)^(?:until|untill|unti|untl|till|til|at|to|by)\s+(\d{1,2}(?::\d{2}(?::\d{2})?)?\s*(?:am|pm)?)(?:\s*(?:o'?clock))?(?:\s+(.*))?$"#
        if let regex = try? NSRegularExpression(pattern: prepTimePattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        {
            let ns = query as NSString
            let timeStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let targetDate = resolveClockTarget(timeStr: timeStr, now: now) {
                let duration = targetDate.timeIntervalSince(now)
                if duration > 0 {
                    var label: String? = nil
                    if match.range(at: 2).location != NSNotFound {
                        let extracted = ns.substring(with: match.range(at: 2)).trimmingCharacters(
                            in: .whitespacesAndNewlines)
                        if !extracted.isEmpty {
                            label = cleanLabel(extracted)
                        }
                    }
                    let finalLabel = explicitLabel ?? label ?? "Timer"
                    return TimerParseResult(
                        duration: duration,
                        targetDate: targetDate,
                        label: finalLabel,
                        originalQuery: originalQuery,
                        displayDuration: formatDuration(duration),
                        displayTarget: formatTargetTime(targetDate),
                        isTargetClockTime: true
                    )
                }
            }
        }

        // Pattern 2: Without preposition, but with explicit clock marker (am/pm, :, o'clock): <time_with_marker> [label]
        let explicitMarkerPattern =
            #"(?i)^(\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm)|\d{1,2}\s*o'?clock)(?:\s+(.*))?$"#
        if let regex = try? NSRegularExpression(pattern: explicitMarkerPattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        {
            let ns = query as NSString
            let timeStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let targetDate = resolveClockTarget(timeStr: timeStr, now: now) {
                let duration = targetDate.timeIntervalSince(now)
                if duration > 0 {
                    var label: String? = nil
                    if match.range(at: 2).location != NSNotFound {
                        let extracted = ns.substring(with: match.range(at: 2)).trimmingCharacters(
                            in: .whitespacesAndNewlines)
                        if !extracted.isEmpty {
                            label = cleanLabel(extracted)
                        }
                    }
                    let finalLabel = explicitLabel ?? label ?? "Timer"
                    return TimerParseResult(
                        duration: duration,
                        targetDate: targetDate,
                        label: finalLabel,
                        originalQuery: originalQuery,
                        displayDuration: formatDuration(duration),
                        displayTarget: formatTargetTime(targetDate),
                        isTargetClockTime: true
                    )
                }
            }
        }

        // Pattern 3: <label> (until/at/till/by/to) <time>
        let trailingTimePattern =
            #"^(.*?)\s+(?:until|untill|unti|untl|till|til|at|to|by)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)(?:\s*(?:o'?clock))?$"#
        if let regex = try? NSRegularExpression(pattern: trailingTimePattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        {
            let ns = query as NSString
            let labelStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let timeStr = ns.substring(with: match.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let targetDate = resolveClockTarget(timeStr: timeStr, now: now) {
                let duration = targetDate.timeIntervalSince(now)
                if duration > 0 {
                    let finalLabel = explicitLabel ?? cleanLabel(labelStr)
                    return TimerParseResult(
                        duration: duration,
                        targetDate: targetDate,
                        label: finalLabel.isEmpty ? "Timer" : finalLabel,
                        originalQuery: originalQuery,
                        displayDuration: formatDuration(duration),
                        displayTarget: formatTargetTime(targetDate),
                        isTargetClockTime: true
                    )
                }
            }
        }

        return nil
    }

    private func parseRelativeClockPhrases(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        let pattern =
            #"(?i)(?:(?:until|untill|till|at|to|by)\s+)?(half|quarter|\d{1,2})\s+(past|to)\s+(\d{1,2}(?:\s*(?:am|pm))?)(?:\s+(.*))?$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        else {
            return nil
        }

        let ns = query as NSString
        let offsetToken = ns.substring(with: match.range(at: 1)).lowercased()
        let direction = ns.substring(with: match.range(at: 2)).lowercased()
        let hourStr = ns.substring(with: match.range(at: 3))

        var minuteOffset = 0
        if offsetToken == "half" {
            minuteOffset = 30
        } else if offsetToken == "quarter" {
            minuteOffset = 15
        } else if let val = Int(offsetToken) {
            minuteOffset = val
        } else {
            return nil
        }

        guard let baseTarget = resolveClockTarget(timeStr: hourStr, now: now) else { return nil }

        let multiplier = (direction == "to") ? -1 : 1
        guard
            let finalTarget = calendar.date(
                byAdding: .minute, value: minuteOffset * multiplier, to: baseTarget)
        else {
            return nil
        }

        // Adjust if finalTarget is in the past
        var targetDate = finalTarget
        if targetDate.timeIntervalSince(now) < 15 {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }

        let duration = targetDate.timeIntervalSince(now)
        guard duration > 0 else { return nil }

        var labelStr: String? = nil
        if match.range(at: 4).location != NSNotFound {
            let extracted = ns.substring(with: match.range(at: 4)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                labelStr = cleanLabel(extracted)
            }
        }

        let finalLabel = explicitLabel ?? labelStr ?? "Timer"
        return TimerParseResult(
            duration: duration,
            targetDate: targetDate,
            label: finalLabel,
            originalQuery: originalQuery,
            displayDuration: formatDuration(duration),
            displayTarget: formatTargetTime(targetDate),
            isTargetClockTime: true
        )
    }

    private func resolveClockTarget(timeStr: String, now: Date) -> Date? {
        let lower = timeStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isPM = lower.contains("pm")
        let isAM = lower.contains("am")
        let cleanTime =
            lower
            .replacingOccurrences(of: "pm", with: "")
            .replacingOccurrences(of: "am", with: "")
            .trimmingCharacters(in: .whitespaces)

        var hour = 0
        var minute = 0
        var second = 0

        if cleanTime.contains(":") {
            let parts = cleanTime.components(separatedBy: ":")
            guard let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            hour = h
            minute = m
            if parts.count > 2, let s = Int(parts[2]) {
                second = s
            }
        } else {
            guard let h = Int(cleanTime) else { return nil }
            hour = h
            minute = 0
        }

        guard hour >= 0, hour <= 23, minute >= 0, minute <= 59 else { return nil }

        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }

        if isAM || isPM || hour > 12 || cleanTime.contains(":") {
            // Definite 24h clock target
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            comps.second = second

            guard let todayTarget = calendar.date(from: comps) else { return nil }
            if todayTarget.timeIntervalSince(now) >= 15 {
                return todayTarget
            }
            return calendar.date(byAdding: .day, value: 1, to: todayTarget)
        }

        // Otherwise ambiguous hour e.g. "7"
        let hour1 = hour == 12 ? 0 : hour
        let hour2 = hour == 12 ? 12 : hour + 12

        let candidate1 = nextOccurrence(hour: hour1, minute: minute, now: now)
        let candidate2 = nextOccurrence(hour: hour2, minute: minute, now: now)

        let candidates = [candidate1, candidate2].compactMap { $0 }.sorted()
        return candidates.first
    }

    // MARK: - 5. Natural Word Durations Parser ("half an hour", "quarter of an hour", "an hour and a half")

    private func parseNaturalWordDurations(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        let patterns: [(regex: String, seconds: TimeInterval)] = [
            (
                #"(?i)\b(?:an?\s+hour\s+and\s+(?:a\s+)?half|1\s+and\s+(?:a\s+)?half\s+hours?|1\.5\s+hours?)\b"#,
                5400
            ),
            (#"(?i)\b(?:half\s+(?:an?\s+)?hour|1/2\s+hour|half\s+hr)\b"#, 1800),
            (#"(?i)\b(?:quarter\s+(?:of\s+)?(?:an?\s+)?hour|1/4\s+hour)\b"#, 900),
            (#"(?i)\b(?:half\s+(?:a\s+)?minute|1/2\s+min)\b"#, 30),
            (#"(?i)\b(?:an?\s+hour|1\s+hour)\b"#, 3600),
            (#"(?i)\b(?:a\s+minute|1\s+minute)\b"#, 60),
        ]

        for (pattern, seconds) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(
                    in: query, range: NSRange(query.startIndex..., in: query))
            else {
                continue
            }

            let ns = query as NSString
            let remaining = ns.replacingCharacters(in: match.range, with: " ")
            let label = explicitLabel ?? cleanLabel(remaining)
            let targetDate = now.addingTimeInterval(seconds)

            return TimerParseResult(
                duration: seconds,
                targetDate: targetDate,
                label: label.isEmpty ? "Timer" : label,
                originalQuery: originalQuery,
                displayDuration: formatDuration(seconds),
                displayTarget: formatTargetTime(targetDate),
                isTargetClockTime: false
            )
        }

        return nil
    }

    // MARK: - 6. Relative Duration Parser ("2min", "for 2min", "1h 30m", "45 minuts", "tea for 2min")

    private func parseRelativeDuration(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        // Regex pattern to extract duration components with typo tolerance
        // e.g. 1.5h, 2 hours, 10 minuts, 30 secnds, 5m, 10s
        let componentPattern =
            #"(?i)(\d+(?:\.\d+)?|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|twenty|twenty-five|thirty|forty|forty-five|fifty|sixty|ninety)\b)\s*(h|hr|hrs|hour|hours|hoour|hoours|hourz|m|min|mins|minute|minutes|minut|minuts|mnt|mnts|mn|s|sec|secs|second|seconds|secnd|secnds|secon|secons|sconds)\b"#

        guard let regex = try? NSRegularExpression(pattern: componentPattern) else { return nil }

        let ns = query as NSString
        let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
        guard !matches.isEmpty else { return nil }

        var totalSeconds: Double = 0
        var matchedRanges: [NSRange] = []

        for match in matches {
            let valStr = ns.substring(with: match.range(at: 1)).lowercased()
            let unitStr = ns.substring(with: match.range(at: 2)).lowercased()

            let value: Double
            if let num = Double(valStr) {
                value = num
            } else if let wordNum = numberWords[valStr] {
                value = wordNum
            } else {
                continue
            }

            matchedRanges.append(match.range)

            if unitStr.starts(with: "h") {
                totalSeconds += value * 3600
            } else if unitStr.starts(with: "s") {
                totalSeconds += value
            } else {
                // minutes
                totalSeconds += value * 60
            }
        }

        guard totalSeconds > 0 else { return nil }

        // Remove matched duration chunks from the string to extract label
        var remaining = query
        for range in matchedRanges.reversed() {
            let nsRemaining = remaining as NSString
            remaining = nsRemaining.replacingCharacters(in: range, with: " ")
        }

        let label = explicitLabel ?? cleanLabel(remaining)
        let targetDate = now.addingTimeInterval(totalSeconds)

        return TimerParseResult(
            duration: totalSeconds,
            targetDate: targetDate,
            label: label.isEmpty ? "Timer" : label,
            originalQuery: originalQuery,
            displayDuration: formatDuration(totalSeconds),
            displayTarget: formatTargetTime(targetDate),
            isTargetClockTime: false
        )
    }

    // MARK: - 7. Plain Number Fallback ("5", "5 tea", "tea 5")

    private func parsePlainNumber(
        query: String, explicitLabel: String?, originalQuery: String, now: Date
    ) -> TimerParseResult? {
        let pattern = #"(?i)^(?:\b(?:for|in|after)\s+)?(\d+(?:\.\d+)?)(?:\s+(.*))?$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        {
            let ns = query as NSString
            let numStr = ns.substring(with: match.range(at: 1))
            guard let val = Double(numStr), val > 0 else { return nil }

            var labelStr: String? = nil
            if match.range(at: 2).location != NSNotFound {
                let extracted = ns.substring(with: match.range(at: 2)).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if !extracted.isEmpty {
                    labelStr = cleanLabel(extracted)
                }
            }

            // Defaults plain number to minutes
            let seconds = val * 60
            let targetDate = now.addingTimeInterval(seconds)
            let finalLabel = explicitLabel ?? labelStr ?? "Timer"

            return TimerParseResult(
                duration: seconds,
                targetDate: targetDate,
                label: finalLabel,
                originalQuery: originalQuery,
                displayDuration: formatDuration(seconds),
                displayTarget: formatTargetTime(targetDate),
                isTargetClockTime: false
            )
        }

        // Check if number is trailing: e.g. "tea 5"
        let trailingPattern = #"^(.*?)\s+(\d+(?:\.\d+)?)$"#
        if let regex = try? NSRegularExpression(pattern: trailingPattern),
            let match = regex.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        {
            let ns = query as NSString
            let labelStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let numStr = ns.substring(with: match.range(at: 2))
            guard let val = Double(numStr), val > 0 else { return nil }

            let seconds = val * 60
            let targetDate = now.addingTimeInterval(seconds)
            let finalLabel = explicitLabel ?? cleanLabel(labelStr)

            return TimerParseResult(
                duration: seconds,
                targetDate: targetDate,
                label: finalLabel.isEmpty ? "Timer" : finalLabel,
                originalQuery: originalQuery,
                displayDuration: formatDuration(seconds),
                displayTarget: formatTargetTime(targetDate),
                isTargetClockTime: false
            )
        }

        return nil
    }

    // MARK: - 8. Formatting Helpers

    public func cleanLabel(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fillers = [
            "for", "fo", "fro", "fr", "in", "inn", "after", "to", "named", "called",
            "labeled", "label:", "title:", "and", "with", "timer for", "timer", "named:",
        ]

        for filler in fillers {
            let lower = clean.lowercased()
            if lower.starts(with: filler + " ") {
                clean = String(clean.dropFirst(filler.count + 1))
            }
            if lower.hasSuffix(" " + filler) {
                clean = String(clean.dropLast(filler.count + 1))
            }
        }

        clean = clean.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'.,:-")))
        guard !clean.isEmpty else { return "Timer" }

        // Capitalize words neatly
        let words = clean.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let capitalized = words.map { word -> String in
            if word.lowercased() == "a" || word.lowercased() == "an" || word.lowercased() == "the"
                || word.lowercased() == "for" || word.lowercased() == "to"
                || word.lowercased() == "of"
            {
                return word.lowercased()
            }
            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")

        return capitalized.isEmpty ? "Timer" : capitalized
    }

    public func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }

        return parts.joined(separator: " ")
    }

    public func formatTargetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
