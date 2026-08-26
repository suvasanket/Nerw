import Foundation
import NerwAction

public final class DateTimeEngine {
    public static let shared = DateTimeEngine()

    public struct DateTimeResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String

        public init(formattedValue: String, peekText: String, subtitle: String = "Date & Time") {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
        }
    }

    private let calendar = Calendar.current
    private let iso8601Formatter = ISO8601DateFormatter()
    private let dateFormats: [String] = [
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "dd-MM-yyyy",
        "dd/MM/yyyy",
        "MMMM d, yyyy",
        "MMMM d",
        "MMM d, yyyy",
        "MMM d",
        "d MMMM yyyy",
        "d MMMM",
        "d MMM yyyy",
        "d MMM",
    ]

    private init() {
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    // MARK: - 1. Date & Time Arithmetic

    /// Date addition/subtraction: e.g. "August 5 + 5", "today + 90 days", "Aug 5 - 10 days"
    public func calculateDateOffset(
        baseDateStr: String, delta: Int, unit: Calendar.Component = .day
    ) -> DateTimeResult? {
        guard let baseDate = parseFlexibleDate(baseDateStr) else { return nil }
        guard let targetDate = calendar.date(byAdding: unit, value: delta, to: baseDate) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        let formatted = formatter.string(from: targetDate)

        let shortFormatter = DateFormatter()
        shortFormatter.dateStyle = .medium
        let baseFormatted = shortFormatter.string(from: baseDate)

        let sign = delta >= 0 ? "+" : "-"
        let absDelta = abs(delta)
        let unitName =
            unit == .day ? "day" : (unit == .month ? "month" : (unit == .year ? "year" : "week"))
        let unitPlural = absDelta == 1 ? unitName : "\(unitName)s"

        let peekText = "\(baseFormatted) \(sign) \(absDelta) \(unitPlural)\nResult: \(formatted)"

        return DateTimeResult(
            formattedValue: formatted,
            peekText: peekText,
            subtitle: "Date Calculation"
        )
    }

    /// Time addition/subtraction: e.g. "3:45pm + 5 hours", "10:30am - 45 mins", "3:45pm + 5"
    public func calculateTimeOffset(baseTimeStr: String, deltaMinutes: Int) -> DateTimeResult? {
        guard let (hour, minute) = parseTime(baseTimeStr) else { return nil }

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard let baseDate = calendar.date(from: dateComponents),
            let targetDate = calendar.date(byAdding: .minute, value: deltaMinutes, to: baseDate)
        else {
            return nil
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let formatted = timeFormatter.string(from: targetDate)
        let baseFormatted = timeFormatter.string(from: baseDate)

        let sign = deltaMinutes >= 0 ? "+" : "-"
        let absMins = abs(deltaMinutes)
        let deltaText: String
        if absMins % 60 == 0 {
            let hrs = absMins / 60
            deltaText = "\(hrs) \(hrs == 1 ? "hour" : "hours")"
        } else {
            deltaText = "\(absMins) mins"
        }

        let peekText = "\(baseFormatted) \(sign) \(deltaText)\nResult: \(formatted)"

        return DateTimeResult(
            formattedValue: formatted,
            peekText: peekText,
            subtitle: "Time Calculation"
        )
    }

    // MARK: - 2. Natural Language Relative Dates

    /// Natural language dates: e.g. "monday in 3 weeks", "next friday", "first day of next month"
    public func parseRelativeDate(query: String) -> DateTimeResult? {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. "<weekday> in <N> weeks" e.g. "monday in 3 weeks"
        if let match = try? NSRegularExpression(
            pattern:
                #"^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+in\s+(\d+)\s+weeks?$"#
        )
        .firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            let ns = lower as NSString
            let dayName = ns.substring(with: match.range(at: 1))
            let weeksStr = ns.substring(with: match.range(at: 2))
            if let weeks = Int(weeksStr), let targetWeekday = weekdayIndex(from: dayName) {
                return calculateWeekdayInWeeks(targetWeekday: targetWeekday, weeks: weeks)
            }
        }

        // 2. "next <weekday>" or "last <weekday>"
        if let match = try? NSRegularExpression(
            pattern: #"^(next|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$"#
        )
        .firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            let ns = lower as NSString
            let direction = ns.substring(with: match.range(at: 1))
            let dayName = ns.substring(with: match.range(at: 2))
            if let targetWeekday = weekdayIndex(from: dayName) {
                return calculateNextOrLastWeekday(
                    targetWeekday: targetWeekday, isNext: direction == "next")
            }
        }

        // 3. "first day of next month" / "last day of this month" / "end of month"
        if lower.contains("first day of next month") {
            return calculateFirstDayOfNextMonth()
        }
        if lower.contains("last day of this month") || lower.contains("end of this month")
            || lower == "end of month"
        {
            return calculateLastDayOfCurrentMonth()
        }
        if lower.contains("first day of this month") || lower.contains("beginning of month") {
            return calculateFirstDayOfCurrentMonth()
        }

        // 4. "in <N> days", "in <N> weeks", "in <N> months"
        if let match = try? NSRegularExpression(
            pattern: #"^in\s+(\d+)\s+(days?|weeks?|months?|years?)$"#
        )
        .firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            let ns = lower as NSString
            let numStr = ns.substring(with: match.range(at: 1))
            let unitStr = ns.substring(with: match.range(at: 2))
            if let num = Int(numStr) {
                let unit: Calendar.Component =
                    unitStr.hasPrefix("day")
                    ? .day
                    : (unitStr.hasPrefix("week")
                        ? .weekOfYear : (unitStr.hasPrefix("month") ? .month : .year))
                return calculateDateOffset(baseDateStr: "today", delta: num, unit: unit)
            }
        }

        // 5. "<N> days ago", "<N> weeks ago"
        if let match = try? NSRegularExpression(
            pattern: #"^(\d+)\s+(days?|weeks?|months?|years?)\s+ago$"#
        )
        .firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            let ns = lower as NSString
            let numStr = ns.substring(with: match.range(at: 1))
            let unitStr = ns.substring(with: match.range(at: 2))
            if let num = Int(numStr) {
                let unit: Calendar.Component =
                    unitStr.hasPrefix("day")
                    ? .day
                    : (unitStr.hasPrefix("week")
                        ? .weekOfYear : (unitStr.hasPrefix("month") ? .month : .year))
                return calculateDateOffset(baseDateStr: "today", delta: -num, unit: unit)
            }
        }

        return nil
    }

    // MARK: - 3. Date Countdowns & Distance

    /// Countdown to date: e.g. "days until 31 Mar", "days until Christmas", "days left in quarter"
    public func calculateCountdown(query: String) -> DateTimeResult? {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = calendar.startOfDay(for: Date())

        // "days left in quarter" / "days until end of quarter"
        if lower.contains("quarter") {
            let month = calendar.component(.month, from: now)
            let quarter = (month - 1) / 3 + 1
            let endMonthOfQuarter = quarter * 3
            var comps = DateComponents()
            comps.year = calendar.component(.year, from: now)
            comps.month = endMonthOfQuarter + 1
            comps.day = 1
            guard let nextQuarterStart = calendar.date(from: comps),
                let endOfQuarter = calendar.date(byAdding: .day, value: -1, to: nextQuarterStart)
            else { return nil }

            let daysLeft = calendar.dateComponents([.day], from: now, to: endOfQuarter).day ?? 0
            return DateTimeResult(
                formattedValue: "\(daysLeft) days left",
                peekText:
                    "Days left in Q\(quarter): \(daysLeft) days\nQuarter ends on \(formatMediumDate(endOfQuarter))",
                subtitle: "Quarter Countdown"
            )
        }

        // "days until Christmas"
        if lower.contains("christmas") {
            var comps = DateComponents()
            comps.year = calendar.component(.year, from: now)
            comps.month = 12
            comps.day = 25
            var christmas = calendar.date(from: comps)!
            if christmas < now {
                comps.year! += 1
                christmas = calendar.date(from: comps)!
            }
            let daysLeft = calendar.dateComponents([.day], from: now, to: christmas).day ?? 0
            return DateTimeResult(
                formattedValue: "\(daysLeft) days",
                peekText: "\(daysLeft) days until Christmas (\(formatMediumDate(christmas)))",
                subtitle: "Holiday Countdown"
            )
        }

        // "days until New Year"
        if lower.contains("new year") {
            var comps = DateComponents()
            comps.year = calendar.component(.year, from: now) + 1
            comps.month = 1
            comps.day = 1
            let newYear = calendar.date(from: comps)!
            let daysLeft = calendar.dateComponents([.day], from: now, to: newYear).day ?? 0
            return DateTimeResult(
                formattedValue: "\(daysLeft) days",
                peekText: "\(daysLeft) days until New Year (\(formatMediumDate(newYear)))",
                subtitle: "Countdown"
            )
        }

        // "days until <target date>" e.g. "days until 31 Mar", "days until March 31"
        let stripped = lower.replacingOccurrences(of: "days until ", with: "")
            .replacingOccurrences(of: "days to ", with: "")
            .replacingOccurrences(of: "how many days until ", with: "")
            .replacingOccurrences(of: "how many days to ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let targetDate = parseFlexibleDate(stripped) {
            var finalTarget = targetDate
            // If date is in the past without explicit year, bump to next year
            if finalTarget < now && !stripped.contains("202") {
                if let nextYear = calendar.date(byAdding: .year, value: 1, to: finalTarget) {
                    finalTarget = nextYear
                }
            }
            let days = calendar.dateComponents([.day], from: now, to: finalTarget).day ?? 0
            let weeks = days / 7
            let remDays = days % 7

            var breakdown = "\(days) days"
            if weeks > 0 {
                breakdown += " (\(weeks) wk\(weeks == 1 ? "" : "s") \(remDays) d)"
            }

            return DateTimeResult(
                formattedValue: "\(days) days",
                peekText: "Until \(formatMediumDate(finalTarget)): \(breakdown)",
                subtitle: "Countdown"
            )
        }

        return nil
    }

    /// Time between two dates: e.g. "time between 1 Jan and 15 Mar"
    public func calculateTimeBetween(firstDateStr: String, secondDateStr: String) -> DateTimeResult?
    {
        guard let date1 = parseFlexibleDate(firstDateStr),
            let date2 = parseFlexibleDate(secondDateStr)
        else { return nil }

        let start = min(date1, date2)
        let end = max(date1, date2)

        let diffComps = calendar.dateComponents([.month, .day], from: start, to: end)
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        let months = diffComps.month ?? 0
        let days = diffComps.day ?? 0

        var desc = "\(totalDays) days"
        if months > 0 {
            desc +=
                " (\(months) \(months == 1 ? "month" : "months"), \(days) \(days == 1 ? "day" : "days"))"
        }

        let peekText = "From \(formatMediumDate(start)) to \(formatMediumDate(end))\nTotal: \(desc)"

        return DateTimeResult(
            formattedValue: "\(totalDays) days",
            peekText: peekText,
            subtitle: "Duration Between Dates"
        )
    }

    // MARK: - 4. ISO 8601 & Epoch / Unix Timestamps

    /// Converts ISO 8601 Zulu timestamp (e.g. 2024-03-15T14:30:00Z) to local time
    public func parseISO8601Timestamp(_ string: String) -> DateTimeResult? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsedDate: Date? = iso8601Formatter.date(from: clean)
        if parsedDate == nil {
            let standardISO = ISO8601DateFormatter()
            parsedDate = standardISO.date(from: clean)
        }

        guard let date = parsedDate else { return nil }

        let localFormatter = DateFormatter()
        localFormatter.dateStyle = .full
        localFormatter.timeStyle = .long
        localFormatter.timeZone = TimeZone.current
        let localStr = localFormatter.string(from: date)

        let epochSeconds = Int64(date.timeIntervalSince1970)

        let peekText =
            "ISO 8601: \(clean)\nLocal Time: \(localStr)\nUnix Timestamp: \(epochSeconds)"

        return DateTimeResult(
            formattedValue: localStr,
            peekText: peekText,
            subtitle: "ISO 8601 Timestamp"
        )
    }

    /// Converts Epoch timestamp (e.g. 1700000000) or outputs current epoch
    public func parseEpochTimestamp(_ string: String) -> DateTimeResult? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // "now in epoch" / "epoch now" / "current epoch"
        if clean == "now in epoch" || clean == "epoch now" || clean == "current epoch"
            || clean == "today in epoch"
        {
            let now = Date()
            let seconds = Int64(now.timeIntervalSince1970)
            let millis = Int64(now.timeIntervalSince1970 * 1000)
            return DateTimeResult(
                formattedValue: "\(seconds)",
                peekText: "Current Unix Epoch:\nSeconds: \(seconds)\nMilliseconds: \(millis)",
                subtitle: "Current Unix Timestamp"
            )
        }

        // Numeric epoch: seconds (10 digits) or milliseconds (13 digits)
        let numStr = clean.replacingOccurrences(of: "epoch", with: "")
            .replacingOccurrences(of: "in date", with: "")
            .replacingOccurrences(of: "in local time", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let epochVal = Double(numStr) else { return nil }

        // Determine if milliseconds (e.g. 1700000000000) or seconds (1700000000)
        let seconds: TimeInterval = epochVal > 1e11 ? epochVal / 1000.0 : epochVal
        let date = Date(timeIntervalSince1970: seconds)

        let localFormatter = DateFormatter()
        localFormatter.dateStyle = .full
        localFormatter.timeStyle = .medium
        localFormatter.timeZone = TimeZone.current
        let localStr = localFormatter.string(from: date)

        let utcFormatter = DateFormatter()
        utcFormatter.dateStyle = .medium
        utcFormatter.timeStyle = .medium
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcStr = utcFormatter.string(from: date)

        let peekText = "Epoch: \(numStr)\nLocal: \(localStr)\nUTC: \(utcStr)"

        return DateTimeResult(
            formattedValue: localStr,
            peekText: peekText,
            subtitle: "Unix Epoch Conversion"
        )
    }

    // MARK: - Helpers

    public func parseFlexibleDate(_ string: String) -> Date? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let now = Date()
        if clean == "today" || clean == "now" {
            return calendar.startOfDay(for: now)
        }
        if clean == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        if clean == "yesterday" {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        }

        let currentYear = calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                // If format lacked year, default to current year
                if !format.contains("y") {
                    var comps = calendar.dateComponents([.month, .day], from: date)
                    comps.year = currentYear
                    return calendar.date(from: comps)
                }
                return date
            }
        }
        return nil
    }

    private func parseTime(_ string: String) -> (hour: Int, minute: Int)? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = ["h:mma", "ha", "h:mm a", "h a", "HH:mm", "H:mm"]
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: clean) {
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                return (hour, minute)
            }
        }
        return nil
    }

    private func weekdayIndex(from name: String) -> Int? {
        switch name.lowercased() {
        case "sunday", "sun": return 1
        case "monday", "mon": return 2
        case "tuesday", "tue", "tues": return 3
        case "wednesday", "wed": return 4
        case "thursday", "thu", "thur", "thurs": return 5
        case "friday", "fri": return 6
        case "saturday", "sat": return 7
        default: return nil
        }
    }

    private func calculateWeekdayInWeeks(targetWeekday: Int, weeks: Int) -> DateTimeResult? {
        let now = Date()
        guard let futureWeekDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: now)
        else { return nil }

        let currentWeekday = calendar.component(.weekday, from: futureWeekDate)
        let deltaDays = targetWeekday - currentWeekday

        guard let finalDate = calendar.date(byAdding: .day, value: deltaDays, to: futureWeekDate)
        else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let formatted = formatter.string(from: finalDate)

        return DateTimeResult(
            formattedValue: formatted,
            peekText: "Result: \(formatted)",
            subtitle: "Relative Date"
        )
    }

    private func calculateNextOrLastWeekday(targetWeekday: Int, isNext: Bool) -> DateTimeResult? {
        let now = calendar.startOfDay(for: Date())
        let currentWeekday = calendar.component(.weekday, from: now)

        var daysDiff = targetWeekday - currentWeekday
        if isNext {
            if daysDiff <= 0 { daysDiff += 7 }
        } else {
            if daysDiff >= 0 { daysDiff -= 7 }
        }

        guard let targetDate = calendar.date(byAdding: .day, value: daysDiff, to: now) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let formatted = formatter.string(from: targetDate)

        return DateTimeResult(
            formattedValue: formatted,
            peekText: "\(isNext ? "Next" : "Last") Occurrence:\n\(formatted)",
            subtitle: "Relative Date"
        )
    }

    private func calculateFirstDayOfNextMonth() -> DateTimeResult? {
        let now = Date()
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return nil }
        var comps = calendar.dateComponents([.year, .month], from: nextMonth)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps) else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let formatted = formatter.string(from: firstDay)

        return DateTimeResult(
            formattedValue: formatted,
            peekText: "First day of next month:\n\(formatted)",
            subtitle: "Calendar Event"
        )
    }

    private func calculateFirstDayOfCurrentMonth() -> DateTimeResult? {
        let now = Date()
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps) else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let formatted = formatter.string(from: firstDay)

        return DateTimeResult(
            formattedValue: formatted,
            peekText: "First day of this month:\n\(formatted)",
            subtitle: "Calendar Event"
        )
    }

    private func calculateLastDayOfCurrentMonth() -> DateTimeResult? {
        let now = Date()
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return nil }
        var comps = calendar.dateComponents([.year, .month], from: nextMonth)
        comps.day = 1
        guard let firstDayOfNext = calendar.date(from: comps),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: firstDayOfNext)
        else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let formatted = formatter.string(from: lastDay)

        return DateTimeResult(
            formattedValue: formatted,
            peekText: "End of month:\n\(formatted)",
            subtitle: "Calendar Event"
        )
    }

    private func formatMediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
