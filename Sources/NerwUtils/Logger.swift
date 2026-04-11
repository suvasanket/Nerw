import Foundation

public final class Logger {
    public static let shared = Logger()

    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.nerw.logger", qos: .utility)
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    public var logDirectory: URL {
        let logsDir = NerwPaths.logsDirectory
        NerwPaths.ensureDirectoryExists(at: logsDir)
        return logsDir
    }

    public var currentLogFile: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logDirectory.appendingPathComponent("nerw-\(dateString).log")
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        setupLogFile()
        redirectStandardStreams()
    }

    private func setupLogFile() {
        let logURL = currentLogFile

        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }

        do {
            logFileHandle = try FileHandle(forWritingTo: logURL)
            logFileHandle?.seekToEndOfFile()
        } catch {
            print("Logger: Failed to open log file: \(error)")
        }
    }

    private func redirectStandardStreams() {
        let logURL = currentLogFile

        do {
            let logFile = try FileHandle(forWritingTo: logURL)
            logFile.seekToEndOfFile()

            dup2(logFile.fileDescriptor, STDOUT_FILENO)
            dup2(logFile.fileDescriptor, STDERR_FILENO)
        } catch {
            print("Logger: Failed to redirect streams: \(error)")
        }
    }

    public func log(
        _ message: String, level: LogLevel = .info, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let formattedMessage =
            "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)"

        logQueue.async { [weak self] in
            self?.writeToFile(formattedMessage)

            #if DEBUG
                print(formattedMessage)
            #endif
        }
    }

    public func debug(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    public func info(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    public func warning(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    public func error(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    public func error(
        _ error: Error, file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(error.localizedDescription, level: .error, file: file, function: function, line: line)
    }

    private func writeToFile(_ message: String) {
        guard let handle = logFileHandle else { return }

        let line = message + "\n"
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }

    public func flush() {
        logQueue.sync {
            try? logFileHandle?.synchronize()
        }
    }

    public func readRecentLogs(lines: Int = 100) -> String {
        guard let handle = FileHandle(forReadingAtPath: currentLogFile.path) else {
            return "Could not read log file"
        }

        defer { try? handle.close() }

        let data = handle.readDataToEndOfFile()
        guard let content = String(data: data, encoding: .utf8) else {
            return "Could not decode log content"
        }

        let allLines = content.components(separatedBy: .newlines)
        let recentLines = allLines.suffix(lines)
        return recentLines.joined(separator: "\n")
    }

    public enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}

public func log(
    _ message: String, file: String = #file, function: String = #function, line: Int = #line
) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

public func logError(
    _ message: String, file: String = #file, function: String = #function, line: Int = #line
) {
    Logger.shared.error(message, file: file, function: function, line: line)
}

public func logWarning(
    _ message: String, file: String = #file, function: String = #function, line: Int = #line
) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

public func logDebug(
    _ message: String, file: String = #file, function: String = #function, line: Int = #line
) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}
