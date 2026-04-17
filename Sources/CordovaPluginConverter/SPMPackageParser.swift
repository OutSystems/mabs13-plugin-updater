import Foundation

/// Handles parsing of Package.swift files to extract dependency information
public class SPMPackageParser {
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    /// Parse Package.swift content to extract package information
    /// - Parameter content: The Package.swift file content
    /// - Returns: SPMPackageInfo if parsing is successful, nil otherwise
    public func parsePackageSwift(_ content: String) -> SPMPackageInfo? {
        logger.debug("Parsing Package.swift content")
        
        let packageInfo = parsePackageContent(content)
        logger.debug("Successfully parsed Package.swift")
        return packageInfo
    }
    
    /// Check if the Package.swift represents a library (not just an executable)
    /// - Parameter content: The Package.swift file content
    /// - Returns: True if it's a library package, false otherwise
    public func isLibraryPackage(_ content: String) -> Bool {
        // Look for .library in products
        content.contains(".library(")
    }
    
    // MARK: - Private Parsing Methods
    
    private func parsePackageContent(_ content: String) -> SPMPackageInfo {
        let packageName = extractPackageName(content) ?? "UnknownPackage"
        let dependencies = extractDependencies(content)
        let products = extractProducts(content)
        let targets = extractTargets(content)
        
        return SPMPackageInfo(
            name: packageName,
            dependencies: dependencies,
            products: products,
            targets: targets
        )
    }
    
    private func extractPackageName(_ content: String) -> String? {
        // Look for: name: "PackageName"
        let pattern = #"name:\s*"([^"]+)""#
        return extractFirstCaptureGroup(from: content, pattern: pattern)
    }
    
    private func extractDependencies(_ content: String) -> [SPMDependency] {
        var dependencies: [SPMDependency] = []
        
        // Extract dependencies section
        guard let dependenciesSection = extractSection(from: content, sectionName: "dependencies") else {
            return dependencies
        }
        
        // Pattern for .package(url: "...", ...)
        let packagePattern = #"\.package\s*\(\s*url:\s*"([^"]+)"[^)]*\)"#
        let matches = findMatches(in: dependenciesSection, pattern: packagePattern)
        
        for match in matches {
            if let url = extractCaptureGroup(from: dependenciesSection, match: match, groupIndex: 1) {
                // Try to extract requirement information
                let requirement = extractRequirement(from: match.fullMatch, in: dependenciesSection)
                dependencies.append(SPMDependency(url: url, requirement: requirement))
            }
        }
        
        return dependencies
    }
    
    private func extractProducts(_ content: String) -> [SPMProduct] {
        var products: [SPMProduct] = []
        
        guard let productsSection = extractSection(from: content, sectionName: "products") else {
            return products
        }
        
        // Pattern for .library(name: "Name", targets: ["Target"])
        let libraryPattern = #"\.library\s*\(\s*name:\s*"([^"]+)"[^)]*targets:\s*\[([^\]]*)\]"#
        let libraryMatches = findMatches(in: productsSection, pattern: libraryPattern)
        
        for match in libraryMatches {
            if let name = extractCaptureGroup(from: productsSection, match: match, groupIndex: 1),
               let targetsString = extractCaptureGroup(from: productsSection, match: match, groupIndex: 2) {
                let targets = parseStringArray(targetsString)
                products.append(SPMProduct(name: name, type: .library, targets: targets))
            }
        }
        
        // Pattern for .executable(name: "Name", targets: ["Target"])
        let executablePattern = #"\.executable\s*\(\s*name:\s*"([^"]+)"[^)]*targets:\s*\[([^\]]*)\]"#
        let executableMatches = findMatches(in: productsSection, pattern: executablePattern)
        
        for match in executableMatches {
            if let name = extractCaptureGroup(from: productsSection, match: match, groupIndex: 1),
               let targetsString = extractCaptureGroup(from: productsSection, match: match, groupIndex: 2) {
                let targets = parseStringArray(targetsString)
                products.append(SPMProduct(name: name, type: .executable, targets: targets))
            }
        }
        
        return products
    }
    
