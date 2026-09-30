import Foundation
import XCTest
@testable import MABS13PluginUpdate

final class ConverterVerificationTests: XCTestCase {
    private var tempDirectory: String!
    private var testPluginXML: String!
    private var runner: StubCommandRunner!

    override func setUp() {
        super.setUp()

        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-verify-" + UUID().uuidString
        do {
            try Foundation.FileManager.default.createDirectory(
                atPath: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        testPluginXML = tempDirectory.appendingPathComponent("plugin.xml")
        runner = StubCommandRunner()
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    private func writePluginXML() throws {
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.verify" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.swift"/>
            </platform>
        </plugin>
        """.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
    }

    private func makeOptions(verify: Bool, dryRun: Bool = false) -> ConversionOptions {
        ConversionOptions(
            force: true,
            dryRun: dryRun,
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: testPluginXML,
            verify: verify
        )
    }

    func testVerificationRunsWhenRequested() async throws {
        try writePluginXML()

        let success = await CordovaToSPMConverter(
            options: makeOptions(verify: true),
            commandRunner: runner
        ).convert()

        XCTAssertTrue(success)
        XCTAssertTrue(runner.invocations.contains { $0.executable == "swift" })
        XCTAssertEqual(runner.buildInvocation?.arguments.first, "-scheme")
        XCTAssertEqual(runner.buildInvocation?.arguments[1], "com.example.verify")
    }

    func testConversionFailsWhenVerificationFails() async throws {
        try writePluginXML()
        runner.results["xcodebuild"] = CommandResult(status: 65, output: "error: no such module 'Cordova'")

        let success = await CordovaToSPMConverter(
            options: makeOptions(verify: true),
            commandRunner: runner
        ).convert()

        XCTAssertFalse(success, "A package that does not build must not be reported as converted")
    }

    func testVerificationIsSkippedInDryRun() async throws {
        try writePluginXML()

        let success = await CordovaToSPMConverter(
            options: makeOptions(verify: true, dryRun: true),
            commandRunner: runner
        ).convert()

        XCTAssertTrue(success)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testNothingIsRunWithoutTheFlag() async throws {
        try writePluginXML()

        let success = await CordovaToSPMConverter(
            options: makeOptions(verify: false),
            commandRunner: runner
        ).convert()

        XCTAssertTrue(success)
        XCTAssertTrue(runner.invocations.isEmpty)
    }
}
