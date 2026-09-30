import Foundation

// MARK: - Import Injection

/// Detection and insertion of the imports a Swift package build needs, which a CocoaPods build
/// gets implicitly from the app target's bridging header.
extension SwiftImportManager {
    /// Modules that make Foundation's types available, by being Foundation or by re-exporting it.
    static let foundationProvidingModules: Set = ["Foundation", "UIKit", "SwiftUI", "AppKit"]

    /// Foundation types a plugin's Swift sources commonly rely on. `NS`-prefixed types are matched
    /// by pattern, since they all come from Foundation or from a framework that re-exports it.
    static let foundationTypePattern = """
    \\b(Data|Date|DateFormatter|DateComponents|Calendar|TimeZone|Locale|URL|URLRequest|URLResponse|\
    URLSession|URLComponents|URLQueryItem|FileManager|FileHandle|Bundle|UUID|IndexPath|CharacterSet|\
    JSONSerialization|JSONEncoder|JSONDecoder|PropertyListSerialization|NotificationCenter|Notification|\
    Timer|RunLoop|Thread|OperationQueue|Operation|Progress|Scanner|NumberFormatter|Measurement|\
    NS[A-Z][A-Za-z0-9]*)\\b
    """

    /// Add `import Foundation` to a file that uses Foundation types without importing it.
    ///
    /// Compiled through CocoaPods the plugin's sources become part of the app target, which has a
    /// bridging header pulling Foundation in implicitly. A Swift package has no bridging header, so
    /// the same file fails to build with errors such as `cannot find 'Data' in scope`.
    func addFoundationImportIfNeeded(to content: String, fileName: String) -> String {
        guard !hasFoundationProvidingImport(content), usesFoundationTypes(content) else { return content }

        logger.debug("Adding missing import Foundation: \(fileName)")
        // A file with imports gets the line alongside them; one without also gets a blank separator
        let block = hasAnyImport(content) ? ["import Foundation"] : ["import Foundation", ""]
        return inserting(block, into: content)
    }

    /// Insert `block` before the file's first import, or — when there is none — before the first
    /// line of real code, so a leading comment or license header stays at the top.
    func inserting(_ block: [String], into content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let insertIndex = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
            ?? firstCodeLineIndex(in: lines)

        var newLines = Array(lines[0 ..< insertIndex])
        newLines.append(contentsOf: block)
        newLines.append(contentsOf: lines[insertIndex...])
        return newLines.joined(separator: "\n")
    }

    private func hasFoundationProvidingImport(_ content: String) -> Bool {
        importedModules(in: content).contains { Self.foundationProvidingModules.contains($0) }
    }

    private func hasAnyImport(_ content: String) -> Bool {
        !importedModules(in: content).isEmpty
    }

    /// Module names imported by the file, e.g. `["Foundation", "IONFilesystemLib"]`. A submodule
    /// import such as `import Foundation.NSData` contributes its root module.
    private func importedModules(in content: String) -> [String] {
        content.components(separatedBy: .newlines).compactMap { line -> String? in
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@") {
                // Strip attributes such as @_exported / @testable
                trimmed = String(trimmed.drop(while: { $0 != " " })).trimmingCharacters(in: .whitespaces)
            }
            guard trimmed.hasPrefix("import ") else { return nil }
            let module = String(trimmed.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
            return module.components(separatedBy: ".").first.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    private func usesFoundationTypes(_ content: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: Self.foundationTypePattern) else { return false }
        let range = NSRange(content.startIndex ..< content.endIndex, in: content)
        return regex.firstMatch(in: content, options: [], range: range) != nil
    }

    /// Index of the first line that is neither blank nor part of a comment block. Falls back to the
    /// end of the file, which handles a file that is entirely comments.
    private func firstCodeLineIndex(in lines: [String]) -> Int {
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty,
               !trimmedLine.hasPrefix("//"),
               !trimmedLine.hasPrefix("/*"),
               !trimmedLine.hasPrefix("*") {
                return index
            }
        }
        return lines.count
    }
}
