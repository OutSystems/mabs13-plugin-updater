import Foundation

/// Errors that can occur during file operations
public enum FileOperationError: Error, LocalizedError {
    case fileNotFound(String)
    case permissionDenied(String)
    case writeError(String, Error)
    case readError(String, Error)
    case directoryCreationFailed(String, Error)

    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            "File not found: \(path)"
        case let .permissionDenied(path):
            "Permission denied: \(path)"
        case let .writeError(path, error):
            "Failed to write file \(path): \(error.localizedDescription)"
        case let .readError(path, error):
            "Failed to read file \(path): \(error.localizedDescription)"
        case let .directoryCreationFailed(path, error):
            "Failed to create directory \(path): \(error.localizedDescription)"
        }
    }
}

/// Handles file system operations with safety checks and logging
public class FileSystemManager {
    private let logger: Logger
    private let dryRun: Bool

    public init(logger: Logger, dryRun: Bool = false) {
        self.logger = logger
        self.dryRun = dryRun
    }

    /// Check if file exists at given path
    /// - Parameter path: File path to check
    /// - Returns: true if file exists, false otherwise
    public func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Read file content as string
    /// - Parameter path: Path to file
    /// - Returns: File content as string
    /// - Throws: FileOperationError if reading fails
    public func readFile(at path: String) throws -> String {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            logger.debug("Successfully read file: \(path)")
            return content
        } catch {
            logger.error("Failed to read file: \(path)")
            throw FileOperationError.readError(path, error)
        }
    }

    /// Write content to file
    /// - Parameters:
    ///   - content: Content to write
    ///   - path: Destination file path
    ///   - createDirectories: Whether to create parent directories if they don't exist
    /// - Throws: FileOperationError if writing fails
    public func writeFile(content: String, to path: String, createDirectories: Bool = true) throws {
        if dryRun {
            logger.info("[DRY-RUN] Would write file: \(path)")
            return
        }

        // Create parent directories if needed
        if createDirectories {
            let parentDirectory = (path as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: parentDirectory) {
                try createDirectory(at: parentDirectory)
            }
        }

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            logger.debug("Successfully wrote file: \(path)")
        } catch {
            logger.error("Failed to write file: \(path)")
            throw FileOperationError.writeError(path, error)
        }
    }

    /// Create directory at given path
    /// - Parameter path: Directory path to create
    /// - Throws: FileOperationError if creation fails
    public func createDirectory(at path: String) throws {
        if dryRun {
            logger.info("[DRY-RUN] Would create directory: \(path)")
            return
        }

        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Successfully created directory: \(path)")
        } catch {
            logger.error("Failed to create directory: \(path)")
            throw FileOperationError.directoryCreationFailed(path, error)
        }
    }

    /// Create backup of existing file
    /// - Parameter path: Path to file to backup
    /// - Returns: Backup file path
    /// - Throws: FileOperationError if backup fails
    public func createBackup(of path: String) throws -> String {
        let backupPath = path + ".backup"

        if dryRun {
            logger.info("[DRY-RUN] Would create backup: \(backupPath)")
            return backupPath
        }

        if fileExists(at: path) {
            do {
                let content = try readFile(at: path)
                try writeFile(content: content, to: backupPath, createDirectories: false)
                logger.debug("Created backup: \(backupPath)")
                return backupPath
            } catch {
                throw error
            }
        }

        return backupPath
    }

    /// Create backup of existing file only if backup flag is enabled
    /// - Parameters:
    ///   - path: Path to file to backup
    ///   - shouldBackup: Whether backup should be created
    /// - Returns: Backup file path if created, nil otherwise
    /// - Throws: FileOperationError if backup fails
    public func createBackupIfNeeded(of path: String, shouldBackup: Bool) throws -> String? {
        guard shouldBackup else {
            logger.debug("Backup skipped for: \(path)")
            return nil
        }

        return try createBackup(of: path)
    }

    /// Resolve plugin.xml path from input or default
    /// - Parameter inputPath: Optional input path
    /// - Returns: Resolved absolute path to plugin.xml
    public func resolvePluginXMLPath(_ inputPath: String?) -> String {
        if let inputPath {
            if inputPath.hasPrefix("/") {
                inputPath
            } else {
                FileManager.default.currentDirectoryPath + "/" + inputPath
            }
        } else {
            FileManager.default.currentDirectoryPath + "/plugin.xml"
        }
    }

    /// Find the relative path for public headers within the source directory
    /// - Parameter sourcePath: The source path to search for header files
    /// - Returns: Relative path to headers directory, or empty string if no headers found
    public func findPublicHeadersPath(in sourcePath: String) -> String {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let fullSourcePath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(sourcePath).path

        // Check if source directory exists
        guard fileExists(at: fullSourcePath) else {
            logger.debug("Source directory does not exist: \(fullSourcePath)")
            return ""
        }

        // Look for .h files recursively
        if let headerFiles = findHeaderFiles(in: fullSourcePath) {
            if !headerFiles.isEmpty {
                logger.debug("Found \(headerFiles.count) header files in \(sourcePath)")
                // Find the most common directory containing headers
                let headerDirs = headerFiles.compactMap { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
                let mostCommonDir = findMostCommonDirectory(in: headerDirs, relativeTo: fullSourcePath)
                return mostCommonDir
            }
        }

        logger.debug("No header files found in \(sourcePath)")
        return ""
    }

    /// Recursively find all .h files in a directory
    /// - Parameter directory: Directory to search
    /// - Returns: Array of header file paths, or nil if directory cannot be read
    private func findHeaderFiles(in directory: String) -> [String]? {
        guard let enumerator = FileManager.default.enumerator(atPath: directory) else {
            return nil
        }

        var headerFiles: [String] = []
        for case let file as String in enumerator where file.hasSuffix(".h") {
            headerFiles.append(URL(fileURLWithPath: directory).appendingPathComponent(file).path)
        }

        return headerFiles
    }

    /// Find the most common directory path relative to source path
    /// - Parameters:
    ///   - directories: Array of directory paths
    ///   - sourcePath: Base source path to make relative paths
    /// - Returns: Relative path to most common directory, or empty string
    private func findMostCommonDirectory(in directories: [String], relativeTo sourcePath: String) -> String {
        guard !directories.isEmpty else { return "" }

        // Count occurrences of each directory
        let dirCounts = directories.reduce(into: [String: Int]()) { counts, dir in
            counts[dir, default: 0] += 1
        }

        // Find most common directory
        guard let mostCommonDir = dirCounts.max(by: { $0.value < $1.value })?.key else {
            return ""
        }

        // Make path relative to source directory
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let headerURL = URL(fileURLWithPath: mostCommonDir)

        // Calculate relative path
        let sourceAbsPath = sourceURL.path
        let headerAbsPath = headerURL.path

        // If header directory is exactly the same as source directory
        if headerAbsPath == sourceAbsPath {
            return "."
        }

        // If header directory is a subdirectory of source
        if headerAbsPath.hasPrefix(sourceAbsPath + "/") {
            let relativePath = String(headerAbsPath.dropFirst(sourceAbsPath.count + 1))
            return relativePath.isEmpty ? "." : relativePath
        }

        return "."
    }
}

