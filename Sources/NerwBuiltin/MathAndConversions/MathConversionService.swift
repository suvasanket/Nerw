import Cocoa
import NerwAction
import NerwCore
import NerwSearchBackend

public final class MathConversionService {
    public static let shared = MathConversionService()

    private init() {}

    public func evaluate(query: String) async -> NerwAction? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let intent = MathConversionDetector.shared.detect(query: trimmed) else {
            // Fallback: try direct math expression evaluation on cleaned query
            let (cleaned, _) = MathConversionDetector.shared.cleanQuery(trimmed)
            if let mathResult = MathEngine.shared.evaluate(expression: cleaned) {
                return createAction(
                    title: mathResult.formattedValue,
                    subtitle: mathResult.subtitle,
                    peekText: mathResult.peekText,
                    icon: .system("equal.circle")
                )
            }
            return nil
        }

        switch intent {
        case .unitConversion(let amount, let fromUnit, let toUnit):
            if let res = UnitConversionEngine.shared.convert(
                amount: amount, from: fromUnit, to: toUnit)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("ruler")
                )
            }

        case .compoundUnitConversion(let a1, let u1, let a2, let u2, let toUnit):
            if let res = UnitConversionEngine.shared.convertCompound(
                firstAmount: a1, firstUnit: u1, secondAmount: a2, secondUnit: u2, to: toUnit)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("ruler")
                )
            }

        case .humanTimespan(let amount, let unit):
            if let res = UnitConversionEngine.shared.convertToTimespan(
                amount: amount, unitStr: unit)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("hourglass")
                )
            }

        case .workPlanning(let q):
            if let res = UnitConversionEngine.shared.calculateWorkPlanning(query: q) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("briefcase")
                )
            }

        case .currencyConversion(let amount, let fromCurrency, let toCurrency):
            if let res = await CurrencyConversionEngine.shared.convert(
                amount: amount, from: fromCurrency, to: toCurrency)
            {
                let icon: NerwAction.IconType =
                    res.isError ? .system("wifi.exclamationmark") : .system("dollarsign.circle")
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    courtesyText: res.courtesyText,
                    icon: icon
                )
            }

        case .baseConversion(let value, let fromBase, let toBase):
            if let res = MathEngine.shared.convertBase(
                value: value, fromBase: fromBase, toBase: toBase)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("number.circle")
                )
            }

        case .designUnit(let amount, let fromUnit, let toUnit, let ppi):
            if let res = DesignUnitEngine.shared.convert(
                amount: amount, from: fromUnit, to: toUnit, ppi: ppi)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("aspectratio")
                )
            }

        case .timeInCity(let city):
            if let res = WorldClockEngine.shared.currentTime(in: city) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("clock")
                )
            }

        case .crossCityTime(let timeStr, let fromCity, let toCity):
            if let res = WorldClockEngine.shared.convertTime(
                timeStr: timeStr, from: fromCity, to: toCity)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("globe")
                )
            }

        case .timeDiff(let city):
            if let res = WorldClockEngine.shared.timeDifference(with: city) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("arrow.left.and.right.circle")
                )
            }

        case .timeProjection(let delayHours, let city):
            if let res = WorldClockEngine.shared.projectTime(
                delayHours: delayHours, destination: city)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("clock.badge.checkmark")
                )
            }

        case .dateMath(let baseDate, let delta, _):
            if let res = DateTimeEngine.shared.calculateDateOffset(
                baseDateStr: baseDate, delta: delta, unit: .day)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("calendar")
                )
            }

        case .timeMath(let baseTime, let deltaMins):
            if let res = DateTimeEngine.shared.calculateTimeOffset(
                baseTimeStr: baseTime, deltaMinutes: deltaMins)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("clock.arrow.circlepath")
                )
            }

        case .dateCountdown(let q):
            if let res = DateTimeEngine.shared.calculateCountdown(query: q)
                ?? DateTimeEngine.shared.parseRelativeDate(query: q)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("calendar.badge.clock")
                )
            }

        case .timeBetweenDates(let d1, let d2):
            if let res = DateTimeEngine.shared.calculateTimeBetween(
                firstDateStr: d1, secondDateStr: d2)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("calendar")
                )
            }

        case .isoOrEpoch(let ts):
            if let res = DateTimeEngine.shared.parseISO8601Timestamp(ts)
                ?? DateTimeEngine.shared.parseEpochTimestamp(ts)
            {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("clock")
                )
            }

        case .tipCalculation(let q):
            if let res = MathEngine.shared.solveTip(q) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("percent")
                )
            }

        case .ratioCalculation(let q):
            if let res = MathEngine.shared.solveRatio(q) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("aspectratio")
                )
            }

        case .percentageChange(let q):
            if let res = MathEngine.shared.solvePercentageChange(q) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("chart.line.uptrend.xyaxis")
                )
            }

        case .mathExpression(let expr):
            if let res = MathEngine.shared.evaluate(expression: expr) {
                return createAction(
                    title: res.formattedValue,
                    subtitle: res.subtitle,
                    peekText: res.peekText,
                    icon: .system("equal.circle")
                )
            }
        }

        return nil
    }

    private func createAction(
        title: String,
        subtitle: String,
        peekText: String,
        courtesyText: String? = nil,
        icon: NerwAction.IconType? = nil
    ) -> NerwAction {
        let cleanResult = title.components(separatedBy: " = ").last ?? title
        return NerwAction(
            id: "nerw.mathconversion.\(UUID().uuidString)",
            title: title,
            subtitle: subtitle,
            icon: icon,
            peek: NerwAction.PeekData(
                title: "",
                text: peekText,
                icon: nil,
                textFontSize: 24.0,
                courtesyText: courtesyText
            ),
            category: .mathConversion,
            triggers: [],
            type: .instant(perform: { action in
                // Copy result to clipboard on enter
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cleanResult, forType: .string)
                Nerw.notify("Copied to clipboard")
                NerwSystem.shared.ui?.hideWindow()
            })
        )
    }
}
