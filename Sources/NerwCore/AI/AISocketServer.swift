import Foundation
import NerwUtils

public final class AISocketServer {
    public static let shared = AISocketServer()

    private let socketPath: String
    private var serverFD: Int32 = -1
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "com.nerw.ai.socketserver", qos: .userInitiated)
    private let clientsLock = NSLock()
    private var activeClients: Set<Int32> = []

    private init() {
        self.socketPath = NerwPaths.aiSocketPath.path
    }

    /// Starts the socket server on a background queue.
    public func start() {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            self.runServer()
        }
    }

    /// Stops the socket server, disconnects all clients, and removes the socket file.
    public func stop() {
        isRunning = false

        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }

        clientsLock.withLock {
            for clientFD in activeClients {
                close(clientFD)
            }
            activeClients.removeAll()
        }

        unlink(socketPath)
        Logger.shared.info("AISocketServer: Stopped and socket unlinked.")
    }

    private func runServer() {
        guard !isRunning else { return }
        isRunning = true

        // Remove stale socket file
        unlink(socketPath)

        // Ensure parent directory exists
        let socketURL = URL(fileURLWithPath: socketPath)
        let parentDir = socketURL.deletingLastPathComponent()
        NerwPaths.ensureDirectoryExists(at: parentDir)

        // Create socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Logger.shared.error("AISocketServer: Failed to create socket: \(errno)")
            isRunning = false
            return
        }
        serverFD = fd

        // Set SO_REUSEADDR
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            pathBytes.withUnsafeBytes { src in
                let count = min(src.count, buf.count - 1)
                buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(count)))
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, addrLen)
            }
        }

        guard bindResult == 0 else {
            Logger.shared.error("AISocketServer: Bind failed: \(errno)")
            close(fd)
            serverFD = -1
            isRunning = false
            return
        }

        // Listen
        guard listen(fd, 10) == 0 else {
            Logger.shared.error("AISocketServer: Listen failed: \(errno)")
            close(fd)
            serverFD = -1
            isRunning = false
            return
        }

        Logger.shared.info("AISocketServer: Listening on \(socketPath)")

        while isRunning {
            let client = accept(serverFD, nil, nil)
            guard client >= 0 else {
                if isRunning {
                    Logger.shared.error("AISocketServer: Accept failed: \(errno)")
                }
                break
            }

            clientsLock.withLock {
                activeClients.insert(client)
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(client)
            }
        }
    }

    private func handleClient(_ clientFD: Int32) {
        var readBuffer = Data()

        while isRunning {
            // Process complete lines from buffer
            while let newlineIdx = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer[readBuffer.startIndex..<newlineIdx]
                readBuffer.removeSubrange(readBuffer.startIndex...newlineIdx)

                if let msg = try? JSONDecoder().decode(AISocketMessage.self, from: lineData) {
                    processMessage(msg, clientFD: clientFD)
                }
            }

            // Read next chunk of bytes
            var chunk = [UInt8](repeating: 0, count: 4096)
            let n = read(clientFD, &chunk, chunk.count)
            if n <= 0 {
                // Connection closed or error
                break
            }
            readBuffer.append(contentsOf: chunk.prefix(n))
        }

        close(clientFD)
        clientsLock.withLock {
            activeClients.remove(clientFD)
        }
    }

    private func processMessage(_ msg: AISocketMessage, clientFD: Int32) {
        guard msg.type == "chat_request" else {
            sendError("Unsupported message type: \(msg.type)", msgId: msg.id, clientFD: clientFD)
            return
        }

        guard let payloadData = msg.payloadData,
            let reqPayload = try? JSONDecoder().decode(AIChatRequestPayload.self, from: payloadData)
        else {
            sendError("Malformed chat request payload", msgId: msg.id, clientFD: clientFD)
            return
        }

        let imagesData = reqPayload.images.compactMap { Data(base64Encoded: $0) }

        Task {
            do {
                var messages: [AIChatMessage] = reqPayload.history ?? []
                messages.append(AIChatMessage(role: .user, content: reqPayload.prompt))

                let stream = try await AIService.shared.generateResponse(
                    messages: messages,
                    images: imagesData,
                    isStreaming: reqPayload.isStreaming
                )

                for try await deltaText in stream {
                    let resPayload = AIChatResponsePayload(
                        text: deltaText, error: nil, isDone: false)
                    let resPayloadData = try JSONEncoder().encode(resPayload)
                    let resMsg = AISocketMessage(id: msg.id, type: "chunk", payload: resPayloadData)
                    writeMessage(resMsg, clientFD: clientFD)
                }

                let donePayload = AIChatResponsePayload(text: "", error: nil, isDone: true)
                let donePayloadData = try JSONEncoder().encode(donePayload)
                let doneMsg = AISocketMessage(id: msg.id, type: "done", payload: donePayloadData)
                writeMessage(doneMsg, clientFD: clientFD)
            } catch {
                sendError(error.localizedDescription, msgId: msg.id, clientFD: clientFD)
            }
        }
    }

    private func writeMessage(_ msg: AISocketMessage, clientFD: Int32) {
        guard clientFD >= 0,
            let data = try? JSONEncoder().encode(msg),
            let line = String(data: data, encoding: .utf8)
        else { return }

        let lineWithNewline = line + "\n"
        guard let bytes = lineWithNewline.data(using: .utf8) else { return }

        _ = bytes.withUnsafeBytes { write(clientFD, $0.baseAddress!, $0.count) }
    }

    private func sendError(_ text: String, msgId: String?, clientFD: Int32) {
        let errPayload = AIChatResponsePayload(text: "", error: text, isDone: true)
        if let errPayloadData = try? JSONEncoder().encode(errPayload) {
            let errMsg = AISocketMessage(id: msgId, type: "error", payload: errPayloadData)
            writeMessage(errMsg, clientFD: clientFD)
        }
    }
}

// MARK: - Protocol Envelopes

public struct AISocketMessage: Codable {
    public let id: String?
    public let type: String  // "chat_request", "chunk", "done", "error"
    public let payload: String?  // Base64 encoded JSON payload

    public init(id: String? = nil, type: String, payload: Data? = nil) {
        self.id = id
        self.type = type
        self.payload = payload?.base64EncodedString()
    }

    public var payloadData: Data? {
        payload.flatMap { Data(base64Encoded: $0) }
    }
}

public struct AIChatMessage: Codable {
    public enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIChatRequestPayload: Codable {
    public let prompt: String
    public let history: [AIChatMessage]?
    public let images: [String]  // Base64 encoded image strings
    public let isStreaming: Bool

    public init(
        prompt: String, history: [AIChatMessage]? = nil, images: [String] = [],
        isStreaming: Bool = true
    ) {
        self.prompt = prompt
        self.history = history
        self.images = images
        self.isStreaming = isStreaming
    }
}

public struct AIChatResponsePayload: Codable {
    public let text: String
    public let error: String?
    public let isDone: Bool

    public init(text: String, error: String? = nil, isDone: Bool) {
        self.text = text
        self.error = error
        self.isDone = isDone
    }
}
