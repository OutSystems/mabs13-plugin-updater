import Foundation
import SWXMLHash

/// Errors that can occur during XML parsing
public enum XMLParsingError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidXML(String)
    case missingPluginId
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            "Plugin XML file not found at: \(path)"
        case let .invalidXML(reason):
            "Invalid XML content: \(reason)"
        case .missingPluginId:
            "Plugin XML is missing required 'id' attribute"
        case let .parsingFailed(reason):
            "Failed to parse XML: \(reason)"
        }
    }
}

/// Handles parsing of Cordova plugin.xml files
public class XMLParser {
    /// Parse plugin.xml file and extract metadata
    /// - Parameter xmlPath: Path to the plugin.xml file
    /// - Returns: Parsed plugin metadata
    /// - Throws: XMLParsingError if parsing fails
    public static func parsePluginXML(at xmlPath: String) throws -> PluginMetadata {
        // Read file content
        guard let xmlContent = try? String(contentsOfFile: xmlPath, encoding: .utf8) else {
            throw XMLParsingError.fileNotFound(xmlPath)
        }

        return try parsePluginXML(content: xmlContent)
    }

    /// Parse plugin.xml content and extract metadata
    /// - Parameter content: Raw XML content as string
    /// - Returns: Parsed plugin metadata
    /// - Throws: XMLParsingError if parsing fails
    public static func parsePluginXML(content: String) throws -> PluginMetadata {
        let xml = XMLHash.parse(content)

        // Extract plugin ID
        guard let pluginId = xml["plugin"].element?.attribute(by: "id")?.text else {
            throw XMLParsingError.missingPluginId
        }

        // Extract pod dependencies from all platforms
        var allDependencies: [PodDependency] = []
        var hasPodspec = false

        // Helper to parse pod elements from a podspec node
        func parsePods(from podspec: XMLIndexer) {
            let podElements = podspec["pods"]["pod"].all
            for podElement in podElements {
                guard let name = podElement.element?.attribute(by: "name")?.text else { continue }
                let spec = podElement.element?.attribute(by: "spec")?.text
                let git = podElement.element?.attribute(by: "git")?.text
                let tag = podElement.element?.attribute(by: "tag")?.text
                let branch = podElement.element?.attribute(by: "branch")?.text
                // Require at least spec or git to create a dependency
                guard spec != nil || git != nil else { continue }
                let dependency = PodDependency(name: name, spec: spec, git: git, tag: tag, branch: branch)
                if !allDependencies.contains(dependency) {
                    allDependencies.append(dependency)
                }
            }
        }

        // Look for podspec sections only in iOS platform
        for platform in xml["plugin"]["platform"].all {
            // Only process iOS platforms
            if let platformName = platform.element?.attribute(by: "name")?.text,
               platformName.lowercased() == "ios" {
                if platform["podspec"].element != nil {
                    hasPodspec = true
                    parsePods(from: platform["podspec"])
                }
            }
        }

        return PluginMetadata(
            pluginId: pluginId,
            dependencies: allDependencies,
            hasPodspec: hasPodspec,
            originalXmlContent: content
        )
    }

    /// Generate updated plugin.xml content with iOS platform package attribute
    /// - Parameters:
    ///   - metadata: Original plugin metadata
    ///   - addNospmAttribute: Whether to add nospm="true" attribute to pod elements (default: true)
    /// - Returns: Updated XML content with package="swift" for iOS platform and nospm attributes
    public static func generateUpdatedXML(from metadata: PluginMetadata, addNospmAttribute: Bool = true) -> String {
        var updatedContent = metadata.originalXmlContent

        // First: Always ensure iOS platform has package="swift" attribute
        let platformPattern = #"<platform\s+name="ios"([^>]*?)>"#
        guard let platformRegex = try? NSRegularExpression(pattern: platformPattern, options: []) else {
            return updatedContent // Return original content if regex fails
        }

        let nsString = updatedContent as NSString
        let matches = platformRegex.matches(in: updatedContent, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let matchedString = nsString.substring(with: match.range)
            let replacement: String = if matchedString.contains("package=") {
                // Replace existing package attribute with "swift"
                matchedString.replacingOccurrences(
                    of: #"package="[^"]*""#,
                    with: #"package="swift""#,
                    options: .regularExpression
                )
            } else {
                // Add package="swift" attribute
                matchedString.replacingOccurrences(of: ">", with: " package=\"swift\">")
            }

            updatedContent = (updatedContent as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        // Second: Add nospm="true" attribute to pod elements (if requested)
        if addNospmAttribute {
            let podPattern = #"<pod\s+([^>]*?)/?>"#
            guard let podRegex = try? NSRegularExpression(pattern: podPattern, options: []) else {
                return updatedContent // Return content if regex fails
            }

            let podMatches = podRegex.matches(in: updatedContent, range: NSRange(location: 0, length: (updatedContent as NSString).length))

            for match in podMatches.reversed() {
                let matchedString = (updatedContent as NSString).substring(with: match.range)
                let replacement: String = if matchedString.contains("nospm=") {
                    // Replace existing nospm attribute with "true"
                    matchedString.replacingOccurrences(
                        of: #"nospm="[^"]*""#,
                        with: #"nospm="true""#,
                        options: .regularExpression
                    )
                } else {
                    // Add nospm="true" attribute - handle both self-closing and regular tags
                    if matchedString.contains("/>") {
                        matchedString.replacingOccurrences(of: "/>", with: " nospm=\"true\" />")
                    } else {
                        matchedString.replacingOccurrences(of: ">", with: " nospm=\"true\">")
                    }
                }

                updatedContent = (updatedContent as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        return updatedContent
    }
}
