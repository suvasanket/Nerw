import Foundation

/// Fast, comprehensive detector for math, unit conversion, currency conversion, and base conversion intents.
public final class MathConversionDetector {
    public static let shared = MathConversionDetector()

    // MARK: - Detected Intent Models

    public enum Intent: Equatable {
        case unitConversion(amount: Double, fromUnit: String, toUnit: String)
        case compoundUnitConversion(
            firstAmount: Double, firstUnit: String, secondAmount: Double, secondUnit: String,
            toUnit: String)
        case currencyConversion(amount: Double, fromCurrency: String, toCurrency: String)
        case baseConversion(value: String, fromBase: Int, toBase: Int)
        case mathExpression(expression: String)
    }

    // MARK: - Precompiled Regular Expressions

    private let prefixPatterns: [NSRegularExpression]
    private let trailingQuestionPattern: NSRegularExpression

    // Base conversion patterns
    private let basePattern1: NSRegularExpression  // "0xFF in dec", "0b1010 to hex"
    private let basePattern2: NSRegularExpression  // "255 in hex", "10 to binary"
    private let basePattern3: NSRegularExpression  // "hex 0xFF", "bin 1010"

    // Currency patterns
    private let currencySymbolPattern1: NSRegularExpression  // "$100 to eur", "€50 in usd"
    private let currencySymbolPattern2: NSRegularExpression  // "100$ in eur", "50€ to $"
    private let currencyCodePattern: NSRegularExpression  // "100 usd to eur", "50 euros in dollars"

    // Unit conversion patterns
    private let unitConversionPattern: NSRegularExpression  // "100 km to miles", "100km to mi"
    private let unitFractionPattern: NSRegularExpression  // "1/2 cup to ml"
    private let unitCompoundPattern: NSRegularExpression  // "5 ft 10 in to cm", "1 hr 30 min to sec"
    private let unitHowManyPattern: NSRegularExpression  // "how many miles in 100 km"

    // Quick Math patterns
    private let mathBasicPattern: NSRegularExpression  // standard arithmetic
    private let mathFunctionPattern: NSRegularExpression  // sqrt(144), sin(90), log(10)
    private let mathPercentagePattern1: NSRegularExpression  // 50% of 200, 20% off 80
    private let mathPercentagePattern2: NSRegularExpression  // 100 + 20%, 100 - 15%
    private let mathWordOpPattern: NSRegularExpression  // 10 plus 20, half of 80, square root of 144
    private let mathFactorialPattern: NSRegularExpression  // 5!

    // Known Currency Symbols
    public static let currencySymbols: [String: String] = [
        "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR",
        "₩": "KRW", "฿": "THB", "₽": "RUB", "R$": "BRL", "zł": "PLN",
        "kr": "SEK", "₺": "TRY", "₪": "ILS", "C$": "CAD", "CAD$": "CAD",
        "A$": "AUD", "AUD$": "AUD", "NZ$": "NZD", "HK$": "HKD", "S$": "SGD",
        "NT$": "TWD", "₫": "VND", "CHF": "CHF", "Kč": "CZK", "Ft": "HUF",
    ]