    private func extractTargets(_ content: String) -> [SPMTarget] {
        var targets: [SPMTarget] = []
        
        guard let targetsSection = extractSection(from: content, sectionName: "targets") else {
            return targets
        }
        
        // Pattern for .target(name: "Name", ...)
        let targetPattern = #"\.target\s*\(\s*name:\s*"([^"]+)"[^)]*\)"#
        let matches = findMatches(in: targetsSection, pattern: targetPattern)
        
        for match in matches {
            if let name = extractCaptureGroup(from: targetsSection, match: match, groupIndex: 1) {
                // Extract dependencies
                let dependencies = extractTargetDependencies(from: match.fullMatch, in: targetsSection)
                targets.append(SPMTarget(name: name, dependencies: dependencies))
            }
        }
        
        return targets
    }
    
    private func extractRequirement(from matchText: String, in content: String) -> SPMRequirement {
        // Look for various requirement patterns
        if let version = extractFirstCaptureGroup(from: matchText, pattern: #"from:\s*"([^"]+)""#) {
            .from(version)
        } else if let version = extractFirstCaptureGroup(from: matchText, pattern: #"exact:\s*"([^"]+)""#) {
            .exact(version)
        } else if let branch = extractFirstCaptureGroup(from: matchText, pattern: #"branch:\s*"([^"]+)""#) {
            .branch(branch)
        } else if let tag = extractFirstCaptureGroup(from: matchText, pattern: #"revision:\s*"([^"]+)""#) {
            .tag(tag)
        } else {
            // Default to latest if no specific requirement is found
            .from("0.0.0")
        }
    }
    
    private func extractTargetDependencies(from matchText: String, in content: String) -> [String] {
        guard let dependenciesString = extractFirstCaptureGroup(
            from: matchText,
            pattern: #"dependencies:\s*\[([^\]]*)\]"#
        ) else {
            return []
        }
        return parseStringArray(dependenciesString)
    }
    
    // MARK: - Helper Methods
    
    private func extractSection(from content: String, sectionName: String) -> String? {
        // [^\[\]]* excludes both [ and ] so nested arrays like targets: ["Foo"] are not swallowed
        // before (?:\[[^\]]*\]) can match them.
        let pattern = #"\#(sectionName):\s*\[([^\[\]]*(?:\[[^\]]*\][^\[\]]*)*)\]"#
        return extractFirstCaptureGroup(from: content, pattern: pattern)
    }
    
    private func extractFirstCaptureGroup(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func findMatches(in text: String, pattern: String) -> [(fullMatch: String, range: NSRange)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return (String(text[range]), match.range)
        }
    }
    
    private func extractCaptureGroup(from text: String, match: (fullMatch: String, range: NSRange),
                                     groupIndex: Int)
        -> String? {
        let pattern = #"\.(?:library|executable|target)\s*\([^)]*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let regexMatch = regex.firstMatch(in: text, options: [], range: match.range),
              regexMatch.numberOfRanges > groupIndex,
              let range = Range(regexMatch.range(at: groupIndex), in: text) else {
            // Fallback: try to extract from the full match string directly
            return extractFirstCaptureGroup(from: match.fullMatch, pattern: getGroupPattern(for: groupIndex))
        }
        
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getGroupPattern(for index: Int) -> String {
        switch index {
        case 1:
            #"name:\s*"([^"]+)""#
        case 2:
            #"targets:\s*\[([^\]]*)\]"#
        default:
            #"([^"]+)"#
        }
    }
    
    private func parseStringArray(_ arrayString: String) -> [String] {
        let pattern = #""([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let matches = regex.matches(
            in: arrayString,
            options: [],
            range: NSRange(location: 0, length: arrayString.count)
        )
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: arrayString) else { return nil }
            return String(arrayString[range])
        }
    }
}
