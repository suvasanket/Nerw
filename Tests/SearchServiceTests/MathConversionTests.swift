import Foundation
import NerwAction
import NerwBuiltin
import NerwSearchBackend

public func runMathConversionTests() {
    print("[Testing] Starting Math, Unit & Currency Conversion tests...")

    testMathConversionDetector()
    testUnitConversions()
    testCompoundUnitConversions()
    testCurrencyConversions()
    testCurrencyEngineEvaluation()
    testQuickMathEvaluation()
    testNumberBaseConversions()
    testQueryCategorizerMathAndConversionIntents()

    print("[Testing] All Math, Unit & Currency Conversion tests PASSED.")
}

func testMathConversionDetector() {
    let detector = MathConversionDetector.shared

    // 1. Unit conversions
    assert(detector.detect(query: "100 km to miles") != nil, "100 km to miles")
    assert(detector.detect(query: "100km to mi") != nil, "100km to mi")
    assert(detector.detect(query: "50 kg in lbs") != nil, "50 kg in lbs")
    assert(detector.detect(query: "32f to c") != nil, "32f to c")
    assert(detector.detect(query: "convert 100 km to miles") != nil, "convert 100 km to miles")
    assert(detector.detect(query: "what is 100 km in miles?") != nil, "what is 100 km in miles?")
    assert(detector.detect(query: "how many miles in 100 km") != nil, "how many miles in 100 km")
    assert(detector.detect(query: "5 ft 10 in to cm") != nil, "5 ft 10 in to cm")
    assert(detector.detect(query: "1/2 cup to ml") != nil, "1/2 cup to ml")

    // 2. Currency conversions
    assert(detector.detect(query: "19usd to jpy") != nil, "19usd to jpy")
    assert(detector.detect(query: "19usd jpy") != nil, "19usd jpy")
    assert(detector.detect(query: "19 usd to jpy") != nil, "19 usd to jpy")
    assert(detector.detect(query: "19 usd jpy") != nil, "19 usd jpy")
    assert(detector.detect(query: "$19 to jpy") != nil, "$19 to jpy")
    assert(detector.detect(query: "19$ in jpy") != nil, "19$ in jpy")
    assert(detector.detect(query: "$100 to eur") != nil, "$100 to eur")
    assert(detector.detect(query: "100$ in eur") != nil, "100$ in eur")
    assert(detector.detect(query: "100 usd to eur") != nil, "100 usd to eur")
    assert(detector.detect(query: "50 euros in dollars") != nil, "50 euros in dollars")
    assert(detector.detect(query: "convert $50 to inr") != nil, "convert $50 to inr")
    assert(
        detector.detect(query: "how much is 100 usd in eur?") != nil, "how much is 100 usd in eur?")

    // 3. Quick Math
    assert(detector.detect(query: "2 + 2") != nil, "2 + 2")
    assert(detector.detect(query: "100 * (15 + 5)") != nil, "100 * (15 + 5)")
    assert(detector.detect(query: "sqrt(144)") != nil, "sqrt(144)")
    assert(detector.detect(query: "sin(90 deg)") != nil, "sin(90 deg)")
    assert(detector.detect(query: "50% of 200") != nil, "50% of 200")
    assert(detector.detect(query: "10 plus 20") != nil, "10 plus 20")
    assert(detector.detect(query: "5!") != nil, "5!")
    assert(detector.detect(query: "0xFF in dec") != nil, "0xFF in dec")
    assert(detector.detect(query: "255 in hex") != nil, "255 in hex")

    // 4. Non-math queries (false positive avoidance)
    assert(detector.detect(query: "1Password") == nil, "1Password should not be math")
    assert(detector.detect(query: "7-Zip") == nil, "7-Zip should not be math")
    assert(detector.detect(query: "F1") == nil, "F1 should not be math")
    assert(detector.detect(query: "MP3 Rocket") == nil, "MP3 Rocket should not be math")
    assert(
        detector.detect(query: "how to install docker") == nil,
        "how to install docker should not be math")
    assert(detector.detect(query: "swiftui tutorial") == nil, "swiftui tutorial should not be math")

    print("  ✓ testMathConversionDetector passed.")
}

