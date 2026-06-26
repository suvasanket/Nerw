import Foundation
import NerwUtils

public class AILogger {
    public static let shared = AILogger()

    private let logsDir: URL

    private init() {
        self.logsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".nerw/ai_logs")
        try? FileManager.default.createDirectory(
            at: self.logsDir, withIntermediateDirectories: true)
    }

    public func startLog(providerName: String, payload: [String: Any]) -> String {
        guard ConfigManager.shared.config.aiConfig.isConversationLogEnabled else { return "" }

        let logId = UUID().uuidString
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "chat_\(timestamp)_\(providerName)_\(logId.prefix(8)).json"
        let fileURL = logsDir.appendingPathComponent(filename)

        let logData: [String: Any] = [
            "id": logId,
            "timestamp": timestamp,
            "provider": providerName,
            "requestPayload": payload,
            "response": "",
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: logData, options: .prettyPrinted)
            try data.write(to: fileURL)
        } catch {
            Logger.shared.error("AILogger: Failed to write initial log - \(error)")
        }

        return logId
    }

    public func finishLog(logId: String, responseText: String) {
        guard ConfigManager.shared.config.aiConfig.isConversationLogEnabled, !logId.isEmpty else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logsDir, includingPropertiesForKeys: nil)
            guard
                let fileURL = files.first(where: { $0.lastPathComponent.contains(logId.prefix(8)) })
            else {
                Logger.shared.error("AILogger: Could not find log file for ID \(logId)")
                return
            }

            let data = try Data(contentsOf: fileURL)
            if var logData = try JSONSerialization.jsonObject(with: data, options: [])
                as? [String: Any]
            {
                logData["response"] = responseText
                let updatedData = try JSONSerialization.data(
                    withJSONObject: logData, options: .prettyPrinted)
                try updatedData.write(to: fileURL)
            }
        } catch {
            Logger.shared.error("AILogger: Failed to update log - \(error)")
        }
    }
}
