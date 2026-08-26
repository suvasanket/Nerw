import Foundation
import NerwAction

public final class WorldClockEngine {
    public static let shared = WorldClockEngine()

    public struct WorldClockResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String

        public init(formattedValue: String, peekText: String, subtitle: String = "World Clock") {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
        }
    }

    public struct LocationInfo {
        public let name: String
        public let country: String
        public let timeZone: TimeZone

        public init(name: String, country: String, timeZoneIdentifier: String) {
            self.name = name
            self.country = country
            self.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
        }
    }

    private var registry: [String: LocationInfo] = [:]

    private init() {
        registerAllLocations()
    }

    // MARK: - 1. Time in City / Destination

    public func currentTime(in query: String) -> WorldClockResult? {
        guard let location = resolveLocation(query) else { return nil }

        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = location.timeZone
        let formattedTime = timeFormatter.string(from: now)

        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateStyle = .full
        fullDateFormatter.timeZone = location.timeZone
        let formattedDate = fullDateFormatter.string(from: now)

        let tzAbbr = location.timeZone.abbreviation(for: now) ?? ""
        let offsetSeconds = location.timeZone.secondsFromGMT(for: now)
        let utcOffsetStr = formatUTCOffset(offsetSeconds)

        let relativeOffsetStr = formatRelativeOffset(targetTZ: location.timeZone, date: now)

        let title = "\(formattedTime) in \(location.name)"
        let peekText =
            "\(location.name), \(location.country)\n\(formattedTime) (\(tzAbbr) • \(utcOffsetStr))\n\(formattedDate)\n\(relativeOffsetStr)"

        return WorldClockResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "World Clock"
        )
    }

    // MARK: - 2. Cross-City Time Conversion (e.g. "5pm ldn in sf")

    public func convertTime(timeStr: String, from fromQuery: String, to toQuery: String)
        -> WorldClockResult?
    {
        guard let fromLoc = resolveLocation(fromQuery),
            let toLoc = resolveLocation(toQuery),
            let (hour, minute) = parseTime(timeStr)
        else {
            return nil
        }

        var sourceCal = Calendar.current
        sourceCal.timeZone = fromLoc.timeZone

        let now = Date()
        var dateComps = sourceCal.dateComponents([.year, .month, .day], from: now)
        dateComps.hour = hour
        dateComps.minute = minute
        dateComps.second = 0

        guard let sourceDate = sourceCal.date(from: dateComps) else { return nil }

        let targetFormatter = DateFormatter()
        targetFormatter.timeStyle = .short
        targetFormatter.timeZone = toLoc.timeZone
        let targetTime = targetFormatter.string(from: sourceDate)

        let sourceFormatter = DateFormatter()
        sourceFormatter.timeStyle = .short
        sourceFormatter.timeZone = fromLoc.timeZone
        let formattedSourceTime = sourceFormatter.string(from: sourceDate)

        // Day difference check
        var targetCal = Calendar.current
        targetCal.timeZone = toLoc.timeZone
        let sourceDay = sourceCal.component(.day, from: sourceDate)
        let targetDay = targetCal.component(.day, from: sourceDate)

        let dayDiffText: String
        if targetDay > sourceDay {
            dayDiffText = " (Next day)"
        } else if targetDay < sourceDay {
            dayDiffText = " (Previous day)"
        } else {
            dayDiffText = " (Same day)"
        }

        let sourceAbbr = fromLoc.timeZone.abbreviation(for: sourceDate) ?? ""
        let targetAbbr = toLoc.timeZone.abbreviation(for: sourceDate) ?? ""

        let title =
            "\(targetTime) in \(toLoc.name)\(dayDiffText == " (Same day)" ? "" : dayDiffText)"
        let peekText =
            "\(formattedSourceTime) \(fromLoc.name) (\(sourceAbbr)) =\n\(targetTime) \(toLoc.name) (\(targetAbbr))\(dayDiffText)"

        return WorldClockResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "Timezone Conversion"
        )
    }

    // MARK: - 3. Time Difference ("time diff Paris", "diff Tokyo")

    public func timeDifference(with query: String) -> WorldClockResult? {
        guard let location = resolveLocation(query) else { return nil }

        let now = Date()
        let localSeconds = TimeZone.current.secondsFromGMT(for: now)
        let remoteSeconds = location.timeZone.secondsFromGMT(for: now)
        let diffSeconds = remoteSeconds - localSeconds

        let absHours = abs(diffSeconds) / 3600
        let absMins = (abs(diffSeconds) % 3600) / 60

        let direction = diffSeconds >= 0 ? "ahead of" : "behind"
        let formattedDiff: String
        if absMins == 0 {
            formattedDiff = "\(absHours) hr\(absHours == 1 ? "" : "s")"
        } else {
            formattedDiff = "\(absHours)h \(absMins)m"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = location.timeZone
        let remoteTime = timeFormatter.string(from: now)

        let tzAbbr = location.timeZone.abbreviation(for: now) ?? ""
        let title = "\(location.name) is \(formattedDiff) \(direction) you"
        let peekText =
            "\(location.name), \(location.country) (\(tzAbbr))\nCurrent Time: \(remoteTime)\n\(location.name) is \(formattedDiff) \(direction) your local time"

        return WorldClockResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "Time Difference"
        )
    }

    // MARK: - 4. Time Projections ("time in 4 hours", "time in 4 hours in San Francisco")

    public func projectTime(delayHours: Double, destination: String? = nil) -> WorldClockResult? {
        let now = Date()
        let targetDate = now.addingTimeInterval(delayHours * 3600)

        let timeZone: TimeZone
        let locationName: String
        if let dest = destination, let loc = resolveLocation(dest) {
            timeZone = loc.timeZone
            locationName = " in \(loc.name)"
        } else {
            timeZone = TimeZone.current
            locationName = ""
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        let timeStr = formatter.string(from: targetDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeZone = timeZone
        let dateStr = dateFormatter.string(from: targetDate)

        let sign = delayHours >= 0 ? "in " : ""
        let absH = abs(delayHours)
        let durationText = floor(absH) == absH ? "\(Int(absH)) hours" : "\(absH) hours"

        let title = "\(timeStr)\(locationName)"
        let peekText = "Time \(sign)\(durationText)\(locationName):\n\(timeStr) (\(dateStr))"

        return WorldClockResult(
            formattedValue: title,
            peekText: peekText,
            subtitle: "Time Projection"
        )
    }

    // MARK: - Location Resolution

    public func resolveLocation(_ query: String) -> LocationInfo? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let loc = registry[clean] {
            return loc
        }
        let noSpaces = clean.replacingOccurrences(of: " ", with: "")
        if let loc = registry[noSpaces] {
            return loc
        }

        // Check if query is directly a valid TimeZone identifier (e.g. "America/New_York", "PST", "UTC")
        if let tz = TimeZone(identifier: query) ?? TimeZone(abbreviation: query.uppercased()) {
            return LocationInfo(
                name: query.uppercased(), country: "Time Zone", timeZoneIdentifier: tz.identifier)
        }

        return nil
    }

    // MARK: - Formatting Helpers

    private func formatUTCOffset(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absSec = abs(seconds)
        let hours = absSec / 3600
        let minutes = (absSec % 3600) / 60
        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        } else {
            return String(format: "UTC%@%d:%02d", sign, hours, minutes)
        }
    }

    private func formatRelativeOffset(targetTZ: TimeZone, date: Date) -> String {
        let localOffset = TimeZone.current.secondsFromGMT(for: date)
        let targetOffset = targetTZ.secondsFromGMT(for: date)
        let diff = targetOffset - localOffset

        if diff == 0 {
            return "Same time as your local location"
        }

        let direction = diff > 0 ? "ahead of" : "behind"
        let absDiff = abs(diff)
        let hours = absDiff / 3600
        let minutes = (absDiff % 3600) / 60

        let timeString: String
        if minutes == 0 {
            timeString = "\(hours) \(hours == 1 ? "hour" : "hours")"
        } else {
            timeString = "\(hours)h \(minutes)m"
        }

        return "\(timeString) \(direction) your local time"
    }

    private func parseTime(_ string: String) -> (hour: Int, minute: Int)? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = ["h:mma", "ha", "h:mm a", "h a", "HH:mm", "H:mm"]
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: clean) {
                let cal = Calendar.current
                let hour = cal.component(.hour, from: date)
                let minute = cal.component(.minute, from: date)
                return (hour, minute)
            }
        }
        return nil
    }

    // MARK: - Location Database

    private func register(_ keys: [String], name: String, country: String, tz: String) {
        let info = LocationInfo(name: name, country: country, timeZoneIdentifier: tz)
        for key in keys {
            registry[key.lowercased()] = info
            registry[key.lowercased().replacingOccurrences(of: " ", with: "")] = info
        }
    }

    private func registerAllLocations() {
        // Americas - North
        register(
            ["san francisco", "sf", "sfo"], name: "San Francisco", country: "United States",
            tz: "America/Los_Angeles")
        register(
            ["los angeles", "la", "lax"], name: "Los Angeles", country: "United States",
            tz: "America/Los_Angeles")
        register(
            ["seattle", "sea"], name: "Seattle", country: "United States", tz: "America/Los_Angeles"
        )
        register(
            ["new york", "nyc", "ny", "jfk", "lga", "ewr"], name: "New York",
            country: "United States", tz: "America/New_York")
        register(
            ["chicago", "ord"], name: "Chicago", country: "United States", tz: "America/Chicago")
        register(
            ["austin", "aus", "dallas", "dfw", "houston", "iah"], name: "Texas",
            country: "United States", tz: "America/Chicago")
        register(["denver", "den"], name: "Denver", country: "United States", tz: "America/Denver")
        register(
            ["phoenix", "phx"], name: "Phoenix", country: "United States", tz: "America/Phoenix")
        register(
            ["boston", "bos"], name: "Boston", country: "United States", tz: "America/New_York")
        register(
            ["miami", "mia", "orlando", "mco", "atlanta", "atl"], name: "Miami / Atlanta",
            country: "United States", tz: "America/New_York")
        register(
            ["honolulu", "hnl", "hawaii"], name: "Honolulu", country: "United States",
            tz: "Pacific/Honolulu")
        register(
            ["anchorage", "anc", "alaska"], name: "Anchorage", country: "United States",
            tz: "America/Anchorage")
        register(["toronto", "yyz"], name: "Toronto", country: "Canada", tz: "America/Toronto")
        register(
            ["vancouver", "yvr"], name: "Vancouver", country: "Canada", tz: "America/Vancouver")
        register(["montreal", "yul"], name: "Montreal", country: "Canada", tz: "America/Toronto")

        // Americas - Central & South
        register(
            ["mexico city", "mex", "cdmx"], name: "Mexico City", country: "Mexico",
            tz: "America/Mexico_City")
        register(
            ["são paulo", "sao paulo", "gru"], name: "São Paulo", country: "Brazil",
            tz: "America/Sao_Paulo")
        register(
            ["rio de janeiro", "rio", "gig"], name: "Rio de Janeiro", country: "Brazil",
            tz: "America/Sao_Paulo")
        register(
            ["buenos aires", "eze"], name: "Buenos Aires", country: "Argentina",
            tz: "America/Argentina/Buenos_Aires")
        register(["santiago", "scl"], name: "Santiago", country: "Chile", tz: "America/Santiago")
        register(
            ["bogotá", "bogota", "bog"], name: "Bogotá", country: "Colombia", tz: "America/Bogota")
        register(["lima", "lim"], name: "Lima", country: "Peru", tz: "America/Lima")

        // Europe - UK & West
        register(
            ["london", "ldn", "lon", "lhr", "lgw"], name: "London", country: "United Kingdom",
            tz: "Europe/London")
        register(["dublin", "dub"], name: "Dublin", country: "Ireland", tz: "Europe/Dublin")
        register(
            ["paris", "par", "cdg", "ory"], name: "Paris", country: "France", tz: "Europe/Paris")
        register(["berlin", "ber"], name: "Berlin", country: "Germany", tz: "Europe/Berlin")
        register(
            ["frankfurt", "fra", "munich", "muc"], name: "Frankfurt / Munich", country: "Germany",
            tz: "Europe/Berlin")
        register(
            ["amsterdam", "ams"], name: "Amsterdam", country: "Netherlands", tz: "Europe/Amsterdam")
        register(["brussels", "bru"], name: "Brussels", country: "Belgium", tz: "Europe/Brussels")
        register(["madrid", "mad"], name: "Madrid", country: "Spain", tz: "Europe/Madrid")
        register(["barcelona", "bcn"], name: "Barcelona", country: "Spain", tz: "Europe/Madrid")
        register(["lisbon", "lis"], name: "Lisbon", country: "Portugal", tz: "Europe/Lisbon")
        register(
            ["rome", "rom", "fco", "milan", "mxp"], name: "Rome / Milan", country: "Italy",
            tz: "Europe/Rome")
        register(
            ["zurich", "zrh", "geneva", "gva"], name: "Zurich / Geneva", country: "Switzerland",
            tz: "Europe/Zurich")
        register(["vienna", "vie"], name: "Vienna", country: "Austria", tz: "Europe/Vienna")
        register(
            ["stockholm", "arn"], name: "Stockholm", country: "Sweden", tz: "Europe/Stockholm")
        register(["oslo", "osl"], name: "Oslo", country: "Norway", tz: "Europe/Oslo")
        register(
            ["copenhagen", "cph"], name: "Copenhagen", country: "Denmark", tz: "Europe/Copenhagen")
        register(["helsinki", "hel"], name: "Helsinki", country: "Finland", tz: "Europe/Helsinki")
        register(["athens", "ath"], name: "Athens", country: "Greece", tz: "Europe/Athens")
        register(["warsaw", "waw"], name: "Warsaw", country: "Poland", tz: "Europe/Warsaw")
        register(["prague", "prg"], name: "Prague", country: "Czech Republic", tz: "Europe/Prague")
        register(["budapest", "bud"], name: "Budapest", country: "Hungary", tz: "Europe/Budapest")
        register(["istanbul", "ist"], name: "Istanbul", country: "Turkey", tz: "Europe/Istanbul")
        register(["moscow", "svo", "dme"], name: "Moscow", country: "Russia", tz: "Europe/Moscow")

        // Middle East & Africa
        register(
            ["dubai", "dxb", "uae"], name: "Dubai", country: "United Arab Emirates",
            tz: "Asia/Dubai")
        register(["doha", "doh"], name: "Doha", country: "Qatar", tz: "Asia/Qatar")
        register(["riyadh", "ruh"], name: "Riyadh", country: "Saudi Arabia", tz: "Asia/Riyadh")
        register(
            ["tel aviv", "tlv", "jerusalem"], name: "Tel Aviv", country: "Israel",
            tz: "Asia/Jerusalem")
        register(["cairo", "cai"], name: "Cairo", country: "Egypt", tz: "Africa/Cairo")
        register(
            ["cape town", "cpt", "johannesburg", "jnb"], name: "Cape Town / Johannesburg",
            country: "South Africa", tz: "Africa/Johannesburg")
        register(["nairobi", "nbo"], name: "Nairobi", country: "Kenya", tz: "Africa/Nairobi")
        register(["lagos", "los"], name: "Lagos", country: "Nigeria", tz: "Africa/Lagos")

        // Asia
        register(
            ["tokyo", "tok", "tyo", "hnd", "nrt"], name: "Tokyo", country: "Japan", tz: "Asia/Tokyo"
        )
        register(["seoul", "icn", "sel"], name: "Seoul", country: "South Korea", tz: "Asia/Seoul")
        register(
            ["beijing", "pek", "pkx", "shanghai", "pvg", "sha"], name: "Beijing / Shanghai",
            country: "China", tz: "Asia/Shanghai")
        register(
            ["hong kong", "hk", "hkg"], name: "Hong Kong", country: "Hong Kong",
            tz: "Asia/Hong_Kong")
        register(["taipei", "tpe"], name: "Taipei", country: "Taiwan", tz: "Asia/Taipei")
        register(
            ["singapore", "sin", "sg"], name: "Singapore", country: "Singapore",
            tz: "Asia/Singapore")
        register(
            ["bangkok", "bkk", "dmk"], name: "Bangkok", country: "Thailand", tz: "Asia/Bangkok")
        register(
            ["kuala lumpur", "kul", "kl"], name: "Kuala Lumpur", country: "Malaysia",
            tz: "Asia/Kuala_Lumpur")
        register(["jakarta", "cgk"], name: "Jakarta", country: "Indonesia", tz: "Asia/Jakarta")
        register(["manila", "mnl"], name: "Manila", country: "Philippines", tz: "Asia/Manila")
        register(
            ["hanoi", "han", "ho chi minh", "sgn"], name: "Vietnam", country: "Vietnam",
            tz: "Asia/Ho_Chi_Minh")
        register(["mumbai", "bom", "bombay"], name: "Mumbai", country: "India", tz: "Asia/Kolkata")
        register(
            ["delhi", "del", "new delhi"], name: "Delhi", country: "India", tz: "Asia/Kolkata")
        register(
            ["bangalore", "blr", "bengaluru"], name: "Bangalore", country: "India",
            tz: "Asia/Kolkata")
        register(
            ["hyderabad", "hyd", "chennai", "maa", "kolkata", "ccu"], name: "India (IST)",
            country: "India", tz: "Asia/Kolkata")

        // Oceania
        register(["sydney", "syd"], name: "Sydney", country: "Australia", tz: "Australia/Sydney")
        register(
            ["melbourne", "mel"], name: "Melbourne", country: "Australia", tz: "Australia/Melbourne"
        )
        register(
            ["brisbane", "bne"], name: "Brisbane", country: "Australia", tz: "Australia/Brisbane")
        register(["perth", "per"], name: "Perth", country: "Australia", tz: "Australia/Perth")
        register(
            ["auckland", "akl", "wellington", "wlg"], name: "Auckland", country: "New Zealand",
            tz: "Pacific/Auckland")

        // Standard Timezone Abbreviations
        register(
            ["utc", "gmt", "zulu", "z"], name: "UTC", country: "Coordinated Universal Time",
            tz: "UTC")
        register(
            ["pst", "pdt", "pacific time"], name: "Pacific Time", country: "US / Canada",
            tz: "America/Los_Angeles")
        register(
            ["est", "edt", "eastern time"], name: "Eastern Time", country: "US / Canada",
            tz: "America/New_York")
        register(
            ["cst", "cdt", "central time"], name: "Central Time", country: "US / Canada",
            tz: "America/Chicago")
        register(
            ["mst", "mdt", "mountain time"], name: "Mountain Time", country: "US / Canada",
            tz: "America/Denver")
        register(
            ["jst", "japan time"], name: "Japan Standard Time", country: "Japan", tz: "Asia/Tokyo")
        register(
            ["kst", "korea time"], name: "Korea Standard Time", country: "South Korea",
            tz: "Asia/Seoul")
        register(
            ["ist", "india time"], name: "India Standard Time", country: "India", tz: "Asia/Kolkata"
        )
        register(
            ["cet", "cest", "central european time"], name: "Central European Time",
            country: "Europe", tz: "Europe/Paris")
        register(
            ["aest", "aedt", "australian eastern time"], name: "Australian Eastern Time",
            country: "Australia", tz: "Australia/Sydney")
        register(
            ["nzst", "nzdt"], name: "New Zealand Time", country: "New Zealand",
            tz: "Pacific/Auckland")
    }
}
