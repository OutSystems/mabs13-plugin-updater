import Foundation

/// Manages adding Cordova imports to Swift source files
public class SwiftImportManager {
    private let logger: Logger
    private let fileManager: FileSystemManager
    
    public init(logger: Logger, fileManager: FileSystemManager) {
        self.logger = logger
        self.fileManager = fileManager
    }
    
    /// Add the conditional Cordova import to the Swift files of a plugin's iOS sources.
    /// - Parameters:
    ///   - pluginDirectory: The root directory of the plugin
    ///   - sourceDirectories: Directories to scan, relative to the plugin root. These come from the
    ///     plugin's `<source-file>` declarations, so a plugin that keeps its sources somewhere other
    ///     than `src/ios` is still processed. Missing directories are skipped.
    /// - Returns: True if successful, false otherwise
    public func addCordovaImports(
        in pluginDirectory: String,
        sourceDirectories: [String] = ["src/ios"]
    )
        -> Bool {
        logger.info("Adding conditional Cordova imports to Swift files...")

        let existingDirectories = resolveExistingDirectories(sourceDirectories, in: pluginDirectory)

        guard !existingDirectories.isEmpty else {
            logger.warn(
                "None of the plugin's iOS source directories were found, so no Swift file was " +
                    "updated with the conditional Cordova import: \(sourceDirectories.joined(separator: ", "))"
            )
            return true // Not an error, just nothing to do
        }

        let swiftFiles = findSwiftFiles(in: existingDirectories)
        logger.debug("Found \(swiftFiles.count) Swift files to process")

        var successCount = 0
        var errorCount = 0

        for swiftFile in swiftFiles {
            if processSingleSwiftFile(at: swiftFile) {
                successCount += 1
                logger.debug("✓ Processed: \(URL(fileURLWithPath: swiftFile).lastPathComponent)")
            } else {
                errorCount += 1
                logger.error("✗ Failed to process: \(URL(fileURLWithPath: swiftFile).lastPathComponent)")
            }
        }

        if swiftFiles.isEmpty {
            logger.info("No Swift files found in \(existingDirectories.joined(separator: ", "))")
        } else {
            logger.info("Swift import processing complete: \(successCount) succeeded, \(errorCount) failed")
        }

        return errorCount == 0
    }

    // MARK: - Private Methods

    /// Map plugin-relative directories to absolute paths, keeping only those that exist.
    private func resolveExistingDirectories(_ directories: [String], in pluginDirectory: String) -> [String] {
        var seen = Set<String>()
        return directories.compactMap { directory -> String? in
            let fullPath = URL(fileURLWithPath: pluginDirectory).appendingPathComponent(directory).path
            guard seen.insert(fullPath).inserted else { return nil }
            guard FileManager.default.fileExists(atPath: fullPath) else {
                logger.debug("No source directory found at: \(fullPath)")
                return nil
            }
            return fullPath
        }
    }

    /// Collect the Swift files of several directories, without processing a file twice when one
    /// declared directory is nested inside another.
    private func findSwiftFiles(in directories: [String]) -> [String] {
        var seen = Set<String>()
        return directories
            .flatMap { findSwiftFiles(in: $0) }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    private func findSwiftFiles(in directory: String) -> [String] {
        var swiftFiles: [String] = []
        
        guard let enumerator = FileManager.default.enumerator(atPath: directory) else {
            logger.error("Failed to create directory enumerator for: \(directory)")
            return []
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".swift") {
                let fullPath = URL(fileURLWithPath: directory).appendingPathComponent(file).path
                swiftFiles.append(fullPath)
            }
        }
        
        return swiftFiles.sorted()
    }
    
    private func processSingleSwiftFile(at filePath: String) -> Bool {
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Check if file already has Cordova import
            if hasExistingCordovaImport(content) {
                logger.debug("File already has Cordova import: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                return true
            }
            
            // Check if file needs Cordova import (contains Cordova-related code)
            if !needsCordovaImport(content) {
                logger.debug("File doesn't need Cordova import: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                return true
            }
            
            let updatedContent = addConditionalCordovaImport(to: content)
            
            // Use FileSystemManager to handle dry-run logic
            try fileManager.writeFile(content: updatedContent, to: filePath, createDirectories: false)
            
            return true
        } catch {
            logger.error("Failed to process Swift file \(filePath): \(error.localizedDescription)")
            return false
        }
    }
    
    private func hasExistingCordovaImport(_ content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check for existing Cordova imports
            if trimmedLine == "import Cordova" ||
                trimmedLine.contains("#if canImport(Cordova)") ||
                trimmedLine.contains("import Cordova") && trimmedLine.contains("#if") {
                return true
            }
        }
        
        return false
    }
    
    private func needsCordovaImport(_ content: String) -> Bool {
        // List of Cordova-related patterns that indicate the file needs Cordova import
        let cordovaPatterns = [
            "CDVPlugin",
            "CDVCommandDelegate",
            "CDVPluginResult",
            "CDVInvokedUrlCommand",
            "CDVViewController",
            "CDVWebViewEngine",
            "CDVUserAgentUtil",
            "CDVAvailability",
            "CDVTimer",
            "CDVLocalStorage",
            "CDVHandlersFactory",
            "CDVConfigParser",
            "CDVAppDelegate",
            "CDVCommandQueue",
            "CDVConnection",
            "CDVDevice",
            "CDVFile",
            "CDVGlobalization",
            "CDVInAppBrowser",
            "CDVLocation",
            "CDVNotification",
            "CDVSound",
            "CDVSplashScreen",
            "CDVURLProtocol",
            "CDVWhitelist"
        ]
        
        for pattern in cordovaPatterns where content.contains(pattern) {
            return true
        }

        return false
    }
    
    private func addConditionalCordovaImport(to content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var newLines: [String] = []
        var foundFirstImport = false
        var importAdded = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // If this is an import line and we haven't added our import yet
            if trimmedLine.hasPrefix("import "), !foundFirstImport {
                foundFirstImport = true
                
                // Add the conditional Cordova import before the first existing import
                newLines.append("#if canImport(Cordova)")
                newLines.append("import Cordova")
                newLines.append("#endif")
                newLines.append("")
                importAdded = true
            }
            
            newLines.append(line)
        }
        
        // If no imports were found, add after any initial comment/license block
        if !importAdded {
            // Default: append at the end (handles files that are entirely comments)
            var insertIndex = lines.count

            // Find the first line that is not a comment or blank — insert before it
            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if !trimmedLine.isEmpty,
                   !trimmedLine.hasPrefix("//"),
                   !trimmedLine.hasPrefix("/*"),
                   !trimmedLine.hasPrefix("*") {
                    insertIndex = index
                    break
                }
            }

            newLines = Array(lines[0 ..< insertIndex])
            newLines.append("#if canImport(Cordova)")
            newLines.append("import Cordova")
            newLines.append("#endif")
            newLines.append("")
            newLines.append(contentsOf: lines[insertIndex...])
        }
        
        return newLines.joined(separator: "\n")
    }
}
