import XCTest
@testable import cdv2spm

final class SwiftImportManagerTests: XCTestCase {
    private var tempDirectory: URL!
    private var logger: Logger!
    private var fileManager: FileSystemManager!
    private var swiftImportManager: SwiftImportManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftImportManagerTests-\(UUID().uuidString)")
        
        do {
            try Foundation.FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }
        
        logger = Logger(verbose: false)
        fileManager = FileSystemManager(logger: logger, dryRun: false)
        swiftImportManager = SwiftImportManager(logger: logger, fileManager: fileManager)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? Foundation.FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testAddCordovaImportToSwiftFileWithCDVPlugin() throws {
        // Create src/ios directory structure
        let srcIOSDir = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(at: srcIOSDir, withIntermediateDirectories: true)
        
        // Create a Swift file that needs Cordova import
        let swiftFile = srcIOSDir.appendingPathComponent("TestPlugin.swift")
        let swiftContent = """
        import Foundation
        import UIKit
        
        @objc(TestPlugin)
        class TestPlugin: CDVPlugin {
            func testMethod() {
                // Some implementation
            }
        }
        """
        
        try swiftContent.write(to: swiftFile, atomically: true, encoding: .utf8)
        
        // Run the import manager
        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)
        
        XCTAssertTrue(success)
        
        // Check if the import was added
        let updatedContent = try String(contentsOf: swiftFile)
        XCTAssertTrue(updatedContent.contains("#if canImport(Cordova)"))
        XCTAssertTrue(updatedContent.contains("import Cordova"))
        XCTAssertTrue(updatedContent.contains("#endif"))
        
        // Verify the import is added before other imports
        let lines = updatedContent.components(separatedBy: .newlines)
        let cordovaImportIndex = lines.firstIndex { $0.contains("#if canImport(Cordova)") }
        let foundationImportIndex = lines.firstIndex { $0.contains("import Foundation") }
        
