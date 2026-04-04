import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
}

final class MDLogger {
    static let shared = MDLogger()

    private let logDir: URL
    private let logFile: URL
    private let maxSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private let maxRotated = 3
    private let queue = DispatchQueue(label: "nl.robinvanbaalen.mdreader.logger")
    private var handle: FileHandle?
    private let isDevMode: Bool
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        isDevMode = ProcessInfo.processInfo.environment["MDREADER_DEV"] == "1"

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDir = appSupport.appendingPathComponent("mdreader/logs")
        logFile = logDir.appendingPathComponent("mdreader.log")

        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: logFile)
        handle?.seekToEndOfFile()
    }

    deinit {
        try? handle?.close()
    }

    // MARK: - Public API

    func debug(_ message: String, component: String = "App") {
        write(.debug, component: component, message: message)
    }
    func info(_ message: String, component: String = "App") {
        write(.info, component: component, message: message)
    }
    func warn(_ message: String, component: String = "App") {
        write(.warn, component: component, message: message)
    }
    func error(_ message: String, component: String = "App") {
        write(.error, component: component, message: message)
    }

    /// Returns the full log contents for sharing
    func logContents() -> String {
        queue.sync {
            (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        }
    }

    /// Returns the path to the log directory
    var logDirectoryPath: String { logDir.path }

    /// Returns the path to the current log file
    var logFilePath: String { logFile.path }

    // MARK: - Internals

    private func write(_ level: LogLevel, component: String, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(component)] \(message)\n"

        queue.async { [self] in
            // Always write to log file
            if let data = line.data(using: .utf8) {
                handle?.write(data)
            }

            // In dev mode, also print to stderr (visible in terminal)
            if isDevMode {
                FileHandle.standardError.write(line.data(using: .utf8) ?? Data())
            }

            // Rotate if needed
            rotateIfNeeded()
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? UInt64, size > maxSize else { return }

        try? handle?.close()
        handle = nil

        // Shift old logs: mdreader.3.log → delete, .2 → .3, .1 → .2, current → .1
        let fm = FileManager.default
        for i in stride(from: maxRotated, through: 1, by: -1) {
            let old = logDir.appendingPathComponent("mdreader.\(i).log")
            if i == maxRotated {
                try? fm.removeItem(at: old)
            } else {
                let dest = logDir.appendingPathComponent("mdreader.\(i + 1).log")
                try? fm.moveItem(at: old, to: dest)
            }
        }
        let rotated = logDir.appendingPathComponent("mdreader.1.log")
        try? fm.moveItem(at: logFile, to: rotated)
        fm.createFile(atPath: logFile.path, contents: nil)
        handle = try? FileHandle(forWritingTo: logFile)
    }
}

// Convenience
let log = MDLogger.shared
