import Foundation
import XCTest
@testable import MABS13PluginUpdate

final class ConverterTests: XCTestCase {
    var tempDirectory: String!
    var testPluginXML: String!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for tests
        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-converter-tests-" + UUID().uuidString
        do {
            try Foundation.FileManager.default.createDirectory(
                atPath: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }
        
        // Create test plugin.xml path
        testPluginXML = tempDirectory.appendingPathComponent("plugin.xml")
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Conversion Success Tests
    
    func testSuccessfulConversionWithDependencies() async throws {
        // Create test plugin.xml with dependencies
        let pluginXMLContent = """
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
                <source-file src="src/ios/TestPlugin.m"/>
            </platform>
        </plugin>
        """
        
        try pluginXMLContent.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
        
        // Configure options for automatic conversion (force mode)
        let options = ConversionOptions(
            force: true, // Skip confirmations
            dryRun: false,
            verbose: false,
            noGitignore: true, // Skip gitignore to simplify test
            backup: false,
            autoResolve: false,
            inputPath: testPluginXML
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertTrue(success, "Conversion should succeed")
        
        // Verify Package.swift was created
        let packageSwiftPath = tempDirectory.appendingPathComponent("Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageSwiftPath))
        
        // Verify Package.swift content
        let packageContent = try String(contentsOfFile: packageSwiftPath)
        XCTAssertTrue(packageContent.contains("com.example.testplugin"))
        XCTAssertTrue(packageContent.contains("AFNetworking"))
        XCTAssertTrue(packageContent.contains("SDWebImage"))
        
        // Verify plugin.xml was updated (package="swift" added)
        let updatedXML = try String(contentsOfFile: testPluginXML)
        XCTAssertTrue(updatedXML.contains("package=\"swift\""))
    }
    
    func testSuccessfulConversionWithoutDependencies() async throws {
        // Create simple plugin.xml without dependencies
        let pluginXMLContent = """
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
        
        try pluginXMLContent.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
        
        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: testPluginXML
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertTrue(success)
        
        // Verify Package.swift was created and doesn't contain conversion placeholders
        let packageSwiftPath = tempDirectory.appendingPathComponent("Package.swift")
        let packageContent = try String(contentsOfFile: packageSwiftPath)
        XCTAssertFalse(packageContent.contains("TODO: Convert CocoaPods dependency"))
    }
    
    func testDryRunMode() async throws {
        let pluginXMLContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.dryrun" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """
        
        try pluginXMLContent.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
        
        let options = ConversionOptions(
            force: true,
            dryRun: true, // Enable dry run
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: testPluginXML
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertTrue(success)
        
        // In dry run mode, no files should be created or modified
        let packageSwiftPath = tempDirectory.appendingPathComponent("Package.swift")
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageSwiftPath))
        
        // Original plugin.xml should remain unchanged
        let originalContent = try String(contentsOfFile: testPluginXML)
        XCTAssertFalse(originalContent.contains("package=\"swift\""))
    }
    
    // MARK: - Error Handling Tests
    
    func testConversionFailsWithMissingPluginXML() async {
        let nonExistentPath = tempDirectory.appendingPathComponent("nonexistent.xml")
        
        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            inputPath: nonExistentPath
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertFalse(success, "Conversion should fail with missing file")
    }
    
    func testConversionFailsWithInvalidXML() async throws {
        let invalidXMLContent = """
        This is not XML at all
        Just plain text that should cause parsing to fail
        """
        
        try invalidXMLContent.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
        
        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            inputPath: testPluginXML
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertFalse(success, "Conversion should fail with invalid XML")
    }
    
    func testConversionFailsWithMissingPluginId() async throws {
        let xmlWithoutId = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """
        
        try xmlWithoutId.write(toFile: testPluginXML, atomically: true, encoding: .utf8)
        
        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            inputPath: testPluginXML
        )
        
        let converter = CordovaToSPMConverter(options: options)
        let success = await converter.convert()
        
        XCTAssertFalse(success, "Conversion should fail without plugin ID")
    }
}
