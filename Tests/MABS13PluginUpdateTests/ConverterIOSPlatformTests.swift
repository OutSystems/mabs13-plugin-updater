import Foundation
import XCTest
@testable import MABS13PluginUpdate

/// End-to-end cover for the refusal: a plugin with no iOS platform must come out of a run exactly
/// as it went in, with a non-success result, rather than gaining a Package.swift it cannot use.
final class ConverterIOSPlatformTests: XCTestCase {
    private var tempDirectory: String!
    private var pluginXMLPath: String!

    override func setUp() {
        super.setUp()

        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-ios-platform-tests-" + UUID().uuidString
        do {
            try Foundation.FileManager.default.createDirectory(
                atPath: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        pluginXMLPath = tempDirectory.appendingPathComponent("plugin.xml")
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    private func makeOptions() -> ConversionOptions {
        ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: pluginXMLPath
        )
    }

    func testAnAndroidOnlyPluginIsRefusedAndNothingIsWritten() async throws {
        // Arrange: a real Cordova plugin with no iOS implementation at all
        let pluginXMLContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="com.example.androidonly"
                version="1.0.0">
            <name>Android Only Plugin</name>
        
            <platform name="android">
                <source-file src="src/android/Plugin.java" target-dir="src/com/example"/>
            </platform>
        </plugin>
        """

        try pluginXMLContent.write(toFile: pluginXMLPath, atomically: true, encoding: .utf8)

        // Act
        let converter = CordovaToSPMConverter(options: makeOptions())
        let success = await converter.convert()

        // Assert: refused, and the plugin is left exactly as it was
        XCTAssertFalse(success, "A plugin with no iOS platform should be refused")

        let packageSwiftPath = tempDirectory.appendingPathComponent("Package.swift")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: packageSwiftPath),
            "No Package.swift should be written for a plugin with no iOS platform"
        )

        let unchangedXML = try String(contentsOfFile: pluginXMLPath)
        XCTAssertEqual(unchangedXML, pluginXMLContent)
    }

    func testAPluginWithAnIOSPlatformIsStillConverted() async throws {
        // Arrange: the same shape, with an iOS platform added
        let pluginXMLContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="com.example.crossplatform"
                version="1.0.0">
            <name>Cross Platform Plugin</name>
        
            <platform name="android">
                <source-file src="src/android/Plugin.java" target-dir="src/com/example"/>
            </platform>
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """

        try pluginXMLContent.write(toFile: pluginXMLPath, atomically: true, encoding: .utf8)

        // Act
        let converter = CordovaToSPMConverter(options: makeOptions())
        let success = await converter.convert()

        // Assert
        XCTAssertTrue(success, "A plugin that declares an iOS platform should still convert")

        let packageSwiftPath = tempDirectory.appendingPathComponent("Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageSwiftPath))
    }
}