func testUnitConversions() {
    let engine = UnitConversionEngine.shared

    // Length
    let kmToMi = engine.convert(amount: 100, from: "km", to: "miles")
    guard let kmToMi = kmToMi else { fatalError("FAIL: 100 km to miles conversion failed") }
    assert(
        kmToMi.formattedValue.contains("mi"),
        "km to miles symbol mismatch: \(kmToMi.formattedValue)")
    assert(
        kmToMi.formattedValue.contains("62.1371"),
        "km to miles value mismatch: \(kmToMi.formattedValue)")

    let mToFt = engine.convert(amount: 10, from: "meters", to: "feet")
    guard let mToFt = mToFt else { fatalError("FAIL: 10 meters to feet conversion failed") }
    assert(mToFt.formattedValue.contains("ft"), "m to feet: \(mToFt.formattedValue)")

    let inToCm = engine.convert(amount: 1, from: "inch", to: "cm")
    guard let inToCm = inToCm else { fatalError("FAIL: 1 inch to cm conversion failed") }
    assert(inToCm.formattedValue.contains("2.54"), "1 in to cm value: \(inToCm.formattedValue)")

    // Mass
    let kgToLb = engine.convert(amount: 10, from: "kg", to: "lbs")
    guard let kgToLb = kgToLb else { fatalError("FAIL: 10 kg to lbs failed") }
    assert(kgToLb.formattedValue.contains("22.0462"), "10 kg to lbs: \(kgToLb.formattedValue)")

    let gToOz = engine.convert(amount: 500, from: "grams", to: "oz")
    guard let gToOz = gToOz else { fatalError("FAIL: 500 grams to oz failed") }
    assert(
        gToOz.formattedValue.contains("17.637") || gToOz.formattedValue.contains("17.6369")
            || gToOz.formattedValue.contains("17.63"),
        "500 g to oz: \(gToOz.formattedValue)")

    // Temperature
    let cToF = engine.convert(amount: 100, from: "c", to: "f")
    guard let cToF = cToF else { fatalError("FAIL: 100 c to f failed") }
    assert(cToF.formattedValue.contains("212"), "100 c to f: \(cToF.formattedValue)")

    let negCToF = engine.convert(amount: -40, from: "c", to: "f")
    guard let negCToF = negCToF else { fatalError("FAIL: -40 c to f failed") }
    assert(negCToF.formattedValue.contains("-40"), "-40 c to f: \(negCToF.formattedValue)")

    let cToK = engine.convert(amount: 0, from: "c", to: "k")
    guard let cToK = cToK else { fatalError("FAIL: 0 c to k failed") }
    assert(cToK.formattedValue.contains("273.15"), "0 c to k: \(cToK.formattedValue)")

    // Volume
    let lToGal = engine.convert(amount: 1, from: "liter", to: "gallons")
    guard let lToGal = lToGal else { fatalError("FAIL: 1 liter to gallons failed") }
    assert(lToGal.formattedValue.contains("0.2642"), "1 l to gal: \(lToGal.formattedValue)")

    let tbspToTsp = engine.convert(amount: 2, from: "tbsp", to: "tsp")
    guard let tbspToTsp = tbspToTsp else { fatalError("FAIL: 2 tbsp to tsp failed") }
    assert(tbspToTsp.formattedValue.contains("6"), "2 tbsp to tsp: \(tbspToTsp.formattedValue)")

    // Area
    let acreToSqft = engine.convert(amount: 1, from: "acre", to: "sqft")
    guard let acreToSqft = acreToSqft else { fatalError("FAIL: 1 acre to sqft failed") }
    assert(
        acreToSqft.formattedValue.contains("43,560") || acreToSqft.formattedValue.contains("43560"),
        "1 acre to sqft: \(acreToSqft.formattedValue)")

    // Data Storage
    let gbToMb = engine.convert(amount: 1, from: "GB", to: "MB")
    guard let gbToMb = gbToMb else { fatalError("FAIL: 1 GB to MB failed") }
    assert(
        gbToMb.formattedValue.contains("1,000") || gbToMb.formattedValue.contains("1000")
            || gbToMb.formattedValue.contains("1,024") || gbToMb.formattedValue.contains("1024"),
        "1 GB to MB: \(gbToMb.formattedValue)")

    let bitsToBytes = engine.convert(amount: 8, from: "bits", to: "bytes")
    guard let bitsToBytes = bitsToBytes else { fatalError("FAIL: 8 bits to bytes failed") }
    assert(
        bitsToBytes.formattedValue.contains("1"), "8 bits to bytes: \(bitsToBytes.formattedValue)")

    // Speed
    let mphToKmh = engine.convert(amount: 60, from: "mph", to: "km/h")
    guard let mphToKmh = mphToKmh else { fatalError("FAIL: 60 mph to km/h failed") }
    assert(
        mphToKmh.formattedValue.contains("96.5606"), "60 mph to km/h: \(mphToKmh.formattedValue)")

    // Time / Duration
    let hrToMin = engine.convert(amount: 2, from: "hours", to: "minutes")
    guard let hrToMin = hrToMin else { fatalError("FAIL: 2 hours to minutes failed") }
    assert(hrToMin.formattedValue.contains("120"), "2 hours to minutes: \(hrToMin.formattedValue)")

    let daysToHr = engine.convert(amount: 3, from: "days", to: "hours")
    guard let daysToHr = daysToHr else { fatalError("FAIL: 3 days to hours failed") }
    assert(daysToHr.formattedValue.contains("72"), "3 days to hours: \(daysToHr.formattedValue)")

    let wkToDays = engine.convert(amount: 2, from: "weeks", to: "days")
    guard let wkToDays = wkToDays else { fatalError("FAIL: 2 weeks to days failed") }
    assert(wkToDays.formattedValue.contains("14"), "2 weeks to days: \(wkToDays.formattedValue)")

    // Energy & Power
    let jToCal = engine.convert(amount: 1000, from: "joules", to: "calories")
    guard let jToCal = jToCal else { fatalError("FAIL: 1000 joules to calories failed") }
    assert(jToCal.formattedValue.contains("239"), "1000 J to cal: \(jToCal.formattedValue)")

    let kwToW = engine.convert(amount: 1, from: "kw", to: "watts")
    guard let kwToW = kwToW else { fatalError("FAIL: 1 kw to watts failed") }
    assert(
        kwToW.formattedValue.contains("1,000") || kwToW.formattedValue.contains("1000"),
        "1 kw to W: \(kwToW.formattedValue)")

    let hpToW = engine.convert(amount: 1, from: "hp", to: "watts")
    guard let hpToW = hpToW else { fatalError("FAIL: 1 hp to watts failed") }
    assert(hpToW.formattedValue.contains("745.7"), "1 hp to W: \(hpToW.formattedValue)")

    // Pressure
    let atmToPsi = engine.convert(amount: 1, from: "atm", to: "psi")
    guard let atmToPsi = atmToPsi else { fatalError("FAIL: 1 atm to psi failed") }
    assert(
        atmToPsi.formattedValue.contains("14.6959") || atmToPsi.formattedValue.contains("14.696"),
        "1 atm to psi: \(atmToPsi.formattedValue)")

    // Angle
    let degToRad = engine.convert(amount: 180, from: "deg", to: "rad")
    guard let degToRad = degToRad else { fatalError("FAIL: 180 deg to rad failed") }
    assert(
        degToRad.formattedValue.contains("3.1415") || degToRad.formattedValue.contains("3.1416"),
        "180 deg to rad: \(degToRad.formattedValue)")

    print("  ✓ testUnitConversions passed.")
}

