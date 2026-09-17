import XCTest
@testable import MABS13PluginUpdate

/// Covers scanning source directories other than `src/ios`, the layout used by plugins that keep
/// their iOS code under a monorepo path such as `packages/cordova-plugin/ios`.
final class SwiftImportManagerSourceDirectoryTests: XCTestCase {
    private var tempDirectory: URL!
    private var swiftImportManager: SwiftImportManager!

    override func setUp() {
        super.setUp()

        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftImportManagerSourceDirTests-\(UUID().uuidString)")

        do {
            try Foundation.FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }

        let logger = Logger(verbose: false)
        swiftImportManager = SwiftImportManager(
            logger: logger,
            fileManager: FileSystemManager(logger: logger, dryRun: false)
        )
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    @discardableResult
    private func writePluginFile(at relativePath: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(relativePath)
        try Foundation.FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private var pluginSource: String {
        """
        import Foundation

        @objc(OSFilePlugin)
        class OSFilePlugin: CDVPlugin {
        }
        """
    }

    func testProcessesSourcesOutsideSrcIOS() throws {
        let file = try writePluginFile(
            at: "packages/cordova-plugin/ios/OSFilePlugin.swift",
            content: pluginSource
        )

        let success = swiftImportManager.addCordovaImports(
            in: tempDirectory.path,
            sourceDirectories: ["packages/cordova-plugin/ios"]
        )

        XCTAssertTrue(success)
        XCTAssertTrue(try String(contentsOf: file).contains("#if canImport(Cordova)"))
    }

    func testDefaultDirectoryRemainsSrcIOS() throws {
        let file = try writePluginFile(at: "src/ios/OSFilePlugin.swift", content: pluginSource)

        XCTAssertTrue(swiftImportManager.addCordovaImports(in: tempDirectory.path))
        XCTAssertTrue(try String(contentsOf: file).contains("#if canImport(Cordova)"))
    }

    func testSourcesOutsideSrcIOSAreLeftAloneWhenNotDeclared() throws {
        let file = try writePluginFile(
            at: "packages/cordova-plugin/ios/OSFilePlugin.swift",
            content: pluginSource
        )

        // Only src/ios is scanned, and it does not exist here
        XCTAssertTrue(swiftImportManager.addCordovaImports(in: tempDirectory.path))
        XCTAssertFalse(try String(contentsOf: file).contains("#if canImport(Cordova)"))
    }

    func testProcessesSeveralDirectories() throws {
        let first = try writePluginFile(at: "packages/plugin/ios/First.swift", content: pluginSource)
        let second = try writePluginFile(at: "src/ios/Second.swift", content: pluginSource)

        let success = swiftImportManager.addCordovaImports(
            in: tempDirectory.path,
            sourceDirectories: ["packages/plugin/ios", "src/ios"]
        )

        XCTAssertTrue(success)
        XCTAssertTrue(try String(contentsOf: first).contains("#if canImport(Cordova)"))
        XCTAssertTrue(try String(contentsOf: second).contains("#if canImport(Cordova)"))
    }

    func testNestedDirectoriesProcessEachFileOnce() throws {
        let file = try writePluginFile(at: "src/ios/nested/Plugin.swift", content: pluginSource)

        let success = swiftImportManager.addCordovaImports(
            in: tempDirectory.path,
            sourceDirectories: ["src/ios", "src/ios/nested"]
        )

        XCTAssertTrue(success)
        let updated = try String(contentsOf: file)
        XCTAssertEqual(updated.components(separatedBy: "#if canImport(Cordova)").count - 1, 1)
    }

    func testMissingDirectoriesAreSkipped() throws {
        let file = try writePluginFile(at: "src/ios/Plugin.swift", content: pluginSource)

        let success = swiftImportManager.addCordovaImports(
            in: tempDirectory.path,
            sourceDirectories: ["does/not/exist", "src/ios"]
        )

        XCTAssertTrue(success)
        XCTAssertTrue(try String(contentsOf: file).contains("#if canImport(Cordova)"))
    }

    func testNoDeclaredDirectoryExists() {
        let success = swiftImportManager.addCordovaImports(
            in: tempDirectory.path,
            sourceDirectories: ["packages/cordova-plugin/ios"]
        )

        // Nothing to do is not a failure, but it must not be silent either
        XCTAssertTrue(success)
    }
}
