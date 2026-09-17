import XCTest
@testable import MABS13PluginUpdate

final class XMLParserDeploymentTargetTests: XCTestCase {
    private func parse(_ platformBody: String) throws -> PluginMetadata {
        try XMLParser.parsePluginXML(content: """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
        \(platformBody)
            </platform>
        </plugin>
        """)
    }

    func testDeploymentTargetPreferenceWithValue() throws {
        let metadata = try parse("""
                <preference name="deployment-target" value="16.0"/>
        """)

        XCTAssertEqual(metadata.deploymentTarget, IOSPlatformVersion(major: 16))
    }

    func testDeploymentTargetPreferenceWithDefault() throws {
        let metadata = try parse("""
                <preference name="deployment-target" default="16.4"/>
        """)

        XCTAssertEqual(metadata.deploymentTarget, IOSPlatformVersion(major: 16, minor: 4))
    }

    func testDeploymentTargetInsideConfigFile() throws {
        let metadata = try parse("""
                <config-file parent="/*" target="config.xml">
                    <preference name="SwiftVersion" value="5"/>
                    <preference name="IPHONEOS_DEPLOYMENT_TARGET" value="17.0"/>
                </config-file>
        """)

        XCTAssertEqual(metadata.deploymentTarget, IOSPlatformVersion(major: 17))
    }

    func testHighestDeploymentTargetWins() throws {
        let metadata = try parse("""
                <preference name="deployment-target" value="15.0"/>
                <preference name="iphoneos-deployment-target" value="16.2"/>
        """)

        XCTAssertEqual(metadata.deploymentTarget, IOSPlatformVersion(major: 16, minor: 2))
    }

    func testUnrelatedPreferencesAreIgnored() throws {
        let metadata = try parse("""
                <preference name="SwiftVersion" value="5"/>
        """)

        XCTAssertNil(metadata.deploymentTarget)
    }

    func testNonVersionDeploymentTargetIsIgnored() throws {
        let metadata = try parse("""
                <preference name="deployment-target" value="$IOS_TARGET"/>
        """)

        XCTAssertNil(metadata.deploymentTarget)
    }

    func testNoPreferenceAtAll() throws {
        let metadata = try parse("""
                <source-file src="src/ios/Plugin.swift"/>
        """)

        XCTAssertNil(metadata.deploymentTarget)
    }
}
