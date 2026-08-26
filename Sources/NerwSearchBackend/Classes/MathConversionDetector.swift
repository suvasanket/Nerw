import Foundation

public final class MathConversionDetector {
    public static let shared = MathConversionDetector()

    public enum Intent: Equatable {
        case unitConversion(amount: Double, fromUnit: String, toUnit: String)
        case compoundUnitConversion(
            firstAmount: Double, firstUnit: String, secondAmount: Double, secondUnit: String,
            toUnit: String)
        case humanTimespan(amount: Double, unit: String)
        case workPlanning(query: String)
        case currencyConversion(amount: Double, fromCurrency: String, toCurrency: String)
        case baseConversion(value: String, fromBase: Int, toBase: Int)
        case designUnit(amount: Double, fromUnit: String, toUnit: String, ppi: Double?)
        case timeInCity(city: String)
        case crossCityTime(timeStr: String, fromCity: String, toCity: String)
        case timeDiff(city: String)
        case timeProjection(delayHours: Double, city: String?)
        case dateMath(baseDate: String, delta: Int, unit: String)
        case timeMath(baseTime: String, deltaMins: Int)
        case dateCountdown(query: String)
        case timeBetweenDates(firstDate: String, secondDate: String)
        case isoOrEpoch(timestamp: String)
        case tipCalculation(query: String)
        case ratioCalculation(query: String)
        case percentageChange(query: String)
        case mathExpression(expression: String)
    }

    // Pre-compiled regex patterns
    private let prefixPatterns: [NSRegularExpression]
    private let trailingQuestionPattern: NSRegularExpression

    // Base conversions
    private let basePattern1: NSRegularExpression
    private let basePattern2: NSRegularExpression
    private let basePattern3: NSRegularExpression

    // Currency conversions
    private let currencySymbolPattern1: NSRegularExpression
    private let currencySymbolPattern2: NSRegularExpression
    private let currencyCodePattern: NSRegularExpression
    private let currencyPrefixedCodePattern: NSRegularExpression  // "USD1K to EUR", "USD 1K in JPY", "USD1K"
    private let currencyImplicitFromPattern: NSRegularExpression  // "10K in EUR", "500 to JPY"

    // Unit conversion patterns
    private let unitConversionPattern: NSRegularExpression
    private let unitFractionPattern: NSRegularExpression
    private let unitCompoundPattern: NSRegularExpression
    private let unitHowManyPattern: NSRegularExpression
    private let humanTimespanPattern: NSRegularExpression

    // Design unit pattern
    private let designUnitPattern: NSRegularExpression  // "2 inches in px at 72 ppi", "16px in rem"

    // World Clock & Timezone patterns
    private let timeInCityPattern: NSRegularExpression  // "time in tokyo", "time in JFK"
    private let crossCityTimePattern: NSRegularExpression  // "5pm ldn in sf", "9am nyc to tokyo"
    private let timeDiffPattern: NSRegularExpression  // "time diff Paris", "diff Tokyo"
    private let timeProjectionPattern: NSRegularExpression  // "time in 4 hours in SF", "time in 4 hours"

    // Date & Time patterns
    private let dateMathPattern: NSRegularExpression  // "August 5 + 5", "today + 90 days", "Aug 5 - 10 days"
    private let timeMathPattern: NSRegularExpression  // "3:45pm + 5 hours", "10:30am - 45 min", "3:45pm + 5"
    private let dateCountdownPattern: NSRegularExpression  // "days until 31 Mar", "days left in quarter"
    private let timeBetweenDatesPattern: NSRegularExpression  // "time between 1 Jan and 15 Mar"
    private let iso8601Pattern: NSRegularExpression  // "2024-03-15T14:30:00Z"
    private let epochPattern: NSRegularExpression  // "1700000000 in date", "now in epoch"