    // Currency names to ISO codes
    public static let currencyNames: [String: String] = [
        "usd": "USD", "dollar": "USD", "dollars": "USD", "buck": "USD", "bucks": "USD",
        "eur": "EUR", "euro": "EUR", "euros": "EUR",
        "gbp": "GBP", "pound": "GBP", "pounds": "GBP", "quid": "GBP",
        "jpy": "JPY", "yen": "JPY",
        "inr": "INR", "rupee": "INR", "rupees": "INR",
        "cad": "CAD", "canadian dollar": "CAD", "canadian dollars": "CAD",
        "aud": "AUD", "australian dollar": "AUD", "australian dollars": "AUD",
        "chf": "CHF", "swiss franc": "CHF", "swiss francs": "CHF", "franc": "CHF", "francs": "CHF",
        "cny": "CNY", "rmb": "CNY", "yuan": "CNY", "chinese yuan": "CNY",
        "krw": "KRW", "won": "KRW", "korean won": "KRW",
        "mxn": "MXN", "peso": "MXN", "pesos": "MXN", "mexican peso": "MXN",
        "brl": "BRL", "real": "BRL", "reais": "BRL", "brazilian real": "BRL",
        "rub": "RUB", "ruble": "RUB", "rubles": "RUB",
        "sek": "SEK", "krona": "SEK", "kronor": "SEK", "swedish krona": "SEK",
        "nok": "NOK", "norwegian krone": "NOK", "kroner": "NOK",
        "dkk": "DKK", "danish krone": "DKK",
        "pln": "PLN", "zloty": "PLN", "polish zloty": "PLN",
        "try": "TRY", "turkish lira": "TRY", "lira": "TRY",
        "ils": "ILS", "shekel": "ILS", "shekels": "ILS", "israeli shekel": "ILS",
        "sgd": "SGD", "singapore dollar": "SGD", "singapore dollars": "SGD",
        "hkd": "HKD", "hong kong dollar": "HKD", "hong kong dollars": "HKD",
        "nzd": "NZD", "new zealand dollar": "NZD", "new zealand dollars": "NZD",
        "thb": "THB", "baht": "THB", "thai baht": "THB",
        "zar": "ZAR", "rand": "ZAR", "south african rand": "ZAR",
        "idr": "IDR", "rupiah": "IDR", "indonesian rupiah": "IDR",
        "myr": "MYR", "ringgit": "MYR", "malaysian ringgit": "MYR",
        "php": "PHP", "philippine peso": "PHP",
        "czk": "CZK", "czech koruna": "CZK", "koruna": "CZK",
        "huf": "HUF", "forint": "HUF", "hungarian forint": "HUF",
        "ron": "RON", "romanian leu": "RON", "leu": "RON",
        "bgn": "BGN", "bulgarian lev": "BGN", "lev": "BGN",
        "isk": "ISK", "icelandic krona": "ISK",
    ]

