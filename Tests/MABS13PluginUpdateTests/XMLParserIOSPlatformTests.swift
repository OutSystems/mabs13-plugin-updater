import XCTest
@testable import MABS13PluginUpdate

/// Everything this tool writes is iOS-only, so a plugin that declares no `<platform name="ios">`
/// has to be recognised as such and refused rather than handed a Package.swift it cannot use.
final class XMLParserIOSPlatformTests: XCTestCase {
    private func makePluginXML(platforms: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="com.example.testplugin"
                version="1.0.0">
        \(platforms)
        </plugin>
        """
    }

    func testAnIOSPlatformIsDetected() throws {
        // Arrange
        let xmlContent = makePluginXML(platforms: """
            <platform name="ios">
                <source-file src="src/ios/Plugin.swift"/>
            </platform>
        """)

        // Act
        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Assert
        XCTAssertTrue(metadata.hasIOSPlatform)
    }

    func testAnAndroidOnlyPluginHasNoIOSPlatform() throws {
        // Arrange
        let xmlContent = makePluginXML(platforms: """
            <platform name="android">
                <source-file src="src/android/Plugin.java" target-dir="src/com/example"/>
            </platform>
        """)

        // Act
        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Assert
        XCTAssertFalse(metadata.hasIOSPlatform)
    }

    func testAPluginWithNoPlatformAtAllHasNoIOSPlatform() throws {
        // Arrange
        let xmlContent = makePluginXML(platforms: "    <js-module src=\"www/plugin.js\"/>")

        // Act
        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Assert
        XCTAssertFalse(metadata.hasIOSPlatform)
    }

    func testAnEmptyIOSPlatformStillCounts() throws {
        // Arrange: nothing to read inside it, but the plugin does target iOS
        let xmlContent = makePluginXML(platforms: """
            <platform name="android"/>
            <platform name="ios"/>
        """)

        // Act
        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Assert
        XCTAssertTrue(metadata.hasIOSPlatform)
        XCTAssertFalse(metadata.hasPodspec)
    }

    func testTheIOSPlatformNameIsMatchedCaseInsensitively() throws {
        // Arrange
        let xmlContent = makePluginXML(platforms: "    <platform name=\"iOS\"/>")

        // Act
        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Assert
        XCTAssertTrue(metadata.hasIOSPlatform)
    }

    func testMetadataBuiltByHandAssumesAnIOSPlatform() {
        // Arrange / Act: only the parser can observe the absence, so the default must not refuse
        let metadata = PluginMetadata(
            pluginId: "com.example.testplugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        // Assert
        XCTAssertTrue(metadata.hasIOSPlatform)
    }

    func testTheRefusalNamesThePluginAndTheMissingPlatform() {
        // Arrange
        let error = XMLParsingError.noIOSPlatform("com.example.androidonly")

        // Act
        let message = error.errorDescription

        // Assert
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("com.example.androidonly") == true)
        XCTAssertTrue(message?.contains("<platform name=\"ios\">") == true)
    }
}
