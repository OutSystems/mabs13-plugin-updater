import Foundation

/// ANSI color codes for terminal output
public enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"

    /// Apply color to text
    public func colorize(_ text: String) -> String {
        rawValue + text + ANSIColor.reset.rawValue
    }
}

/// Log levels for different types of messages
public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case success = "SUCCESS"

    /// Color associated with each log level
    public var color: ANSIColor {
        switch self {
        case .debug: .magenta
        case .info: .cyan
        case .warn: .yellow
        case .error: .red
        case .success: .green
        }
    }

    /// Prefix for log messages
    public var prefix: String {
        "[\(rawValue)]"
    }
}

/// Logger class with color support and level filtering.
/// Thread-safe: concurrent async tasks can log without interleaving lines.
public class Logger {
    private let verbose: Bool
    private let noColor: Bool
    private let queue = DispatchQueue(label: "cdv2spm.logger")

    public init(verbose: Bool = false, noColor: Bool = false) {
        self.verbose = verbose
        self.noColor = noColor
    }

    /// Log a message with specified level
    /// - Parameters:
    ///   - level: Log level
    ///   - message: Message to log
    public func log(_ level: LogLevel, _ message: String) {
        // Skip debug messages unless verbose mode is enabled
        if level == .debug, !verbose {
            return
        }

        let prefix = level.prefix
        let coloredMessage = noColor ? "\(prefix) \(message)" : level.color.colorize("\(prefix) \(message)")

        queue.sync {
            if level == .error {
                fputs(coloredMessage + "\n", stderr)
            } else {
                print(coloredMessage)
            }
        }
    }

    /// Convenience methods for different log levels
    public func debug(_ message: String) {
        log(.debug, message)
    }

    public func info(_ message: String) {
        log(.info, message)
    }

    public func warn(_ message: String) {
        log(.warn, message)
    }

    public func error(_ message: String) {
        log(.error, message)
    }

    public func success(_ message: String) {
        log(.success, message)
    }
}

/// Handles user interaction and confirmation dialogs
public class UserInteraction {
    private let force: Bool
    private let logger: Logger

    public init(force: Bool = false, logger: Logger) {
        self.force = force
        self.logger = logger
    }

    /// Ask user for confirmation
    /// - Parameters:
    ///   - message: Question to ask the user
    ///   - defaultYes: Default answer if user just presses enter
    /// - Returns: true if user confirms, false otherwise
    public func confirmAction(_ message: String, defaultYes: Bool = true) -> Bool {
        // Skip confirmation if force flag is set
        if force {
            logger.debug("Force mode enabled, automatically confirming: \(message)")
            return true
        }

        let suffix = defaultYes ? " (Y/n): " : " (y/N): "
        print(message + suffix, terminator: "")

        guard let input = readLine() else {
            return defaultYes
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.isEmpty {
            return defaultYes
        }

        return trimmed == "y" || trimmed == "yes"
    }

    /// Display a separator line
    /// - Parameter character: Character to use for the line
    /// - Parameter length: Length of the line
    public func printSeparator(_ character: Character = "=", length: Int = 60) {
        print(String(repeating: character, count: length))
    }

    /// Display important information box
    /// - Parameter message: Message to display
    public func printImportantMessage(_ message: String) {
        printSeparator()
        print("[IMPORTANT] \(message)")
        printSeparator()
    }
}