    // Base units tokens for fast keyword filtering
    public static let knownUnitTokens: Set<String> = [
        // Length
        "nm", "um", "µm", "micron", "microns", "micrometer", "micrometers",
        "mm", "millimeter", "millimeters", "millimetre", "millimetres",
        "cm", "centimeter", "centimeters", "centimetre", "centimetres",
        "dm", "decimeter", "decimeters",
        "m", "meter", "meters", "metre", "metres",
        "dam", "hm", "km", "kilometer", "kilometers", "kilometre", "kilometres",
        "in", "inch", "inches", "\"", "ft", "foot", "feet", "'",
        "yd", "yard", "yards", "mi", "mile", "miles",
        "nmi", "nauticalmile", "nauticalmiles", "ly", "lightyear", "lightyears", "au", "parsec",
        "parsecs", "pc",
        // Mass
        "pg", "ng", "ug", "µg", "mcg", "microgram", "micrograms",
        "mg", "milligram", "milligrams",
        "cg", "dg", "g", "gram", "grams",
        "kg", "kilo", "kilos", "kilogram", "kilograms",
        "t", "ton", "tons", "tonne", "tonnes", "metricton", "metrictons",
        "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds",
        "st", "stone", "stones", "ct", "carat", "carats", "slug", "slugs", "ozt",
        // Temperature
        "c", "°c", "celsius", "centigrade", "degc",
        "f", "°f", "fahrenheit", "degf",
        "k", "°k", "kelvin", "degk",
        // Volume
        "ml", "cc", "milliliter", "milliliters", "millilitre", "millilitres",
        "cl", "dl", "l", "liter", "liters", "litre", "litres",
        "tsp", "teaspoon", "teaspoons", "tbsp", "tablespoon", "tablespoons",
        "floz", "fluidounce", "fluidounces", "cup", "cups", "pt", "pint", "pints",
        "qt", "quart", "quarts", "gal", "gallon", "gallons",
        "m3", "cm3", "mm3", "km3", "in3", "ft3", "yd3",
        // Area
        "sqmm", "mm2", "mm²", "sqcm", "cm2", "cm²",
        "sqm", "m2", "m²", "squaremeter", "squaremeters", "squaremetre", "squaremetres",
        "sqkm", "km2", "km²", "squarekilometer", "squarekilometers",
        "ha", "hectare", "hectares", "are", "ares",
        "sqin", "in2", "in²", "squareinch", "squareinches",
        "sqft", "ft2", "ft²", "squarefoot", "squarefeet",
        "sqyd", "yd2", "yd²", "squareyard", "squareyards",
        "sqmi", "mi2", "mi²", "squaremile", "squaremiles",
        "acre", "acres",
        // Data
        "b", "bit", "bits", "byte", "bytes",
        "kb", "kbit", "kilobit", "kilobits", "kilobyte", "kilobytes",
        "mb", "mbit", "megabit", "megabits", "megabyte", "megabytes",
        "gb", "gbit", "gigabit", "gigabits", "gigabyte", "gigabytes",
        "tb", "tbit", "terabit", "terabits", "terabyte", "terabytes",
        "pb", "pbit", "petabit", "petabits", "petabyte", "petabytes",
        "kib", "kibibyte", "kibibytes", "mib", "mebibyte", "mebibytes",
        "gib", "gibibyte", "gibibytes", "tib", "tebibyte", "tebibytes",
        "kbps", "mbps", "gbps", "tbps",
        // Speed
        "mps", "m/s", "kmh", "kph", "kmph", "km/h", "mph", "mi/h", "knot", "knots", "kt", "kts",
        "fps", "ft/s",
        // Time
        "ns", "nanosecond", "nanoseconds", "us", "µs", "microsecond", "microseconds",
        "ms", "millisecond", "milliseconds", "s", "sec", "secs", "second", "seconds",
        "min", "mins", "minute", "minutes", "h", "hr", "hrs", "hour", "hours",
        "d", "day", "days", "wk", "wks", "week", "weeks", "mo", "mos", "month", "months", "yr",
        "yrs", "year", "years",
        // Energy & Power
        "j", "joule", "joules", "kj", "kilojoule", "kilojoules", "cal", "calorie", "calories",
        "kcal", "kilocalorie", "kilocalories", "wh", "kwh", "btu", "btus",
        "w", "watt", "watts", "kw", "kilowatt", "kilowatts", "mw", "megawatt", "megawatts", "gw",
        "gigawatt", "hp", "horsepower",
        // Pressure
        "pa", "pascal", "pascals", "kpa", "kilopascal", "kilopascals", "mpa", "gpa", "bar", "bars",
        "mbar", "psi", "atm", "atmosphere", "atmospheres", "torr", "mmhg", "inhg",
        // Angle
        "deg", "degree", "degrees", "°", "rad", "radian", "radians", "grad", "gradians", "arcmin",
        "arcsec",
        // Fuel
        "mpg", "l/100km",
    ]

