import Foundation
import JavaScriptCore

public final class MathEngine {
    public static let shared = MathEngine()

    public struct MathResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String

        public init(formattedValue: String, peekText: String, subtitle: String = "Calculation") {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
        }
    }

    private let jsContext: JSContext

    private init() {
        let context = JSContext() ?? JSContext(virtualMachine: JSVirtualMachine())!

        let setupScript = """
            const deg2rad = d => d * (Math.PI / 180);
            const rad2deg = r => r * (180 / Math.PI);
            const sin = Math.sin;
            const cos = Math.cos;
            const tan = Math.tan;
            const asin = Math.asin;
            const acos = Math.acos;
            const atan = Math.atan;
            const atan2 = Math.atan2;
            const sinh = Math.sinh;
            const cosh = Math.cosh;
            const tanh = Math.tanh;
            const sqrt = Math.sqrt;
            const cbrt = Math.cbrt;
            const abs = Math.abs;
            const ceil = Math.ceil;
            const floor = Math.floor;
            const round = Math.round;
            const trunc = Math.trunc;
            const log = Math.log;
            const ln = Math.log;
            const log10 = Math.log10;
            const log2 = Math.log2;
            const exp = Math.exp;
            const pow = Math.pow;
            const min = Math.min;
            const max = Math.max;
            const hypot = Math.hypot;
            const pi = Math.PI;
            const PI = Math.PI;
            const e = Math.E;
            const E = Math.E;
            const tau = 2 * Math.PI;
            const TAU = 2 * Math.PI;
            function fact(n) {
                if (n < 0 || Math.floor(n) !== n) return NaN;
                if (n === 0 || n === 1) return 1;
                let r = 1;
                for (let i = 2; i <= n; i++) r *= i;
                return r;
            }
            """
        context.evaluateScript(setupScript)
        self.jsContext = context
    }

    // MARK: - Evaluation API

    public func evaluate(expression: String) -> MathResult? {
        let preprocessed = preprocessExpression(expression)
        guard !preprocessed.isEmpty else { return nil }

        // Percentage check: e.g. "50 as % of 200" or "50 in % of 200"
        let isPercentageResult =
            expression.lowercased().contains("as % of")
            || expression.lowercased().contains("in % of")

        guard let evalResult = jsContext.evaluateScript(preprocessed), evalResult.isNumber else {
            return nil
        }

        let num = evalResult.toDouble()
        guard num.isFinite else { return nil }

        let formatted = formatNumber(num) + (isPercentageResult ? "%" : "")
        let peekText =
            "\(expression.trimmingCharacters(in: .whitespacesAndNewlines)) = \(formatted)"

        return MathResult(
            formattedValue: formatted,
            peekText: peekText,
            subtitle: "Calculation"
        )
    }

    // MARK: - Number Base Conversions

    public func convertBase(value: String, fromBase: Int, toBase: Int) -> MathResult? {
        var cleanVal = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanVal.hasPrefix("0x") || cleanVal.hasPrefix("0X") {
            cleanVal = String(cleanVal.dropFirst(2))
        } else if cleanVal.hasPrefix("0b") || cleanVal.hasPrefix("0B") {
            cleanVal = String(cleanVal.dropFirst(2))
        } else if cleanVal.hasPrefix("0o") || cleanVal.hasPrefix("0O") {
            cleanVal = String(cleanVal.dropFirst(2))
        }

        guard let intVal = Int64(cleanVal, radix: fromBase) else { return nil }

        let formatted: String
        let baseName: String
        switch toBase {
        case 16:
            formatted = "0x" + String(intVal, radix: 16, uppercase: true)
            baseName = "Hexadecimal"
        case 2:
            formatted = "0b" + String(intVal, radix: 2)
            baseName = "Binary"
        case 8:
            formatted = "0o" + String(intVal, radix: 8)
            baseName = "Octal"
        default:
            formatted = String(intVal)
            baseName = "Decimal"
        }

        let peekText = "\(value) = \(formatted) (\(baseName))"
        return MathResult(
            formattedValue: formatted,
            peekText: peekText,
            subtitle: "\(baseName) Conversion"
        )
    }

    // MARK: - Preprocessing

    private func preprocessExpression(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Replace unicode operators
        s = s.replacingOccurrences(of: "×", with: "*")
        s = s.replacingOccurrences(of: "÷", with: "/")
        s = s.replacingOccurrences(of: "π", with: "PI")
        s = s.replacingOccurrences(of: "τ", with: "tau")

        // Words to operators
        s = s.replacingOccurrences(of: "multiplied by", with: "*", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "divided by", with: "/", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "plus", with: "+", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "minus", with: "-", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "times", with: "*", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " over ", with: " / ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " mod ", with: " % ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " modulo ", with: " % ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "half of ", with: "0.5 * ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "quarter of ", with: "0.25 * ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "square root of ", with: "sqrt(", options: .caseInsensitive)
        if input.lowercased().contains("square root of") {
            s += ")"
        }
        s = s.replacingOccurrences(of: "cube root of ", with: "cbrt(", options: .caseInsensitive)
        if input.lowercased().contains("cube root of") {
            s += ")"
        }

        // Degree annotations in trigonometric functions: sin(90 deg), sin(90deg), sin(90°) -> sin(deg2rad(90))
        let degPattern = try! NSRegularExpression(
            pattern:
                #"(sin|cos|tan|asin|acos|atan)\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*(?:deg|°)\s*\)"#,
            options: .caseInsensitive)
        s = degPattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1(deg2rad($2))")

        // Factorial: (\d+)! -> fact($1)
        let factPattern = try! NSRegularExpression(pattern: #"(\d+)\s*!"#)
        s = factPattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "fact($1)")

        // Percentage preprocessing
        // 1. "X as % of Y" or "X in % of Y" -> ((X / Y) * 100)
        let pctOfPattern1 = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)\s+(?:as|in)\s+%\s+of\s+([+-]?[0-9]*\.?[0-9]+)"#,
            options: .caseInsensitive)
        s = pctOfPattern1.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "(($1 / $2) * 100)")

        // 2. "X% off Y" -> (Y - (X / 100) * Y)
        let pctOffPattern = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)%\s+off\s+([+-]?[0-9]*\.?[0-9]+)"#,
            options: .caseInsensitive)
        s = pctOffPattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "($2 - ($1 / 100) * $2)")

        // 3. "X% of Y" -> ((X / 100) * Y)
        let pctOfPattern2 = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)%\s+of\s+([+-]?[0-9]*\.?[0-9]+)"#,
            options: .caseInsensitive)
        s = pctOfPattern2.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "(($1 / 100) * $2)")

        // 4. "Y + X%" -> (Y * (1 + X / 100))
        let pctAddPattern = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)\s*\+\s*([+-]?[0-9]*\.?[0-9]+)%"#)
        s = pctAddPattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "($1 * (1 + $2 / 100))")

        // 5. "Y - X%" -> (Y * (1 - X / 100))
        let pctSubPattern = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)\s*\-\s*([+-]?[0-9]*\.?[0-9]+)%"#)
        s = pctSubPattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "($1 * (1 - $2 / 100))")

        // 6. Standalone "X%" -> (X / 100)
        let pctSinglePattern = try! NSRegularExpression(pattern: #"([+-]?[0-9]*\.?[0-9]+)%"#)
        s = pctSinglePattern.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "($1 / 100)")

        // Replace ^ with ** for JavaScript exponentiation
        s = s.replacingOccurrences(of: "^", with: "**")

        return s
    }

    // MARK: - Formatting

    private func formatNumber(_ val: Double) -> String {
        // Floating point round-off error correction (e.g. 0.1 + 0.2 = 0.30000000000000004)
        let rounded = (val * 1e10).rounded() / 1e10

        if rounded.isFinite && floor(rounded) == rounded && abs(rounded) < 1e12 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: rounded))
                ?? String(format: "%.0f", rounded)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: rounded)) ?? String(format: "%.4f", rounded)
    }
}
