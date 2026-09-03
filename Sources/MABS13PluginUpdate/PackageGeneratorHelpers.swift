import Foundation

/// Computed layout for an SPM target derived from a plugin's native source declarations.
struct NativeSourceLayout {
    let path: String
    let sources: [String]
    let cSettings: [CCompilerSetting]
}

// MARK: - Native Source Layout Helpers

extension PackageGenerator {
    /// Compute the SPM target path, explicit sources list, and cSettings from native source metadata.
    /// Returns the existing sourcePath unchanged when no native sources are declared.
    static func computeNativeSourceLayout(
        from metadata: PluginMetadata,
        defaultSourcePath: String
    )
        -> NativeSourceLayout {
        guard !metadata.nativeSources.isEmpty else {
            return NativeSourceLayout(path: defaultSourcePath, sources: [], cSettings: [])
        }

        // Unique source directories, preserving declaration order
        var seenDirs = Set<String>()
        let sourceDirs = metadata.nativeSources
            .map(\.directory)
            .filter { seenDirs.insert($0).inserted }

        let targetPath: String
        let explicitSources: [String]

        if sourceDirs.count == 1 {
            targetPath = sourceDirs[0]
            explicitSources = []
        } else {
            targetPath = commonAncestorPath(of: sourceDirs)
            explicitSources = metadata.nativeSources.map { relativePath($0.path, to: targetPath) }
        }

        // Merge all compiler-flag defines from all source files (deduplicated)
        let allDefines = CompilerFlagsParser.merge(
            metadata.nativeSources.map { CompilerFlagsParser.parse($0.rawCompilerFlags) }
        )

        // Additional header search paths (directories that have headers but are not
        // the publicHeadersPath so SPM doesn't add them automatically)
        let publicHeadersDir = computePublicHeadersPath(
            from: metadata.headerPaths,
            targetPath: targetPath
        )
        let searchPaths = computeHeaderSearchPaths(
            headerPaths: metadata.headerPaths,
            targetPath: targetPath,
            excludingDir: publicHeadersDir
        ).map { CCompilerSetting.headerSearchPath($0) }

        // Header search paths come first so that include resolution is obvious
        return NativeSourceLayout(path: targetPath, sources: explicitSources, cSettings: searchPaths + allDefines)
    }

    /// Return the longest common ancestor directory path for a set of directory paths.
    static func commonAncestorPath(of dirs: [String]) -> String {
        guard dirs.count > 1 else { return dirs.first ?? "." }
        let components = dirs.map { $0.components(separatedBy: "/") }
        let minLen = components.map(\.count).min() ?? 0
        var common: [String] = []
        for index in 0 ..< minLen {
            let component = components[0][index]
            guard components.allSatisfy({ $0[index] == component }) else { break }
            common.append(component)
        }
        return common.isEmpty ? "." : common.joined(separator: "/")
    }

    /// Return `path` relative to `base`, stripping the base prefix and separator.
    static func relativePath(_ path: String, to base: String) -> String {
        let prefix = base + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    /// Derive publicHeadersPath (relative to targetPath) from the first <header-file> declaration.
    static func computePublicHeadersPath(from headerPaths: [String], targetPath: String) -> String {
        guard let first = headerPaths.first else { return "" }
        let dir = (first as NSString).deletingLastPathComponent
        if dir == targetPath { return "." }
        let prefix = targetPath + "/"
        if dir.hasPrefix(prefix) { return String(dir.dropFirst(prefix.count)) }
        return "."
    }

    /// Return header directories (relative to targetPath) that need an explicit
    /// `.headerSearchPath()` cSetting — i.e. all header dirs except the publicHeadersPath.
    static func computeHeaderSearchPaths(
        headerPaths: [String],
        targetPath: String,
        excludingDir publicDir: String
    )
        -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in headerPaths {
            let dir = (path as NSString).deletingLastPathComponent
            let relDir: String
            if dir == targetPath {
                relDir = "."
            } else {
                let prefix = targetPath + "/"
                relDir = dir.hasPrefix(prefix) ? String(dir.dropFirst(prefix.count)) : dir
            }
            guard relDir != publicDir, seen.insert(relDir).inserted else { continue }
            result.append(relDir)
        }
        return result
    }
}
