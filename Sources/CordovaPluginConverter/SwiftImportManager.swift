import Foundation

/// Manages adding Cordova imports to Swift source files
public class SwiftImportManager {
    private let logger: Logger
    private let fileManager: FileSystemManager
    
    public init(logger: Logger, fileManager: FileSystemManager) {
        self.logger = logger
        self.fileManager = fileManager
    }
    
    /// Add conditional Cordova import to all Swift files in src/ios directory
    /// - Parameter pluginDirectory: The root directory of the plugin
    /// - Returns: True if successful, false otherwise
    public func addCordovaImports(in pluginDirectory: String) -> Bool {
        logger.info("Adding conditional Cordova imports to Swift files...")
        
        let srcIOSPath = URL(fileURLWithPath: pluginDirectory).appendingPathComponent("src/ios").path
        
        guard FileManager.default.fileExists(atPath: srcIOSPath) else {
            logger.debug("No src/ios directory found at: \(srcIOSPath)")
            return true // Not an error, just nothing to do
        }
        
        let swiftFiles = findSwiftFiles(in: srcIOSPath)
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
            logger.info("No Swift files found in src/ios directory")
        } else {
            logger.info("Swift import processing complete: \(successCount) succeeded, \(errorCount) failed")
        }
        
        return errorCount == 0
    }
    
    // MARK: - Private Methods
    
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
            if trimmedLine.hasPrefix("import ") && !foundFirstImport {
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
                if !trimmedLine.isEmpty &&
                   !trimmedLine.hasPrefix("//") &&
                   !trimmedLine.hasPrefix("/*") &&
                   !trimmedLine.hasPrefix("*") {
                    insertIndex = index
                    break
                }
            }

            newLines = Array(lines[0..<insertIndex])
            newLines.append("#if canImport(Cordova)")
            newLines.append("import Cordova")
            newLines.append("#endif")
            newLines.append("")
            newLines.append(contentsOf: lines[insertIndex...])
        }
        
        return newLines.joined(separator: "\n")
    }
}
