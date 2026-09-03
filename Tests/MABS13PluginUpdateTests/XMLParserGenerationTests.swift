import XCTest
@testable import MABS13PluginUpdate

final class XMLParserGenerationTests: XCTestCase {
    func testGenerateUpdatedXMLWithMultiplePlatforms() {
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.multiplatform" version="1.0.0">
            <platform name="android">
                <source-file src="android/Plugin.java"/>
            </platform>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="TestPod" spec="1.0.0"/>
                    </pods>
                </podspec>
            </platform>
            <platform name="ios" package="old">
                <source-file src="ios/Additional.m"/>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.multiplatform",
            dependencies: [PodDependency(name: "TestPod", spec: "1.0.0")],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata, addNospmAttribute: true)

        // Should update all iOS platforms
        XCTAssertTrue(updatedXML.contains("platform name=\"ios\" package=\"swift\""))
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))

        // Android platform should remain unchanged
        XCTAssertTrue(updatedXML.contains("platform name=\"android\""))
        XCTAssertFalse(updatedXML.contains("platform name=\"android\" package=\"swift\""))
    }

    func testGenerateUpdatedXMLPreservesNonIOSContent() {
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.preserve" version="1.0.0">
            <name>Preserve Test</name>
            <description>Should preserve non-iOS content</description>
            <js-module src="www/plugin.js" name="TestPlugin"/>
            <platform name="android">
                <source-file src="android/Plugin.java" target-dir="src/com/example"/>
            </platform>
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="ToBeRemoved" spec="1.0.0"/>
                    </pods>
                </podspec>
                <source-file src="ios/Plugin.m"/>
            </platform>
            <platform name="browser">
                <js-module src="www/browser.js"/>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.preserve",
            dependencies: [PodDependency(name: "ToBeRemoved", spec: "1.0.0")],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata, addNospmAttribute: true)

        // Should preserve plugin metadata
        XCTAssertTrue(updatedXML.contains("<name>Preserve Test</name>"))
        XCTAssertTrue(updatedXML.contains("<description>Should preserve non-iOS content</description>"))

        // Should preserve JS module
        XCTAssertTrue(updatedXML.contains("js-module src=\"www/plugin.js\""))

        // Should preserve Android platform unchanged
        XCTAssertTrue(updatedXML.contains("platform name=\"android\""))
        XCTAssertTrue(updatedXML.contains("android/Plugin.java"))

        // Should preserve browser platform unchanged
        XCTAssertTrue(updatedXML.contains("platform name=\"browser\""))
        XCTAssertTrue(updatedXML.contains("www/browser.js"))

        // iOS platform should be updated
        XCTAssertTrue(updatedXML.contains("platform name=\"ios\" package=\"swift\""))
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
        XCTAssertTrue(updatedXML.contains("ios/Plugin.m"))
    }

    func testGenerateUpdatedXMLWithoutPodspecRemoval() {
        let originalXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="test.keep.podspec" version="1.0.0">
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="KeepThisPod" spec="1.0.0"/>
                    </pods>
                </podspec>
                <source-file src="ios/Plugin.m"/>
            </platform>
        </plugin>
        """

        let metadata = PluginMetadata(
            pluginId: "test.keep.podspec",
            dependencies: [PodDependency(name: "KeepThisPod", spec: "1.0.0")],
            hasPodspec: true,
            originalXmlContent: originalXML
        )

        let updatedXML = XMLParser.generateUpdatedXML(from: metadata, addNospmAttribute: false)

        // Should keep podspec when addNospmAttribute is false
        XCTAssertTrue(updatedXML.contains("<podspec>"))
        XCTAssertTrue(updatedXML.contains("KeepThisPod"))
        XCTAssertFalse(updatedXML.contains("nospm=\"true\""))

        // Should still add package="swift"
        XCTAssertTrue(updatedXML.contains("platform name=\"ios\" package=\"swift\""))
    }

    func testGenerateUpdatedXMLWithComplexStructure() {
        let (_, metadata) = createComplexPluginTestData()
        let updatedXML = XMLParser.generateUpdatedXML(from: metadata, addNospmAttribute: true)
        
        verifyComplexPluginMetadataPreserved(updatedXML)
        verifyComplexPluginIOSPlatformUpdated(updatedXML)
        verifyComplexPluginAndroidPlatformUnchanged(updatedXML)
    }
    
    // MARK: - Helper Methods for Complex Plugin Test
    
    private func createComplexPluginTestData() -> (String, PluginMetadata) {
        let originalXML = createComplexPluginXML()
        let metadata = createComplexPluginMetadata(originalXML: originalXML)
        return (originalXML, metadata)
    }
    
    private func createComplexPluginXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="complex.plugin" version="2.1.0">
            <name>Complex Plugin</name>
            <description>A complex plugin with multiple elements</description>
            <author>Test Author</author>
            <license>MIT</license>
        
            <js-module src="www/plugin.js" name="ComplexPlugin">
                <clobbers target="window.plugins.complex"/>
            </js-module>
        
            <platform name="ios">
                <config-file target="config.xml" parent="/*">
                    <feature name="ComplexPlugin">
                        <param name="ios-package" value="CDVComplexPlugin"/>
                    </feature>
                </config-file>
        
                <podspec>
                    <config>
                        <ios-deployment-target>12.0</ios-deployment-target>
                    </config>
                    <pods>
                        <pod name="ComplexDependency" spec="~> 3.0"/>
                        <pod name="AnotherDep" spec="= 1.2.3"/>
                    </pods>
                </podspec>
        
                <header-file src="src/ios/CDVComplexPlugin.h"/>
                <source-file src="src/ios/CDVComplexPlugin.m"/>
        
                <framework src="Foundation.framework"/>
                <framework src="UIKit.framework"/>
            </platform>
        
            <platform name="android">
                <config-file target="res/xml/config.xml" parent="/*">
                    <feature name="ComplexPlugin">
                        <param name="android-package" value="com.example.ComplexPlugin"/>
                    </feature>
                </config-file>
                <source-file src="src/android/ComplexPlugin.java" target-dir="src/com/example"/>
            </platform>
        </plugin>
        """
    }
    
    private func createComplexPluginMetadata(originalXML: String) -> PluginMetadata {
        PluginMetadata(
            pluginId: "complex.plugin",
            dependencies: [
                PodDependency(name: "ComplexDependency", spec: "~> 3.0"),
                PodDependency(name: "AnotherDep", spec: "= 1.2.3")
            ],
            hasPodspec: true,
            originalXmlContent: originalXML
        )
    }
    
    private func verifyComplexPluginMetadataPreserved(_ updatedXML: String) {
        // Should preserve all metadata
        XCTAssertTrue(updatedXML.contains("<name>Complex Plugin</name>"))
        XCTAssertTrue(updatedXML.contains("<description>A complex plugin with multiple elements</description>"))
        XCTAssertTrue(updatedXML.contains("<author>Test Author</author>"))
        XCTAssertTrue(updatedXML.contains("<license>MIT</license>"))
        
        // Should preserve JS module
        XCTAssertTrue(updatedXML.contains("js-module src=\"www/plugin.js\""))
        XCTAssertTrue(updatedXML.contains("window.plugins.complex"))
    }
    
    private func verifyComplexPluginIOSPlatformUpdated(_ updatedXML: String) {
        // iOS platform should be updated
        XCTAssertTrue(updatedXML.contains("platform name=\"ios\" package=\"swift\""))
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
        
        // Should preserve other iOS elements
        XCTAssertTrue(updatedXML.contains("CDVComplexPlugin.h"))
        XCTAssertTrue(updatedXML.contains("CDVComplexPlugin.m"))
        XCTAssertTrue(updatedXML.contains("Foundation.framework"))
        XCTAssertTrue(updatedXML.contains("config-file target=\"config.xml\""))
    }
    
    private func verifyComplexPluginAndroidPlatformUnchanged(_ updatedXML: String) {
        // Android platform should remain unchanged
        XCTAssertTrue(updatedXML.contains("platform name=\"android\""))
        XCTAssertFalse(updatedXML.contains("platform name=\"android\" package=\"swift\""))
        XCTAssertTrue(updatedXML.contains("com.example.ComplexPlugin"))
        XCTAssertTrue(updatedXML.contains("src/android/ComplexPlugin.java"))
    }
}
