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

        /// Collect Cordova variable preferences (name → default value).
        /// Plugin-level preferences are a baseline; platform-level ones override them.
        func collectPreferences(from indexer: XMLIndexer) -> [String: String] {
            var prefs: [String: String] = [:]
            for pref in indexer["preference"].all {
                if let name = pref.element?.attribute(by: "name")?.text,
                   let defaultValue = pref.element?.attribute(by: "default")?.text {
                    prefs[name] = defaultValue
                }
            }
            return prefs
        }

        let pluginPreferences = collectPreferences(from: xml["plugin"])

        // Extract pod dependencies from all platforms
        var allDependencies: [PodDependency] = []
        var hasPodspec = false
        var localFrameworks: [LocalXCFramework] = []

        /// Helper to parse pod elements from a podspec node
        func parsePods(from podspec: XMLIndexer, preferences: [String: String]) {
            let podElements = podspec["pods"]["pod"].all
            for podElement in podElements {
                guard let name = podElement.element?.attribute(by: "name")?.text else { continue }

                // Resolve Cordova variable substitution in spec (e.g. "$MY_VERSION" → "1.2.3")
                let rawSpec = podElement.element?.attribute(by: "spec")?.text
                let spec = rawSpec.map { resolveVariable($0, using: preferences) }

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

        // Look for podspec sections and xcframeworks only in iOS platform
        for platform in xml["plugin"]["platform"].all {
            // Only process iOS platforms
            if let platformName = platform.element?.attribute(by: "name")?.text,
               platformName.lowercased() == "ios" {
                // Merge plugin-level preferences with platform-level ones (platform wins)
                var preferences = pluginPreferences
                preferences.merge(collectPreferences(from: platform)) { _, new in new }

                if platform["podspec"].element != nil {
                    hasPodspec = true
                    parsePods(from: platform["podspec"], preferences: preferences)
                }

                // Collect local .xcframework bundles declared with custom="true"
                for framework in platform["framework"].all {
                    guard let src = framework.element?.attribute(by: "src")?.text,
                          src.hasSuffix(".xcframework"),
                          framework.element?.attribute(by: "custom")?.text == "true"
                    else { continue }
                    let name = URL(fileURLWithPath: src).deletingPathExtension().lastPathComponent
                    let fw = LocalXCFramework(name: name, path: src)
                    if !localFrameworks.contains(fw) {
                        localFrameworks.append(fw)
                    }
                }
            }
        }

        return PluginMetadata(
            pluginId: pluginId,
            dependencies: allDependencies,
            hasPodspec: hasPodspec,
            originalXmlContent: content,
            localFrameworks: localFrameworks
        )
    }

    /// Resolve a Cordova variable reference in a spec string.
    /// If the value is exactly `$VAR_NAME`, returns the preference default for `VAR_NAME`.
    /// Otherwise returns the original value unchanged.
    private static func resolveVariable(_ value: String, using preferences: [String: String]) -> String {
        guard value.hasPrefix("$") else { return value }
        let varName = String(value.dropFirst())
        return preferences[varName] ?? value
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
            // Pattern matches <pod> tags whose attributes are double-quoted.
            // Using `"[^"]*"` for each value means `>` inside quotes (e.g. spec="~> 3.0")
            // is consumed as part of the value and never treated as the tag-close character.
            let podPattern = #"<pod(?:\s+[^=\s>]+="[^"]*")*\s*/?>"#
            guard let podRegex = try? NSRegularExpression(pattern: podPattern, options: []) else {
                return updatedContent
            }

            let podMatches = podRegex.matches(
                in: updatedContent,
                range: NSRange(updatedContent.startIndex..., in: updatedContent)
            )

            for match in podMatches.reversed() {
                let matchedString = (updatedContent as NSString).substring(with: match.range)
                let replacement: String = if matchedString.contains("nospm=") {
                    // Update existing nospm attribute in place
                    matchedString.replacingOccurrences(
                        of: #"nospm="[^"]*""#,
                        with: #"nospm="true""#,
                        options: .regularExpression
                    )
                } else if matchedString.hasSuffix("/>") {
                    // Self-closing tag: insert before />
                    String(matchedString.dropLast(2)) + " nospm=\"true\" />"
                } else {
                    // Regular tag: insert before the closing >
                    String(matchedString.dropLast(1)) + " nospm=\"true\">"
                }

                updatedContent = (updatedContent as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        return updatedContent
    }
}
