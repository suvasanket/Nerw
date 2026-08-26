import Foundation
import NerwAction
import NerwBuiltin
import NerwSearchBackend

public func runMathConversionTests() {
    print("[Testing] Starting Unified Math, Unit, Timezone, Date & Design Conversion tests...")

    testMathConversionDetector()
    testUnitConversions()
    testCompoundUnitConversions()
    testCurrencyConversions()
    testCurrencyEngineEvaluation()
    testQuickMathEvaluation()
    testAdvancedMathTrigTipsRatios()
    testNumberBaseConversions()
    testDateTimeEngine()
    testWorldClockEngine()
    testDesignUnitEngine()
    testTimespanAndWorkPlanning()
    testEndToEndServiceEvaluation()
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

    // 2. Currency conversions & shorthands
    assert(detector.detect(query: "19usd to jpy") != nil, "19usd to jpy")
    assert(detector.detect(query: "19usd jpy") != nil, "19usd jpy")
    assert(detector.detect(query: "19 usd to jpy") != nil, "19 usd to jpy")
    assert(detector.detect(query: "19 usd jpy") != nil, "19 usd jpy")
    assert(detector.detect(query: "$19 to jpy") != nil, "$19 to jpy")
    assert(detector.detect(query: "19$ in jpy") != nil, "19$ in jpy")
    assert(detector.detect(query: "$100 to eur") != nil, "$100 to eur")
    assert(detector.detect(query: "USD1K to EUR") != nil, "USD1K to EUR")
    assert(detector.detect(query: "10K in EUR") != nil, "10K in EUR")

    // 3. World Clock & Timezones
    assert(detector.detect(query: "time in tokyo") != nil, "time in tokyo")
    assert(detector.detect(query: "time in JFK") != nil, "time in JFK")
    assert(detector.detect(query: "time in São Paulo") != nil, "time in São Paulo")
    assert(detector.detect(query: "5pm ldn in sf") != nil, "5pm ldn in sf")
    assert(detector.detect(query: "9am nyc in tokyo") != nil, "9am nyc in tokyo")
    assert(detector.detect(query: "time diff Paris") != nil, "time diff Paris")
    assert(detector.detect(query: "diff Tokyo") != nil, "diff Tokyo")
    assert(detector.detect(query: "time in 4 hours") != nil, "time in 4 hours")
    assert(
        detector.detect(query: "time in 4 hours in San Francisco") != nil,
        "time in 4 hours in San Francisco")

    // 4. Date & Calendar Math
    assert(detector.detect(query: "August 5 + 5") != nil, "August 5 + 5")
    assert(detector.detect(query: "today + 90 days") != nil, "today + 90 days")
    assert(detector.detect(query: "3:45pm + 5") != nil, "3:45pm + 5")
    assert(detector.detect(query: "10:30am - 45 min") != nil, "10:30am - 45 min")
    assert(detector.detect(query: "monday in 3 weeks") != nil, "monday in 3 weeks")
    assert(detector.detect(query: "next friday") != nil, "next friday")
    assert(detector.detect(query: "days until 31 Mar") != nil, "days until 31 Mar")
    assert(detector.detect(query: "days left in quarter") != nil, "days left in quarter")
    assert(
        detector.detect(query: "time between 1 Jan and 15 Mar") != nil,
        "time between 1 Jan and 15 Mar")
    assert(detector.detect(query: "2024-03-15T14:30:00Z") != nil, "2024-03-15T14:30:00Z")
    assert(detector.detect(query: "1700000000 in date") != nil, "1700000000 in date")
    assert(detector.detect(query: "now in epoch") != nil, "now in epoch")

    // 5. Timespans & Work Planning
    assert(detector.detect(query: "145 mins to timespan") != nil, "145 mins to timespan")
    assert(detector.detect(query: "55h in workdays") != nil, "55h in workdays")
    assert(detector.detect(query: "workhours in 2026") != nil, "workhours in 2026")

    // 6. Design Units
    assert(detector.detect(query: "2 inches in px at 72 ppi") != nil, "2 inches in px at 72 ppi")
    assert(detector.detect(query: "16px in rem") != nil, "16px in rem")

    // 7. Quick Math, Tips, Ratios & Percentages
    assert(detector.detect(query: "2 + 2") != nil, "2 + 2")
    assert(detector.detect(query: "sqrt(625)") != nil, "sqrt(625)")
    assert(detector.detect(query: "cot(45 deg)") != nil, "cot(45 deg)")
    assert(detector.detect(query: "sec(60 deg)") != nil, "sec(60 deg)")
    assert(detector.detect(query: "2 power 10") != nil, "2 power 10")
    assert(detector.detect(query: "15% tip on 42") != nil, "15% tip on 42")
    assert(detector.detect(query: "ratio of 3 to 5") != nil, "ratio of 3 to 5")
    assert(detector.detect(query: "% increase from 50 to 75") != nil, "% increase from 50 to 75")

    // 8. Non-math queries (false positive avoidance)
    assert(detector.detect(query: "1Password") == nil, "1Password should not be math")
    assert(detector.detect(query: "7-Zip") == nil, "7-Zip should not be math")
    assert(detector.detect(query: "F1") == nil, "F1 should not be math")
    assert(
        detector.detect(query: "how to install docker") == nil,
        "how to install docker should not be math")
    assert(detector.detect(query: "swiftui tutorial") == nil, "swiftui tutorial should not be math")

    print("  ✓ testMathConversionDetector passed.")
}

