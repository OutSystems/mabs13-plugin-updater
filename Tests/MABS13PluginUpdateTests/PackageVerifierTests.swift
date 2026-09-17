import XCTest
@testable import MABS13PluginUpdate

/// Records the commands it is asked to run and replies with canned results.
final class StubCommandRunner: CommandRunning {
    struct Invocation: Equatable {
        let executable: String
        let arguments: [String]
        let workingDirectory: String?
    }

    private(set) var invocations: [Invocation] = []
    /// Keyed by executable name; the default is a success
    var results: [String: CommandResult] = [:]
    /// Result for `xcodebuild -version`, the availability probe
    var xcodeAvailable = true

    func run(_ executable: String, arguments: [String], workingDirectory: String?) -> CommandResult {
        invocations.append(
            Invocation(executable: executable, arguments: arguments, workingDirectory: workingDirectory)
        )

        if executable == "xcodebuild", arguments == ["-version"] {
            return xcodeAvailable
                ? CommandResult(status: 0, output: "Xcode 26.0")
                : CommandResult(status: 127, output: "xcodebuild: command not found")
        }

        return results[executable] ?? CommandResult(status: 0, output: "")
    }

    var buildInvocation: Invocation? {
        invocations.first { $0.executable == "xcodebuild" && $0.arguments != ["-version"] }
    }
}

final class PackageVerifierTests: XCTestCase {
    private var runner: StubCommandRunner!
    private var verifier: PackageVerifier!

    override func setUp() {
        super.setUp()
        runner = StubCommandRunner()
        verifier = PackageVerifier(logger: Logger(verbose: false), runner: runner)
    }

    func testBothStepsPass() {
        let report = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        XCTAssertTrue(report.succeeded)
        XCTAssertEqual(report.steps.map(\.outcome), [.passed, .passed])
    }

    func testManifestIsLoadedWithSwiftPM() {
        _ = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        let manifestInvocation = runner.invocations.first { $0.executable == "swift" }
        XCTAssertEqual(
            manifestInvocation,
            StubCommandRunner.Invocation(
                executable: "swift",
                arguments: ["package", "dump-package", "--package-path", "/tmp/plugin"],
                workingDirectory: "/tmp/plugin"
            )
        )
    }

    func testBuildTargetsIOSAndTheProductScheme() {
        _ = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        let build = runner.buildInvocation
        XCTAssertEqual(build?.workingDirectory, "/tmp/plugin")
        XCTAssertEqual(build?.arguments, [
            "-scheme", "com.example.plugin",
            "-destination", "generic/platform=iOS",
            "-derivedDataPath", ".build/verify",
            "-quiet",
            "build"
        ])
    }

    func testFailingManifestSkipsTheBuild() {
        runner.results["swift"] = CommandResult(status: 1, output: "error: invalid manifest")

        let report = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        XCTAssertFalse(report.succeeded)
        XCTAssertEqual(report.steps[0].outcome, .failed("error: invalid manifest"))
        XCTAssertEqual(report.steps[1].outcome, .skipped("the manifest could not be loaded"))
        XCTAssertNil(runner.buildInvocation)
    }

    func testFailingBuildFailsTheReportAndKeepsTheOutput() {
        runner.results["xcodebuild"] = CommandResult(status: 65, output: "error: cannot find 'Data' in scope")

        let report = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        XCTAssertFalse(report.succeeded)
        XCTAssertEqual(report.steps[1].outcome, .failed("error: cannot find 'Data' in scope"))
    }

    func testMissingXcodeSkipsTheBuildWithoutFailing() {
        runner.xcodeAvailable = false

        let report = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        XCTAssertTrue(report.succeeded)
        XCTAssertEqual(report.steps[1].outcome, .skipped("xcodebuild is not available"))
        XCTAssertNil(runner.buildInvocation)
    }

    func testStepsCarryTheCommandThatWasRun() {
        let report = verifier.verify(packageDirectory: "/tmp/plugin", productName: "com.example.plugin")

        XCTAssertEqual(report.steps[0].command, "swift package dump-package --package-path /tmp/plugin")
        XCTAssertTrue(report.steps[1].command.hasPrefix("xcodebuild -scheme com.example.plugin"))
    }
}

final class ProcessCommandRunnerTests: XCTestCase {
    private let runner = ProcessCommandRunner()

    func testCapturesOutputAndSuccess() {
        let result = runner.run("echo", arguments: ["hello"], workingDirectory: nil)

        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.output.contains("hello"))
    }

    func testCapturesExitStatus() {
        let result = runner.run("sh", arguments: ["-c", "exit 3"], workingDirectory: nil)

        XCTAssertEqual(result.status, 3)
        XCTAssertFalse(result.succeeded)
    }

    func testCapturesStandardError() {
        let result = runner.run("sh", arguments: ["-c", "echo boom >&2; exit 1"], workingDirectory: nil)

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.output.contains("boom"))
    }

    func testRunsInTheGivenDirectory() {
        let result = runner.run("pwd", arguments: [], workingDirectory: "/tmp")

        XCTAssertTrue(result.succeeded)
        // /tmp is a symlink to /private/tmp on macOS
        XCTAssertTrue(result.output.contains("tmp"))
    }

    func testUnknownExecutableFails() {
        let result = runner.run("definitely-not-a-command-\(UUID().uuidString)", arguments: [], workingDirectory: nil)

        XCTAssertFalse(result.succeeded)
    }
}