func testCompoundUnitConversions() {
    let engine = UnitConversionEngine.shared

    // 5 ft 10 in to cm -> 5 * 12 + 10 = 70 in = 177.8 cm
    let ftInToCm = engine.convertCompound(
        firstAmount: 5, firstUnit: "ft", secondAmount: 10, secondUnit: "in", to: "cm")
    guard let ftInToCm = ftInToCm else { fatalError("FAIL: 5 ft 10 in to cm failed") }
    assert(
        ftInToCm.formattedValue.contains("177.8"), "5 ft 10 in to cm: \(ftInToCm.formattedValue)")

    // 1 hr 30 min to seconds -> 3600 + 1800 = 5400 s
    let hrMinToSec = engine.convertCompound(
        firstAmount: 1, firstUnit: "hr", secondAmount: 30, secondUnit: "min", to: "sec")
    guard let hrMinToSec = hrMinToSec else { fatalError("FAIL: 1 hr 30 min to sec failed") }
    assert(
        hrMinToSec.formattedValue.contains("5,400") || hrMinToSec.formattedValue.contains("5400"),
        "1 hr 30 min to sec: \(hrMinToSec.formattedValue)")

    print("  ✓ testCompoundUnitConversions passed.")
}

func testCurrencyConversions() {
    let detector = MathConversionDetector.shared

    assert(detector.resolveCurrencyCode("$") == "USD", "$ should be USD")
    assert(detector.resolveCurrencyCode("€") == "EUR", "€ should be EUR")
    assert(detector.resolveCurrencyCode("£") == "GBP", "£ should be GBP")
    assert(detector.resolveCurrencyCode("¥") == "JPY", "¥ should be JPY")
    assert(detector.resolveCurrencyCode("₹") == "INR", "₹ should be INR")
    assert(detector.resolveCurrencyCode("dollars") == "USD", "dollars should be USD")
    assert(detector.resolveCurrencyCode("euros") == "EUR", "euros should be EUR")
    assert(detector.resolveCurrencyCode("pounds") == "GBP", "pounds should be GBP")
    assert(detector.resolveCurrencyCode("yen") == "JPY", "yen should be JPY")
    assert(detector.resolveCurrencyCode("rupees") == "INR", "rupees should be INR")
    assert(detector.resolveCurrencyCode("cad") == "CAD", "cad should be CAD")

    print("  ✓ testCurrencyConversions passed.")
}

