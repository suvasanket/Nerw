import Foundation
import NerwAction

public final class DesignUnitEngine {
    public static let shared = DesignUnitEngine()

    public struct DesignUnitResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String

        public init(
            formattedValue: String, peekText: String, subtitle: String = "Design Unit Conversion"
        ) {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
        }
    }

    public enum DesignUnit: String {
        case px, pt
        case inch = "in"
        case cm, mm, rem, em
    }

    private init() {}

    // MARK: - DPI / PPI & Typography Conversion

    /// Converts physical/pixel dimensions at custom or default PPI (e.g. 72 or 96) and CSS typography units
    public func convert(
        amount: Double,
        from fromUnitStr: String,
        to toUnitStr: String,
        ppi explicitPPI: Double? = nil,
        baseFontSize: Double = 16.0
    ) -> DesignUnitResult? {
        guard let fromUnit = parseDesignUnit(fromUnitStr),
            let toUnit = parseDesignUnit(toUnitStr)
        else {
            return nil
        }

        // Determine effective PPI: explicit > 72 default for print/inches, 96 for CSS px/pt
        let ppi =
            explicitPPI
            ?? ((fromUnit == .inch || toUnit == .inch || fromUnit == .cm || toUnit == .cm
                || fromUnit == .mm || toUnit == .mm) ? 72.0 : 96.0)

        // 1. Convert source to Pixels (px)
        let pixels: Double
        switch fromUnit {
        case .px:
            pixels = amount
        case .pt:
            // 1 pt = (ppi / 72) px
            pixels = amount * (ppi / 72.0)
        case .inch:
            pixels = amount * ppi
        case .cm:
            // 1 inch = 2.54 cm -> cm = inch * 2.54 -> inch = cm / 2.54
            pixels = (amount / 2.54) * ppi
        case .mm:
            pixels = (amount / 25.4) * ppi
        case .rem, .em:
            pixels = amount * baseFontSize
        }

        // 2. Convert Pixels (px) to destination unit
        let resultVal: Double
        switch toUnit {
        case .px:
            resultVal = pixels
        case .pt:
            resultVal = pixels / (ppi / 72.0)
        case .inch:
            resultVal = pixels / ppi
        case .cm:
            resultVal = (pixels / ppi) * 2.54
        case .mm:
            resultVal = (pixels / ppi) * 25.4
        case .rem, .em:
            resultVal = pixels / baseFontSize
        }

        let formattedAmount = formatNumber(amount)
        let formattedResult = formatNumber(resultVal)

        let ppiDesc = explicitPPI != nil ? " at \(Int(ppi)) PPI" : ""
        let resultTitle = "\(formattedResult) \(toUnit.rawValue)"
        let peekText =
            "\(formattedAmount) \(fromUnit.rawValue) =\n\(formattedResult) \(toUnit.rawValue)\(ppiDesc)\n(Base font size: \(Int(baseFontSize))px)"

        return DesignUnitResult(
            formattedValue: resultTitle,
            peekText: peekText,
            subtitle: "Design Unit Conversion"
        )
    }

    private func parseDesignUnit(_ str: String) -> DesignUnit? {
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch clean {
        case "px", "pixel", "pixels": return .px
        case "pt", "point", "points": return .pt
        case "in", "inch", "inches", "\"": return .inch
        case "cm", "centimeter", "centimeters": return .cm
        case "mm", "millimeter", "millimeters": return .mm
        case "rem", "rems": return .rem
        case "em", "ems": return .em
        default: return nil
        }
    }

    private func formatNumber(_ val: Double) -> String {
        if val.isFinite && floor(val) == val && abs(val) < 1e12 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: val)) ?? String(format: "%.0f", val)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: val)) ?? String(format: "%.4f", val)
    }
}
