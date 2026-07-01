import Foundation

/// Parses raw Cordova compiler-flags strings into structured SPM CCompilerSetting values.
/// Only -D (preprocessor define) flags are extracted; other flags (e.g. -w) are ignored
/// because SPM's cSettings API does not have a safe equivalent for warning control flags.
public enum CompilerFlagsParser {
    /// Parse a raw compiler flags string into CCompilerSetting values.
    /// - Parameter rawFlags: Flags string from the compiler-flags attribute,
    ///   e.g. "-DSQLITE_HAS_CODEC -DHAVE_USLEEP=1 -w"
    /// - Returns: Array of CCompilerSetting (defines only; non-define flags are skipped)
    public static func parse(_ rawFlags: String) -> [CCompilerSetting] {
        rawFlags
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("-D") }
            .compactMap { token -> CCompilerSetting? in
                let definition = String(token.dropFirst(2))
                guard !definition.isEmpty else { return nil }
                if let equalsIndex = definition.firstIndex(of: "=") {
                    let key = String(definition[definition.startIndex ..< equalsIndex])
                    let value = String(definition[definition.index(after: equalsIndex)...])
                    guard !key.isEmpty else { return nil }
                    return .defineWithValue(key, value)
                }
                return .define(definition)
            }
    }

    /// Merge multiple CCompilerSetting arrays into one, deduplicating by rendered spmCode.
    /// - Parameter settingsArrays: Arrays to merge
    /// - Returns: Deduplicated, ordered result (first occurrence wins)
    public static func merge(_ settingsArrays: [[CCompilerSetting]]) -> [CCompilerSetting] {
        var seen = Set<String>()
        var result: [CCompilerSetting] = []
        for setting in settingsArrays.flatMap({ $0 }) where seen.insert(setting.spmCode).inserted {
            result.append(setting)
        }
        return result
    }
}
