import Foundation
import NerwAction

public final class UnitConversionEngine {
    public static let shared = UnitConversionEngine()

    public enum UnitCategory: String, Sendable {
        case length
        case mass
        case temperature
        case volume
        case area
        case dataStorage
        case speed
        case duration
        case energy
        case power
        case pressure
        case angle
        case fuelEfficiency
    }

    public struct ConversionResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String

        public init(formattedValue: String, peekText: String, subtitle: String = "Unit Conversion")
        {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
        }
    }

    // Extended Unit Duration for days, weeks, months, years
    public final class ExtendedUnitDuration: Dimension, @unchecked Sendable {
        public static let days = ExtendedUnitDuration(
            symbol: "d", converter: UnitConverterLinear(coefficient: 86400))
        public static let weeks = ExtendedUnitDuration(
            symbol: "wk", converter: UnitConverterLinear(coefficient: 604800))
        public static let months = ExtendedUnitDuration(
            symbol: "mo", converter: UnitConverterLinear(coefficient: 2_629_800))
        public static let years = ExtendedUnitDuration(
            symbol: "yr", converter: UnitConverterLinear(coefficient: 31_557_600))
        public static let seconds = ExtendedUnitDuration(
            symbol: "s", converter: UnitConverterLinear(coefficient: 1))
        public static let minutes = ExtendedUnitDuration(
            symbol: "min", converter: UnitConverterLinear(coefficient: 60))
        public static let hours = ExtendedUnitDuration(
            symbol: "hr", converter: UnitConverterLinear(coefficient: 3600))
        public static let milliseconds = ExtendedUnitDuration(
            symbol: "ms", converter: UnitConverterLinear(coefficient: 0.001))
        public static let microseconds = ExtendedUnitDuration(
            symbol: "µs", converter: UnitConverterLinear(coefficient: 0.000001))
        public static let nanoseconds = ExtendedUnitDuration(
            symbol: "ns", converter: UnitConverterLinear(coefficient: 0.000000001))

        public override class func baseUnit() -> ExtendedUnitDuration {
            return ExtendedUnitDuration.seconds
        }
    }

    // Extended Unit Energy for Wh, kWh, BTU
    public final class ExtendedUnitEnergy: Dimension, @unchecked Sendable {
        public static let joules = ExtendedUnitEnergy(
            symbol: "J", converter: UnitConverterLinear(coefficient: 1))
        public static let kilojoules = ExtendedUnitEnergy(
            symbol: "kJ", converter: UnitConverterLinear(coefficient: 1000))
        public static let calories = ExtendedUnitEnergy(
            symbol: "cal", converter: UnitConverterLinear(coefficient: 4.184))
        public static let kilocalories = ExtendedUnitEnergy(
            symbol: "kcal", converter: UnitConverterLinear(coefficient: 4184))
        public static let wattHours = ExtendedUnitEnergy(
            symbol: "Wh", converter: UnitConverterLinear(coefficient: 3600))
        public static let kilowattHours = ExtendedUnitEnergy(
            symbol: "kWh", converter: UnitConverterLinear(coefficient: 3_600_000))
        public static let btu = ExtendedUnitEnergy(
            symbol: "BTU", converter: UnitConverterLinear(coefficient: 1055.056))

        public override class func baseUnit() -> ExtendedUnitEnergy {
            return ExtendedUnitEnergy.joules
        }
    }

    // Unit definition entry
    private struct UnitEntry {
        let category: UnitCategory
        let dimension: Dimension
        let symbol: String
        let fullSingular: String
        let fullPlural: String
    }

    private var unitDictionary: [String: UnitEntry] = [:]

    private init() {
        registerAllUnits()
    }

    // MARK: - Unit Registry

    private func register(
        category: UnitCategory,
        dimension: Dimension,
        symbol: String,
        singular: String,
        plural: String,
        aliases: [String]
    ) {
        let entry = UnitEntry(
            category: category,
            dimension: dimension,
            symbol: symbol,
            fullSingular: singular,
            fullPlural: plural
        )
        unitDictionary[symbol.lowercased()] = entry
        unitDictionary[singular.lowercased()] = entry
        unitDictionary[plural.lowercased()] = entry
        for alias in aliases {
            unitDictionary[alias.lowercased()] = entry
            unitDictionary[alias.lowercased().replacingOccurrences(of: " ", with: "")] = entry
        }
    }

    private func registerAllUnits() {
        // ── 1. Length ──────────────────────────────────────────────────
        register(
            category: .length, dimension: UnitLength.nanometers, symbol: "nm",
            singular: "nanometer", plural: "nanometers", aliases: ["nanometre", "nanometres"])
        register(
            category: .length, dimension: UnitLength.micrometers, symbol: "µm",
            singular: "micrometer", plural: "micrometers",
            aliases: ["um", "micron", "microns", "micrometre", "micrometres"])
        register(
            category: .length, dimension: UnitLength.millimeters, symbol: "mm",
            singular: "millimeter", plural: "millimeters", aliases: ["millimetre", "millimetres"])
        register(
            category: .length, dimension: UnitLength.centimeters, symbol: "cm",
            singular: "centimeter", plural: "centimeters", aliases: ["centimetre", "centimetres"])
        register(
            category: .length, dimension: UnitLength.decimeters, symbol: "dm",
            singular: "decimeter", plural: "decimeters", aliases: ["decimetre", "decimetres"])
        register(
            category: .length, dimension: UnitLength.meters, symbol: "m", singular: "meter",
            plural: "meters", aliases: ["metre", "metres"])
        register(
            category: .length, dimension: UnitLength.decameters, symbol: "dam",
            singular: "decameter", plural: "decameters", aliases: ["decametre", "decametres"])
        register(
            category: .length, dimension: UnitLength.hectometers, symbol: "hm",
            singular: "hectometer", plural: "hectometers", aliases: ["hectometre", "hectometres"])
        register(
            category: .length, dimension: UnitLength.kilometers, symbol: "km",
            singular: "kilometer", plural: "kilometers", aliases: ["kilometre", "kilometres"])
        register(
            category: .length, dimension: UnitLength.megameters, symbol: "Mm",
            singular: "megameter", plural: "megameters", aliases: ["megametre", "megametres"])
        register(
            category: .length, dimension: UnitLength.inches, symbol: "in", singular: "inch",
            plural: "inches", aliases: ["\""])
        register(
            category: .length, dimension: UnitLength.feet, symbol: "ft", singular: "foot",
            plural: "feet", aliases: ["'"])
        register(
            category: .length, dimension: UnitLength.yards, symbol: "yd", singular: "yard",
            plural: "yards", aliases: ["yds"])
        register(
            category: .length, dimension: UnitLength.miles, symbol: "mi", singular: "mile",
            plural: "miles", aliases: [])
        register(
            category: .length, dimension: UnitLength.nauticalMiles, symbol: "nmi",
            singular: "nautical mile", plural: "nautical miles",
            aliases: ["naut mi", "nauticalmile", "nauticalmiles"])
        register(
            category: .length, dimension: UnitLength.lightyears, symbol: "ly",
            singular: "light year", plural: "light years", aliases: ["lightyear", "lightyears"])
        register(
            category: .length, dimension: UnitLength.astronomicalUnits, symbol: "au",
            singular: "astronomical unit", plural: "astronomical units",
            aliases: ["astronomicalunit", "astronomicalunits"])
        register(
            category: .length, dimension: UnitLength.parsecs, symbol: "pc", singular: "parsec",
            plural: "parsecs", aliases: [])
        register(
            category: .length, dimension: UnitLength.furlongs, symbol: "fur", singular: "furlong",
            plural: "furlongs", aliases: [])
        register(
            category: .length, dimension: UnitLength.fathoms, symbol: "fth", singular: "fathom",
            plural: "fathoms", aliases: [])

        // ── 2. Mass / Weight ───────────────────────────────────────────
        register(
            category: .mass, dimension: UnitMass.picograms, symbol: "pg", singular: "picogram",
            plural: "picograms", aliases: [])
        register(
            category: .mass, dimension: UnitMass.nanograms, symbol: "ng", singular: "nanogram",
            plural: "nanograms", aliases: [])
        register(
            category: .mass, dimension: UnitMass.micrograms, symbol: "µg", singular: "microgram",
            plural: "micrograms", aliases: ["ug", "mcg"])
        register(
            category: .mass, dimension: UnitMass.milligrams, symbol: "mg", singular: "milligram",
            plural: "milligrams", aliases: [])
        register(
            category: .mass, dimension: UnitMass.centigrams, symbol: "cg", singular: "centigram",
            plural: "centigrams", aliases: [])
        register(
            category: .mass, dimension: UnitMass.decigrams, symbol: "dg", singular: "decigram",
            plural: "decigrams", aliases: [])
        register(
            category: .mass, dimension: UnitMass.grams, symbol: "g", singular: "gram",
            plural: "grams", aliases: [])
        register(
            category: .mass, dimension: UnitMass.kilograms, symbol: "kg", singular: "kilogram",
            plural: "kilograms", aliases: ["kilo", "kilos"])
        register(
            category: .mass, dimension: UnitMass.metricTons, symbol: "t", singular: "tonne",
            plural: "tonnes", aliases: ["metric ton", "metric tons", "metricton", "metrictons"])
        register(
            category: .mass, dimension: UnitMass.ounces, symbol: "oz", singular: "ounce",
            plural: "ounces", aliases: [])
        register(
            category: .mass, dimension: UnitMass.pounds, symbol: "lb", singular: "pound",
            plural: "pounds", aliases: ["lbs"])
        register(
            category: .mass, dimension: UnitMass.stones, symbol: "st", singular: "stone",
            plural: "stones", aliases: [])
        register(
            category: .mass, dimension: UnitMass.shortTons, symbol: "ton", singular: "short ton",
            plural: "short tons", aliases: ["tons", "us ton", "us tons"])
        register(
            category: .mass, dimension: UnitMass.carats, symbol: "ct", singular: "carat",
            plural: "carats", aliases: [])
        register(
            category: .mass, dimension: UnitMass.ouncesTroy, symbol: "ozt", singular: "troy ounce",
            plural: "troy ounces", aliases: ["oz t"])
        register(
            category: .mass, dimension: UnitMass.slugs, symbol: "slug", singular: "slug",
            plural: "slugs", aliases: [])

        // ── 3. Temperature ─────────────────────────────────────────────
        register(
            category: .temperature, dimension: UnitTemperature.celsius, symbol: "°C",
            singular: "celsius", plural: "celsius",
            aliases: ["c", "°c", "centigrade", "deg c", "degree c", "degrees c", "degc"])
        register(
            category: .temperature, dimension: UnitTemperature.fahrenheit, symbol: "°F",
            singular: "fahrenheit", plural: "fahrenheit",
            aliases: ["f", "°f", "deg f", "degree f", "degrees f", "degf"])
        register(
            category: .temperature, dimension: UnitTemperature.kelvin, symbol: "K",
            singular: "kelvin", plural: "kelvin",
            aliases: ["k", "°k", "deg k", "degree k", "degrees k", "degk"])

        // ── 4. Volume / Liquid Capacity ────────────────────────────────
        register(
            category: .volume, dimension: UnitVolume.milliliters, symbol: "ml",
            singular: "milliliter", plural: "milliliters",
            aliases: ["millilitre", "millilitres", "cc"])
        register(
            category: .volume, dimension: UnitVolume.centiliters, symbol: "cl",
            singular: "centiliter", plural: "centiliters", aliases: ["centilitre", "centilitres"])
        register(
            category: .volume, dimension: UnitVolume.deciliters, symbol: "dl",
            singular: "deciliter", plural: "deciliters", aliases: ["decilitre", "decilitres"])
        register(
            category: .volume, dimension: UnitVolume.liters, symbol: "l", singular: "liter",
            plural: "liters", aliases: ["litre", "litres"])
        register(
            category: .volume, dimension: UnitVolume.kiloliters, symbol: "kl",
            singular: "kiloliter", plural: "kiloliters", aliases: ["kilolitre", "kilolitres"])
        register(
            category: .volume, dimension: UnitVolume.megaliters, symbol: "ML",
            singular: "megaliter", plural: "megaliters", aliases: ["megalitre", "megalitres"])
        register(
            category: .volume, dimension: UnitVolume.cubicMeters, symbol: "m³",
            singular: "cubic meter", plural: "cubic meters",
            aliases: ["m3", "cubic metre", "cubic metres", "cubicmeter", "cubicmeters"])
        register(
            category: .volume, dimension: UnitVolume.cubicCentimeters, symbol: "cm³",
            singular: "cubic centimeter", plural: "cubic centimeters",
            aliases: [
                "cm3", "cubic centimetre", "cubic centimetres", "cubiccentimeter",
                "cubiccentimeters",
            ])
        register(
            category: .volume, dimension: UnitVolume.cubicMillimeters, symbol: "mm³",
            singular: "cubic millimeter", plural: "cubic millimeters",
            aliases: ["mm3", "cubic millimetre", "cubic millimetres"])
        register(
            category: .volume, dimension: UnitVolume.cubicKilometers, symbol: "km³",
            singular: "cubic kilometer", plural: "cubic kilometers",
            aliases: ["km3", "cubic kilometre", "cubic kilometres"])
        register(
            category: .volume, dimension: UnitVolume.teaspoons, symbol: "tsp", singular: "teaspoon",
            plural: "teaspoons", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.tablespoons, symbol: "tbsp",
            singular: "tablespoon", plural: "tablespoons", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.fluidOunces, symbol: "fl oz",
            singular: "fluid ounce", plural: "fluid ounces",
            aliases: ["floz", "fluidounce", "fluidounces", "fl. oz."])
        register(
            category: .volume, dimension: UnitVolume.cups, symbol: "cup", singular: "cup",
            plural: "cups", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.pints, symbol: "pt", singular: "pint",
            plural: "pints", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.quarts, symbol: "qt", singular: "quart",
            plural: "quarts", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.gallons, symbol: "gal", singular: "gallon",
            plural: "gallons", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.imperialFluidOunces, symbol: "imp fl oz",
            singular: "imperial fluid ounce", plural: "imperial fluid ounces", aliases: ["imp floz"]
        )
        register(
            category: .volume, dimension: UnitVolume.imperialPints, symbol: "imp pt",
            singular: "imperial pint", plural: "imperial pints", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.imperialQuarts, symbol: "imp qt",
            singular: "imperial quart", plural: "imperial quarts", aliases: [])
        register(
            category: .volume, dimension: UnitVolume.imperialGallons, symbol: "imp gal",
            singular: "imperial gallon", plural: "imperial gallons",
            aliases: ["imperial gallon", "imperial gallons"])
        register(
            category: .volume, dimension: UnitVolume.cubicInches, symbol: "in³",
            singular: "cubic inch", plural: "cubic inches",
            aliases: ["in3", "cubicinch", "cubicinches"])
        register(
            category: .volume, dimension: UnitVolume.cubicFeet, symbol: "ft³",
            singular: "cubic foot", plural: "cubic feet",
            aliases: ["ft3", "cubicfoot", "cubicfeet"])
        register(
            category: .volume, dimension: UnitVolume.cubicYards, symbol: "yd³",
            singular: "cubic yard", plural: "cubic yards",
            aliases: ["yd3", "cubicyard", "cubicyards"])

        // ── 5. Area ────────────────────────────────────────────────────
        register(
            category: .area, dimension: UnitArea.squareMillimeters, symbol: "mm²",
            singular: "square millimeter", plural: "square millimeters",
            aliases: ["sqmm", "mm2", "square millimetre", "square millimetres"])
        register(
            category: .area, dimension: UnitArea.squareCentimeters, symbol: "cm²",
            singular: "square centimeter", plural: "square centimeters",
            aliases: ["sqcm", "cm2", "square centimetre", "square centimetres"])
        register(
            category: .area, dimension: UnitArea.squareMeters, symbol: "m²",
            singular: "square meter", plural: "square meters",
            aliases: [
                "sqm", "sq m", "m2", "square metre", "square metres", "squaremeter", "squaremeters",
            ])
        register(
            category: .area, dimension: UnitArea.squareKilometers, symbol: "km²",
            singular: "square kilometer", plural: "square kilometers",
            aliases: [
                "sqkm", "sq km", "km2", "square kilometre", "square kilometres", "squarekilometer",
                "squarekilometers",
            ])
        register(
            category: .area, dimension: UnitArea.hectares, symbol: "ha", singular: "hectare",
            plural: "hectares", aliases: [])
        register(
            category: .area, dimension: UnitArea.ares, symbol: "a", singular: "are", plural: "ares",
            aliases: [])
        register(
            category: .area, dimension: UnitArea.squareInches, symbol: "in²",
            singular: "square inch", plural: "square inches",
            aliases: ["sqin", "sq in", "in2", "squareinch", "squareinches"])
        register(
            category: .area, dimension: UnitArea.squareFeet, symbol: "ft²", singular: "square foot",
            plural: "square feet", aliases: ["sqft", "sq ft", "ft2", "squarefoot", "squarefeet"])
        register(
            category: .area, dimension: UnitArea.squareYards, symbol: "yd²",
            singular: "square yard", plural: "square yards",
            aliases: ["sqyd", "sq yd", "yd2", "squareyard", "squareyards"])
        register(
            category: .area, dimension: UnitArea.squareMiles, symbol: "mi²",
            singular: "square mile", plural: "square miles",
            aliases: ["sqmi", "sq mi", "mi2", "squaremile", "squaremiles"])
        register(
            category: .area, dimension: UnitArea.acres, symbol: "ac", singular: "acre",
            plural: "acres", aliases: ["acre", "acres"])

        // ── 6. Digital Information / Data Storage ──────────────────────
        register(
            category: .dataStorage, dimension: UnitInformationStorage.bits, symbol: "bit",
            singular: "bit", plural: "bits", aliases: ["b"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.bytes, symbol: "B",
            singular: "byte", plural: "bytes", aliases: ["byte", "bytes"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.kilobits, symbol: "kbit",
            singular: "kilobit", plural: "kilobits", aliases: ["kb", "kbps"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.kilobytes, symbol: "kB",
            singular: "kilobyte", plural: "kilobytes", aliases: ["kb_byte", "KB"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.megabits, symbol: "Mbit",
            singular: "megabit", plural: "megabits", aliases: ["mb_bit", "mbps"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.megabytes, symbol: "MB",
            singular: "megabyte", plural: "megabytes", aliases: ["mb", "MB"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.gigabits, symbol: "Gbit",
            singular: "gigabit", plural: "gigabits", aliases: ["gb_bit", "gbps"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.gigabytes, symbol: "GB",
            singular: "gigabyte", plural: "gigabytes", aliases: ["gb", "GB"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.terabits, symbol: "Tbit",
            singular: "terabit", plural: "terabits", aliases: ["tb_bit", "tbps"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.terabytes, symbol: "TB",
            singular: "terabyte", plural: "terabytes", aliases: ["tb", "TB"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.petabits, symbol: "Pbit",
            singular: "petabit", plural: "petabits", aliases: ["pb_bit"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.petabytes, symbol: "PB",
            singular: "petabyte", plural: "petabytes", aliases: ["pb", "PB"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.kibibytes, symbol: "KiB",
            singular: "kibibyte", plural: "kibibytes", aliases: ["kib"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.mebibytes, symbol: "MiB",
            singular: "mebibyte", plural: "mebibytes", aliases: ["mib"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.gibibytes, symbol: "GiB",
            singular: "gibibyte", plural: "gibibytes", aliases: ["gib"])
        register(
            category: .dataStorage, dimension: UnitInformationStorage.tebibytes, symbol: "TiB",
            singular: "tebibyte", plural: "tebibytes", aliases: ["tib"])

        // ── 7. Speed ───────────────────────────────────────────────────
        register(
            category: .speed, dimension: UnitSpeed.metersPerSecond, symbol: "m/s",
            singular: "meter per second", plural: "meters per second",
            aliases: ["mps", "metre per second", "metres per second"])
        register(
            category: .speed, dimension: UnitSpeed.kilometersPerHour, symbol: "km/h",
            singular: "kilometer per hour", plural: "kilometers per hour",
            aliases: ["kmh", "kph", "kmph", "kilometre per hour", "kilometres per hour"])
        register(
            category: .speed, dimension: UnitSpeed.milesPerHour, symbol: "mph",
            singular: "mile per hour", plural: "miles per hour", aliases: ["mi/h"])
        register(
            category: .speed, dimension: UnitSpeed.knots, symbol: "kn", singular: "knot",
            plural: "knots", aliases: ["kt", "kts"])

        // ── 8. Time / Duration ─────────────────────────────────────────
        register(
            category: .duration, dimension: ExtendedUnitDuration.nanoseconds, symbol: "ns",
            singular: "nanosecond", plural: "nanoseconds", aliases: [])
        register(
            category: .duration, dimension: ExtendedUnitDuration.microseconds, symbol: "µs",
            singular: "microsecond", plural: "microseconds", aliases: ["us"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.milliseconds, symbol: "ms",
            singular: "millisecond", plural: "milliseconds", aliases: [])
        register(
            category: .duration, dimension: ExtendedUnitDuration.seconds, symbol: "s",
            singular: "second", plural: "seconds", aliases: ["sec", "secs"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.minutes, symbol: "min",
            singular: "minute", plural: "minutes", aliases: ["mins", "m"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.hours, symbol: "hr",
            singular: "hour", plural: "hours", aliases: ["hrs", "h"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.days, symbol: "d", singular: "day",
            plural: "days", aliases: ["day", "days"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.weeks, symbol: "wk",
            singular: "week", plural: "weeks", aliases: ["wks", "week", "weeks"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.months, symbol: "mo",
            singular: "month", plural: "months", aliases: ["mos", "month", "months"])
        register(
            category: .duration, dimension: ExtendedUnitDuration.years, symbol: "yr",
            singular: "year", plural: "years", aliases: ["yrs", "year", "years"])

        // ── 9. Energy ──────────────────────────────────────────────────
        register(
            category: .energy, dimension: ExtendedUnitEnergy.joules, symbol: "J", singular: "joule",
            plural: "joules", aliases: ["j"])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.kilojoules, symbol: "kJ",
            singular: "kilojoule", plural: "kilojoules", aliases: ["kj"])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.calories, symbol: "cal",
            singular: "calorie", plural: "calories", aliases: [])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.kilocalories, symbol: "kcal",
            singular: "kilocalorie", plural: "kilocalories", aliases: ["cal_large"])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.wattHours, symbol: "Wh",
            singular: "watt-hour", plural: "watt-hours", aliases: ["wh", "watt hour", "watt hours"])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.kilowattHours, symbol: "kWh",
            singular: "kilowatt-hour", plural: "kilowatt-hours",
            aliases: ["kwh", "kilowatt hour", "kilowatt hours"])
        register(
            category: .energy, dimension: ExtendedUnitEnergy.btu, symbol: "BTU", singular: "BTU",
            plural: "BTUs", aliases: ["btu", "btus"])

        // ── 10. Power ──────────────────────────────────────────────────
        register(
            category: .power, dimension: UnitPower.watts, symbol: "W", singular: "watt",
            plural: "watts", aliases: ["w"])
        register(
            category: .power, dimension: UnitPower.milliwatts, symbol: "mW", singular: "milliwatt",
            plural: "milliwatts", aliases: ["mw_power"])
        register(
            category: .power, dimension: UnitPower.kilowatts, symbol: "kW", singular: "kilowatt",
            plural: "kilowatts", aliases: ["kw"])
        register(
            category: .power, dimension: UnitPower.megawatts, symbol: "MW", singular: "megawatt",
            plural: "megawatts", aliases: ["mw"])
        register(
            category: .power, dimension: UnitPower.gigawatts, symbol: "GW", singular: "gigawatt",
            plural: "gigawatts", aliases: ["gw"])
        register(
            category: .power, dimension: UnitPower.horsepower, symbol: "hp", singular: "horsepower",
            plural: "horsepower", aliases: ["hp"])

        // ── 11. Pressure ───────────────────────────────────────────────
        register(
            category: .pressure, dimension: UnitPressure.newtonsPerMetersSquared, symbol: "Pa",
            singular: "pascal", plural: "pascals", aliases: ["pa"])
        register(
            category: .pressure, dimension: UnitPressure.kilopascals, symbol: "kPa",
            singular: "kilopascal", plural: "kilopascals", aliases: ["kpa"])
        register(
            category: .pressure, dimension: UnitPressure.megapascals, symbol: "MPa",
            singular: "megapascal", plural: "megapascals", aliases: ["mpa"])
        register(
            category: .pressure, dimension: UnitPressure.gigapascals, symbol: "GPa",
            singular: "gigapascal", plural: "gigapascals", aliases: ["gpa"])
        register(
            category: .pressure, dimension: UnitPressure.bars, symbol: "bar", singular: "bar",
            plural: "bars", aliases: [])
        register(
            category: .pressure, dimension: UnitPressure.millibars, symbol: "mbar",
            singular: "millibar", plural: "millibars", aliases: [])
        register(
            category: .pressure, dimension: UnitPressure.poundsForcePerSquareInch, symbol: "psi",
            singular: "pound per square inch", plural: "pounds per square inch", aliases: ["psi"])
        register(
            category: .pressure,
            dimension: Dimension(
                symbol: "atm", converter: UnitConverterLinear(coefficient: 101325)), symbol: "atm",
            singular: "atmosphere", plural: "atmospheres", aliases: [])
        register(
            category: .pressure, dimension: UnitPressure.millimetersOfMercury, symbol: "mmHg",
            singular: "millimeter of mercury", plural: "millimeters of mercury",
            aliases: ["torr", "mmhg"])
        register(
            category: .pressure, dimension: UnitPressure.inchesOfMercury, symbol: "inHg",
            singular: "inch of mercury", plural: "inches of mercury", aliases: ["inhg"])

        // ── 12. Angle ──────────────────────────────────────────────────
        register(
            category: .angle, dimension: UnitAngle.degrees, symbol: "°", singular: "degree",
            plural: "degrees", aliases: ["deg", "degree", "degrees"])
        register(
            category: .angle, dimension: UnitAngle.radians, symbol: "rad", singular: "radian",
            plural: "radians", aliases: [])
        register(
            category: .angle, dimension: UnitAngle.gradians, symbol: "grad", singular: "gradian",
            plural: "gradians", aliases: ["gon"])
        register(
            category: .angle, dimension: UnitAngle.arcMinutes, symbol: "arcmin",
            singular: "arcminute", plural: "arcminutes", aliases: ["arc minute", "arc minutes"])
        register(
            category: .angle, dimension: UnitAngle.arcSeconds, symbol: "arcsec",
            singular: "arcsecond", plural: "arcseconds", aliases: ["arc second", "arc seconds"])

        // ── 13. Fuel Efficiency ────────────────────────────────────────
        register(
            category: .fuelEfficiency, dimension: UnitFuelEfficiency.milesPerGallon, symbol: "mpg",
            singular: "mile per gallon", plural: "miles per gallon", aliases: ["miles per gallon"])
        register(
            category: .fuelEfficiency, dimension: UnitFuelEfficiency.litersPer100Kilometers,
            symbol: "L/100km", singular: "liter per 100 kilometers",
            plural: "liters per 100 kilometers",
            aliases: ["l/100km", "litres per 100 kilometres", "l/100 km"])
    }

    // MARK: - Lookup

    private func findUnit(for string: String) -> UnitEntry? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let entry = unitDictionary[clean] {
            return entry
        }
        let noSpaces = clean.replacingOccurrences(of: " ", with: "")
        if let entry = unitDictionary[noSpaces] {
            return entry
        }
        return nil
    }

    // MARK: - Formatting Helpers

    public func formatNumber(_ val: Double) -> String {
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

    // MARK: - Standard & Compound Conversion Methods

    public func convert(amount: Double, from fromStr: String, to toStr: String) -> ConversionResult?
    {
        guard let fromEntry = findUnit(for: fromStr),
            let toEntry = findUnit(for: toStr)
        else {
            return nil
        }

        guard fromEntry.category == toEntry.category else {
            return nil
        }

        let convertedValue: Double
        if fromEntry.category == .fuelEfficiency {
            if fromEntry.symbol == toEntry.symbol {
                convertedValue = amount
            } else if fromEntry.symbol == "mpg" && toEntry.symbol == "L/100km" {
                convertedValue = 235.214583 / amount
            } else if fromEntry.symbol == "L/100km" && toEntry.symbol == "mpg" {
                convertedValue = 235.214583 / amount
            } else {
                convertedValue = amount
            }
        } else {
            let baseValue = fromEntry.dimension.converter.baseUnitValue(fromValue: amount)
            convertedValue = toEntry.dimension.converter.value(fromBaseUnitValue: baseValue)
        }

        let formattedAmount = formatNumber(amount)
        let formattedConverted = formatNumber(convertedValue)

        let resultTitle = "\(formattedConverted) \(toEntry.symbol)"
        let fromUnitName = amount == 1.0 ? fromEntry.fullSingular : fromEntry.fullPlural
        let toUnitName = convertedValue == 1.0 ? toEntry.fullSingular : toEntry.fullPlural

        let peekText = "\(formattedAmount) \(fromUnitName) = \(formattedConverted) \(toUnitName)"

        return ConversionResult(
            formattedValue: resultTitle,
            peekText: peekText,
            subtitle: "Unit Conversion"
        )
    }

    public func convertCompound(
        firstAmount: Double, firstUnit: String,
        secondAmount: Double, secondUnit: String,
        to toStr: String
    ) -> ConversionResult? {
        guard let entry1 = findUnit(for: firstUnit),
            let entry2 = findUnit(for: secondUnit),
            let toEntry = findUnit(for: toStr)
        else {
            return nil
        }

        guard entry1.category == entry2.category, entry1.category == toEntry.category else {
            return nil
        }

        let base1 = entry1.dimension.converter.baseUnitValue(fromValue: firstAmount)
        let base2 = entry2.dimension.converter.baseUnitValue(fromValue: secondAmount)
        let totalBase = base1 + base2
        let totalConverted = toEntry.dimension.converter.value(fromBaseUnitValue: totalBase)

        let formatted1 = formatNumber(firstAmount)
        let formatted2 = formatNumber(secondAmount)
        let formattedTotal = formatNumber(totalConverted)

        let resultTitle = "\(formattedTotal) \(toEntry.symbol)"
        let toUnitName = totalConverted == 1.0 ? toEntry.fullSingular : toEntry.fullPlural

        let peekText =
            "\(formatted1) \(entry1.symbol) \(formatted2) \(entry2.symbol) = \(formattedTotal) \(toUnitName)"

        return ConversionResult(
            formattedValue: resultTitle,
            peekText: peekText,
            subtitle: "Unit Conversion"
        )
    }

    // MARK: - Human Timespan Breakdown ("145 mins to timespan", "90000 seconds in timespan")

    public func convertToTimespan(amount: Double, unitStr: String) -> ConversionResult? {
        guard let entry = findUnit(for: unitStr), entry.category == .duration else { return nil }

        let totalSeconds = entry.dimension.converter.baseUnitValue(fromValue: amount)
        guard totalSeconds >= 0 else { return nil }

        let totalSecInt = Int(totalSeconds)
        let days = totalSecInt / 86400
        let hours = (totalSecInt % 86400) / 3600
        let minutes = (totalSecInt % 3600) / 60
        let seconds = totalSecInt % 60

        var parts: [String] = []
        var fullParts: [String] = []

        if days > 0 {
            parts.append("\(days)d")
            fullParts.append("\(days) \(days == 1 ? "day" : "days")")
        }
        if hours > 0 {
            parts.append("\(hours)h")
            fullParts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if minutes > 0 {
            parts.append("\(minutes)m")
            fullParts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds)s")
            fullParts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")")
        }

        let shortTitle = parts.joined(separator: " ")
        let fullDesc = fullParts.joined(separator: ", ")
        let formattedAmount = formatNumber(amount)
        let peekText = "\(formattedAmount) \(entry.symbol) =\n\(fullDesc) (\(shortTitle))"

        return ConversionResult(
            formattedValue: shortTitle,
            peekText: peekText,
            subtitle: "Timespan Breakdown"
        )
    }

    // MARK: - Work Planning ("55h in workdays", "workhours in 2026")

    public func calculateWorkPlanning(query: String) -> ConversionResult? {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. "workhours in <year>" or "workdays in <year>"
        let yearPattern = try! NSRegularExpression(
            pattern: #"^(workhours|workdays|working\s+days|working\s+hours)\s+in\s+(\d{4})$"#,
            options: .caseInsensitive)
        let ns = lower as NSString
        if let m = yearPattern.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower))
        {
            let type = ns.substring(with: m.range(at: 1))
            if let year = Int(ns.substring(with: m.range(at: 2))) {
                let workdays = calculateWorkingDays(in: year)
                let workhours = workdays * 8
                if type.contains("hour") {
                    return ConversionResult(
                        formattedValue: "\(formatNumber(Double(workhours))) work hours",
                        peekText:
                            "Year \(year):\n\(workdays) work days (Monday–Friday)\n\(formatNumber(Double(workhours))) total work hours (at 8h/day)",
                        subtitle: "Work Planning"
                    )
                } else {
                    return ConversionResult(
                        formattedValue: "\(workdays) work days",
                        peekText:
                            "Year \(year):\n\(workdays) work days (Monday–Friday)\n\(formatNumber(Double(workhours))) total work hours (at 8h/day)",
                        subtitle: "Work Planning"
                    )
                }
            }
        }

        // 2. "<N>h in workdays" or "<N> hours in workdays"
        let hoursToWorkdaysPattern = try! NSRegularExpression(
            pattern: #"^([0-9.]+)\s*(?:h|hrs|hours?)\s+(?:in|to)\s+(?:workdays?|working\s+days?)$"#,
            options: .caseInsensitive)
        if let m = hoursToWorkdaysPattern.firstMatch(
            in: lower, range: NSRange(lower.startIndex..., in: lower))
        {
            if let hours = Double(ns.substring(with: m.range(at: 1))) {
                let workdays = hours / 8.0
                let formatted = formatNumber(workdays)
                return ConversionResult(
                    formattedValue: "\(formatted) workdays",
                    peekText:
                        "\(formatNumber(hours)) hours = \(formatted) workdays (at 8 hours/day)",
                    subtitle: "Work Planning"
                )
            }
        }

        // 3. "<N> workdays in hours"
        let workdaysToHoursPattern = try! NSRegularExpression(
            pattern: #"^([0-9.]+)\s*(?:workdays?|working\s+days?)\s+(?:in|to)\s+(?:hours?|h|hrs)$"#,
            options: .caseInsensitive)
        if let m = workdaysToHoursPattern.firstMatch(
            in: lower, range: NSRange(lower.startIndex..., in: lower))
        {
            if let workdays = Double(ns.substring(with: m.range(at: 1))) {
                let hours = workdays * 8.0
                let formatted = formatNumber(hours)
                return ConversionResult(
                    formattedValue: "\(formatted) hours",
                    peekText:
                        "\(formatNumber(workdays)) workdays = \(formatted) hours (at 8 hours/day)",
                    subtitle: "Work Planning"
                )
            }
        }

        return nil
    }

    private func calculateWorkingDays(in year: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: year, month: 1, day: 1)
        guard var date = calendar.date(from: comps) else { return 261 }

        var count = 0
        while calendar.component(.year, from: date) == year {
            let weekday = calendar.component(.weekday, from: date)
            // In Gregorian Calendar: 1 = Sunday, 7 = Saturday
            if weekday != 1 && weekday != 7 {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return count
    }
}
