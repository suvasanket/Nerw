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
    private let iso8601WithFractional = ISO8601DateFormatter()
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
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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

        // 4. "in <N> days", "in <N> weeks", "in <N> months", "in <N> years"
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

        // 5. "<N> days/weeks/months/years from now/today"
        if let match = try? NSRegularExpression(
            pattern: #"^(\d+)\s+(days?|weeks?|months?|years?)\s+from\s+(?:now|today)$"#
        ).firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
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

        // 6. "<N> days ago", "<N> weeks ago"
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

    /// Countdown to date: e.g. "days until 31 Mar", "days until Christmas", "days left in quarter", "days until next sunday", "days until november"
    public func calculateCountdown(query: String) -> DateTimeResult? {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: now)

        // 1. "days in <month> [year]" or "days in <year>" e.g. "days in november", "how many days in august", "days in 2026"
        if let daysInMatch = try? NSRegularExpression(
            pattern: #"^(?:how\s+many\s+)?days\s+(?:are\s+)?in\s+([a-zA-Z0-9\s]+)$"#
        ).firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            let ns = lower as NSString
            let target = ns.substring(with: daysInMatch.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            // Year only e.g. "2026", "2024", "a year", "this year"
            if target == "a year" || target == "this year" || target == "the year"
                || Int(target) != nil
            {
                let year = Int(target) ?? currentYear
                let isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
                let numDays = isLeap ? 366 : 365
                let leapStr = isLeap ? " (Leap Year)" : ""
                return DateTimeResult(
                    formattedValue: "\(numDays) days",
                    peekText:
                        "\(year) has \(numDays) days\(leapStr)\n52 weeks and \(isLeap ? 2 : 1) day\(isLeap ? "s" : "")",
                    subtitle: "Days in Year"
                )
            }

            // Month [and Year] e.g. "november", "february 2024", "august"
            let parts = target.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let monthStr = parts.first, let mIndex = monthIndex(from: monthStr) {
                let year = (parts.count > 1 ? Int(parts[1]) : nil) ?? currentYear
                let comps = DateComponents(year: year, month: mIndex, day: 1)
                if let monthDate = calendar.date(from: comps),
                    let range = calendar.range(of: .day, in: .month, for: monthDate)
                {
                    let count = range.count
                    let mName = monthName(from: mIndex)
                    return DateTimeResult(
                        formattedValue: "\(count) days",
                        peekText: "\(mName) \(year) has \(count) days",
                        subtitle: "Days in Month"
                    )
                }
            }
        }

        // 2. "days left in <quarter/year/month/week>"
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
                    "Days left in Q\(quarter): \(daysLeft) days\nQuarter ends on \(formatFullDate(endOfQuarter))",
                subtitle: "Quarter Countdown"
            )
        }

        if lower.contains("days left in year") || lower.contains("days left in this year")
            || lower.contains("days until end of year")
            || lower.contains("days left in \(currentYear)")
        {
            let comps = DateComponents(year: currentYear, month: 12, day: 31)
            if let endOfYear = calendar.date(from: comps) {
                let daysLeft = calendar.dateComponents([.day], from: now, to: endOfYear).day ?? 0
                return DateTimeResult(
                    formattedValue: "\(daysLeft) days left",
                    peekText:
                        "Days left in \(currentYear): \(daysLeft) days\nYear ends on \(formatFullDate(endOfYear))",
                    subtitle: "Year Countdown"
                )
            }
        }

        if lower.contains("days left in month") || lower.contains("days left in this month")
            || lower.contains("days until end of month")
        {
            if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: now) {
                var comps = calendar.dateComponents([.year, .month], from: nextMonthDate)
                comps.day = 1
                if let firstOfNext = calendar.date(from: comps),
                    let endOfMonth = calendar.date(byAdding: .day, value: -1, to: firstOfNext)
                {
                    let daysLeft =
                        calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
                    let currentMonthName = monthName(from: calendar.component(.month, from: now))
                    return DateTimeResult(
                        formattedValue: "\(daysLeft) days left",
                        peekText:
                            "Days left in \(currentMonthName): \(daysLeft) days\nMonth ends on \(formatFullDate(endOfMonth))",
                        subtitle: "Month Countdown"
                    )
                }
            }
        }

        // 3. "days since <date>" / "weeks since <date>" / "how many days since <date>"
        let isSince =
            lower.contains("since") || lower.contains("days from ") || lower.contains("weeks from ")
        if isSince {
            var stripped = lower
            let sincePrefixes = [
                "how many days since ", "how many days from ", "how many weeks since ",
                "how many weeks from ",
                "days since ", "days from ", "weeks since ", "weeks from ",
            ]
            for p in sincePrefixes {
                if stripped.hasPrefix(p) {
                    stripped.removeFirst(p.count)
                    break
                }
            }
            stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

            if var targetDate = parseFlexibleDate(stripped) {
                if targetDate > now && !stripped.contains(String(currentYear)) {
                    var comps = calendar.dateComponents([.month, .day], from: targetDate)
                    comps.year = currentYear
                    if let adjusted = calendar.date(from: comps) {
                        targetDate = adjusted
                    }
                }
                if targetDate > now {
                    if let lastYear = calendar.date(byAdding: .year, value: -1, to: targetDate) {
                        targetDate = lastYear
                    }
                }
                let totalDays = calendar.dateComponents([.day], from: targetDate, to: now).day ?? 0
                let totalWeeks = totalDays / 7
                let remDays = totalDays % 7

                let isWeeks = lower.contains("week")
                let formatted: String
                if isWeeks {
                    let weeksVal = Double(totalDays) / 7.0
                    formatted =
                        weeksVal.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(totalWeeks) weeks ago" : String(format: "%.1f weeks ago", weeksVal)
                } else {
                    formatted = "\(totalDays) days ago"
                }

                var breakdown = "\(totalDays) days"
                if totalWeeks > 0 {
                    breakdown += " (\(totalWeeks) wk\(totalWeeks == 1 ? "" : "s") \(remDays) d)"
                }

                return DateTimeResult(
                    formattedValue: formatted,
                    peekText: "Elapsed since \(formatFullDate(targetDate)):\n\(breakdown)",
                    subtitle: "Time Elapsed"
                )
            }
        }

        // 4. "days until <date>", "days to <date>", "weeks until <date>", "how many days until <date>"
        var stripped = lower
        let untilPrefixes = [
            "how many days until ", "how many days to ", "how many weeks until ",
            "how many weeks to ",
            "how many months until ", "how many months to ", "days until ", "days to ",
            "weeks until ", "weeks to ",
            "months until ", "months to ",
        ]
        for p in untilPrefixes {
            if stripped.hasPrefix(p) {
                stripped.removeFirst(p.count)
                break
            }
        }
        stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        if let targetDate = parseFlexibleDate(stripped) {
            var finalTarget = targetDate
            if finalTarget < now && !stripped.contains(String(currentYear))
                && !stripped.contains(String(currentYear + 1))
            {
                if let nextYear = calendar.date(byAdding: .year, value: 1, to: finalTarget) {
                    finalTarget = nextYear
                }
            }

            let days = calendar.dateComponents([.day], from: now, to: finalTarget).day ?? 0
            let weeks = days / 7
            let remDays = days % 7

            let isWeeks = lower.contains("week")
            let isMonths = lower.contains("month") && !lower.contains("days")

            let formatted: String
            if isWeeks {
                let weeksVal = Double(days) / 7.0
                formatted =
                    weeksVal.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(weeks) weeks" : String(format: "%.1f weeks", weeksVal)
            } else if isMonths {
                let months =
                    calendar.dateComponents([.month], from: now, to: finalTarget).month ?? 0
                formatted = "\(months) months"
            } else {
                formatted = "\(days) days"
            }

            var breakdown = "\(days) days"
            if weeks > 0 {
                breakdown += " (\(weeks) wk\(weeks == 1 ? "" : "s") \(remDays) d)"
            }

            return DateTimeResult(
                formattedValue: formatted,
                peekText:
                    "\(days) days until \(formatFullDate(finalTarget))\nBreakdown: \(breakdown)",
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
            .replacingOccurrences(of: "in local time", with: "")
            .replacingOccurrences(of: "to local time", with: "")
            .replacingOccurrences(of: "in local", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let date = iso8601Formatter.date(from: clean)
                ?? iso8601WithFractional.date(from: clean)
        else { return nil }

        let localFormatter = DateFormatter()
        localFormatter.dateStyle = .full
        localFormatter.timeStyle = .medium
        localFormatter.timeZone = TimeZone.current
        let localStr = localFormatter.string(from: date)

        let peekText = "UTC: \(clean)\nLocal: \(localStr)"

        return DateTimeResult(
            formattedValue: localStr,
            peekText: peekText,
            subtitle: "ISO 8601 Timestamp"
        )
    }

    /// Converts Unix epoch seconds/milliseconds to local and UTC date/time strings
    public func parseEpochTimestamp(_ string: String) -> DateTimeResult? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if clean == "now in epoch" || clean == "epoch now" || clean == "today in epoch" {
            let nowSeconds = Int64(Date().timeIntervalSince1970)
            return DateTimeResult(
                formattedValue: "\(nowSeconds)",
                peekText: "Current Unix Epoch Timestamp:\n\(nowSeconds)",
                subtitle: "Unix Epoch Timestamp"
            )
        }

        let numStr = clean.replacingOccurrences(of: "epoch ", with: "")
            .replacingOccurrences(of: "in date", with: "")
            .replacingOccurrences(of: "to date", with: "")
            .replacingOccurrences(of: "epoch", with: "")
            .replacingOccurrences(of: "in local time", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let epochVal = Double(numStr) else { return nil }

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
        let startOfToday = calendar.startOfDay(for: now)
        let currentYear = calendar.component(.year, from: now)

        if clean == "today" || clean == "now" {
            return startOfToday
        }
        if clean == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: startOfToday)
        }
        if clean == "yesterday" {
            return calendar.date(byAdding: .day, value: -1, to: startOfToday)
        }

        // Relative Keywords
        if clean == "next weekend" || clean == "this weekend" || clean == "weekend" {
            let currentWeekday = calendar.component(.weekday, from: startOfToday)
            var daysToAdd = 7 - currentWeekday  // 7 is Saturday
            if daysToAdd <= 0 { daysToAdd += 7 }
            return calendar.date(byAdding: .day, value: daysToAdd, to: startOfToday)
        }

        if clean == "next month" || clean == "start of next month"
            || clean == "first day of next month"
        {
            if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: now) {
                var comps = calendar.dateComponents([.year, .month], from: nextMonthDate)
                comps.day = 1
                return calendar.date(from: comps)
            }
        }

        if clean == "end of month" || clean == "last day of this month"
            || clean == "end of this month"
        {
            if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: now) {
                var comps = calendar.dateComponents([.year, .month], from: nextMonthDate)
                comps.day = 1
                if let firstOfNext = calendar.date(from: comps) {
                    return calendar.date(byAdding: .day, value: -1, to: firstOfNext)
                }
            }
        }

        if clean == "end of year" || clean == "last day of year" || clean == "end of this year" {
            let comps = DateComponents(year: currentYear, month: 12, day: 31)
            return calendar.date(from: comps)
        }

        if clean == "next year" || clean == "start of next year" {
            let comps = DateComponents(year: currentYear + 1, month: 1, day: 1)
            return calendar.date(from: comps)
        }

        // Holidays
        if clean == "christmas" || clean == "christmas day" {
            var comps = DateComponents(year: currentYear, month: 12, day: 25)
            if let date = calendar.date(from: comps) {
                if date < startOfToday {
                    comps.year = currentYear + 1
                    return calendar.date(from: comps)
                }
                return date
            }
        }

        if clean == "halloween" {
            var comps = DateComponents(year: currentYear, month: 10, day: 31)
            if let date = calendar.date(from: comps) {
                if date < startOfToday {
                    comps.year = currentYear + 1
                    return calendar.date(from: comps)
                }
                return date
            }
        }

        if clean == "new year" || clean == "new years" || clean == "new year's day"
            || clean == "new years day"
        {
            let comps = DateComponents(year: currentYear + 1, month: 1, day: 1)
            return calendar.date(from: comps)
        }

        if clean == "valentine" || clean == "valentines" || clean == "valentine's day"
            || clean == "valentines day"
        {
            var comps = DateComponents(year: currentYear, month: 2, day: 14)
            if let date = calendar.date(from: comps) {
                if date < startOfToday {
                    comps.year = currentYear + 1
                    return calendar.date(from: comps)
                }
                return date
            }
        }

        if clean == "thanksgiving" || clean == "thanksgiving day" {
            var comps = DateComponents(year: currentYear, month: 11, day: 1)
            if let nov1 = calendar.date(from: comps) {
                let nov1Wkday = calendar.component(.weekday, from: nov1)
                let firstThuDay = 1 + ((5 - nov1Wkday + 7) % 7)
                comps.day = firstThuDay + 21
                if let thanksgivingDate = calendar.date(from: comps) {
                    if thanksgivingDate < startOfToday {
                        comps.year = currentYear + 1
                        comps.day = 1
                        if let nextNov1 = calendar.date(from: comps) {
                            let nextNov1Wkday = calendar.component(.weekday, from: nextNov1)
                            let nextFirstThuDay = 1 + ((5 - nextNov1Wkday + 7) % 7)
                            comps.day = nextFirstThuDay + 21
                            return calendar.date(from: comps)
                        }
                    }
                    return thanksgivingDate
                }
            }
        }

        // Single Month Name: "november", "nov", "next november", "march", "december"
        let monthCandidate =
            clean
            .replacingOccurrences(of: "next ", with: "")
            .replacingOccurrences(of: "this ", with: "")
            .replacingOccurrences(of: "the month of ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let mIndex = monthIndex(from: monthCandidate) {
            var comps = DateComponents(year: currentYear, month: mIndex, day: 1)
            if let date = calendar.date(from: comps) {
                if date <= startOfToday && !clean.contains(String(currentYear)) {
                    comps.year = currentYear + 1
                    return calendar.date(from: comps)
                }
                return date
            }
        }

        // Single Weekday Name: "next sunday", "sunday", "sun", "this sunday", "coming friday"
        let weekdayCandidate =
            clean
            .replacingOccurrences(of: "next ", with: "")
            .replacingOccurrences(of: "this ", with: "")
            .replacingOccurrences(of: "coming ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetWkday = weekdayIndex(from: weekdayCandidate) {
            let currentWkday = calendar.component(.weekday, from: startOfToday)
            var daysToAdd = targetWkday - currentWkday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }
            return calendar.date(byAdding: .day, value: daysToAdd, to: startOfToday)
        }

        // Standard date format parsing
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                if !format.contains("y") {
                    var comps = calendar.dateComponents([.month, .day], from: date)
                    comps.year = currentYear
                    if let constructed = calendar.date(from: comps) {
                        if constructed < startOfToday {
                            comps.year = currentYear + 1
                            return calendar.date(from: comps)
                        }
                        return constructed
                    }
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
        switch name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
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

    private func monthIndex(from name: String) -> Int? {
        switch name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "january", "jan": return 1
        case "february", "feb": return 2
        case "march", "mar": return 3
        case "april", "apr": return 4
        case "may": return 5
        case "june", "jun": return 6
        case "july", "jul": return 7
        case "august", "aug": return 8
        case "september", "sep", "sept": return 9
        case "october", "oct": return 10
        case "november", "nov": return 11
        case "december", "dec": return 12
        default: return nil
        }
    }

    private func monthName(from index: Int) -> String {
        let months = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        if index >= 1 && index <= 12 {
            return months[index - 1]
        }
        return ""
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

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func formatMediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
