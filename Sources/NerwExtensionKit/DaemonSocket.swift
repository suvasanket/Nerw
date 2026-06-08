import Foundation

// MARK: - DaemonSocketServer

/// Extension-side Unix domain socket server.
/// Accepts exactly ONE connection (from the Nerw host) and provides
/// a blocking message loop for the daemon protocol.
///
/// Uses only Foundation + POSIX — no external dependencies.
final class DaemonSocketServer {
    let socketPath: String

    private var serverFD: Int32 = -1
    private var clientFD: Int32 = -1

    // Buffer for partial NDJSON lines from the client
    private var readBuffer = Data()

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    // MARK: - Start / Stop

    /// Creates the socket, binds, listens, and blocks until one client connects.
    /// Call this before entering the message loop.
    func start() throws {
        // Create socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DaemonSocketError.socketCreationFailed(Int(errno))
        }
        serverFD = fd

        // Set SO_REUSEADDR
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Remove stale socket file
        unlink(socketPath)

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
            close(fd)
            throw DaemonSocketError.bindFailed(Int(errno))
        }

        // Listen (backlog of 1 — only Nerw host connects)
        guard listen(fd, 1) == 0 else {
            close(fd)
            throw DaemonSocketError.listenFailed(Int(errno))
        }

        Nerw.log("DaemonSocket: Listening on \(socketPath)")

        // Accept the single Nerw host connection (blocking)
        let client = accept(fd, nil, nil)
        guard client >= 0 else {
            close(fd)
            throw DaemonSocketError.acceptFailed(Int(errno))
        }
        clientFD = client
        Nerw.log("DaemonSocket: Host connected.")
    }

    /// Closes both sockets and removes the socket file.
    func stop() {
        if clientFD >= 0 {
            close(clientFD)
            clientFD = -1
        }
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        unlink(socketPath)
        Nerw.log("DaemonSocket: Stopped.")
    }

    // MARK: - Message I/O

    /// Blocking read of the next complete NDJSON line from the host.
    /// Returns nil when the connection is closed or an error occurs.
    func readMessage() -> DaemonSocketMessage? {
        while true {
            // Check if we already have a complete line in the buffer
            if let newlineIdx = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer[readBuffer.startIndex..<newlineIdx]
                readBuffer.removeSubrange(readBuffer.startIndex...newlineIdx)
                if let msg = try? JSONDecoder().decode(DaemonSocketMessage.self, from: lineData) {
                    return msg
                }
                continue  // Invalid JSON — skip and try next line
            }

            // Read more data
            var chunk = [UInt8](repeating: 0, count: 4096)
            let n = read(clientFD, &chunk, chunk.count)
            if n <= 0 { return nil }  // EOF or error
            readBuffer.append(contentsOf: chunk.prefix(n))
        }
    }

    /// Write a message as an NDJSON line to the host.
    func sendMessage(_ msg: DaemonSocketMessage) {
        guard clientFD >= 0,
            let data = try? JSONEncoder().encode(msg),
            let line = String(data: data, encoding: .utf8)
        else { return }
        let bytes = (line + "\n").data(using: .utf8)!
        _ = bytes.withUnsafeBytes { write(clientFD, $0.baseAddress!, $0.count) }
    }
}

// MARK: - DaemonSocketMessage

/// NDJSON envelope for daemon protocol messages (extension-side mirror of DaemonMessage in host).
struct DaemonSocketMessage: Codable {
    let id: String?
    let type: String
    let payload: String?  // Base64-encoded JSON payload

    init(id: String? = nil, type: String, payload: Data? = nil) {
        self.id = id
        self.type = type
        self.payload = payload?.base64EncodedString()
    }

    var payloadData: Data? {
        payload.flatMap { Data(base64Encoded: $0) }
    }
}

// MARK: - Errors

enum DaemonSocketError: Error {
    case socketCreationFailed(Int)
    case bindFailed(Int)
    case listenFailed(Int)
    case acceptFailed(Int)
}
