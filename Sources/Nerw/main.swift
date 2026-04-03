// main.swift
import Cocoa
import NerwUtils

_ = Logger.shared

setupCrashHandler()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// MARK: - Crash Handler

private func setupCrashHandler() {
    Logger.shared.info("Nerw starting - log file: \(Logger.shared.currentLogFile.path)")

    signal(SIGSEGV) { sig in
        Logger.shared.error("CRASH: Received SIGSEGV signal")
        Logger.shared.flush()
        exit(128 + sig)
    }

    signal(SIGABRT) { sig in
        Logger.shared.error("CRASH: Received SIGABRT signal")
        Logger.shared.flush()
        exit(128 + sig)
    }

    signal(SIGBUS) { sig in
        Logger.shared.error("CRASH: Received SIGBUS signal")
        Logger.shared.flush()
        exit(128 + sig)
    }

    signal(SIGFPE) { sig in
        Logger.shared.error("CRASH: Received SIGFPE signal")
        Logger.shared.flush()
        exit(128 + sig)
    }

    signal(SIGILL) { sig in
        Logger.shared.error("CRASH: Received SIGILL signal")
        Logger.shared.flush()
        exit(128 + sig)
    }
}
