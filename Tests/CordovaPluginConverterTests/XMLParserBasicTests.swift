import XCTest
@testable import cdv2spm

// swiftlint:disable:next type_body_length
final class XMLParserBasicTests: XCTestCase {
    func testParseValidPluginXML() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="com.example.testplugin"
                version="1.0.0">
            <name>Test Plugin</name>
            <description>A test plugin</description>
        
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="AFNetworking" spec="~> 4.0"/>
                        <pod name="SDWebImage" spec="~> 5.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.testplugin")
        XCTAssertEqual(metadata.dependencies.count, 2)
        XCTAssertTrue(metadata.hasPodspec)
        XCTAssertEqual(metadata.originalXmlContent, xmlContent)

        let afnetworking = metadata.dependencies.first { $0.name == "AFNetworking" }
        XCTAssertNotNil(afnetworking)
        XCTAssertEqual(afnetworking?.spec, "~> 4.0")

        let sdwebimage = metadata.dependencies.first { $0.name == "SDWebImage" }
        XCTAssertNotNil(sdwebimage)
        XCTAssertEqual(sdwebimage?.spec, "~> 5.0")
    }

    func testParseNameOnlyPodIsCaptured() throws {
        // A `<pod name="X"/>` with no spec/git is valid CocoaPods syntax meaning "latest".
        // It must still be captured as a dependency (regression test for dropped pods).
        // Also covers a <podspec> containing a nested <config> sibling of <pods>.
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="cordova-plugin-msal"
                version="1.0.0">
            <platform name="ios">
                <podspec>
                    <config>
                        <source url="https://cdn.cocoapods.org/"/>
                    </config>
                    <pods use_frameworks="true">
                        <pod name="MSAL" />
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertTrue(metadata.hasPodspec)
        XCTAssertEqual(metadata.dependencies.count, 1)
        let msal = metadata.dependencies.first { $0.name == "MSAL" }
        XCTAssertNotNil(msal)
        XCTAssertNil(msal?.spec)
    }

    func testParsePluginXMLWithoutPods() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                id="com.example.simple"
                version="1.0.0">
            <name>Simple Plugin</name>
            <platform name="ios">
                <source-file src="src/ios/SimplePlugin.m"/>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.simple")
        XCTAssertEqual(metadata.dependencies.count, 0)
        XCTAssertFalse(metadata.hasPodspec)
        XCTAssertFalse(metadata.hasDependencies)
    }

    func testParsePluginXMLMissingId() {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
                version="1.0.0">
            <name>Missing ID Plugin</name>
        </plugin>
        """

        XCTAssertThrowsError(try XMLParser.parsePluginXML(content: xmlContent)) { error in
            XCTAssertTrue(error is XMLParsingError)
            if case XMLParsingError.missingPluginId = error {
                // Expected error
            } else {
                XCTFail("Expected XMLParsingError.missingPluginId")
            }
        }
    }

    func testParseInvalidXML() {
        let invalidXML = """
        This is not valid XML content
        <plugin id="test" but missing closing tag
        """

        XCTAssertThrowsError(try XMLParser.parsePluginXML(content: invalidXML)) { error in
            // SWXMLHash doesn't always throw parsingFailed for malformed XML
            // It may successfully parse but then fail to find the plugin id
            XCTAssertTrue(error is XMLParsingError)
        }
    }

    func testGenerateUpdatedXMLAddsNospmAttribute() {
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.plugin" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="AFNetworking" spec="~> 4.0"/>
                    </pods>
                </podspec>
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [PodDependency(name: "AFNetworking", spec: "~> 4.0")],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata)

        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
        XCTAssertTrue(updatedXML.contains("<podspec>"))
        XCTAssertTrue(updatedXML.contains("AFNetworking"))
        XCTAssertTrue(updatedXML.contains("source-file"))
    }

    func testGenerateUpdatedXMLHandlesSelfClosingPodTags() {
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.plugin" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="OSInAppBrowserLib" spec="2.2.1" />
                        <pod name="AnotherPod" spec="1.0.0">
                        </pod>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [
                PodDependency(name: "OSInAppBrowserLib", spec: "2.2.1"),
                PodDependency(name: "AnotherPod", spec: "1.0.0")
            ],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata)
        
        // Should correctly handle self-closing tags
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
        XCTAssertFalse(updatedXML.contains("/ nospm=\"true\">"))
        
        // Verify specific transformations
        XCTAssertTrue(updatedXML.contains("OSInAppBrowserLib"))
        XCTAssertTrue(updatedXML.contains("AnotherPod"))
    }

    func testGenerateUpdatedXMLHandlesVersionSpecWithGreaterThan() {
        // Regression test: spec values like "~> 3.0" contain ">" which previously caused
        // the regex to stop early, producing malformed XML.
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.plugin" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="ComplexDependency" spec="~> 3.0"/>
                        <pod name="AnotherDep" spec=">= 2.0.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [
                PodDependency(name: "ComplexDependency", spec: "~> 3.0"),
                PodDependency(name: "AnotherDep", spec: ">= 2.0.0")
            ],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata)

        // nospm must be added as a proper attribute, not spliced into an attribute value
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
        XCTAssertTrue(updatedXML.contains("spec=\"~> 3.0\""), "spec value must be preserved intact")
        XCTAssertTrue(updatedXML.contains("spec=\">= 2.0.0\""), "spec value must be preserved intact")
        // Ensure the XML is well-formed (no attribute value was broken)
        XCTAssertFalse(updatedXML.contains("spec=\"~\""), "spec value must not be truncated at >")
        XCTAssertFalse(updatedXML.contains("spec=\"\""), "spec value must not be emptied")
    }

    func testGenerateUpdatedXMLAddsSwiftPackage() {
        let originalXML = """
        <plugin id="test.plugin">
            <platform name="ios">
                <source-file src="Plugin.m"/>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata)

        XCTAssertTrue(updatedXML.contains("package=\"swift\""))
    }

    func testXMLParsingErrorDescriptions() {
        let fileNotFoundError = XMLParsingError.fileNotFound("/path/to/file")
        let invalidXMLError = XMLParsingError.invalidXML("Missing closing tag")
        let missingPluginIdError = XMLParsingError.missingPluginId
        let parsingFailedError = XMLParsingError.parsingFailed("Unexpected token")

        XCTAssertEqual(fileNotFoundError.errorDescription, "Plugin XML file not found at: /path/to/file")
        XCTAssertEqual(invalidXMLError.errorDescription, "Invalid XML content: Missing closing tag")
        XCTAssertEqual(missingPluginIdError.errorDescription, "Plugin XML is missing required 'id' attribute")
        XCTAssertEqual(parsingFailedError.errorDescription, "Failed to parse XML: Unexpected token")
    }

    func testParseXMLWithSpecialCharactersInPluginId() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.special-chars_123" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.pluginId, "com.example.special-chars_123")
        XCTAssertFalse(metadata.hasPodspec)
        XCTAssertEqual(metadata.dependencies.count, 0)
    }

    func testParseXMLWithAndroidAndIOSPlatforms() throws {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.crossplatform" version="1.0.0">
            <platform name="android">
                <!-- Android specific stuff should be ignored -->
                <source-file src="android/Plugin.java"/>
            </platform>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="IOSOnlyPod" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
            <platform name="browser">
                <!-- Browser platform should be ignored -->
                <js-module src="www/plugin.js"/>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        // Should only process iOS platform
        XCTAssertEqual(metadata.dependencies.count, 1)
        XCTAssertEqual(metadata.dependencies.first?.name, "IOSOnlyPod")
        XCTAssertTrue(metadata.hasPodspec)
    }

    func testParseXMLResolvesCoroadovaVariableSpecFromPlatformPreference() throws {
        // Regression: spec="$IOS_FIREBASE_PERFORMANCE_VERSION" should be resolved to
        // the default value declared in the <preference> element of the same platform.
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.firebase" version="1.0.0" xmlns="http://apache.org/cordova/ns/plugins/1.0">
            <platform name="ios">
                <preference name="IOS_FIREBASE_PERFORMANCE_VERSION" default="10.23.0"/>
                <podspec>
                    <pods use-frameworks="true">
                        <pod name="FirebasePerformance" spec="$IOS_FIREBASE_PERFORMANCE_VERSION" />
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.dependencies.count, 1)
        XCTAssertTrue(metadata.hasPodspec)

        let firebase = metadata.dependencies.first
        XCTAssertEqual(firebase?.name, "FirebasePerformance")
        // The variable must be resolved to the preference default, not kept as "$..."
        XCTAssertEqual(firebase?.spec, "10.23.0")
    }

    func testParseXMLResolvesCoroadovaVariableSpecFromPluginLevelPreference() throws {
        // Preferences can also be declared at the plugin level (outside any platform).
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0" xmlns="http://apache.org/cordova/ns/plugins/1.0">
            <preference name="MY_LIB_VERSION" default="3.1.4"/>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="MyLib" spec="$MY_LIB_VERSION" />
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.dependencies.count, 1)
        let myLib = metadata.dependencies.first
        XCTAssertEqual(myLib?.name, "MyLib")
        XCTAssertEqual(myLib?.spec, "3.1.4")
    }

    func testParseXMLKeepsUnresolvableVariableSpecUnchanged() throws {
        // If a variable has no matching <preference>, keep the raw "$VAR" value so
        // the dependency is still created (and gets a placeholder comment).
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0" xmlns="http://apache.org/cordova/ns/plugins/1.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="SomeLib" spec="$UNDEFINED_VAR" />
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """

        let metadata = try XMLParser.parsePluginXML(content: xmlContent)

        XCTAssertEqual(metadata.dependencies.count, 1)
        let someLib = metadata.dependencies.first
        XCTAssertEqual(someLib?.name, "SomeLib")
        XCTAssertEqual(someLib?.spec, "$UNDEFINED_VAR") // kept as-is
    }
}
