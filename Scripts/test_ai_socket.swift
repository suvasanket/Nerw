#!/usr/bin/env swift
import Foundation

// MARK: - Protocol Models

struct AIChatRequestPayload: Codable {
    let prompt: String
    let images: [String]
    let isStreaming: Bool
}

struct AISocketMessage: Codable {
    let id: String?
    let type: String
    let payload: String?
}

struct AIChatResponsePayload: Codable {
    let text: String
    let error: String?
    let isDone: Bool
}

// MARK: - Main Script Execution

func main() {
    // 1. Resolve socket path
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let socketPath = homeDir.appendingPathComponent(".nerw/run/ai.sock").path

    // Allow custom prompt from command line arguments
    var prompt = "Explain quantum computing in one sentence."
    if CommandLine.arguments.count > 1 {
        prompt = CommandLine.arguments[1...].joined(separator: " ")
    }

    print("--------------------------------------------------")
    print("Nerw AI Socket Test Client")
    print("Connecting to socket: \(socketPath)")
    print("Prompt: \"\(prompt)\"")
    print("--------------------------------------------------")

    // 2. Create Socket
    let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard socketFD >= 0 else {
        print("Error: socket() failed with errno \(errno)")
        exit(1)
    }
    defer { close(socketFD) }

    // 3. Connect to server
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
    let connectResult = withUnsafePointer(to: addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(socketFD, $0, addrLen)
        }
    }

    guard connectResult == 0 else {
        print("Error: Could not connect to Nerw AI socket server. errno=\(errno)")
        print(
            "Tip: Make sure Nerw is running, and that you have enabled 'AI Assistant' in settings (AI tab)."
        )
        exit(1)
    }

    print("Connected successfully. Sending request...")

    // 4. Send request message
    let reqPayload = AIChatRequestPayload(prompt: prompt, images: [], isStreaming: true)
    guard let payloadData = try? JSONEncoder().encode(reqPayload) else {
        print("Error: Failed to serialize request payload.")
        exit(1)
    }

    let reqMsg = AISocketMessage(
        id: UUID().uuidString,
        type: "chat_request",
        payload: payloadData.base64EncodedString()
    )

    guard let reqMsgData = try? JSONEncoder().encode(reqMsg),
        let reqLine = String(data: reqMsgData, encoding: .utf8)
    else {
        print("Error: Failed to serialize envelope.")
        exit(1)
    }

    let sendBytes = (reqLine + "\n").data(using: .utf8)!
    let bytesSent = sendBytes.withUnsafeBytes { write(socketFD, $0.baseAddress!, $0.count) }
    guard bytesSent == sendBytes.count else {
        print("Error: Failed to write complete message to socket.")
        exit(1)
    }

    print("Request sent. Streaming response:")
    print("---")

    // 5. Read stream of responses
    var readBuffer = Data()
    var isDone = false

    while !isDone {
        // Look for newline
        if let newlineIdx = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = readBuffer[readBuffer.startIndex..<newlineIdx]
            readBuffer.removeSubrange(readBuffer.startIndex...newlineIdx)

            if let msg = try? JSONDecoder().decode(AISocketMessage.self, from: lineData) {
                if let payloadBase64 = msg.payload,
                    let payloadData = Data(base64Encoded: payloadBase64),
                    let resPayload = try? JSONDecoder().decode(
                        AIChatResponsePayload.self, from: payloadData)
                {

                    if let error = resPayload.error {
                        print("\n[AI Socket Error]: \(error)")
                        isDone = true
                    } else {
                        // Print the text delta chunk immediately
                        print(resPayload.text, terminator: "")
                        fflush(stdout)

                        if resPayload.isDone {
                            isDone = true
                        }
                    }
                }
            }
            continue
        }

        // Read data chunk
        var chunk = [UInt8](repeating: 0, count: 2048)
        let n = read(socketFD, &chunk, chunk.count)
        if n <= 0 {
            print("\n[Connection closed by server]")
            break
        }
        readBuffer.append(contentsOf: chunk.prefix(n))
    }

    print("\n---")
    print("Stream finished.")
}

main()