/// Handles .gitignore file updates
public class GitignoreManager {
    private let fileManager: FileSystemManager
    private let logger: Logger

    public init(fileManager: FileSystemManager, logger: Logger) {
        self.fileManager = fileManager
        self.logger = logger
    }

    /// Update .gitignore with Swift Package Manager build artifacts
    /// - Parameters:
    ///   - targetDirectory: Directory containing .gitignore
    ///   - shouldBackup: Whether to create backup before modifying
    /// - Returns: ConversionResult indicating success or failure
    public func updateGitignore(in targetDirectory: String, shouldBackup: Bool = false) -> ConversionResult {
        let gitignorePath = (targetDirectory as NSString).appendingPathComponent(".gitignore")

        do {
            // Read existing .gitignore or create empty content
            var currentContent = ""
            if fileManager.fileExists(at: gitignorePath) {
                currentContent = try fileManager.readFile(at: gitignorePath)
            }

            // Parse existing lines
            var lines = currentContent.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Check for required entries
            let requiredEntries = [".build/", ".swiftpm/", "Package.resolved"]
            let commentLine = "# Swift Package Manager"
            var hasChanges = false

            // Check if any of the required entries are missing
            let missingEntries = requiredEntries.filter { !lines.contains($0) }

            if !missingEntries.isEmpty {
                // Add the comment if it's not already present
                if !lines.contains(commentLine) {
                    lines.append("")
                    lines.append(commentLine)
                }

                // Add all missing entries
                for entry in missingEntries {
                    lines.append(entry)
                    hasChanges = true
                    logger.debug("Adding \(entry) to .gitignore")
                }
            }

            if hasChanges {
                // Create backup before modifying if backup flag is enabled
                if let backupPath = try fileManager.createBackupIfNeeded(
                    of: gitignorePath,
                    shouldBackup: shouldBackup
                ) {
                    logger.debug("Created .gitignore backup: \(backupPath)")
                }

                let newContent = lines.joined(separator: "\n") + "\n"
                try fileManager.writeFile(content: newContent, to: gitignorePath)
                return .success("Updated .gitignore with Swift Package Manager entries")
            } else {
                return .skipped(".gitignore already contains required entries")
            }

        } catch {
            logger.error("Failed to update .gitignore: \(error.localizedDescription)")
            return .error("Failed to update .gitignore: \(error.localizedDescription)")
        }
    }
}

/// Utility extensions for path operations
extension String {
    /// Get directory path from file path
    var directoryPath: String {
        (self as NSString).deletingLastPathComponent
    }

    /// Append path component
    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }
}