func testUnitConversions() {
    let engine = UnitConversionEngine.shared

    let kmToMi = engine.convert(amount: 100, from: "km", to: "miles")
    guard let kmToMi = kmToMi else { fatalError("FAIL: 100 km to miles conversion failed") }
    assert(kmToMi.formattedValue.contains("62.1371"), "100 km to miles: \(kmToMi.formattedValue)")

    let cToF = engine.convert(amount: 0, from: "°c", to: "°f")
    guard let cToF = cToF else { fatalError("FAIL: 0 C to F conversion failed") }
    assert(cToF.formattedValue.contains("32"), "0 C to F: \(cToF.formattedValue)")

    let mbToGb = engine.convert(amount: 1024, from: "MB", to: "GB")
    guard let mbToGb = mbToGb else { fatalError("FAIL: 1024 MB to GB failed") }
    assert(
        mbToGb.formattedValue.contains("1.024") || mbToGb.formattedValue.contains("1"),
        "1024 MB to GB: \(mbToGb.formattedValue)")

    print("  ✓ testUnitConversions passed.")
}

func testCompoundUnitConversions() {
    let engine = UnitConversionEngine.shared
    let ftInToCm = engine.convertCompound(
        firstAmount: 5, firstUnit: "ft", secondAmount: 10, secondUnit: "in", to: "cm")
    guard let ftInToCm = ftInToCm else { fatalError("FAIL: 5 ft 10 in to cm failed") }
    assert(
        ftInToCm.formattedValue.contains("177.8"), "5 ft 10 in to cm: \(ftInToCm.formattedValue)")
    print("  ✓ testCompoundUnitConversions passed.")
}

func testCurrencyConversions() {
    let detector = MathConversionDetector.shared
    assert(detector.resolveCurrencyCode("$") == "USD")
    assert(detector.resolveCurrencyCode("€") == "EUR")
    assert(detector.resolveCurrencyCode("¥") == "JPY")
    assert(detector.resolveCurrencyCode("dollars") == "USD")
    print("  ✓ testCurrencyConversions passed.")
}

func testCurrencyEngineEvaluation() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        let res1 = await CurrencyConversionEngine.shared.convert(amount: 19, from: "USD", to: "JPY")
        guard let res1 = res1 else {
            fatalError("FAIL: Currency conversion 19 USD to JPY returned nil")
        }
        assert(!res1.isError)
        assert(res1.formattedValue.contains("JPY"))

        let resIDR = await CurrencyConversionEngine.shared.convert(
            amount: 100, from: "USD", to: "IDR")
        guard let resIDR = resIDR else { fatalError("FAIL: USD to IDR returned nil") }
        assert(resIDR.formattedValue.contains("IDR"))

        semaphore.signal()
    }
    semaphore.wait()
    print("  ✓ testCurrencyEngineEvaluation passed.")
}

