import Foundation
import XCTest
@testable import MABS13PluginUpdate

final class FileSystemManagerGitignoreTests: XCTestCase {
    var tempDirectory: String!
    var logger: Logger!
    var fileManager: FileSystemManager!

    override func setUp() {
        super.setUp()

        // Create temporary directory for tests
        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-tests-" + UUID().uuidString
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

    // MARK: - GitignoreManager Tests

    func testGitignoreManagerUpdateEmptyFile() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: false)

        switch result {
        case let .success(message):
            XCTAssertEqual(message, "Updated .gitignore with Swift Package Manager entries")
        default:
            XCTFail("Expected success result")
        }

        // Verify .gitignore content
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")
        let content = try fileManager.readFile(at: gitignorePath)

        XCTAssertTrue(content.contains("# Swift Package Manager"))
        XCTAssertTrue(content.contains(".build/"))
        XCTAssertTrue(content.contains(".swiftpm/"))
        XCTAssertTrue(content.contains("Package.resolved"))
    }

    func testGitignoreManagerUpdateExistingFile() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")

        // Create existing .gitignore with some content
        let existingContent = """
        # Xcode
        *.xcodeproj/
        DerivedData/
        
        # macOS
        .DS_Store
        """
        try fileManager.writeFile(content: existingContent, to: gitignorePath)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: false)

        switch result {
        case let .success(message):
            XCTAssertEqual(message, "Updated .gitignore with Swift Package Manager entries")
        default:
            XCTFail("Expected success result")
        }

        // Verify .gitignore content includes both old and new entries
        let content = try fileManager.readFile(at: gitignorePath)

        // Old content should be preserved
        XCTAssertTrue(content.contains("# Xcode"))
        XCTAssertTrue(content.contains("*.xcodeproj/"))
        XCTAssertTrue(content.contains(".DS_Store"))

        // New content should be added
        XCTAssertTrue(content.contains("# Swift Package Manager"))
        XCTAssertTrue(content.contains(".build/"))
        XCTAssertTrue(content.contains(".swiftpm/"))
        XCTAssertTrue(content.contains("Package.resolved"))
    }

    func testGitignoreManagerSkipsWhenEntriesExist() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")

        // Create .gitignore with existing SPM entries
        let existingContent = """
        # Swift Package Manager
        .build/
        .swiftpm/
        Package.resolved
        
        # Other stuff
        .DS_Store
        """
        try fileManager.writeFile(content: existingContent, to: gitignorePath)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: false)

        switch result {
        case let .skipped(message):
            XCTAssertEqual(message, ".gitignore already contains required entries")
        default:
            XCTFail("Expected skipped result")
        }

        // Content should remain unchanged
        let content = try fileManager.readFile(at: gitignorePath)
        XCTAssertEqual(content, existingContent)
    }

    func testGitignoreManagerPartialUpdate() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")

        // Create .gitignore with only some SPM entries
        let existingContent = """
        # Existing content
        .DS_Store
        
        # Swift Package Manager
        .build/
        """
        try fileManager.writeFile(content: existingContent, to: gitignorePath)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: false)

        switch result {
        case let .success(message):
            XCTAssertEqual(message, "Updated .gitignore with Swift Package Manager entries")
        default:
            XCTFail("Expected success result")
        }

        // Verify missing entries were added
        let content = try fileManager.readFile(at: gitignorePath)

        // Should preserve existing content
        XCTAssertTrue(content.contains("# Existing content"))
        XCTAssertTrue(content.contains(".DS_Store"))
        XCTAssertTrue(content.contains(".build/"))

        // Should add missing entries
        XCTAssertTrue(content.contains(".swiftpm/"))
        XCTAssertTrue(content.contains("Package.resolved"))
    }

    func testGitignoreManagerCreateBackup() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")

        // Create existing .gitignore
        let existingContent = "# Original content\n.DS_Store\n"
        try fileManager.writeFile(content: existingContent, to: gitignorePath)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: true)

        switch result {
        case .success:
            break
        default:
            XCTFail("Expected success result")
        }

        // Verify backup was created
        let backupPath = gitignorePath + ".backup"
        XCTAssertTrue(fileManager.fileExists(at: backupPath))

        let backupContent = try fileManager.readFile(at: backupPath)
        XCTAssertEqual(backupContent, existingContent)
    }

    func testGitignoreManagerWithNonExistentDirectory() {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let nonExistentDir = tempDirectory.appendingPathComponent("nonexistent")

        // Should still work and create .gitignore in non-existent directory
        let result = gitignoreManager.updateGitignore(in: nonExistentDir, shouldBackup: false)

        switch result {
        case .success:
            // Should succeed and create the directory
            let gitignorePath = nonExistentDir.appendingPathComponent(".gitignore")
            XCTAssertTrue(fileManager.fileExists(at: gitignorePath))
        default:
            XCTFail("Should succeed even with non-existent directory")
        }
    }

    func testGitignoreManagerWithComplexExistingContent() throws {
        let gitignoreManager = GitignoreManager(fileManager: fileManager, logger: logger)
        let gitignorePath = tempDirectory.appendingPathComponent(".gitignore")

        // Create .gitignore with complex existing content
        let existingContent = """
        # Logs
        logs/
        *.log
        
        # Runtime data
        pids/
        *.pid
        
        # Coverage directory used by tools like istanbul
        coverage/
        
        # Dependency directories
        node_modules/
        
        # Optional npm cache directory
        .npm
        
        # Build artifacts
        dist/
        build/
        
        """
        try fileManager.writeFile(content: existingContent, to: gitignorePath)

        let result = gitignoreManager.updateGitignore(in: tempDirectory, shouldBackup: false)

        switch result {
        case .success:
            let content = try fileManager.readFile(at: gitignorePath)

            // All original content should be preserved
            XCTAssertTrue(content.contains("# Logs"))
            XCTAssertTrue(content.contains("node_modules/"))
            XCTAssertTrue(content.contains("coverage/"))

            // New SPM content should be added
            XCTAssertTrue(content.contains("# Swift Package Manager"))
            XCTAssertTrue(content.contains(".build/"))
            XCTAssertTrue(content.contains(".swiftpm/"))
            XCTAssertTrue(content.contains("Package.resolved"))
        default:
            XCTFail("Should succeed with complex existing content")
        }
    }
}
