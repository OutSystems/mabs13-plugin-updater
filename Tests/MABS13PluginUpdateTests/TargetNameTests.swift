import XCTest
@testable import MABS13PluginUpdate

/// The generated manifest keeps the plugin id as package and product name, which is how Cordova
/// iOS 8 references the plugin, and names the target after the plugin's iOS class.
final class TargetNameTests: XCTestCase {
    // MARK: - plugin.xml parsing

    private func parse(_ platformBody: String) throws -> PluginMetadata {
        try XMLParser.parsePluginXML(content: """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.outsystems.plugins.filesystem" version="1.0.0">
            <platform name="ios">
        \(platformBody)
            </platform>
        </plugin>
        """)
    }

    func testIOSPackageParamInsideConfigFile() throws {
        let metadata = try parse("""
                <config-file parent="/*" target="config.xml">
                    <feature name="OSFilePlugin">
                        <param name="ios-package" value="OSFilePlugin"/>
                    </feature>
                </config-file>
        """)

        XCTAssertEqual(metadata.iosPackageClass, "OSFilePlugin")
        XCTAssertEqual(metadata.targetName, "OSFilePlugin")
    }

    func testFeatureDeclaredDirectlyUnderThePlatform() throws {
        let metadata = try parse("""
                <feature name="OSFileViewer">
                    <param name="ios-package" value="OSFileViewerPlugin"/>
                </feature>
        """)

        XCTAssertEqual(metadata.targetName, "OSFileViewerPlugin")
    }

    func testFeatureNameIsUsedWhenThereIsNoIOSPackageParam() throws {
        let metadata = try parse("""
                <config-file parent="/*" target="config.xml">
                    <feature name="OSFilePlugin">
                        <param name="onload" value="true"/>
                    </feature>
                </config-file>
        """)

        XCTAssertEqual(metadata.targetName, "OSFilePlugin")
    }

    func testAndroidPackageParamIsNotUsed() throws {
        let metadata = try XMLParser.parsePluginXML(content: """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.outsystems.plugins.filesystem" version="1.0.0">
            <platform name="android">
                <config-file parent="/*" target="res/xml/config.xml">
                    <feature name="OSFilePlugin">
                        <param name="android-package" value="com.outsystems.plugins.file.OSFilePlugin"/>
                    </feature>
                </config-file>
            </platform>
            <platform name="ios">
                <source-file src="src/ios/Plugin.swift"/>
            </platform>
        </plugin>
        """)

        XCTAssertNil(metadata.iosPackageClass)
        XCTAssertEqual(metadata.targetName, "com.outsystems.plugins.filesystem")
    }

    func testFallsBackToPluginIdWhenNoFeatureIsDeclared() throws {
        let metadata = try parse("""
                <source-file src="src/ios/Plugin.swift"/>
        """)

        XCTAssertNil(metadata.iosPackageClass)
        XCTAssertEqual(metadata.targetName, "com.outsystems.plugins.filesystem")
    }

    // MARK: - Sanitizing

    private func metadata(iosPackageClass: String?) -> PluginMetadata {
        PluginMetadata(
            pluginId: "com.example.plugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            iosPackageClass: iosPackageClass
        )
    }

    func testDottedClassNameIsReducedToAnIdentifier() {
        XCTAssertEqual(metadata(iosPackageClass: "com.example.MyPlugin").targetName, "comexampleMyPlugin")
    }

    func testUnusableClassNameFallsBackToPluginId() {
        XCTAssertEqual(metadata(iosPackageClass: "").targetName, "com.example.plugin")
        XCTAssertEqual(metadata(iosPackageClass: "   ").targetName, "com.example.plugin")
        XCTAssertEqual(metadata(iosPackageClass: "42Plugin").targetName, "com.example.plugin")
    }

    func testUnderscoresAndDigitsAreKept() {
        XCTAssertEqual(metadata(iosPackageClass: "OS_File2Plugin").targetName, "OS_File2Plugin")
    }

    // MARK: - Generated manifest

    func testManifestNamesProductAfterThePluginAndTargetAfterTheClass() throws {
        let metadata = try parse("""
                <config-file parent="/*" target="config.xml">
                    <feature name="OSFilePlugin">
                        <param name="ios-package" value="OSFilePlugin"/>
                    </feature>
                </config-file>
                <source-file src="packages/cordova-plugin/ios/OSFilePlugin.swift"/>
        """)

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("name: \"com.outsystems.plugins.filesystem\""))
        XCTAssertTrue(packageContent.contains("targets: [\"OSFilePlugin\"]"))
        XCTAssertTrue(packageContent.contains("name: \"OSFilePlugin\","))
        XCTAssertFalse(packageContent.contains("targets: [\"com.outsystems.plugins.filesystem\"]"))
    }

    func testManifestFallsBackToThePluginIdForTheTarget() {
        let packageContent = PackageGenerator.generatePackageSwift(from: metadata(iosPackageClass: nil))

        XCTAssertTrue(packageContent.contains("name: \"com.example.plugin\""))
        XCTAssertTrue(packageContent.contains("targets: [\"com.example.plugin\"]"))
    }
}
