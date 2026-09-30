import Foundation

/// Result of running an external command.
public struct CommandResult: Equatable {
    public let status: Int32
    /// Standard output and standard error, combined, which is what an operator needs to read
    /// when a build fails
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }

    public var succeeded: Bool {
        status == 0
    }
}

/// Runs external commands. Abstracted so verification can be tested without invoking a toolchain.
public protocol CommandRunning {
    func run(_ executable: String, arguments: [String], workingDirectory: String?) -> CommandResult
}

/// Runs commands with `Process`, resolving the executable through `PATH`.
public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String], workingDirectory: String?) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: "Failed to run \(executable): \(error.localizedDescription)")
        }

        // Read before waiting, so a command that fills the pipe buffer cannot deadlock
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return CommandResult(
            status: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? ""
        )
    }
}
