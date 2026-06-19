import Cocoa
import JavaScriptCore
import NerwAction
import NerwCore
import NerwSearchBackend

public class MathConversionService {
    public static let shared = MathConversionService()

    private let mathPattern = try! NSRegularExpression(pattern: #"^[\d\s\+\-\*\/\^\(\)\.]+$"#)
    private let conversionPattern = try! NSRegularExpression(
        pattern: #"^([0-9.]+)\s*([a-zA-Z]{1,4})\s+(to|in)\s+([a-zA-Z]{1,4})$"#,
        options: .caseInsensitive)

    // Mapping for common Foundation units
    private let unitMap: [String: Dimension] = [
        // Mass
        "kg": UnitMass.kilograms,
        "g": UnitMass.grams,
        "mg": UnitMass.milligrams,
        "oz": UnitMass.ounces,
        "lb": UnitMass.pounds,
        "lbs": UnitMass.pounds,
        // Length
        "m": UnitLength.meters,
        "km": UnitLength.kilometers,
        "cm": UnitLength.centimeters,
        "mm": UnitLength.millimeters,
        "mi": UnitLength.miles,
        "yd": UnitLength.yards,
        "ft": UnitLength.feet,
        "in": UnitLength.inches,
        // Temperature
        "c": UnitTemperature.celsius,
        "f": UnitTemperature.fahrenheit,
        "k": UnitTemperature.kelvin,
        // Volume
        "l": UnitVolume.liters,
        "ml": UnitVolume.milliliters,
        "gal": UnitVolume.gallons,
        "qt": UnitVolume.quarts,
        "pt": UnitVolume.pints,
        "cup": UnitVolume.cups,
        "floz": UnitVolume.fluidOunces,
        // Time
        "sec": UnitDuration.seconds,
        "min": UnitDuration.minutes,
        "hr": UnitDuration.hours,
        "hrs": UnitDuration.hours,
    ]

    private init() {}

    public func evaluate(query: String) async -> NerwAction? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)

        // 1. Check for Conversion (Unit / Currency)
        if let match = conversionPattern.firstMatch(in: trimmed, range: nsRange) {
            let amountStr = (trimmed as NSString).substring(with: match.range(at: 1))
            let fromStr = (trimmed as NSString).substring(with: match.range(at: 2)).lowercased()
            let toStr = (trimmed as NSString).substring(with: match.range(at: 4)).lowercased()

            guard let amount = Double(amountStr) else { return nil }

            // Try Foundation Units first
            if let fromUnit = unitMap[fromStr], let toUnit = unitMap[toStr] {
                if type(of: fromUnit) == type(of: toUnit) {
                    let measurement = Measurement(value: amount, unit: fromUnit)
                    let converted = measurement.converted(to: toUnit)

                    let formatter = MeasurementFormatter()
                    formatter.unitOptions = .providedUnit
                    formatter.numberFormatter.maximumFractionDigits = 4
                    let resultStr = formatter.string(from: converted)

                    return createAction(
                        title: resultStr, subtitle: "Unit Conversion",
                        peekText: "\(amountStr) \(fromStr.uppercased()) = \(resultStr)")
                }
            }

            // If not Foundation unit, treat as Currency (assume 3 letters)
            if fromStr.count == 3 && toStr.count == 3 {
                return await fetchCurrency(
                    amount: amount, from: fromStr.uppercased(), to: toStr.uppercased())
            }
        }

        // 2. Check for Math Expression
        if mathPattern.firstMatch(in: trimmed, range: nsRange) != nil {
            if trimmed.contains(where: { "+-*/^()".contains($0) }) {
                // Replace ^ with ** for JavaScriptCore
                let jsQuery = trimmed.replacingOccurrences(of: "^", with: "**")
                if let context = JSContext() {
                    // Safety evaluate to prevent weird JS quirks returning non-numeric values
                    if let result = context.evaluateScript(jsQuery), result.isNumber {
                        let resultStr = result.toString() ?? ""
                        return createAction(
                            title: resultStr, subtitle: "Calculation",
                            peekText: "\(trimmed) = \(resultStr)")
                    }
                }
            }
        }

        return nil
    }

    private func fetchCurrency(amount: Double, from: String, to: String) async -> NerwAction? {
        let urlStr = "https://api.frankfurter.dev/v1/latest?base=\(from)&symbols=\(to)"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0  // Short timeout to prevent hanging UI

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any],
                    let rates = json["rates"] as? [String: Double],
                    let rate = rates[to]
                {
                    let convertedAmount = amount * rate
                    let resultStr = String(format: "%.2f %@", convertedAmount, to)
                    return createAction(
                        title: resultStr,
                        subtitle: "Currency Conversion",
                        peekText:
                            "\(amount) \(from) = \(resultStr)",
                        courtesyText: "Powered by Frankfurter"
                    )
                }
            }
        } catch {
            // Return an offline/error state action
            return createAction(
                title: "Offline or Timeout",
                subtitle: "Currency Conversion Failed",
                peekText:
                    "Unable to fetch exchange rates for \(from) to \(to).\nCheck your internet connection.",
                icon: .system("wifi.exclamationmark")
            )
        }
        return nil
    }

    private func createAction(
        title: String, subtitle: String, peekText: String,
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
                if let ui = NerwSystem.shared.ui {
                    ui.hideWindow()
                }
            })
        )
    }
}
