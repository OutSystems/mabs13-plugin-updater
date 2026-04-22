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

        guard let pluginId = xml["plugin"].element?.attribute(by: "id")?.text else {
            throw XMLParsingError.missingPluginId
        }

        let pluginPreferences = collectPreferences(from: xml["plugin"])
        var allDependencies: [PodDependency] = []
        var hasPodspec = false
        var localFrameworks: [LocalXCFramework] = []
        var nativeSources: [NativeSourceFile] = []
        var systemFrameworks: [SystemFramework] = []
        var headerPaths: [String] = []
        let pluginDependencies = parseCordovaPluginDependencies(from: xml["plugin"])

        for platform in xml["plugin"]["platform"].all {
            guard let platformName = platform.element?.attribute(by: "name")?.text,
                  platformName.lowercased() == "ios" else { continue }

            var preferences = pluginPreferences
            preferences.merge(collectPreferences(from: platform)) { _, new in new }

            if platform["podspec"].element != nil {
                hasPodspec = true
                let pods = parsePods(from: platform["podspec"], preferences: preferences)
                for pod in pods where !allDependencies.contains(pod) {
                    allDependencies.append(pod)
                }
            }

            let newSources = parseNativeSources(from: platform)
            for source in newSources where !nativeSources.contains(where: { $0.path == source.path }) {
                nativeSources.append(source)
            }
            for path in parseHeaderPaths(from: platform) where !headerPaths.contains(path) {
                headerPaths.append(path)
            }
            let (local, system) = parseFrameworks(from: platform)
            for fw in local where !localFrameworks.contains(fw) { localFrameworks.append(fw) }
            for fw in system where !systemFrameworks.contains(fw) { systemFrameworks.append(fw) }
        }

        return PluginMetadata(
            pluginId: pluginId,
            dependencies: allDependencies,
            hasPodspec: hasPodspec,
            originalXmlContent: content,
            localFrameworks: localFrameworks,
            nativeSources: nativeSources,
            systemFrameworks: systemFrameworks,
            headerPaths: headerPaths,
            pluginDependencies: pluginDependencies
        )
    }

    /// Collect Cordova variable preferences (name → default value).
    private static func collectPreferences(from indexer: XMLIndexer) -> [String: String] {
        var prefs: [String: String] = [:]
        for pref in indexer["preference"].all {
            if let name = pref.element?.attribute(by: "name")?.text,
               let defaultValue = pref.element?.attribute(by: "default")?.text {
                prefs[name] = defaultValue
            }
        }
        return prefs
    }

    /// Parse pod elements from a podspec node, resolving Cordova variable substitutions.
    private static func parsePods(from podspec: XMLIndexer, preferences: [String: String]) -> [PodDependency] {
        var dependencies: [PodDependency] = []
        for podElement in podspec["pods"]["pod"].all {
            guard let name = podElement.element?.attribute(by: "name")?.text else { continue }
            let rawSpec = podElement.element?.attribute(by: "spec")?.text
            let spec = rawSpec.map { resolveVariable($0, using: preferences) }
            let git = podElement.element?.attribute(by: "git")?.text
            let tag = podElement.element?.attribute(by: "tag")?.text
            let branch = podElement.element?.attribute(by: "branch")?.text
            guard spec != nil || git != nil else { continue }
            let dependency = PodDependency(name: name, spec: spec, git: git, tag: tag, branch: branch)
            if !dependencies.contains(dependency) { dependencies.append(dependency) }
        }
        return dependencies
    }

    /// Resolve a Cordova variable reference in a spec string.
    /// If the value is exactly `$VAR_NAME`, returns the preference default for `VAR_NAME`.
    /// Otherwise returns the original value unchanged.
    private static func resolveVariable(_ value: String, using preferences: [String: String]) -> String {
        guard value.hasPrefix("$") else { return value }
        let varName = String(value.dropFirst())
        return preferences[varName] ?? value
    }

    private static func parseNativeSources(from platform: XMLIndexer) -> [NativeSourceFile] {
        platform["source-file"].all.compactMap { element in
            guard let src = element.element?.attribute(by: "src")?.text else { return nil }
            let flags = element.element?.attribute(by: "compiler-flags")?.text ?? ""
            return NativeSourceFile(path: src, rawCompilerFlags: flags)
        }
    }

    private static func parseHeaderPaths(from platform: XMLIndexer) -> [String] {
        platform["header-file"].all.compactMap { $0.element?.attribute(by: "src")?.text }
    }

    private static func parseFrameworks(
        from platform: XMLIndexer
    ) -> (local: [LocalXCFramework], system: [SystemFramework]) {
        var local: [LocalXCFramework] = []
        var system: [SystemFramework] = []
        for framework in platform["framework"].all {
            guard let src = framework.element?.attribute(by: "src")?.text else { continue }
            let isCustom = framework.element?.attribute(by: "custom")?.text == "true"
            let fwType = framework.element?.attribute(by: "type")?.text ?? ""
            if src.hasSuffix(".xcframework"), isCustom {
                let name = URL(fileURLWithPath: src).deletingPathExtension().lastPathComponent
                local.append(LocalXCFramework(name: name, path: src))
                continue
            }
            guard !isCustom,
                  fwType != "gradleReference", fwType != "projectReference",
                  !src.contains(":") else { continue }
            let name = src.hasSuffix(".framework") ? String(src.dropLast(".framework".count)) : src
            system.append(SystemFramework(name: name))
        }
        return (local, system)
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

// MARK: - Cordova Plugin Dependency Parsing

extension XMLParser {
    /// Parse top-level <dependency> elements that represent Cordova plugin dependencies.
    /// Supports both `url=` and `path=` attributes, and extracts branch/tag from URL fragment (#ref).
    fileprivate static func parseCordovaPluginDependencies(from plugin: XMLIndexer) -> [CordovaPluginDependency] {
        var deps: [CordovaPluginDependency] = []
        for dep in plugin["dependency"].all {
            guard let id = dep.element?.attribute(by: "id")?.text else { continue }
            let rawUrl = dep.element?.attribute(by: "url")?.text
                ?? dep.element?.attribute(by: "path")?.text
            guard let rawUrl,
                  rawUrl.contains("github.com") || rawUrl.contains("gitlab") || rawUrl.hasSuffix(".git")
            else { continue }
            let components = parseGitUrlWithFragment(rawUrl)
            guard !components.gitUrl.isEmpty else { continue }
            let pluginDep = CordovaPluginDependency(id: id, gitUrl: components.gitUrl,
                                                    branch: components.branch, tag: components.tag)
            if !deps.contains(pluginDep) { deps.append(pluginDep) }
        }
        return deps
    }

    private struct GitFragmentComponents {
        let gitUrl: String
        let branch: String?
        let tag: String?
    }

    /// Split a git URL that may contain a `#fragment` into its components.
    /// A fragment that starts with a digit or 'v' followed by a digit is treated as a tag;
    /// anything else (e.g. "spm", "main") is treated as a branch name.
    private static func parseGitUrlWithFragment(_ rawUrl: String) -> GitFragmentComponents {
        guard let hashIndex = rawUrl.firstIndex(of: "#") else {
            return GitFragmentComponents(gitUrl: rawUrl, branch: nil, tag: nil)
        }
        let gitUrl = String(rawUrl[rawUrl.startIndex..<hashIndex])
        let fragment = String(rawUrl[rawUrl.index(after: hashIndex)...])
        guard !fragment.isEmpty else {
            return GitFragmentComponents(gitUrl: gitUrl, branch: nil, tag: nil)
        }
        let looksLikeVersion = fragment.range(of: #"^v?\d"#, options: .regularExpression) != nil
        return looksLikeVersion
            ? GitFragmentComponents(gitUrl: gitUrl, branch: nil, tag: fragment)
            : GitFragmentComponents(gitUrl: gitUrl, branch: fragment, tag: nil)
    }
}
