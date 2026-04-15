import XCTest
@testable import cdv2spm

final class XMLParserPlatformTests: XCTestCase {
    func testParseXMLWithMultipleIOSPlatforms() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.multiplatform" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="FirstPod" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="SecondPod" spec="2.0.0"/>
                    </pods>
                </podspec>
            </platform>
            <platform name="android">
                <source-file src="android/Plugin.java"/>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.multiplatform")
        XCTAssertTrue(metadata.hasPodspec)

        // Should find dependencies from both iOS platforms
        XCTAssertEqual(metadata.dependencies.count, 2)
        let podNames = metadata.dependencies.map(\.name).sorted()
        XCTAssertEqual(podNames, ["FirstPod", "SecondPod"])
    }

    func testParseXMLWithEmptyPodspec() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.emptypods" version="1.0.0">
            <platform name="ios">
                <podspec>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.emptypods")
        XCTAssertTrue(metadata.hasPodspec) // Has podspec element but no pods
        XCTAssertEqual(metadata.dependencies.count, 0)
        XCTAssertFalse(metadata.hasDependencies)
    }

    func testParseXMLWithDuplicateDependencies() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.duplicates" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="DuplicatePod" spec="1.0.0"/>
                        <pod name="UniquePod" spec="2.0.0"/>
                        <pod name="DuplicatePod" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Should deduplicate identical dependencies
        XCTAssertEqual(metadata.dependencies.count, 2)
        let podNames = metadata.dependencies.map(\.name).sorted()
        XCTAssertEqual(podNames, ["DuplicatePod", "UniquePod"])
    }

    func testParseXMLWithPlatformWithoutNameAttribute() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.noname" version="1.0.0">
            <platform>
                <podspec>
                    <pods>
                        <pod name="ShouldBeIgnored" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="ShouldBeIncluded" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Should only process platforms with name="ios"
        XCTAssertEqual(metadata.dependencies.count, 1)
        XCTAssertEqual(metadata.dependencies.first?.name, "ShouldBeIncluded")
    }

    func testParseXMLWithComplexNamespaces() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                xmlns:android="http://schemas.android.com/apk/res/android"
                id="com.example.namespaces"
                version="1.0.0">
            <name>Namespace Test Plugin</name>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="NamespacePod" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.namespaces")
        XCTAssertEqual(metadata.dependencies.count, 1)
        XCTAssertEqual(metadata.dependencies.first?.name, "NamespacePod")
    }

    func testParseXMLWithLocalXCFramework() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.xcframework" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.swift"/>
                <framework src="src/ios/frameworks/OSKeyStoreLib.xcframework" embed="true" custom="true" />
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.localFrameworks.count, 1)
        let fw = try XCTUnwrap(metadata.localFrameworks.first)
        XCTAssertEqual(fw.name, "OSKeyStoreLib")
        XCTAssertEqual(fw.path, "src/ios/frameworks/OSKeyStoreLib.xcframework")
    }

    func testParseXMLIgnoresNonCustomFrameworks() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.sysframework" version="1.0.0">
            <platform name="ios">
                <framework src="Foundation.framework"/>
                <framework src="UIKit.framework"/>
                <framework src="src/ios/MyLib.xcframework" embed="true" custom="true" />
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Only the custom xcframework should be collected
        XCTAssertEqual(metadata.localFrameworks.count, 1)
        XCTAssertEqual(metadata.localFrameworks.first?.name, "MyLib")
    }

    func testParseXMLDeduplicatesLocalFrameworks() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.dedup" version="1.0.0">
            <platform name="ios">
                <framework src="src/ios/Foo.xcframework" custom="true" />
                <framework src="src/ios/Foo.xcframework" custom="true" />
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.localFrameworks.count, 1)
    }

    func testParseXMLWithNestedPodspecStructure() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.nested" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <config>
                        <ios-deployment-target>12.0</ios-deployment-target>
                    </config>
                    <pods>
                        <pod name="FirstPod" spec="1.0.0"/>
                        <pod name="SecondPod" spec="2.0.0" subspecs="Core,UI"/>
                    </pods>
                    <sources>
                        <source>https://github.com/example/specs.git</source>
                    </sources>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.nested")
        XCTAssertTrue(metadata.hasPodspec)
        XCTAssertEqual(metadata.dependencies.count, 2)

        let firstPod = metadata.dependencies.first { $0.name == "FirstPod" }
        XCTAssertNotNil(firstPod)
        XCTAssertEqual(firstPod?.spec, "1.0.0")

        let secondPod = metadata.dependencies.first { $0.name == "SecondPod" }
        XCTAssertNotNil(secondPod)
        XCTAssertEqual(secondPod?.spec, "2.0.0")
    }
}
