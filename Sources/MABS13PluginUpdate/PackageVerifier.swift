import Foundation

/// What happened to one verification step.
public enum VerificationOutcome: Equatable {
    case passed
    case failed(String)
    case skipped(String)
}

/// One verification step and its result.
public struct VerificationStep: Equatable {
    public let name: String
    /// The command as it was run, so the operator can repeat it by hand
    public let command: String
    public let outcome: VerificationOutcome

    public init(name: String, command: String, outcome: VerificationOutcome) {
        self.name = name
        self.command = command
        self.outcome = outcome
    }
}

/// Outcome of verifying a generated package.
public struct VerificationReport: Equatable {
    public let steps: [VerificationStep]

    public init(steps: [VerificationStep]) {
        self.steps = steps
    }

    /// True when nothing failed. A step that could not run (no Xcode, say) does not fail the report.
    public var succeeded: Bool {
        !steps.contains { if case .failed = $0.outcome { true } else { false } }
    }
}

/// Checks that a generated package is actually buildable.
///
/// Presence checks on the generated text cannot catch an unsatisfiable platform, an invalid module
/// name or a source file missing an import — the things that turn up later as a failed MABS build.
/// Compiling the package here is what catches them, while the plugin is still on the operator's
/// machine.
public class PackageVerifier {
    private let logger: Logger
    private let runner: CommandRunning

    public init(logger: Logger, runner: CommandRunning = ProcessCommandRunner()) {
        self.logger = logger
        self.runner = runner
    }

    /// Verify the package at `packageDirectory`.
    /// - Parameters:
    ///   - packageDirectory: Directory holding the generated Package.swift
    ///   - productName: Product to build, which is the plugin id
    /// - Returns: A report with one entry per step
    public func verify(packageDirectory: String, productName: String) -> VerificationReport {
        var steps = [verifyManifest(in: packageDirectory)]

        if case .passed = steps[0].outcome {
            steps.append(buildForIOS(in: packageDirectory, productName: productName))
        } else {
            steps.append(VerificationStep(
                name: "iOS build",
                command: "",
                outcome: .skipped("the manifest could not be loaded")
            ))
        }

        return VerificationReport(steps: steps)
    }

    /// Load the manifest with SwiftPM itself, which rejects a malformed or invalid Package.swift.
    private func verifyManifest(in packageDirectory: String) -> VerificationStep {
        let arguments = ["package", "dump-package", "--package-path", packageDirectory]
        logger.info("Verifying the generated manifest...")
        let result = runner.run("swift", arguments: arguments, workingDirectory: packageDirectory)

        return VerificationStep(
            name: "Manifest",
            command: "swift " + arguments.joined(separator: " "),
            outcome: result.succeeded ? .passed : .failed(result.output)
        )
    }

    /// Build the package for iOS, the step that catches an unsatisfiable deployment target, an
    /// invalid target name and any source file that does not compile outside the app target.
    private func buildForIOS(in packageDirectory: String, productName: String) -> VerificationStep {
        let arguments = [
            "-scheme", productName,
            "-destination", "generic/platform=iOS",
            "-derivedDataPath", ".build/verify",
            "-quiet",
            "build"
        ]
        let command = "xcodebuild " + arguments.joined(separator: " ")

        guard isXcodeAvailable() else {
            logger.warn("xcodebuild is not available, so the generated package was not built for iOS")
            return VerificationStep(
                name: "iOS build",
                command: command,
                outcome: .skipped("xcodebuild is not available")
            )
        }

        logger.info("Building the generated package for iOS (this takes a while)...")
        let result = runner.run("xcodebuild", arguments: arguments, workingDirectory: packageDirectory)

        return VerificationStep(
            name: "iOS build",
            command: command,
            outcome: result.succeeded ? .passed : .failed(result.output)
        )
    }

    private func isXcodeAvailable() -> Bool {
        runner.run("xcodebuild", arguments: ["-version"], workingDirectory: nil).succeeded
    }
}
