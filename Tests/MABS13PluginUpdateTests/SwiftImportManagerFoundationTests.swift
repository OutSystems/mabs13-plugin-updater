import XCTest
@testable import MABS13PluginUpdate

/// Covers the `import Foundation` a Swift-package build needs but a CocoaPods build gets for free
/// through the app target's bridging header.
final class SwiftImportManagerFoundationTests: XCTestCase {
    private var tempDirectory: URL!
    private var sourceDirectory: URL!
    private var swiftImportManager: SwiftImportManager!

    override func setUp() {
        super.setUp()

        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftImportManagerFoundationTests-\(UUID().uuidString)")
        sourceDirectory = tempDirectory.appendingPathComponent("src/ios")

        do {
            try Foundation.FileManager.default.createDirectory(
                at: sourceDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }

        let logger = Logger(verbose: false)
        swiftImportManager = SwiftImportManager(
            logger: logger,
            fileManager: FileSystemManager(logger: logger, dryRun: false)
        )
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    /// Write `content` to a source file, run the import manager, and return the resulting content.
    private func process(_ content: String, fileName: String = "Subject.swift") throws -> String {
        let fileURL = sourceDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(swiftImportManager.addCordovaImports(in: tempDirectory.path))

        return try String(contentsOf: fileURL)
    }

    private func occurrences(of needle: String, in content: String) -> Int {
        content.components(separatedBy: needle).count - 1
    }

    func testAddsFoundationImportToFileWithoutImports() throws {
        let updated = try process("""
        extension IONFILEInfoResult {
            var payload: Data {
                Data()
            }
        }
        """)

        XCTAssertEqual(occurrences(of: "import Foundation", in: updated), 1)
        // The import must come before the code that needs it
        let lines = updated.components(separatedBy: .newlines)
        let importIndex = lines.firstIndex { $0 == "import Foundation" }
        let codeIndex = lines.firstIndex { $0.hasPrefix("extension ") }
        XCTAssertNotNil(importIndex)
        XCTAssertNotNil(codeIndex)
        XCTAssertLessThan(try XCTUnwrap(importIndex), try XCTUnwrap(codeIndex))
    }

    func testAddsFoundationImportAlongsideOtherImports() throws {
        let updated = try process("""
        import IONFilesystemLib

        struct Converter {
            let timestamp: Date
        }
        """)

        XCTAssertEqual(occurrences(of: "import Foundation", in: updated), 1)
        let lines = updated.components(separatedBy: .newlines)
        XCTAssertLessThan(
            try XCTUnwrap(lines.firstIndex { $0 == "import Foundation" }),
            try XCTUnwrap(lines.firstIndex { $0 == "import IONFilesystemLib" })
        )
    }

    func testKeepsLicenseHeaderAboveTheImport() throws {
        let updated = try process("""
        // Copyright (c) 2026 Example Corp.
        // Licensed under the MIT License.

        struct Converter {
            let url: URL
        }
        """)

        let lines = updated.components(separatedBy: .newlines)
        XCTAssertTrue(lines[0].hasPrefix("// Copyright"))
        XCTAssertLessThan(
            try XCTUnwrap(lines.firstIndex { $0.hasPrefix("// Licensed") }),
            try XCTUnwrap(lines.firstIndex { $0 == "import Foundation" })
        )
    }

    func testLeavesFileWithFoundationImportUnchanged() throws {
        let content = """
        import Foundation

        struct Converter {
            let payload: Data
        }
        """

        XCTAssertEqual(try process(content), content)
    }

    func testLeavesFileImportingUIKitUnchanged() throws {
        // UIKit re-exports Foundation, so Data resolves without an explicit import
        let content = """
        import UIKit

        struct Converter {
            let payload: Data
        }
        """

        XCTAssertEqual(try process(content), content)
    }

    func testLeavesFileWithoutFoundationTypesUnchanged() throws {
        let content = """
        enum OSFileMethod: String {
            case readFile
        }
        """

        XCTAssertEqual(try process(content), content)
    }

    func testIdentifierEndingInFoundationTypeNameDoesNotTriggerImport() throws {
        // PluginResultData contains "Data" but is not a Foundation type
        let content = """
        typealias PluginResultData = [String: Any]

        enum PluginStatus {
            case success(payload: PluginResultData)
        }
        """

        XCTAssertEqual(try process(content), content)
    }

    func testAddsBothFoundationAndCordovaImports() throws {
        let updated = try process("""
        @objc(OSFilePlugin)
        class OSFilePlugin: CDVPlugin {
            var payload: Data?
        }
        """)

        XCTAssertEqual(occurrences(of: "import Foundation", in: updated), 1)
        XCTAssertEqual(occurrences(of: "#if canImport(Cordova)", in: updated), 1)

        let lines = updated.components(separatedBy: .newlines)
        XCTAssertLessThan(
            try XCTUnwrap(lines.firstIndex { $0 == "#if canImport(Cordova)" }),
            try XCTUnwrap(lines.firstIndex { $0 == "import Foundation" })
        )
        XCTAssertLessThan(
            try XCTUnwrap(lines.firstIndex { $0 == "import Foundation" }),
            try XCTUnwrap(lines.firstIndex { $0.contains("class OSFilePlugin") })
        )
    }

    func testRunningTwiceIsIdempotent() throws {
        let first = try process("""
        struct Converter {
            let payload: Data
        }
        """)
        let second = try process(first)

        XCTAssertEqual(first, second)
    }

    func testTestableImportDoesNotCountAsFoundationImport() throws {
        let updated = try process("""
        @testable import MyPlugin

        struct Converter {
            let payload: Data
        }
        """)

        XCTAssertEqual(occurrences(of: "import Foundation", in: updated), 1)
    }
}
