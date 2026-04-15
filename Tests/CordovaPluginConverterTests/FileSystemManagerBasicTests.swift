import Foundation
import XCTest
@testable import cdv2spm

final class FileSystemManagerBasicTests: XCTestCase {
    var tempDirectory: String!
    var logger: Logger!
    var fileManager: FileSystemManager!

    override func setUp() {
        super.setUp()

        // Create temporary directory for tests
        tempDirectory = NSTemporaryDirectory() + "cdv2spm-tests-" + UUID().uuidString
        do {
            try Foundation.FileManager.default.createDirectory(
                atPath: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        logger = Logger(verbose: false, noColor: true)
        fileManager = FileSystemManager(logger: logger, dryRun: false)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    func testFileExists() {
        let testFile = tempDirectory.appendingPathComponent("test.txt")

        XCTAssertFalse(fileManager.fileExists(at: testFile))

        // Create file
        Foundation.FileManager.default.createFile(atPath: testFile, contents: Data(), attributes: nil)

        XCTAssertTrue(fileManager.fileExists(at: testFile))
    }

    func testReadAndWriteFile() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testContent = "Hello, World!\nThis is a test file."

        // Write file
        try fileManager.writeFile(content: testContent, to: testFile)

        // Verify file exists
        XCTAssertTrue(fileManager.fileExists(at: testFile))

        // Read file
        let readContent = try fileManager.readFile(at: testFile)
        XCTAssertEqual(readContent, testContent)
    }

    func testReadNonExistentFile() {
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")

        XCTAssertThrowsError(try fileManager.readFile(at: nonExistentFile)) { error in
            XCTAssertTrue(error is FileOperationError)
            if case FileOperationError.readError = error {
                // Expected error
            } else {
                XCTFail("Expected FileOperationError.readError")
            }
        }
    }

    func testCreateDirectory() throws {
        let testDir = tempDirectory.appendingPathComponent("nested/deep/directory")

        XCTAssertFalse(fileManager.fileExists(at: testDir))

        try fileManager.createDirectory(at: testDir)

        var isDirectory: ObjCBool = false
        let exists = Foundation.FileManager.default.fileExists(atPath: testDir, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testWriteFileWithDirectoryCreation() throws {
        let testFile = tempDirectory.appendingPathComponent("nested/directory/test.txt")
        let testContent = "Test content"

        // Directory doesn't exist initially
        XCTAssertFalse(fileManager.fileExists(at: testFile.directoryPath))

        // Write file with createDirectories: true (default)
        try fileManager.writeFile(content: testContent, to: testFile)

        // Verify directory was created
        XCTAssertTrue(fileManager.fileExists(at: testFile.directoryPath))

        // Verify file content
        let readContent = try fileManager.readFile(at: testFile)
        XCTAssertEqual(readContent, testContent)
    }

    func testCreateBackup() throws {
        let originalFile = tempDirectory.appendingPathComponent("original.txt")
        let originalContent = "Original content"

        // Create original file
        try fileManager.writeFile(content: originalContent, to: originalFile)

        // Create backup
        let backupPath = try fileManager.createBackup(of: originalFile)

        XCTAssertEqual(backupPath, originalFile + ".backup")
        XCTAssertTrue(fileManager.fileExists(at: backupPath))

        // Verify backup content
        let backupContent = try fileManager.readFile(at: backupPath)
        XCTAssertEqual(backupContent, originalContent)
    }

    func testCreateBackupOfNonExistentFile() throws {
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")

        // Should not throw error, just return backup path
        let backupPath = try fileManager.createBackup(of: nonExistentFile)
        XCTAssertEqual(backupPath, nonExistentFile + ".backup")
        XCTAssertFalse(fileManager.fileExists(at: backupPath))
    }

    func testResolvePluginXMLPath() {
        let currentDir = Foundation.FileManager.default.currentDirectoryPath

        // Test with nil input
        let defaultPath = fileManager.resolvePluginXMLPath(nil)
        XCTAssertEqual(defaultPath, currentDir + "/plugin.xml")

        // Test with absolute path
        let absolutePath = "/absolute/path/plugin.xml"
        let resolvedAbsolute = fileManager.resolvePluginXMLPath(absolutePath)
        XCTAssertEqual(resolvedAbsolute, absolutePath)

        // Test with relative path
        let relativePath = "relative/plugin.xml"
        let resolvedRelative = fileManager.resolvePluginXMLPath(relativePath)
        XCTAssertEqual(resolvedRelative, currentDir + "/" + relativePath)
    }

    func testDryRunMode() throws {
        let dryRunFileManager = FileSystemManager(logger: logger, dryRun: true)
        let testFile = tempDirectory.appendingPathComponent("dryrun.txt")
        let testContent = "This should not be written"

        // In dry run mode, files should not be actually written
        try dryRunFileManager.writeFile(content: testContent, to: testFile)
        XCTAssertFalse(fileManager.fileExists(at: testFile))

        // Directory creation should also be skipped
        let testDir = tempDirectory.appendingPathComponent("dryrun-dir")
        try dryRunFileManager.createDirectory(at: testDir)
        XCTAssertFalse(fileManager.fileExists(at: testDir))
    }

    func testFileOperationErrorDescriptions() {
        let fileNotFoundError = FileOperationError.fileNotFound("/path/to/file")
        let permissionDeniedError = FileOperationError.permissionDenied("/path/to/file")
        let writeError = FileOperationError.writeError("/path/to/file", NSError(domain: "TestError", code: 1))
        let readError = FileOperationError.readError("/path/to/file", NSError(domain: "TestError", code: 2))
        let dirError = FileOperationError.directoryCreationFailed("/path/to/dir", NSError(domain: "TestError", code: 3))

        XCTAssertTrue(fileNotFoundError.errorDescription?.contains("File not found") == true)
        XCTAssertTrue(permissionDeniedError.errorDescription?.contains("Permission denied") == true)
        XCTAssertTrue(writeError.errorDescription?.contains("Failed to write file") == true)
        XCTAssertTrue(readError.errorDescription?.contains("Failed to read file") == true)
        XCTAssertTrue(dirError.errorDescription?.contains("Failed to create directory") == true)
    }

    // MARK: - Header Detection Tests

    func testFindPublicHeadersPathIgnoresXCFrameworkHeaders() throws {
        // Create a src/ios structure with an xcframework containing .h files
        let xcfwHeadersPath = tempDirectory
            .appendingPathComponent("src/ios/frameworks/MyLib.xcframework/ios-arm64/MyLib.framework/Headers")
        try Foundation.FileManager.default.createDirectory(
            atPath: xcfwHeadersPath, withIntermediateDirectories: true, attributes: nil
        )
        Foundation.FileManager.default.createFile(
            atPath: xcfwHeadersPath.appendingPathComponent("MyLib.h"),
            contents: Data("// MyLib header".utf8),
            attributes: nil
        )

        // Change CWD so that findPublicHeadersPath resolves "src/ios" inside tempDirectory
        let originalDir = Foundation.FileManager.default.currentDirectoryPath
        Foundation.FileManager.default.changeCurrentDirectoryPath(tempDirectory)
        defer { Foundation.FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let headersPath = fileManager.findPublicHeadersPath(in: "src/ios")
        XCTAssertTrue(
            headersPath.isEmpty,
            "Headers inside .xcframework should be ignored, got: \(headersPath)"
        )
    }

    func testFindPublicHeadersPathFindsRegularHeaders() throws {
        // Create src/ios with a plain .h file (not inside xcframework)
        let srcIosPath = tempDirectory.appendingPathComponent("src/ios")
        try Foundation.FileManager.default.createDirectory(
            atPath: srcIosPath, withIntermediateDirectories: true, attributes: nil
        )
        Foundation.FileManager.default.createFile(
            atPath: srcIosPath.appendingPathComponent("MyPlugin.h"),
            contents: Data("// MyPlugin header".utf8),
            attributes: nil
        )

        let originalDir = Foundation.FileManager.default.currentDirectoryPath
        Foundation.FileManager.default.changeCurrentDirectoryPath(tempDirectory)
        defer { Foundation.FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let headersPath = fileManager.findPublicHeadersPath(in: "src/ios")
        XCTAssertFalse(
            headersPath.isEmpty,
            "Regular .h files should be detected"
        )
    }

    // MARK: - Edge Case and Error Handling Tests

    func testCreateBackupIfNeededWithShouldBackupFalse() throws {
        let originalFile = tempDirectory.appendingPathComponent("original.txt")
        let originalContent = "Original content"

        // Create original file
        try fileManager.writeFile(content: originalContent, to: originalFile)

        // Test with shouldBackup = false
        let backupPath = try fileManager.createBackupIfNeeded(of: originalFile, shouldBackup: false)

        // Should return nil when backup is not requested
        XCTAssertNil(backupPath)

        // No backup file should exist
        let expectedBackupPath = originalFile + ".backup"
        XCTAssertFalse(fileManager.fileExists(at: expectedBackupPath))
    }

    func testWriteFileWithCreateDirectoriesFalse() throws {
        let nestedFile = tempDirectory.appendingPathComponent("nonexistent/directory/test.txt")
        let testContent = "Test content"

        // Should throw error when trying to write to non-existent directory
        XCTAssertThrowsError(try fileManager.writeFile(content: testContent, to: nestedFile, createDirectories: false))

        // File should not exist
        XCTAssertFalse(fileManager.fileExists(at: nestedFile))
    }

    func testResolvePluginXMLPathWithSpecialCharacters() {
        let currentDir = Foundation.FileManager.default.currentDirectoryPath

        // Test with path containing spaces
        let pathWithSpaces = "path with spaces/plugin.xml"
        let resolvedSpaces = fileManager.resolvePluginXMLPath(pathWithSpaces)
        XCTAssertEqual(resolvedSpaces, currentDir + "/" + pathWithSpaces)

        // Test with path containing special characters
        let pathWithSpecialChars = "path-with_special.chars/plugin.xml"
        let resolvedSpecial = fileManager.resolvePluginXMLPath(pathWithSpecialChars)
        XCTAssertEqual(resolvedSpecial, currentDir + "/" + pathWithSpecialChars)
    }

    func testFileExistsWithDirectory() throws {
        let testDir = tempDirectory.appendingPathComponent("test-directory")

        // Create directory
        try fileManager.createDirectory(at: testDir)

        // fileExists should return true for directories too
        XCTAssertTrue(fileManager.fileExists(at: testDir))
    }

    func testDryRunModeWithNestedDirectories() throws {
        let dryRunFileManager = FileSystemManager(logger: logger, dryRun: true)
        let nestedFile = tempDirectory.appendingPathComponent("deep/nested/structure/test.txt")
        let testContent = "Should not be written"

        // In dry run mode, nested directories should not be created
        try dryRunFileManager.writeFile(content: testContent, to: nestedFile)

        // Neither the file nor the directories should exist
        XCTAssertFalse(fileManager.fileExists(at: nestedFile))
        XCTAssertFalse(fileManager.fileExists(at: nestedFile.directoryPath))
        XCTAssertFalse(fileManager.fileExists(at: tempDirectory.appendingPathComponent("deep")))
    }
}