    // Quick Math patterns
    private let mathBasicPattern: NSRegularExpression
    private let mathFunctionPattern: NSRegularExpression
    private let mathPercentagePattern1: NSRegularExpression
    private let mathPercentagePattern2: NSRegularExpression
    private let mathWordOpPattern: NSRegularExpression
    private let mathFactorialPattern: NSRegularExpression
    private let mathSuffixPattern: NSRegularExpression  // "10K", "1.5M"
    private let tipPattern: NSRegularExpression
    private let ratioPattern: NSRegularExpression
    private let pctChangePattern: NSRegularExpression
    private let workPlanningPattern: NSRegularExpression

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
        "nm", "um", "µm", "micron", "microns", "micrometer", "micrometers",
        "mm", "millimeter", "millimeters", "millimetre", "millimetres",
        "cm", "centimeter", "centimeters", "centimetre", "centimetres",
        "dm", "decimeter", "decimeters",
        "m", "meter", "meters", "metre", "metres",
        "dam", "hm", "km", "kilometer", "kilometers", "kilometre", "kilometres",
        "in", "inch", "inches", "\"", "ft", "foot", "feet", "'",
        "yd", "yard", "yards", "yds", "mi", "mile", "miles",
        "nmi", "nauticalmile", "nauticalmiles", "ly", "lightyear", "lightyears",
        "au", "astronomicalunit", "astronomicalunits", "pc", "parsec", "parsecs",
        "fur", "furlong", "furlongs", "fth", "fathom", "fathoms",
        "pg", "ng", "ug", "µg", "mg", "milligram", "milligrams",
        "g", "gram", "grams", "kg", "kilo", "kilos", "kilogram", "kilograms",
        "t", "tonne", "tonnes", "oz", "ounce", "ounces",
        "lb", "lbs", "pound", "pounds", "st", "stone", "stones",
        "ton", "tons", "shortton", "shorttons", "ct", "carat", "carats",
        "c", "°c", "celsius", "centigrade", "f", "°f", "fahrenheit", "k", "°k", "kelvin",
        "ml", "milliliter", "milliliters", "millilitre", "millilitres", "cc",
        "cl", "dl", "l", "liter", "liters", "litre", "litres",
        "tsp", "teaspoon", "teaspoons", "tbsp", "tablespoon", "tablespoons",
        "floz", "fluidounce", "fluidounces", "cup", "cups", "pt", "pint", "pints",
        "qt", "quart", "quarts", "gal", "gallon", "gallons",
        "m3", "cm3", "mm3", "km3", "in3", "ft3", "yd3",
        "sqmm", "mm2", "mm²", "sqcm", "cm2", "cm²",
        "sqm", "m2", "m²", "squaremeter", "squaremeters", "squaremetre", "squaremetres",
        "sqkm", "km2", "km²", "squarekilometer", "squarekilometers",
        "ha", "hectare", "hectares", "are", "ares",
        "sqin", "in2", "in²", "squareinch", "squareinches",
        "sqft", "ft2", "ft²", "squarefoot", "squarefeet",
        "sqyd", "yd2", "yd²", "squareyard", "squareyards",
        "sqmi", "mi2", "mi²", "squaremile", "squaremiles",
        "acre", "acres",
        "b", "bit", "bits", "byte", "bytes",
        "kb", "kbit", "kilobit", "kilobits", "kilobyte", "kilobytes",
        "mb", "mbit", "megabit", "megabits", "megabyte", "megabytes",
        "gb", "gbit", "gigabit", "gigabits", "gigabyte", "gigabytes",
        "tb", "tbit", "terabit", "terabits", "terabyte", "terabytes",
        "pb", "pbit", "petabit", "petabits", "petabyte", "petabytes",
        "kib", "kibibyte", "kibibytes", "mib", "mebibyte", "mebibytes",
        "gib", "gibibyte", "gibibytes", "tib", "tebibyte", "tebibytes",
        "kbps", "mbps", "gbps", "tbps",
        "mps", "m/s", "kmh", "kph", "kmph", "km/h", "mph", "mi/h", "knot", "knots", "kt", "kts",
        "fps", "ft/s",
        "ns", "nanosecond", "nanoseconds", "us", "µs", "microsecond", "microseconds",
        "ms", "millisecond", "milliseconds", "s", "sec", "secs", "second", "seconds",
        "min", "mins", "minute", "minutes", "h", "hr", "hrs", "hour", "hours",
        "d", "day", "days", "wk", "wks", "week", "weeks", "mo", "mos", "month", "months", "yr",
        "yrs", "year", "years",
        "j", "joule", "joules", "kj", "kilojoule", "kilojoules", "cal", "calorie", "calories",
        "kcal", "kilocalorie", "kilocalories", "wh", "kwh", "btu", "btus",
        "w", "watt", "watts", "kw", "kilowatt", "kilowatts", "mw", "megawatt", "megawatts", "gw",
        "gigawatt", "hp", "horsepower",
        "pa", "pascal", "pascals", "kpa", "kilopascal", "kilopascals", "mpa", "gpa", "bar", "bars",
        "mbar", "psi", "atm", "atmosphere", "atmospheres", "torr", "mmhg", "inhg",
        "deg", "degree", "degrees", "°", "rad", "radian", "radians", "grad", "gradians", "arcmin",
        "arcsec",
        "mpg", "l/100km",
        "px", "pt", "rem", "em", "ppi", "dpi",
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
        basePattern1 = rx(
            #"^(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+)\s+(?:to|in|into|as)\s+(dec|decimal|hex|hexadecimal|bin|binary|oct|octal)$"#
        )
        basePattern2 = rx(
            #"^(\d+)\s+(?:to|in|into|as)\s+(hex|hexadecimal|bin|binary|oct|octal|dec|decimal)$"#)
        basePattern3 = rx(#"^(hex|bin|oct|dec)\s+(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+)$"#)

        // Currency conversions
        currencySymbolPattern1 = rx(
            #"^([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF)\s*([+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )
        currencySymbolPattern2 = rx(
            #"^([+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?)\s*([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )
        currencyCodePattern = rx(
            #"^([+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?)\s*([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)(?:\s*(?:to|in|into|as|->|-->|=>|=)\s*|\s+)([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )
        currencyPrefixedCodePattern = rx(
            #"^([a-zA-Z]{3})\s*([0-9.]+[kKmMbBtT]?)(?:\s+(?:to|in|into|as|->|-->|=>|=)\s+([a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?|[$€£¥₹₩฿₽zł₺₪₫KčFt]))?$"#
        )
        currencyImplicitFromPattern = rx(
            #"^([0-9.]+[kKmMbBtT]?)\s+(?:to|in|into|as|->|-->|=>|=)\s+([$€£¥₹₩฿₽zł₺₪₫KčFt]|C\$|A\$|NZ\$|HK\$|S\$|R\$|CHF|[a-zA-Z]{3}|[a-zA-Z]+(?:\s+[a-zA-Z]+)?)$"#
        )

        // Unit conversions
        unitConversionPattern = rx(
            #"^([+-]?[0-9]*\.?[0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        unitFractionPattern = rx(
            #"^([0-9]+)\s*/\s*([0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        unitCompoundPattern = rx(
            #"^([0-9.]+)\s*([a-zA-Z'\"°]+)\s+([0-9.]+)\s*([a-zA-Z'\"°]+)\s*(?:to|in|into|as|->|-->|=>|=)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        unitHowManyPattern = rx(
            #"^(?:how\s+many)\s+([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)\s+(?:in|are\s+in|are\s+there\s+in)\s+([+-]?[0-9]*\.?[0-9]+)\s*([a-zA-Z°µ'\"/²³0-9]+(?:\s+[a-zA-Z°µ'\"/²³0-9]+)?)$"#
        )
        humanTimespanPattern = rx(
            #"^([0-9.]+)\s*([a-zA-Z]+)\s+(?:in|to|as)\s+(?:timespan|human\s+readable|human)$"#)

        // Design Units
        designUnitPattern = rx(
            #"^([0-9.]+)\s*(px|pt|in|inch|inches|cm|mm|rem|em)\s+(?:in|to)\s+(px|pt|in|inch|inches|cm|mm|rem|em)(?:\s+(?:at|@)\s+([0-9.]+)\s*(?:ppi|dpi))?$"#
        )

        // World Clock
        timeInCityPattern = rx(#"^time\s+(?:in|at|for)\s+(.+)$"#)
        crossCityTimePattern = rx(
            #"^(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2})\s+([a-zA-Z\s]+?)\s+(?:in|to|at)\s+([a-zA-Z\s]+)$"#
        )
        timeDiffPattern = rx(#"^(?:time\s+diff|diff|timezone\s+diff)\s+(.+)$"#)
        timeProjectionPattern = rx(
            #"^time\s+(?:in\s+)?([+-]?[0-9.]+)\s+hours?(?:\s+(?:in|at)\s+(.+))?$"#)

        // Date & Time
        dateMathPattern = rx(
            #"^([a-zA-Z0-9\s,\/]+?)\s*([\+\-])\s*(\d+)\s*(days?|weeks?|months?|years?|d|w|m|y)?$"#)
        timeMathPattern = rx(
            #"^(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2})\s*([\+\-])\s*(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m)?$"#
        )
        dateCountdownPattern = rx(
            #"^(?:(?:how\s+many\s+)?(?:days|weeks|months)\s+(?:until|to|left\s+in|since|from|in)|how\s+many\s+days\s+are\s+in)\s+(.+)$"#
        )
        timeBetweenDatesPattern = rx(#"^(?:time|days|duration)\s+between\s+(.+?)\s+and\s+(.+)$"#)
        iso8601Pattern = rx(
            #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?(?:\s+(?:in|to)\s+(?:local|local\s+time))?$"#
        )
        epochPattern = rx(
            #"^(?:epoch\s+(\d{10,13})|(\d{10,13})\s+(?:in\s+date|in\s+local\s+time|to\s+date|epoch)|now\s+in\s+epoch|epoch\s+now|today\s+in\s+epoch)$"#
        )

        // Quick Math
        mathBasicPattern = rx(#"^[\s\d\+\-\*\/\^\(\)\.\,\×\÷\%\s\bkKmMbBtT]+$"#)
        mathFunctionPattern = rx(
            #"^(?:sin|cos|tan|cot|sec|csc|asin|acos|atan|acot|asec|acsc|sinh|cosh|tanh|coth|sech|csch|asinh|acosh|atanh|sqrt|cbrt|abs|ceil|floor|round|log|ln|log10|log2|exp|pow|min|max|hypot|deg|rad)\s*\(.+\)$"#
        )
        mathPercentagePattern1 = rx(
            #"^[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?\s*%\s*(?:of|off)\s+[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?$"#
        )
        mathPercentagePattern2 = rx(
            #"^[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?\s*[\+\-]\s*[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?\s*%$"#)
        mathWordOpPattern = rx(
            #"^(?:(?:[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?)\s+(?:plus|minus|times|power|multiplied\s+by|divided\s+by|over|mod|modulo)\s+(?:[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?)|(?:half|quarter|square\s+root|cube\s+root)\s+of\s+(?:[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]?))$"#
        )
        mathFactorialPattern = rx(#"^\d+\s*!$"#)
        mathSuffixPattern = rx(#"^[+-]?[0-9]*\.?[0-9]+[kKmMbBtT]$"#)
        tipPattern = rx(#"^[+-]?[0-9]*\.?[0-9]+%\s+tip\s+on\s+.*$"#)
        ratioPattern = rx(#"^(?:ratio\s+of\s+.*|scale\s+.*)$"#)
        pctChangePattern = rx(
            #"^(?:%|percentage)\s+(?:change|increase|decrease|diff|difference)\s+.*$"#)
        workPlanningPattern = rx(
            #"^(?:workhours\s+in\s+\d{4}|workdays\s+in\s+\d{4}|\d+\s*h\s+in\s+workdays|\d+\s+workdays\s+in\s+hours)$"#
        )
    }

    // MARK: - Normalization / Preprocessing

    public func cleanQuery(_ query: String) -> (cleaned: String, hadPrefix: Bool) {
        var trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var hadPrefix = false

        trimmed = trailingQuestionPattern.stringByReplacingMatches(
            in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed), withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        for pattern in prefixPatterns {
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = pattern.firstMatch(in: trimmed, range: nsRange) {
                let prefixLen = match.range.length
                trimmed = String(trimmed.dropFirst(prefixLen)).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                hadPrefix = true
                break
            }
        }
        return (trimmed, hadPrefix)
    }

    // MARK: - Main Intent Detection

    public func detect(query: String) -> Intent? {
        let trimmedRaw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else { return nil }

        // False positive prevention
        if isExcludedSingleWordApp(trimmedRaw) {
            return nil
        }

        let (cleaned, hadPrefix) = cleanQuery(trimmedRaw)
        guard !cleaned.isEmpty else { return nil }

        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)

        // 1. World Clock & Timezone
        if let intent = detectWorldClock(cleaned, range: nsRange) {
            return intent
        }

        // 2. Date, Time & Timestamps
        if let intent = detectDateTime(cleaned, range: nsRange) {
            return intent
        }

        // 3. Design Units
        if let intent = detectDesignUnit(cleaned, range: nsRange) {
            return intent
        }

        // 4. Work Planning
        if workPlanningPattern.firstMatch(in: cleaned, range: nsRange) != nil {
            return .workPlanning(query: cleaned)
        }

        // 5. Human Timespan Breakdown
        if let m = humanTimespanPattern.firstMatch(in: cleaned, range: nsRange) {
            let ns = cleaned as NSString
            let amtStr = ns.substring(with: m.range(at: 1))
            let unitStr = ns.substring(with: m.range(at: 2))
            if let amt = Double(amtStr) {
                return .humanTimespan(amount: amt, unit: unitStr)
            }
        }

        // 6. Currency Conversions
        if let intent = detectCurrencyConversion(cleaned, range: nsRange, hadPrefix: hadPrefix) {
            return intent
        }

        // 7. Base Conversions
        if let intent = detectBaseConversion(cleaned, range: nsRange) {
            return intent
        }

        // 8. Unit Conversions
        if let intent = detectUnitConversion(cleaned, range: nsRange, hadPrefix: hadPrefix) {
            return intent
        }

        // 9. Quick Math, Tips, Ratios & Percentages
        if let intent = detectQuickMath(cleaned, range: nsRange, hadPrefix: hadPrefix) {
            return intent
        }

        return nil
    }

    // MARK: - World Clock Detection

    private func detectWorldClock(_ query: String, range: NSRange) -> Intent? {
        let ns = query as NSString

        // "time in 4 hours in SF" / "time in 4 hours"
        if let m = timeProjectionPattern.firstMatch(in: query, range: range) {
            let delayStr = ns.substring(with: m.range(at: 1))
            let cityStr: String? =
                m.range(at: 2).location != NSNotFound
                ? ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
            if let delay = Double(delayStr) {
                return .timeProjection(delayHours: delay, city: cityStr)
            }
        }

        // "time diff Paris" / "diff Tokyo"
        if let m = timeDiffPattern.firstMatch(in: query, range: range) {
            let city = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            return .timeDiff(city: city)
        }

        // "5pm ldn in sf" / "9am nyc to tokyo"
        if let m = crossCityTimePattern.firstMatch(in: query, range: range) {
            let timeStr = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let fromCity = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let toCity = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            // Ensure not a unit conversion (e.g. "10kg in lbs")
            if !isLikelyUnit(fromCity) && !isLikelyUnit(toCity) {
                return .crossCityTime(timeStr: timeStr, fromCity: fromCity, toCity: toCity)
            }
        }

        // "time in tokyo" / "time in JFK"
        if let m = timeInCityPattern.firstMatch(in: query, range: range) {
            let city = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !city.contains("4 hours") && !city.contains("hours") {
                return .timeInCity(city: city)
            }
        }

        return nil
    }

    // MARK: - Date & Time Detection

    private func detectDateTime(_ query: String, range: NSRange) -> Intent? {
        let ns = query as NSString
        let lower = query.lowercased()

        // ISO 8601
        if iso8601Pattern.firstMatch(in: query, range: range) != nil {
            return .isoOrEpoch(timestamp: query)
        }

        // Epoch
        if epochPattern.firstMatch(in: query, range: range) != nil {
            return .isoOrEpoch(timestamp: query)
        }

        // Countdown: "days until 31 Mar", "days left in quarter"
        if dateCountdownPattern.firstMatch(in: query, range: range) != nil {
            return .dateCountdown(query: query)
        }

        // "time between 1 Jan and 15 Mar"
        if let m = timeBetweenDatesPattern.firstMatch(in: query, range: range) {
            let d1 = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let d2 = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            return .timeBetweenDates(firstDate: d1, secondDate: d2)
        }

        // Relative Natural Language: "monday in 3 weeks", "next friday", "first day of next month", "next sunday", "3 weeks from now", "in 5 days", "5 days ago"
        if lower.contains("monday in") || lower.contains("tuesday in")
            || lower.contains("wednesday in") || lower.contains("thursday in")
            || lower.contains("friday in") || lower.contains("saturday in")
            || lower.contains("sunday in") || lower.hasPrefix("next ") || lower.hasPrefix("last ")
            || lower.contains("day of next month") || lower.contains("end of month")
            || lower.contains("day of this month") || lower.contains("end of year")
            || lower.contains("from now") || lower.contains("from today")
            || (lower.hasPrefix("in ")
                && (lower.contains("day") || lower.contains("week") || lower.contains("month")
                    || lower.contains("year")))
            || (lower.hasSuffix(" ago")
                && (lower.contains("day") || lower.contains("week") || lower.contains("month")
                    || lower.contains("year")))
        {
            return .dateCountdown(query: query)
        }

        // Time math: "3:45pm + 5", "10:30am - 45 min"
        if let m = timeMathPattern.firstMatch(in: query, range: range) {
            let baseTime = ns.substring(with: m.range(at: 1))
            let sign = ns.substring(with: m.range(at: 2))
            let valStr = ns.substring(with: m.range(at: 3))
            let unitStr =
                m.range(at: 4).location != NSNotFound
                ? ns.substring(with: m.range(at: 4)).lowercased() : "hours"
            if let val = Int(valStr) {
                let deltaMins: Int
                if unitStr.hasPrefix("m") && !unitStr.hasPrefix("mo") {
                    deltaMins = val
                } else {
                    deltaMins = val * 60
                }
                let signedDelta = sign == "-" ? -deltaMins : deltaMins
                return .timeMath(baseTime: baseTime, deltaMins: signedDelta)
            }
        }

        // Date math: "August 5 + 5", "today + 90 days", "Aug 5 - 10 days"
        if let m = dateMathPattern.firstMatch(in: query, range: range) {
            let baseDate = ns.substring(with: m.range(at: 1)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let sign = ns.substring(with: m.range(at: 2))
            let valStr = ns.substring(with: m.range(at: 3))
            let unitStr =
                m.range(at: 4).location != NSNotFound
                ? ns.substring(with: m.range(at: 4)).lowercased() : "days"
            if let val = Int(valStr) {
                // Ensure baseDate is not purely a number to avoid matching arithmetic like "10 + 5"
                if Double(baseDate) == nil
                    && (isMonthName(baseDate) || baseDate.lowercased() == "today"
                        || baseDate.lowercased() == "now" || baseDate.contains("/"))
                {
                    let signedVal = sign == "-" ? -val : val
                    return .dateMath(baseDate: baseDate, delta: signedVal, unit: unitStr)
                }
            }
        }

        return nil
    }

    private func isMonthName(_ str: String) -> Bool {
        let months = [
            "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
            "january", "february", "march", "april", "june", "july", "august", "september",
            "october", "november", "december",
        ]
        let lower = str.lowercased()
        return months.contains(where: { lower.contains($0) })
    }

    // MARK: - Design Unit Detection

    private func detectDesignUnit(_ query: String, range: NSRange) -> Intent? {
        let ns = query as NSString
        if let m = designUnitPattern.firstMatch(in: query, range: range) {
            let amtStr = ns.substring(with: m.range(at: 1))
            let fromUnit = ns.substring(with: m.range(at: 2))
            let toUnit = ns.substring(with: m.range(at: 3))
            var ppi: Double? = nil
            if m.range(at: 4).location != NSNotFound {
                ppi = Double(ns.substring(with: m.range(at: 4)))
            }
            if let amt = Double(amtStr) {
                return .designUnit(amount: amt, fromUnit: fromUnit, toUnit: toUnit, ppi: ppi)
            }
        }
        return nil
    }

    // MARK: - Currency Detection

    private func detectCurrencyConversion(_ query: String, range: NSRange, hadPrefix: Bool)
        -> Intent?
    {
        let ns = query as NSString

        // Pattern: "USD1K to EUR", "USD 1K in JPY", "USD1K"
        if let m = currencyPrefixedCodePattern.firstMatch(in: query, range: range) {
            let fromCode = ns.substring(with: m.range(at: 1))
            let amountStr = ns.substring(with: m.range(at: 2))
            let toRaw: String? =
                m.range(at: 3).location != NSNotFound
                ? ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                : nil

            if let amount = parseAmountWithSuffix(amountStr),
                let resolvedFrom = resolveCurrencyCode(fromCode)
            {
                let resolvedTo = (toRaw != nil ? resolveCurrencyCode(toRaw!) : nil) ?? "USD"
                return .currencyConversion(
                    amount: amount, fromCurrency: resolvedFrom, toCurrency: resolvedTo)
            }
        }

        // Pattern: "10K in EUR", "500 to JPY" (implicit from currency = USD)
        if let m = currencyImplicitFromPattern.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let toRaw = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = parseAmountWithSuffix(amountStr),
                let toCode = resolveCurrencyCode(toRaw),
                !isLikelyUnit(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: "USD", toCurrency: toCode)
            }
        }

        // Pattern: "$100 to eur", "€50 in usd"
        if let m = currencySymbolPattern1.firstMatch(in: query, range: range) {
            let symbol = ns.substring(with: m.range(at: 1))
            let amountStr = ns.substring(with: m.range(at: 2))
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = parseAmountWithSuffix(amountStr),
                let fromCode = resolveCurrencyCode(symbol),
                let toCode = resolveCurrencyCode(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }
        }

        // Pattern: "100$ in eur", "50€ to $"
        if let m = currencySymbolPattern2.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let symbol = ns.substring(with: m.range(at: 2))
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = parseAmountWithSuffix(amountStr),
                let fromCode = resolveCurrencyCode(symbol),
                let toCode = resolveCurrencyCode(toRaw)
            {
                return .currencyConversion(
                    amount: amount, fromCurrency: fromCode, toCurrency: toCode)
            }
        }

        // Pattern: "100 usd to eur", "19usd to jpy", "19usd jpy", "50 euros in dollars"
        if let m = currencyCodePattern.firstMatch(in: query, range: range) {
            let amountStr = ns.substring(with: m.range(at: 1))
            let fromRaw = ns.substring(with: m.range(at: 2)).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let toRaw = ns.substring(with: m.range(at: 3)).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if let amount = parseAmountWithSuffix(amountStr),
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

    public func parseAmountWithSuffix(_ str: String) -> Double? {
        var clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
        var multiplier: Double = 1.0
        if clean.hasSuffix("k") || clean.hasSuffix("K") {
            multiplier = 1_000
            clean.removeLast()
        } else if clean.hasSuffix("m") || clean.hasSuffix("M") {
            multiplier = 1_000_000
            clean.removeLast()
        } else if clean.hasSuffix("b") || clean.hasSuffix("B") {
            multiplier = 1_000_000_000
            clean.removeLast()
        } else if clean.hasSuffix("t") || clean.hasSuffix("T") {
            multiplier = 1_000_000_000_000
            clean.removeLast()
        }
        guard let num = Double(clean) else { return nil }
        return num * multiplier
    }

    // MARK: - Unit Detection

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
                let amount = parseAmountWithSuffix(amountStr)
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

    // MARK: - Base Conversions

    private func detectBaseConversion(_ query: String, range: NSRange) -> Intent? {
        let ns = query as NSString

        // "0xFF in dec", "0b1010 to hex"
        if let m = basePattern1.firstMatch(in: query, range: range) {
            let val = ns.substring(with: m.range(at: 1))
            let targetBaseStr = ns.substring(with: m.range(at: 2)).lowercased()
            let fromBase: Int =
                val.hasPrefix("0x")
                ? 16 : (val.hasPrefix("0b") ? 2 : (val.hasPrefix("0o") ? 8 : 10))
            let toBase = parseBase(targetBaseStr)
            return .baseConversion(value: val, fromBase: fromBase, toBase: toBase)
        }

        // "255 in hex", "10 to binary"
        if let m = basePattern2.firstMatch(in: query, range: range) {
            let val = ns.substring(with: m.range(at: 1))
            let targetBaseStr = ns.substring(with: m.range(at: 2)).lowercased()
            let toBase = parseBase(targetBaseStr)
            return .baseConversion(value: val, fromBase: 10, toBase: toBase)
        }

        // "hex 0xFF", "bin 1010"
        if let m = basePattern3.firstMatch(in: query, range: range) {
            let targetBaseStr = ns.substring(with: m.range(at: 1)).lowercased()
            let val = ns.substring(with: m.range(at: 2))
            let fromBase: Int =
                val.hasPrefix("0x")
                ? 16 : (val.hasPrefix("0b") ? 2 : (val.hasPrefix("0o") ? 8 : 10))
            let toBase = parseBase(targetBaseStr)
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

    // MARK: - Quick Math Detection

    private func detectQuickMath(_ query: String, range: NSRange, hadPrefix: Bool) -> Intent? {
        // Tips: "15% tip on 42"
        if tipPattern.firstMatch(in: query, range: range) != nil {
            return .tipCalculation(query: query)
        }

        // Ratios: "ratio of 3 to 5", "scale 16:9 to width 1920"
        if ratioPattern.firstMatch(in: query, range: range) != nil {
            return .ratioCalculation(query: query)
        }

        // Percentage Change: "% increase from 50 to 75"
        if pctChangePattern.firstMatch(in: query, range: range) != nil {
            return .percentageChange(query: query)
        }

        // Factorial: "5!"
        if mathFactorialPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Standalone Suffix: "10K", "1.5M", "2B"
        if mathSuffixPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Percentages: "50% of 200", "20% off 80"
        if mathPercentagePattern1.firstMatch(in: query, range: range) != nil
            || mathPercentagePattern2.firstMatch(in: query, range: range) != nil
        {
            return .mathExpression(expression: query)
        }

        // Word Operators: "10 plus 20", "half of 80"
        if mathWordOpPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Math Functions: "sqrt(144)", "cot(45 deg)", "sin(90)"
        if mathFunctionPattern.firstMatch(in: query, range: range) != nil {
            return .mathExpression(expression: query)
        }

        // Basic Math Expression: "2 + 2", "100 * (15 + 5)"
        if mathBasicPattern.firstMatch(in: query, range: range) != nil {
            // Must contain at least one mathematical operator
            if query.contains(where: { "+-*/^%×÷".contains($0) }) {
                return .mathExpression(expression: query)
            }
            if hadPrefix {
                return .mathExpression(expression: query)
            }
        }

        return nil
    }

    // MARK: - App Name Exclusions

    private func isExcludedSingleWordApp(_ query: String) -> Bool {
        let lower = query.lowercased()
        let knownApps: Set<String> = [
            "1password", "7-zip", "mp3rocket", "f1", "f12024", "f12025", "f12026",
            "office365", "microsoft365", "winrar", "7zip", "h2o", "3dsmax",
        ]
        return knownApps.contains(
            lower.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))
    }
}
