import Foundation
import XCTest
@testable import MABS13PluginUpdate

/// End-to-end conversion of a plugin whose iOS sources live outside `src/ios`.
final class ConverterSourceDirectoryTests: XCTestCase {
    var tempDirectory: String!
    var testPluginXML: String!

    override func setUp() {
        super.setUp()

        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-converter-srcdir-" + UUID().uuidString
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
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    func testConversionInjectsCordovaImportInDeclaredSourceDirectory() async throws {
        // A plugin that keeps its iOS sources outside src/ios, as monorepo-style plugins do
        let pluginXMLContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.monorepo" version="1.0.0">
            <platform name="ios">
                <source-file src="packages/cordova-plugin/ios/MonorepoPlugin.swift"/>
            </platform>
        </plugin>
        """

        try pluginXMLContent.write(toFile: testPluginXML, atomically: true, encoding: .utf8)

        let sourceDirectory = tempDirectory.appendingPathComponent("packages/cordova-plugin/ios")
        try Foundation.FileManager.default.createDirectory(
            atPath: sourceDirectory,
            withIntermediateDirectories: true
        )
        let swiftFile = sourceDirectory.appendingPathComponent("MonorepoPlugin.swift")
        try """
        import Foundation
        
        @objc(MonorepoPlugin)
        class MonorepoPlugin: CDVPlugin {
        }
        """.write(toFile: swiftFile, atomically: true, encoding: .utf8)

        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: testPluginXML
        )

        let success = await CordovaToSPMConverter(options: options).convert()

        XCTAssertTrue(success)

        let updatedSource = try String(contentsOfFile: swiftFile)
        XCTAssertTrue(updatedSource.contains("#if canImport(Cordova)"))
        XCTAssertTrue(updatedSource.contains("import Cordova"))

        let packageContent = try String(contentsOfFile: tempDirectory.appendingPathComponent("Package.swift"))
        XCTAssertTrue(packageContent.contains("path: \"packages/cordova-plugin/ios\""))
    }
}