func testCurrencyEngineEvaluation() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        // 1. Direct Engine evaluation of "19 USD to JPY"
        let res1 = await CurrencyConversionEngine.shared.convert(amount: 19, from: "USD", to: "JPY")
        guard let res1 = res1 else {
            fatalError("FAIL: Currency conversion 19 USD to JPY returned nil")
        }
        assert(!res1.isError, "Currency conversion should not be error: \(res1.peekText)")
        assert(
            res1.formattedValue.contains("JPY"),
            "Formatted value should contain JPY: \(res1.formattedValue)")

        // 2. End-to-End Service evaluation for "19usd to jpy"
        let action1 = await MathConversionService.shared.evaluate(query: "19usd to jpy")
        guard let action1 = action1 else { fatalError("FAIL: 19usd to jpy returned nil action") }
        assert(action1.title.contains("JPY"), "Action title must contain JPY: \(action1.title)")

        // 3. Compact with space "19usd jpy"
        let action2 = await MathConversionService.shared.evaluate(query: "19usd jpy")
        guard let action2 = action2 else { fatalError("FAIL: 19usd jpy returned nil action") }
        assert(action2.title.contains("JPY"), "Action title must contain JPY: \(action2.title)")

        // 4. "$19 to jpy"
        let action3 = await MathConversionService.shared.evaluate(query: "$19 to jpy")
        guard let action3 = action3 else { fatalError("FAIL: $19 to jpy returned nil action") }
        assert(action3.title.contains("JPY"), "Action title must contain JPY: \(action3.title)")

        // 5. "100 usd to idr" (integer rate)
        let resIDR = await CurrencyConversionEngine.shared.convert(
            amount: 100, from: "USD", to: "IDR")
        guard let resIDR = resIDR else { fatalError("FAIL: USD to IDR returned nil") }
        assert(resIDR.formattedValue.contains("IDR"), "USD to IDR: \(resIDR.formattedValue)")

        semaphore.signal()
    }
    semaphore.wait()
    print("  ✓ testCurrencyEngineEvaluation passed.")
}