        XCTAssertNotNil(cordovaImportIndex)
        XCTAssertNotNil(foundationImportIndex)
        XCTAssertLessThan(try XCTUnwrap(cordovaImportIndex), try XCTUnwrap(foundationImportIndex))
    }
    
    func testSkipSwiftFileWithoutCordovaReferences() throws {
        // Create src/ios directory structure
        let srcIOSDir = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(at: srcIOSDir, withIntermediateDirectories: true)
        
        // Create a Swift file that doesn't need Cordova import
        let swiftFile = srcIOSDir.appendingPathComponent("Utility.swift")
        let swiftContent = """
        import Foundation
        
        class Utility {
            static func doSomething() -> String {
                return "Hello"
            }
        }
        """
        
        try swiftContent.write(to: swiftFile, atomically: true, encoding: .utf8)
        
        // Run the import manager
        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)
        
        XCTAssertTrue(success)
        
        // Check that no import was added
        let updatedContent = try String(contentsOf: swiftFile)
        XCTAssertFalse(updatedContent.contains("#if canImport(Cordova)"))
        XCTAssertFalse(updatedContent.contains("import Cordova"))
        XCTAssertEqual(updatedContent, swiftContent) // Content should be unchanged
    }
    
    func testSkipSwiftFileWithExistingCordovaImport() throws {
        // Create src/ios directory structure
        let srcIOSDir = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(at: srcIOSDir, withIntermediateDirectories: true)
        
        // Create a Swift file that already has Cordova import
        let swiftFile = srcIOSDir.appendingPathComponent("ExistingPlugin.swift")
        let swiftContent = """
        import Foundation
        import Cordova
        
        @objc(ExistingPlugin)
        class ExistingPlugin: CDVPlugin {
            func testMethod() {
                // Some implementation
            }
        }
        """
        
        try swiftContent.write(to: swiftFile, atomically: true, encoding: .utf8)
        
        // Run the import manager
        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)
        
        XCTAssertTrue(success)
        
        // Check that content is unchanged
        let updatedContent = try String(contentsOf: swiftFile)
        XCTAssertEqual(updatedContent, swiftContent)
    }
    
    func testHandleNoSrcIOSDirectory() {
        // Don't create src/ios directory

        // Run the import manager
        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)

        // Should succeed (nothing to do)
        XCTAssertTrue(success)
    }

    func testAddCordovaImportToFileWithOnlyComments() throws {
        // Create src/ios directory structure
        let srcIOSDir = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(at: srcIOSDir, withIntermediateDirectories: true)

        // Create a Swift file that is entirely a license comment block followed by CDV usage
        // This exercises the insertIndex = lines.count fallback path
        let swiftFile = srcIOSDir.appendingPathComponent("LicenseOnly.swift")
        let swiftContent = """
        // Copyright (c) 2024 Example Corp.
        // Licensed under the MIT License.
        //
        // This file uses CDVPlugin to implement a plugin.
        class LicensePlugin: CDVPlugin {}
        """

        try swiftContent.write(to: swiftFile, atomically: true, encoding: .utf8)

        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)

        XCTAssertTrue(success)

        let updatedContent = try String(contentsOf: swiftFile)
        XCTAssertTrue(updatedContent.contains("#if canImport(Cordova)"))
        XCTAssertTrue(updatedContent.contains("import Cordova"))
        XCTAssertTrue(updatedContent.contains("#endif"))

        // The import block must appear before the class declaration
        let lines = updatedContent.components(separatedBy: .newlines)
        let importBlockIndex = lines.firstIndex { $0.contains("#if canImport(Cordova)") }
        let classLineIndex = lines.firstIndex { $0.hasPrefix("class LicensePlugin") }

        XCTAssertNotNil(importBlockIndex)
        XCTAssertNotNil(classLineIndex)
        if let imp = importBlockIndex, let cls = classLineIndex {
            XCTAssertLessThan(imp, cls)
        }
    }
    
    func testProcessMultipleSwiftFiles() throws {
        // Create src/ios directory structure
        let srcIOSDir = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(at: srcIOSDir, withIntermediateDirectories: true)
        
        // Create multiple Swift files
        let plugin1 = srcIOSDir.appendingPathComponent("Plugin1.swift")
        let plugin1Content = """
        import Foundation
        
        @objc(Plugin1)
        class Plugin1: CDVPlugin {
        }
        """
        
        let plugin2 = srcIOSDir.appendingPathComponent("Plugin2.swift")
        let plugin2Content = """
        import UIKit
        
        class Plugin2: CDVPlugin {
            func handleCommand(_ command: CDVInvokedUrlCommand) {
            }
        }
        """
        
        let utilityFile = srcIOSDir.appendingPathComponent("Utility.swift")
        let utilityContent = """
        import Foundation
        
        class Utility {
            static func helper() {}
        }
        """
        
        try plugin1Content.write(to: plugin1, atomically: true, encoding: .utf8)
        try plugin2Content.write(to: plugin2, atomically: true, encoding: .utf8)
        try utilityContent.write(to: utilityFile, atomically: true, encoding: .utf8)
        
        // Run the import manager
        let success = swiftImportManager.addCordovaImports(in: tempDirectory.path)
        
        XCTAssertTrue(success)
        
        // Check plugin1 - should have import added
        let updatedPlugin1 = try String(contentsOf: plugin1)
        XCTAssertTrue(updatedPlugin1.contains("#if canImport(Cordova)"))
        
        // Check plugin2 - should have import added
        let updatedPlugin2 = try String(contentsOf: plugin2)
        XCTAssertTrue(updatedPlugin2.contains("#if canImport(Cordova)"))
        
        // Check utility - should NOT have import added
        let updatedUtility = try String(contentsOf: utilityFile)
        XCTAssertFalse(updatedUtility.contains("#if canImport(Cordova)"))
        XCTAssertEqual(updatedUtility, utilityContent)
    }
}