func testQuickMathEvaluation() {
    let math = MathEngine.shared
    assert(math.evaluate(expression: "2 + 2")?.formattedValue == "4")
    assert(math.evaluate(expression: "100 - 45")?.formattedValue == "55")
    assert(math.evaluate(expression: "12 * 15")?.formattedValue == "180")
    assert(math.evaluate(expression: "144 / 12")?.formattedValue == "12")
    assert(
        math.evaluate(expression: "2 ^ 10")?.formattedValue == "1,024"
            || math.evaluate(expression: "2 ^ 10")?.formattedValue == "1024")
    assert(
        math.evaluate(expression: "2 power 10")?.formattedValue == "1,024"
            || math.evaluate(expression: "2 power 10")?.formattedValue == "1024")
    assert(math.evaluate(expression: "square root of 625")?.formattedValue == "25")
    assert(math.evaluate(expression: "50% of 200")?.formattedValue == "100")
    assert(math.evaluate(expression: "20% off 80")?.formattedValue == "64")
    print("  ✓ testQuickMathEvaluation passed.")
}

func testAdvancedMathTrigTipsRatios() {
    let math = MathEngine.shared

    // Reciprocal trig: cot(45 deg) = 1, sec(60 deg) = 2, csc(30 deg) = 2
    let cot45 = math.evaluate(expression: "cot(45 deg)")?.formattedValue
    assert(cot45 == "1", "cot(45 deg) should be 1, got \(String(describing: cot45))")

    let sec60 = math.evaluate(expression: "sec(60 deg)")?.formattedValue
    assert(sec60 == "2", "sec(60 deg) should be 2, got \(String(describing: sec60))")

    let csc30 = math.evaluate(expression: "csc(30 deg)")?.formattedValue
    assert(csc30 == "2", "csc(30 deg) should be 2, got \(String(describing: csc30))")

    // Number suffixes: 10K + 500 = 10,500, 2.5M * 4 = 10,000,000
    let suffixMath1 = math.evaluate(expression: "10K + 500")?.formattedValue
    assert(
        suffixMath1?.contains("10,500") == true || suffixMath1?.contains("10500") == true,
        "10K + 500: \(String(describing: suffixMath1))")

    let suffixMath2 = math.evaluate(expression: "2.5M * 4")?.formattedValue
    assert(
        suffixMath2?.contains("10,000,000") == true || suffixMath2?.contains("1,00,00,000") == true
            || suffixMath2?.contains("10000000") == true,
        "2.5M * 4: \(String(describing: suffixMath2))")

    // Tips: "15% tip on 42" -> Tip: $6.30, Total: $48.30
    let tip = math.solveTip("15% tip on 42")
    guard let tip = tip else { fatalError("FAIL: 15% tip on 42 failed") }
    assert(
        tip.formattedValue.contains("6.30") && tip.formattedValue.contains("48.30"),
        "Tip: \(tip.formattedValue)")

    // Ratios: "ratio of 3 to 5" -> 3:5
    let ratio = math.solveRatio("ratio of 3 to 5")
    guard let ratio = ratio else { fatalError("FAIL: ratio of 3 to 5 failed") }
    assert(ratio.formattedValue.contains("3:5"), "Ratio: \(ratio.formattedValue)")

    // Scale aspect ratio: "scale 16:9 to width 1920" -> 1920 x 1080
    let scale = math.solveRatio("scale 16:9 to width 1920")
    guard let scale = scale else { fatalError("FAIL: scale 16:9 to width 1920 failed") }
    assert(
        scale.formattedValue.contains("1,920") || scale.formattedValue.contains("1920"),
        "Scale: \(scale.formattedValue)")
    assert(
        scale.formattedValue.contains("1,080") || scale.formattedValue.contains("1080"),
        "Scale: \(scale.formattedValue)")

    // Percentage change: "% increase from 50 to 75" -> +50%
    let pctChange = math.solvePercentageChange("% increase from 50 to 75")
    guard let pctChange = pctChange else { fatalError("FAIL: % increase from 50 to 75 failed") }
    assert(pctChange.formattedValue.contains("50%"), "% change: \(pctChange.formattedValue)")

    print("  ✓ testAdvancedMathTrigTipsRatios passed.")
}

func testNumberBaseConversions() {
    let math = MathEngine.shared
    assert(math.convertBase(value: "0xFF", fromBase: 16, toBase: 10)?.formattedValue == "255")
    assert(math.convertBase(value: "255", fromBase: 10, toBase: 16)?.formattedValue == "0xFF")
    assert(math.convertBase(value: "0b1010", fromBase: 2, toBase: 10)?.formattedValue == "10")
    print("  ✓ testNumberBaseConversions passed.")
}