func testQuickMathEvaluation() {
    let math = MathEngine.shared

    // Basic arithmetic
    assert(math.evaluate(expression: "2 + 2")?.formattedValue == "4", "2 + 2")
    assert(math.evaluate(expression: "100 - 45")?.formattedValue == "55", "100 - 45")
    assert(math.evaluate(expression: "12 * 15")?.formattedValue == "180", "12 * 15")
    assert(math.evaluate(expression: "144 / 12")?.formattedValue == "12", "144 / 12")
    assert(
        math.evaluate(expression: "2^10")?.formattedValue == "1,024"
            || math.evaluate(expression: "2^10")?.formattedValue == "1024", "2^10")
    assert(math.evaluate(expression: "10 % 3")?.formattedValue == "1", "10 % 3")
    assert(math.evaluate(expression: "(10 + 5) * 4")?.formattedValue == "60", "(10 + 5) * 4")

    // Precision and floating points
    assert(
        math.evaluate(expression: "0.1 + 0.2")?.formattedValue == "0.3",
        "0.1 + 0.2 floating point fix")
    assert(math.evaluate(expression: "1.5 * 3.2")?.formattedValue == "4.8", "1.5 * 3.2")

    // Functions
    assert(math.evaluate(expression: "sqrt(144)")?.formattedValue == "12", "sqrt(144)")
    assert(math.evaluate(expression: "cbrt(27)")?.formattedValue == "3", "cbrt(27)")
    assert(math.evaluate(expression: "abs(-42)")?.formattedValue == "42", "abs(-42)")
    assert(math.evaluate(expression: "ceil(4.1)")?.formattedValue == "5", "ceil(4.1)")
    assert(math.evaluate(expression: "floor(4.9)")?.formattedValue == "4", "floor(4.9)")
    assert(math.evaluate(expression: "round(4.5)")?.formattedValue == "5", "round(4.5)")
    assert(math.evaluate(expression: "log10(1000)")?.formattedValue == "3", "log10(1000)")
    assert(math.evaluate(expression: "log2(64)")?.formattedValue == "6", "log2(64)")
    assert(math.evaluate(expression: "cos(0)")?.formattedValue == "1", "cos(0)")
    assert(math.evaluate(expression: "sin(90 deg)")?.formattedValue == "1", "sin(90 deg)")

    // Percentages
    assert(math.evaluate(expression: "50% of 200")?.formattedValue == "100", "50% of 200")
    assert(math.evaluate(expression: "20% off 80")?.formattedValue == "64", "20% off 80")
    assert(math.evaluate(expression: "100 + 20%")?.formattedValue == "120", "100 + 20%")
    assert(math.evaluate(expression: "100 - 15%")?.formattedValue == "85", "100 - 15%")
    assert(math.evaluate(expression: "25 * 20%")?.formattedValue == "5", "25 * 20%")
    assert(math.evaluate(expression: "50 as % of 200")?.formattedValue == "25%", "50 as % of 200")

    // Word Operators
    assert(math.evaluate(expression: "10 plus 20")?.formattedValue == "30", "10 plus 20")
    assert(math.evaluate(expression: "50 minus 15")?.formattedValue == "35", "50 minus 15")
    assert(math.evaluate(expression: "6 times 7")?.formattedValue == "42", "6 times 7")
    assert(
        math.evaluate(expression: "100 divided by 4")?.formattedValue == "25", "100 divided by 4")
    assert(math.evaluate(expression: "half of 80")?.formattedValue == "40", "half of 80")
    assert(math.evaluate(expression: "quarter of 200")?.formattedValue == "50", "quarter of 200")
    assert(
        math.evaluate(expression: "square root of 144")?.formattedValue == "12",
        "square root of 144")
    assert(math.evaluate(expression: "cube root of 27")?.formattedValue == "3", "cube root of 27")

    // Factorial
    assert(math.evaluate(expression: "5!")?.formattedValue == "120", "5!")
    assert(math.evaluate(expression: "0!")?.formattedValue == "1", "0!")

    print("  ✓ testQuickMathEvaluation passed.")
}

