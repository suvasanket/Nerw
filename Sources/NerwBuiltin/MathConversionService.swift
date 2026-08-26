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

        // 1. Detect Intent using MathConversionDetector
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

        // 2. Route based on Intent
        switch intent {
        case .unitConversion(let amount, let fromUnit, let toUnit):
            if let unitResult = UnitConversionEngine.shared.convert(
                amount: amount, from: fromUnit, to: toUnit)
            {
                return createAction(
                    title: unitResult.formattedValue,
                    subtitle: unitResult.subtitle,
                    peekText: unitResult.peekText,
                    icon: .system("ruler")
                )
            }

        case .compoundUnitConversion(
            let firstAmount, let firstUnit, let secondAmount, let secondUnit, let toUnit):
            if let unitResult = UnitConversionEngine.shared.convertCompound(
                firstAmount: firstAmount, firstUnit: firstUnit,
                secondAmount: secondAmount, secondUnit: secondUnit,
                to: toUnit
            ) {
                return createAction(
                    title: unitResult.formattedValue,
                    subtitle: unitResult.subtitle,
                    peekText: unitResult.peekText,
                    icon: .system("ruler")
                )
            }

        case .currencyConversion(let amount, let fromCurrency, let toCurrency):
            if let currencyResult = await CurrencyConversionEngine.shared.convert(
                amount: amount, from: fromCurrency, to: toCurrency
            ) {
                let icon: NerwAction.IconType =
                    currencyResult.isError
                    ? .system("wifi.exclamationmark")
                    : .system("dollarsign.circle")

                return createAction(
                    title: currencyResult.formattedValue,
                    subtitle: currencyResult.subtitle,
                    peekText: currencyResult.peekText,
                    courtesyText: currencyResult.courtesyText,
                    icon: icon
                )
            }

        case .baseConversion(let value, let fromBase, let toBase):
            if let baseResult = MathEngine.shared.convertBase(
                value: value, fromBase: fromBase, toBase: toBase)
            {
                return createAction(
                    title: baseResult.formattedValue,
                    subtitle: baseResult.subtitle,
                    peekText: baseResult.peekText,
                    icon: .system("number.circle")
                )
            }

        case .mathExpression(let expression):
            if let mathResult = MathEngine.shared.evaluate(expression: expression) {
                return createAction(
                    title: mathResult.formattedValue,
                    subtitle: mathResult.subtitle,
                    peekText: mathResult.peekText,
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
                NSPasteboard.general.setString(title, forType: .string)
                Nerw.notify("Copied to clipboard")
                NerwSystem.shared.ui?.hideWindow()
            })
        )
    }
}