func testDateTimeEngine() {
    let dateEngine = DateTimeEngine.shared

    // Date math: "August 5 + 5"
    let dateMath = dateEngine.calculateDateOffset(baseDateStr: "August 5", delta: 5, unit: .day)
    guard let dateMath = dateMath else { fatalError("FAIL: August 5 + 5 failed") }
    assert(
        (dateMath.formattedValue.contains("August") || dateMath.formattedValue.contains("Aug"))
            && dateMath.formattedValue.contains("10"),
        "August 5 + 5: \(dateMath.formattedValue)")

    // Time math: "3:45pm + 5 hours" (300 mins) -> 8:45 PM
    let timeMath = dateEngine.calculateTimeOffset(baseTimeStr: "3:45pm", deltaMinutes: 300)
    guard let timeMath = timeMath else { fatalError("FAIL: 3:45pm + 5 hours failed") }
    assert(timeMath.formattedValue.contains("8:45"), "3:45pm + 5: \(timeMath.formattedValue)")

    // Relative date: "monday in 3 weeks"
    let relDate = dateEngine.parseRelativeDate(query: "monday in 3 weeks")
    assert(relDate != nil, "monday in 3 weeks should parse")

    // Countdown: "days left in quarter"
    let qCountdown = dateEngine.calculateCountdown(query: "days left in quarter")
    assert(qCountdown != nil, "days left in quarter should calculate")

    // ISO 8601: "2024-03-15T14:30:00Z"
    let iso = dateEngine.parseISO8601Timestamp("2024-03-15T14:30:00Z")
    guard let iso = iso else { fatalError("FAIL: ISO 8601 parsing failed") }
    assert(iso.formattedValue.contains("2024"), "ISO timestamp: \(iso.formattedValue)")

    // Epoch: "now in epoch"
    let epochNow = dateEngine.parseEpochTimestamp("now in epoch")
    assert(
        epochNow != nil && (Int64(epochNow!.formattedValue) ?? 0) > 1_700_000_000,
        "Epoch now should be valid timestamp")

    print("  ✓ testDateTimeEngine passed.")
}

func testWorldClockEngine() {
    let clock = WorldClockEngine.shared

    // 1. Time in City: "time in tokyo", "time in JFK", "time in São Paulo"
    let tokyoTime = clock.currentTime(in: "tokyo")
    guard let tokyoTime = tokyoTime else { fatalError("FAIL: time in tokyo failed") }
    assert(tokyoTime.formattedValue.contains("Tokyo"), "Tokyo: \(tokyoTime.formattedValue)")

    let jfkTime = clock.currentTime(in: "JFK")
    guard let jfkTime = jfkTime else { fatalError("FAIL: time in JFK failed") }
    assert(jfkTime.formattedValue.contains("New York"), "JFK: \(jfkTime.formattedValue)")

    let saoPauloTime = clock.currentTime(in: "são paulo")
    guard let saoPauloTime = saoPauloTime else { fatalError("FAIL: time in São Paulo failed") }
    assert(
        saoPauloTime.formattedValue.contains("São Paulo"),
        "São Paulo: \(saoPauloTime.formattedValue)")

    // 2. Cross-City Time: "5pm ldn in sf"
    let cross = clock.convertTime(timeStr: "5pm", from: "ldn", to: "sf")
    guard let cross = cross else { fatalError("FAIL: 5pm ldn in sf failed") }
    assert(
        (cross.formattedValue.contains("9:00") || cross.formattedValue.contains("09:00"))
            && cross.formattedValue.contains("San Francisco"),
        "5pm ldn in sf: \(cross.formattedValue)")

    // 3. Time diff: "time diff Paris"
    let diff = clock.timeDifference(with: "Paris")
    guard let diff = diff else { fatalError("FAIL: time diff Paris failed") }
    assert(diff.formattedValue.contains("Paris"), "Diff Paris: \(diff.formattedValue)")

    // 4. Time projection: "time in 4 hours in San Francisco"
    let proj = clock.projectTime(delayHours: 4, destination: "San Francisco")
    guard let proj = proj else { fatalError("FAIL: time in 4 hours in SF failed") }
    assert(proj.formattedValue.contains("San Francisco"), "Time projection: \(proj.formattedValue)")

    print("  ✓ testWorldClockEngine passed.")
}