func testNumberBaseConversions() {
    let math = MathEngine.shared

    // Hex to Dec
    let hexToDec = math.convertBase(value: "0xFF", fromBase: 16, toBase: 10)
    assert(
        hexToDec?.formattedValue == "255",
        "0xFF to dec: \(String(describing: hexToDec?.formattedValue))")

    // Dec to Hex
    let decToHex = math.convertBase(value: "255", fromBase: 10, toBase: 16)
    assert(
        decToHex?.formattedValue == "0xFF",
        "255 to hex: \(String(describing: decToHex?.formattedValue))")

    // Bin to Dec
    let binToDec = math.convertBase(value: "0b1010", fromBase: 2, toBase: 10)
    assert(
        binToDec?.formattedValue == "10",
        "0b1010 to dec: \(String(describing: binToDec?.formattedValue))")

    // Dec to Bin
    let decToBin = math.convertBase(value: "10", fromBase: 10, toBase: 2)
    assert(
        decToBin?.formattedValue == "0b1010",
        "10 to bin: \(String(describing: decToBin?.formattedValue))")

    // Octal
    let octToDec = math.convertBase(value: "0o77", fromBase: 8, toBase: 10)
    assert(
        octToDec?.formattedValue == "63",
        "0o77 to dec: \(String(describing: octToDec?.formattedValue))")

    let decToOct = math.convertBase(value: "63", fromBase: 10, toBase: 8)
    assert(
        decToOct?.formattedValue == "0o77",
        "63 to oct: \(String(describing: decToOct?.formattedValue))")

    print("  ✓ testNumberBaseConversions passed.")
}

func testQueryCategorizerMathAndConversionIntents() {
    let categorizer = QueryCategorizer.shared

    // Math conversions
    let testQueries = [
        "100 km to miles",
        "100km to mi",
        "50 kg in lbs",
        "32f to c",
        "convert 100 km to miles",
        "what is 100 kg in lbs?",
        "how many miles in 100 km",
        "19usd to jpy",
        "19usd jpy",
        "19 usd to jpy",
        "19 usd jpy",
        "$19 to jpy",
        "19$ in jpy",
        "$100 to eur",
        "100$ in eur",
        "100 usd to eur",
        "50 euros in dollars",
        "2 + 2",
        "sqrt(144)",
        "50% of 200",
        "10 plus 20",
        "0xFF in dec",
        "255 in hex",
    ]

    for q in testQueries {
        let res = categorizer.classifySync(q)
        if res.category != .mathConversion {
            fatalError(
                "FAIL: Expected .mathConversion for query '\(q)', got '\(String(describing: res.category))'"
            )
        }
    }

    // Web searches (must not be intercepted by math)
    let webQueries = [
        "how to install docker on mac",
        "where to buy macbook pro",
        "best swiftui tutorials 2026",
        "weather in san francisco",
    ]

    for q in webQueries {
        let res = categorizer.classifySync(q)
        if res.category != .webSearch {
            fatalError(
                "FAIL: Expected .webSearch for query '\(q)', got '\(String(describing: res.category))'"
            )
        }
    }

    // URLs (must remain URLs)
    let urlQueries = [
        "github.com",
        "https://swift.org",
        "192.168.1.1",
        "localhost:3000",
    ]

    for q in urlQueries {
        let res = categorizer.classifySync(q)
        if res.category != .url {
            fatalError(
                "FAIL: Expected .url for query '\(q)', got '\(String(describing: res.category))'")
        }
    }

    // Apps / Non-math queries
    let appQueries = [
        "1Password",
        "7-Zip",
        "F1",
        "MP3 Rocket",
        "Visual Studio Code",
    ]

    for q in appQueries {
        let res = categorizer.classifySync(q)
        if res.category == .mathConversion {
            fatalError("FAIL: App query '\(q)' was falsely classified as .mathConversion")
        }
    }

    print("  ✓ testQueryCategorizerMathAndConversionIntents passed.")
}