    private init() {
        func rx(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }

        // Prefixes to strip
        let prefixList = [
            #"^(?:calculate|calc|math|evaluate|eval)\s+"#,
            #"^(?:convert|conversion\s+of|conversion)\s+"#,
            #"^(?:what\s+is|what's|whats|what\s+are)\s+"#,
            #"^(?:how\s+much\s+is|how\s+much\s+are|how\s+much\s+in|how\s+much)\s+"#,
            #"^(?:price\s+of|cost\s+of|value\s+of)\s+"#,
        ]
        prefixPatterns = prefixList.map { rx($0) }
        trailingQuestionPattern = rx(#"\?+$"#)

        // Base conversions
        // 1. "0xFF to dec", "0b1010 in hex"
        basePattern1 = rx(
            #"^(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+)\s+(?:to|in|into|as)\s+(dec|decimal|hex|hexadecimal|bin|binary|oct|octal)$"#
        )
        // 2. "255 in hex", "10 to binary"
        basePattern2 = rx(
            #"^(\d+)\s+(?:to|in|into|as)\s+(hex|hexadecimal|bin|binary|oct|octal|dec|decimal)$"#)
        // 3. "hex 0xFF", "bin 1010", "dec 0xFF"
        basePattern3 = rx(#"^(hex|bin|oct|dec)\s+(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+)$"#)

        // Currency conversions
        // 1. "$100 to eur", "€50 in usd", "₹1500 to $"
        currencySymbolPattern1 = rx(
            #"^([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF)\s*([+-]?[0-9]*\.?[0-9]+)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )
        // 2. "100$ in eur", "50€ to $"
        currencySymbolPattern2 = rx(
            #"^([+-]?[0-9]*\.?[0-9]+)\s*([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )
        // 3. "100 usd to eur", "19usd to jpy", "19usd jpy", "50 euros in dollars"
        currencyCodePattern = rx(
            #"^([+-]?[0-9]*\.?[0-9]+)\s*([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )

        // Unit conversions
        // 1. Standard / compact: "100 km to miles", "100km to mi", "50 kg in lbs", "32f to c", "1 acre to sqft"
        unitConversionPattern = rx(
            #"^([+-]?[0-9]*\.?[0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        // 2. Fractions: "1/2 cup to ml", "3/4 tsp in tbsp"
        unitFractionPattern = rx(
            #"^([0-9]+)\s*/\s*([0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        // 3. Compound: "5 ft 10 in to cm", "1 hr 30 min to sec"
        unitCompoundPattern = rx(
            #"^([0-9.]+)\s*([a-zA-Z'\"°]+)\s+([0-9.]+)\s*([a-zA-Z'\"°]+)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        // 4. "how many miles in 100 km", "how many centimeters are in 5 inches"
        unitHowManyPattern = rx(
            #"^(?:how\s+many)\s+([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s+(?:in|are\s+in|are\s+there\s+in)\s+([+-]?[0-9]*\.?[0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )

        // Quick Math
        // Arithmetic expressions containing digits and +, -, *, /, ^, %, parens
        mathBasicPattern = rx(#"^[\s\d\+\-\*\/\^\(\)\.\,\×\÷\%]+$"#)
        // Functions: sqrt(144), sin(90), cos(pi/2), log(100), abs(-5), round(4.5), etc.
        mathFunctionPattern = rx(
            #"^(?:sin|cos|tan|asin|acos|atan|sqrt|cbrt|abs|ceil|floor|round|log|ln|log10|log2|exp|pow|min|max|hypot|deg|rad)\s*\(.+\)$"#
        )
        // Percentages: "50% of 200", "20% off 80", "50 as % of 200"
        mathPercentagePattern1 = rx(
            #"^[+-]?[0-9]*\.?[0-9]+\s*%\s*(?:of|off)\s+[+-]?[0-9]*\.?[0-9]+$"#)
        mathPercentagePattern2 = rx(#"^[+-]?[0-9]*\.?[0-9]+\s*[\+\-]\s*[+-]?[0-9]*\.?[0-9]+\s*%$"#)
        // Word operators: "10 plus 20", "50 minus 15", "6 times 7", "100 divided by 4", "half of 80", "square root of 144"
        mathWordOpPattern = rx(
            #"^(?:(?:[+-]?[0-9]*\.?[0-9]+)\s+(?:plus|minus|times|multiplied\s+by|divided\s+by|over|mod|modulo)\s+(?:[+-]?[0-9]*\.?[0-9]+)|(?:half|quarter|square\s+root|cube\s+root)\s+of\s+(?:[+-]?[0-9]*\.?[0-9]+))$"#
        )
        // Factorial: "5!", "10!"
        mathFactorialPattern = rx(#"^\d+\s*!$"#)
    }

    // MARK: - Normalization / Preprocessing

    public func cleanQuery(_ query: String) -> (cleaned: String, hadPrefix: Bool) {
        var trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trailingQuestionPattern.stringByReplacingMatches(
            in: trimmed,
            range: NSRange(trimmed.startIndex..., in: trimmed),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var hadPrefix = false
        for pattern in prefixPatterns {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = pattern.firstMatch(in: trimmed, range: range) {
                if match.range.location == 0 {
                    trimmed = (trimmed as NSString).replacingCharacters(in: match.range, with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    hadPrefix = true
                    break
                }
            }
        }

        return (trimmed, hadPrefix)
    }

    // MARK: - Main Detection API

    /// Analyzes the query and returns the detected math/conversion intent if found.
    public func detect(query: String) -> Intent? {
        let (cleaned, hadPrefix) = cleanQuery(query)
        guard !cleaned.isEmpty else { return nil }

        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)

        // 1. Base Conversions
        if let baseIntent = detectBaseConversion(cleaned, range: nsRange) {
            return baseIntent
        }

        // 2. Currency Conversions
        if let currencyIntent = detectCurrencyConversion(
            cleaned, range: nsRange, hadPrefix: hadPrefix)
        {
            return currencyIntent
        }

        // 3. Unit Conversions (including compound and "how many")
        if let unitIntent = detectUnitConversion(cleaned, range: nsRange, hadPrefix: hadPrefix) {
            return unitIntent
        }

        // 4. Quick Math Expressions
        if let mathIntent = detectQuickMath(cleaned, range: nsRange, hadPrefix: hadPrefix) {
            return mathIntent
        }

        return nil
    }

    // MARK: - Private Detectors

    private func detectBaseConversion(_ query: String, range: NSRange) -> Intent? {
        let ns = query as NSString

        if let m = basePattern1.firstMatch(in: query, range: range) {
            let val = ns.substring(with: m.range(at: 1))
            let toStr = ns.substring(with: m.range(at: 2)).lowercased()
            let fromBase =
                val.hasPrefix("0x")
                ? 16 : (val.hasPrefix("0b") ? 2 : (val.hasPrefix("0o") ? 8 : 10))
            let toBase = parseBase(toStr)
            return .baseConversion(value: val, fromBase: fromBase, toBase: toBase)
        }

        if let m = basePattern2.firstMatch(in: query, range: range) {
            let val = ns.substring(with: m.range(at: 1))
            let toStr = ns.substring(with: m.range(at: 2)).lowercased()
            let toBase = parseBase(toStr)
            return .baseConversion(value: val, fromBase: 10, toBase: toBase)
        }

        if let m = basePattern3.firstMatch(in: query, range: range) {
            let toStr = ns.substring(with: m.range(at: 1)).lowercased()
            let val = ns.substring(with: m.range(at: 2))
            let fromBase =
                val.hasPrefix("0x")
                ? 16 : (val.hasPrefix("0b") ? 2 : (val.hasPrefix("0o") ? 8 : 10))
            let toBase = parseBase(toStr)
            return .baseConversion(value: val, fromBase: fromBase, toBase: toBase)
        }

        return nil
    }

    private func parseBase(_ str: String) -> Int {
        switch str {
        case "hex", "hexadecimal": return 16
        case "bin", "binary": return 2
        case "oct", "octal": return 8
        default: return 10
        }
    }

    private func detectCurrencyConversion(_ query: String, range: NSRange, hadPrefix: Bool)
        -> Intent?
    {
        let ns = query as NSString

        // Pattern 1: "$100 to eur", "€50 in usd"
        if let m = currencySymbolPattern1.firstMatch(in: query, range: range) {
            let symbol = ns.substring(with: m.range(at: 1))
            let amountStr = ns.substring(with: m.range(at: 2))
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = Double(amountStr),
                let fromCode = resolveCurrencyCode(symbol),
                let toCode = resolveCurrencyCode(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }
        }

        // Pattern 2: "100$ in eur", "50€ to $"
        if let m = currencySymbolPattern2.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let symbol = ns.substring(with: m.range(at: 2))
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = Double(amountStr),
                let fromCode = resolveCurrencyCode(symbol),
                let toCode = resolveCurrencyCode(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }
        }

        // Pattern 3: "100 usd to eur", "50 euros in dollars"
        if let m = currencyCodePattern.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let fromRaw = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = Double(amountStr),
                let fromCode = resolveCurrencyCode(fromRaw),
                let toCode = resolveCurrencyCode(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }
        }

        return nil
    }

    public func resolveCurrencyCode(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let code = Self.currencySymbols[trimmed] {
            return code
        }
        let lower = trimmed.lowercased()
        if let code = Self.currencyNames[lower] {
            return code
        }
        if trimmed.count == 3 && trimmed.allSatisfy({ $0.isLetter }) {
            return trimmed.uppercased()
        }
        return nil
    }

    private func detectUnitConversion(_ query: String, range: NSRange, hadPrefix: Bool) -> Intent? {
        let ns = query as NSString

        // "how many miles in 100 km"
        if let m = unitHowManyPattern.firstMatch(in: query, range: range) {
            let toUnit = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let amountStr = ns.substring(with: m.range(at: 2))
            let fromUnit = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = Double(amountStr), isLikelyUnit(fromUnit) && isLikelyUnit(toUnit) {
                return .unitConversion(amount: amount, fromUnit: fromUnit, toUnit: toUnit)
            }
        }

        // Compound: "5 ft 10 in to cm", "1 hr 30 min to sec"
        if let m = unitCompoundPattern.firstMatch(in: query, range: range) {
            let amt1Str = ns.substring(with: m.range(at: 1))
            let unit1 = ns.substring(with: m.range(at: 2))
            let amt2Str = ns.substring(with: m.range(at: 3))
            let unit2 = ns.substring(with: m.range(at: 4))
            let toUnit = ns.substring(with: m.range(at: 5)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amt1 = Double(amt1Str), let amt2 = Double(amt2Str),
                isLikelyUnit(unit1) && isLikelyUnit(unit2) && isLikelyUnit(toUnit)
            {
                return .compoundUnitConversion(
                    firstAmount: amt1, firstUnit: unit1, secondAmount: amt2, secondUnit: unit2,
                    toUnit: toUnit)
            }
        }

        // Fractions: "1/2 cup to ml"
        if let m = unitFractionPattern.firstMatch(in: query, range: range) {
            let numStr = ns.substring(with: m.range(at: 1))
            let denStr = ns.substring(with: m.range(at: 2))
            let fromUnit = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let toUnit = ns.substring(with: m.range(at: 4)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let num = Double(numStr), let den = Double(denStr), den != 0,
                isLikelyUnit(fromUnit) && isLikelyUnit(toUnit)
            {
                let amount = num / den
                return .unitConversion(amount: amount, fromUnit: fromUnit, toUnit: toUnit)
            }
        }

        // Standard / Compact: "100 km to miles", "100km to mi", "50 kg in lbs", "32f to c"
        if let m = unitConversionPattern.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let fromUnit = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let toUnit = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            // If both from and to resolve as currency codes, treat as currency conversion
            if let fromCode = resolveCurrencyCode(fromUnit),
                let toCode = resolveCurrencyCode(toUnit),
                let amount = Double(amountStr)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }

            if let amount = Double(amountStr), isLikelyUnit(fromUnit) && isLikelyUnit(toUnit) {
                return .unitConversion(amount: amount, fromUnit: fromUnit, toUnit: toUnit)
            }
        }

        return nil
    }

    public func isLikelyUnit(_ str: String) -> Bool {
        let normalized = str.lowercased().replacingOccurrences(of: " ", with: "")
        if Self.knownUnitTokens.contains(normalized) {
            return true
        }
        if Self.knownUnitTokens.contains(str.lowercased()) {
            return true
        }
        return false
    }

    private func detectQuickMath(_ query: String, range: NSRange, hadPrefix: Bool) -> Intent? {
        // Factorial
        if mathFactorialPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Percentage calculations
        if mathPercentagePattern1.firstMatch(in: query, range: range) != nil
            || mathPercentagePattern2.firstMatch(in: query, range: range) != nil
        {
            return .mathExpression(expression: query)
        }

        // Mathematical functions
        if mathFunctionPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Word operators (e.g. "10 plus 20", "half of 80")
        if mathWordOpPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Standard Arithmetic expressions
        if mathBasicPattern.firstMatch(in: query, range: range) != nil {
            // Must contain at least one operator (+, -, *, /, ^, ×, ÷, %, !) to avoid matching single numbers or filenames
            if query.contains(where: { "+-*/^×÷%!".contains($0) }) {
                // Must have at least one digit
                if query.contains(where: { $0.isNumber }) {
                    return .mathExpression(expression: query)
                }
            }
        }

        // Constants combined with operators or digits: e.g. "2 * pi", "pi * 5^2", "e^2"
        let lower = query.lowercased()
        if (lower.contains("pi") || lower.contains("π") || lower.contains("tau")
            || lower.contains("τ") || lower == "e" || lower.contains(" e ") || lower.hasPrefix("e*")
            || lower.hasPrefix("e^"))
            && (query.contains(where: { "+-*/^×÷()".contains($0) }) || hadPrefix)
        {
            return .mathExpression(expression: query)
        }

        return nil
    }
}
