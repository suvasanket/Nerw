import Foundation

// MARK: - DaemonMessage

/// Envelope for all IPC messages between Nerw (client) and a daemon (server).
/// Serialised as NDJSON — one JSON object per line.
public struct DaemonMessage: Codable {
    /// Correlation ID for matching requests to responses. Nil for push messages.
    public let id: String?
    /// Message type: "query", "action", "health", "stop",
    ///               "response", "action_response", "health_response", "ext_command"
    public let type: String
    /// Type-specific payload serialised as a raw JSON fragment (to avoid a full generic).
    public let payload: Data?

    public init(id: String? = nil, type: String, payload: Data? = nil) {
        self.id = id
        self.type = type
        self.payload = payload
    }

    // MARK: Custom Codable (payload stored as raw Base64 to keep envelope simple)

    enum CodingKeys: String, CodingKey { case id, type, payload }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        if let b64 = try c.decodeIfPresent(String.self, forKey: .payload) {
            payload = Data(base64Encoded: b64)
        } else {
            payload = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(payload?.base64EncodedString(), forKey: .payload)
    }
}

// MARK: - DaemonConnection

/// Host-side connection to a single daemon process via its Unix domain socket.
/// Thread-safe; one instance per running daemon.
public class DaemonConnection {
    public let extensionId: String

    private let socketPath: String
    private var socketFD: Int32 = -1
    private var fileHandle: FileHandle?
    private let lock = NSLock()

    /// Pending request continuations keyed by correlation ID.
    private var pending: [String: (Data?) -> Void] = [:]
    private let pendingLock = NSLock()

    /// Called on the main queue when the daemon pushes an unsolicited command.
    public var onExtCommand: (([ExtensionCommand]) -> Void)?

    public var isConnected: Bool { socketFD >= 0 }

    public init(extensionId: String, socketPath: String) {
        self.extensionId = extensionId
        self.socketPath = socketPath
    }

    // MARK: - Connect / Disconnect

    public func connect() throws {
        lock.withLock {
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = socketPath.utf8CString
            withUnsafeMutableBytes(of: &addr.sun_path) { buf in
                pathBytes.withUnsafeBytes { src in
                    let count = min(src.count, buf.count - 1)
                    buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(count)))
                }
            }

            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else {
                print("[DaemonConnection:\(extensionId)] socket() failed: \(errno)")
                return
            }

            let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let result = withUnsafePointer(to: addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, addrLen)
                }
            }

            guard result == 0 else {
                close(fd)
                print("[DaemonConnection:\(extensionId)] connect() failed: \(errno)")
                return
            }

            self.socketFD = fd
            self.fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        }

        guard isConnected else {
            throw DaemonIPCError.connectionFailed(extensionId)
        }

        // Start background read loop
        startReadLoop()
    }

    public func disconnect() {
        lock.withLock {
            if socketFD >= 0 {
                close(socketFD)
                socketFD = -1
                fileHandle = nil
            }
        }
        // Cancel all pending requests
        pendingLock.withLock {
            for (_, cb) in pending { cb(nil) }
            pending.removeAll()
        }
    }

    // MARK: - Sending

    /// Send a query and call the completion with raw result JSON data (or nil on error/timeout).
    public func sendQuery(
        _ input: ExtensionInput,
        timeout: TimeInterval = 2.0,
        completion: @escaping (Data?) -> Void
    ) {
        guard let payloadData = try? JSONEncoder().encode(input) else {
            completion(nil)
            return
        }
        let reqId = UUID().uuidString
        let msg = DaemonMessage(id: reqId, type: "query", payload: payloadData)
        send(msg)

        pendingLock.withLock { pending[reqId] = completion }

        // Timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            self.pendingLock.withLock {
                if let cb = self.pending.removeValue(forKey: reqId) {
                    cb(nil)
                }
            }
        }
    }

    /// Send an action (fire-and-forget; daemon may push ext_commands back).
    public func sendAction(_ input: ExtensionInput) {
        guard let payloadData = try? JSONEncoder().encode(input) else { return }
        let msg = DaemonMessage(id: UUID().uuidString, type: "action", payload: payloadData)
        send(msg)
    }

    /// Health-check. Returns true if daemon responds within 3 seconds.
    public func healthCheck(timeout: TimeInterval = 3.0, completion: @escaping (Bool) -> Void) {
        let reqId = UUID().uuidString
        let msg = DaemonMessage(id: reqId, type: "health")
        send(msg)

        pendingLock.withLock {
            pending[reqId] = { _ in completion(true) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            self.pendingLock.withLock {
                if let cb = self.pending.removeValue(forKey: reqId) {
                    cb(nil)  // nil = timed out → unhealthy
                }
            }
        }
    }

    /// Send a graceful stop request.
    public func sendStop() {
        send(DaemonMessage(type: "stop"))
    }

    // MARK: - Internal

    private func send(_ message: DaemonMessage) {
        guard let data = try? JSONEncoder().encode(message),
            let line = String(data: data, encoding: .utf8)
        else { return }
        let lineWithNewline = line + "\n"
        guard let bytes = lineWithNewline.data(using: .utf8) else { return }
        lock.withLock {
            fileHandle?.write(bytes)
        }
    }

    private func startReadLoop() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var buffer = Data()

            while self.isConnected {
                guard self.socketFD >= 0 else { break }

                // Read available data (blocking via low-level read for simplicity)
                var chunk = [UInt8](repeating: 0, count: 4096)
                let n = read(self.socketFD, &chunk, chunk.count)
                if n <= 0 { break }  // EOF or error
                buffer.append(contentsOf: chunk.prefix(n))

                // Extract complete newline-delimited messages
                while let newlineIdx = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer[buffer.startIndex..<newlineIdx]
                    buffer.removeSubrange(buffer.startIndex...newlineIdx)

                    if let msg = try? JSONDecoder().decode(DaemonMessage.self, from: lineData) {
                        self.handleMessage(msg)
                    }
                }
            }
        }
    }

    private func handleMessage(_ msg: DaemonMessage) {
        switch msg.type {
        case "response", "health_response":
            // Resolve pending request
            if let reqId = msg.id {
                let cb = pendingLock.withLock { pending.removeValue(forKey: reqId) }
                cb?(msg.payload)
            }

        case "ext_command":
            // Unsolicited push from daemon — parse commands and forward to host
            if let data = msg.payload,
                let response = try? JSONDecoder().decode(ExtensionActionResponse.self, from: data)
            {
                let commands = response.commands ?? []
                DispatchQueue.main.async { [weak self] in
                    self?.onExtCommand?(commands)
                }
            }

        default:
            print("[DaemonConnection:\(extensionId)] Unknown message type: \(msg.type)")
        }
    }
}

// MARK: - Errors

public enum DaemonIPCError: Error {
    case connectionFailed(String)
    case socketTimeout(String)
}
