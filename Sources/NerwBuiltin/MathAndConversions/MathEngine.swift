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
            const cot = x => 1 / Math.tan(x);
            const sec = x => 1 / Math.cos(x);
            const csc = x => 1 / Math.sin(x);
            const asin = Math.asin;
            const acos = Math.acos;
            const atan = Math.atan;
            const atan2 = Math.atan2;
            const acot = x => Math.atan(1 / x);
            const asec = x => Math.acos(1 / x);
            const acsc = x => Math.asin(1 / x);
            const sinh = Math.sinh;
            const cosh = Math.cosh;
            const tanh = Math.tanh;
            const coth = x => 1 / Math.tanh(x);
            const sech = x => 1 / Math.cosh(x);
            const csch = x => 1 / Math.sinh(x);
            const asinh = Math.asinh;
            const acosh = Math.acosh;
            const atanh = Math.atanh;
            const acoth = x => Math.atanh(1 / x);
            const asech = x => Math.acosh(1 / x);
            const acsch = x => Math.asinh(1 / x);
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

    // MARK: - 1. General Evaluation

    public func evaluate(expression: String) -> MathResult? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for specialized solvers first:
        // A. Tip calculation: "15% tip on 42"
        if let tipResult = solveTip(trimmed) {
            return tipResult
        }

        // B. Ratio / Aspect ratio: "ratio of 3 to 5", "scale 16:9 to width 1920"
        if let ratioResult = solveRatio(trimmed) {
            return ratioResult
        }

        // C. Percentage change: "% increase from 50 to 75"
        if let pctChangeResult = solvePercentageChange(trimmed) {
            return pctChangeResult
        }

        // Preprocess standard math expression
        let preprocessed = preprocessExpression(trimmed)
        guard !preprocessed.isEmpty else { return nil }

        let isPercentageResult =
            trimmed.lowercased().contains("as % of") || trimmed.lowercased().contains("in % of")

        guard let evalResult = jsContext.evaluateScript(preprocessed), evalResult.isNumber else {
            return nil
        }

        let num = evalResult.toDouble()
        guard num.isFinite else { return nil }

        let formatted = formatNumber(num) + (isPercentageResult ? "%" : "")
        let peekText = "\(trimmed) = \(formatted)"

        return MathResult(
            formattedValue: formatted,
            peekText: peekText,
            subtitle: "Calculation"
        )
    }

    // MARK: - 2. Tip Calculation ("15% tip on 42", "20% tip on 85 with 4 people")

    public func solveTip(_ query: String) -> MathResult? {
        let pattern = try! NSRegularExpression(
            pattern:
                #"^([+-]?[0-9]*\.?[0-9]+)%\s+tip\s+on\s+([$€£¥₹]?\s*[0-9.]+)(?:\s+(?:split|with|for)\s+(\d+)\s*(?:people|persons|split)?)?$"#,
            options: .caseInsensitive
        )
        let ns = query as NSString
        guard
            let match = pattern.firstMatch(
                in: query, range: NSRange(query.startIndex..., in: query))
        else {
            return nil
        }

        let tipPctStr = ns.substring(with: match.range(at: 1))
        var billStr = ns.substring(with: match.range(at: 2))
        billStr = billStr.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let tipPct = Double(tipPctStr), let bill = Double(billStr) else { return nil }

        let splitCount: Int
        if match.range(at: 3).location != NSNotFound {
            splitCount = Int(ns.substring(with: match.range(at: 3))) ?? 1
        } else {
            splitCount = 1
        }

        let tipAmount = bill * (tipPct / 100.0)
        let total = bill + tipAmount

        let fmtTip = formatCurrencyNumber(tipAmount)
        let fmtTotal = formatCurrencyNumber(total)
        let fmtBill = formatCurrencyNumber(bill)

        let title: String
        let peekText: String
        if splitCount > 1 {
            let perPerson = total / Double(splitCount)
            let fmtPerPerson = formatCurrencyNumber(perPerson)
            title = "\(fmtPerPerson) / person (\(fmtTotal) total)"
            peekText =
                "Bill: \(fmtBill) • Tip (\(tipPctStr)%): \(fmtTip)\nTotal: \(fmtTotal)\nSplit (\(splitCount) people): \(fmtPerPerson) each"
        } else {
            title = "Tip: \(fmtTip) • Total: \(fmtTotal)"
            peekText = "Bill: \(fmtBill)\nTip (\(tipPctStr)%): \(fmtTip)\nTotal: \(fmtTotal)"
        }

        return MathResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "Tip Calculator"
        )
    }

    // MARK: - 3. Ratio & Aspect Ratio ("ratio of 3 to 5", "scale 16:9 to width 1920")

    public func solveRatio(_ query: String) -> MathResult? {
        let ns = query as NSString
        let range = NSRange(query.startIndex..., in: query)

        // "ratio of 3 to 5"
        let ratioOfPattern = try! NSRegularExpression(
            pattern: #"^ratio\s+of\s+([0-9.]+)\s+(?:to|and)\s+([0-9.]+)$"#,
            options: .caseInsensitive)
        if let m = ratioOfPattern.firstMatch(in: query, range: range) {
            if let a = Double(ns.substring(with: m.range(at: 1))),
                let b = Double(ns.substring(with: m.range(at: 2))), b != 0
            {
                let total = a + b
                let pctA = (a / total) * 100.0
                let pctB = (b / total) * 100.0
                let decimalVal = a / b

                let fmtA = formatNumber(a)
                let fmtB = formatNumber(b)
                let fmtDec = formatNumber(decimalVal)
                let fmtPctA = formatNumber(pctA)
                let fmtPctB = formatNumber(pctB)

                let title = "\(fmtA):\(fmtB) (\(fmtPctA)% : \(fmtPctB)%)"
                let peekText =
                    "Ratio \(fmtA) : \(fmtB)\nProportion: \(fmtPctA)% to \(fmtPctB)%\nDecimal Value: \(fmtDec)"

                return MathResult(formattedValue: title, peekText: peekText, subtitle: "Ratio")
            }
        }

        // "scale 16:9 to width 1920"
        let scalePattern = try! NSRegularExpression(
            pattern:
                #"^(?:scale\s+)?([0-9.]+)\s*[:/]\s*([0-9.]+)\s+(?:to\s+)?(width|height|w|h)\s+([0-9.]+)$"#,
            options: .caseInsensitive
        )
        if let m = scalePattern.firstMatch(in: query, range: range) {
            if let rW = Double(ns.substring(with: m.range(at: 1))),
                let rH = Double(ns.substring(with: m.range(at: 2))),
                let dimVal = Double(ns.substring(with: m.range(at: 4))), rW > 0, rH > 0
            {
                let dimType = ns.substring(with: m.range(at: 3)).lowercased()
                let resultW: Double
                let resultH: Double
                if dimType.hasPrefix("w") {
                    resultW = dimVal
                    resultH = (dimVal / rW) * rH
                } else {
                    resultH = dimVal
                    resultW = (dimVal / rH) * rW
                }

                let fmtW = formatNumber(resultW)
                let fmtH = formatNumber(resultH)
                let title = "\(fmtW) × \(fmtH)"
                let peekText =
                    "Aspect Ratio \(formatNumber(rW)):\(formatNumber(rH))\nScaled Dimension:\nWidth: \(fmtW) px\nHeight: \(fmtH) px"

                return MathResult(
                    formattedValue: title, peekText: peekText, subtitle: "Aspect Ratio Scaler")
            }
        }

        return nil
    }

    // MARK: - 4. Percentage Change ("% increase from 50 to 75", "percentage change from 100 to 80")

    public func solvePercentageChange(_ query: String) -> MathResult? {
        let pattern = try! NSRegularExpression(
            pattern:
                #"^(?:%|percentage)\s+(?:change|increase|decrease|diff|difference)\s+(?:from|between)\s+([+-]?[0-9]*\.?[0-9]+)\s+(?:to|and)\s+([+-]?[0-9]*\.?[0-9]+)$"#,
            options: .caseInsensitive
        )
        let ns = query as NSString
        guard let m = pattern.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
            let fromVal = Double(ns.substring(with: m.range(at: 1))),
            let toVal = Double(ns.substring(with: m.range(at: 2))), fromVal != 0
        else {
            return nil
        }

        let change = toVal - fromVal
        let pctChange = (change / abs(fromVal)) * 100.0

        let sign = pctChange > 0 ? "+" : ""
        let fmtPct = "\(sign)\(formatNumber(pctChange))%"
        let fmtFrom = formatNumber(fromVal)
        let fmtTo = formatNumber(toVal)
        let fmtDiff = formatNumber(change)

        let title = "\(fmtPct) change"
        let peekText =
            "From \(fmtFrom) to \(fmtTo)\nDifference: \(fmtDiff)\nPercentage Change: \(fmtPct)"

        return MathResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "Percentage Change"
        )
    }

    // MARK: - 5. Number Base Conversions

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

        // Replace unicode operators & constants
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
        s = s.replacingOccurrences(of: " power ", with: " ** ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " over ", with: " / ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " mod ", with: " % ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: " modulo ", with: " % ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "half of ", with: "0.5 * ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "quarter of ", with: "0.25 * ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "square root of ", with: "sqrt(", options: .caseInsensitive)
        if input.lowercased().contains("square root of") { s += ")" }
        s = s.replacingOccurrences(of: "cube root of ", with: "cbrt(", options: .caseInsensitive)
        if input.lowercased().contains("cube root of") { s += ")" }

        // Suffix expansions: 1K/1k (1e3), 1M/1m (1e6), 1B/1b (1e9), 1T/1t (1e12)
        // Match numbers immediately followed by K, M, B, T (e.g. 10K, 2.5M, 1B)
        let suffixPattern = try! NSRegularExpression(
            pattern: #"([+-]?[0-9]*\.?[0-9]+)\s*([kKmMbBtT])\b"#)
        let matches = suffixPattern.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .reversed()
        for match in matches {
            let ns = s as NSString
            let numStr = ns.substring(with: match.range(at: 1))
            let suffix = ns.substring(with: match.range(at: 2)).uppercased()
            if let baseNum = Double(numStr) {
                let multiplier: Double
                switch suffix {
                case "K": multiplier = 1_000
                case "M": multiplier = 1_000_000
                case "B": multiplier = 1_000_000_000
                case "T": multiplier = 1_000_000_000_000
                default: multiplier = 1.0
                }
                let expanded = String(format: "%.0f", baseNum * multiplier)
                if let swiftRange = Range(match.range, in: s) {
                    s.replaceSubrange(swiftRange, with: expanded)
                }
            }
        }

        // Degree annotations in trigonometric functions: sin(90 deg), cot(45°), etc.
        let degPattern = try! NSRegularExpression(
            pattern:
                #"(sin|cos|tan|cot|sec|csc|asin|acos|atan|acot|asec|acsc)\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*(?:deg|°)\s*\)"#,
            options: .caseInsensitive
        )
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

    private func formatCurrencyNumber(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: val)) ?? String(format: "%.2f", val)
    }
}