func testDesignUnitEngine() {
    let design = DesignUnitEngine.shared

    // 2 inches in px at 72 ppi -> 144 px
    let inToPx72 = design.convert(amount: 2, from: "in", to: "px", ppi: 72)
    guard let inToPx72 = inToPx72 else { fatalError("FAIL: 2 inches in px at 72 ppi failed") }
    assert(inToPx72.formattedValue == "144 px", "2 in at 72 ppi: \(inToPx72.formattedValue)")

    // 16px in rem (at 16px base) -> 1 rem
    let pxToRem = design.convert(amount: 16, from: "px", to: "rem")
    guard let pxToRem = pxToRem else { fatalError("FAIL: 16px in rem failed") }
    assert(pxToRem.formattedValue == "1 rem", "16px in rem: \(pxToRem.formattedValue)")

    // 1.5rem in px -> 24 px
    let remToPx = design.convert(amount: 1.5, from: "rem", to: "px")
    guard let remToPx = remToPx else { fatalError("FAIL: 1.5rem in px failed") }
    assert(remToPx.formattedValue == "24 px", "1.5rem in px: \(remToPx.formattedValue)")

    print("  ✓ testDesignUnitEngine passed.")
}

func testTimespanAndWorkPlanning() {
    let units = UnitConversionEngine.shared

    // 145 mins to timespan -> 2h 25m
    let timespan = units.convertToTimespan(amount: 145, unitStr: "mins")
    guard let timespan = timespan else { fatalError("FAIL: 145 mins to timespan failed") }
    assert(timespan.formattedValue == "2h 25m", "145 mins timespan: \(timespan.formattedValue)")

    // 55h in workdays -> 6.875 workdays
    let workdays = units.calculateWorkPlanning(query: "55h in workdays")
    guard let workdays = workdays else { fatalError("FAIL: 55h in workdays failed") }
    assert(workdays.formattedValue.contains("6.875"), "55h in workdays: \(workdays.formattedValue)")

    // workhours in 2026 -> ~2,088 work hours
    let workhours = units.calculateWorkPlanning(query: "workhours in 2026")
    guard let workhours = workhours else { fatalError("FAIL: workhours in 2026 failed") }
    assert(
        workhours.formattedValue.contains("work hours"),
        "workhours in 2026: \(workhours.formattedValue)")

    print("  ✓ testTimespanAndWorkPlanning passed.")
}

func testEndToEndServiceEvaluation() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        let queries = [
            "19usd to jpy",
            "145 mins to timespan",
            "55h in workdays",
            "time in tokyo",
            "5pm ldn in sf",
            "time diff Paris",
            "2 inches in px at 72 ppi",
            "August 5 + 5",
            "15% tip on 42",
            "cot(45 deg)",
            "10K in EUR",
        ]

        for q in queries {
            let action = await MathConversionService.shared.evaluate(query: q)
            guard let action = action else {
                fatalError("FAIL: MathConversionService returned nil for '\(q)'")
            }
            assert(!action.title.isEmpty, "Action title for '\(q)' must not be empty")
            assert(action.category == .mathConversion, "Action category must be .mathConversion")
            assert(action.peek != nil, "Peek data for '\(q)' must not be nil")
        }

        semaphore.signal()
    }
    semaphore.wait()
    print("  ✓ testEndToEndServiceEvaluation passed.")
}

func testQueryCategorizerMathAndConversionIntents() {
    let categorizer = QueryCategorizer.shared

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
        "time in tokyo",
        "5pm ldn in sf",
        "time diff Paris",
        "August 5 + 5",
        "3:45pm + 5",
        "monday in 3 weeks",
        "days until 31 Mar",
        "145 mins to timespan",
        "55h in workdays",
        "2 inches in px at 72 ppi",
        "15% tip on 42",
        "ratio of 3 to 5",
        "cot(45 deg)",
        "2 + 2",
        "sqrt(625)",
        "2 power 10",
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
        "why is the sky blue in summer",
        "best restaurants in new york city",
        "who is the president of france",
        "what are the top movies of 2026",
    ]

    for q in webQueries {
        let res = categorizer.classifySync(q)
        if res.category != .webSearch {
            fatalError(
                "FAIL: Expected .webSearch for query '\(q)', got '\(String(describing: res.category))'"
            )
        }
    }

    print("  ✓ testQueryCategorizerMathAndConversionIntents passed.")
}
