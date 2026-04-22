import Foundation

/// Handles generation of Swift Package Manager Package.swift files
public class PackageGenerator {
    /// Generate Package.swift content based on plugin metadata
    /// - Parameters:
    ///   - metadata: Plugin metadata containing dependencies
    ///   - sourcePath: Fallback path when no native sources are declared (defaults to "src/ios")
    ///   - fileManager: FileSystemManager for filesystem-based header detection (fallback)
    ///   - resolvedDependencies: Optional array of resolved dependencies (for auto-resolution)
    /// - Returns: Complete Package.swift content as string
    public static func generatePackageSwift(
        from metadata: PluginMetadata,
        sourcePath: String = "src/ios",
        fileManager: FileSystemManager? = nil,
        resolvedDependencies: [ResolvedDependency]? = nil,
        resolvedPluginDependencies: [ResolvedPluginDependency]? = nil
    ) -> String {
        let packageName = metadata.packageName
        let (packageDepsString, targetDepsString) = buildDependencyStrings(
            from: metadata,
            resolvedDependencies: resolvedDependencies,
            resolvedPluginDependencies: resolvedPluginDependencies
        )

        // Compute source layout from native sources when available
        let layout = computeNativeSourceLayout(from: metadata, defaultSourcePath: sourcePath)

        // Determine publicHeadersPath: prefer metadata-derived value, fallback to filesystem scan
        let metadataHeadersPath = computePublicHeadersPath(
            from: metadata.headerPaths,
            targetPath: layout.path
        )
        let publicHeadersPath = metadataHeadersPath.isEmpty
            ? (fileManager?.findPublicHeadersPath(in: layout.path) ?? "")
            : metadataHeadersPath

        let linkerSettings = metadata.systemFrameworks.map { LinkerSetting.linkedFramework($0.name) }

        let targetsContent = buildTargetsContent(
            targetName: packageName,
            localFrameworks: metadata.localFrameworks,
            targetDependenciesString: targetDepsString,
            sourcePath: layout.path,
            publicHeadersPath: publicHeadersPath,
            explicitSources: layout.sources,
            cSettings: layout.cSettings,
            linkerSettings: linkerSettings
        )
        return """
        // swift-tools-version:5.9
        import PackageDescription

        let package = Package(
            name: "\(packageName)",
            platforms: [.iOS(.v14)],
            products: [
                .library(
                    name: "\(packageName)",
                    targets: ["\(packageName)"])
            ],
            dependencies: [
        \(packageDepsString)
            ],
            targets: [
        \(targetsContent)
            ]
        )
        """
    }

    private static func buildDependencyStrings(
        from metadata: PluginMetadata,
        resolvedDependencies: [ResolvedDependency]?,
        resolvedPluginDependencies: [ResolvedPluginDependency]?
    ) -> (packageDeps: String, targetDeps: String) {
        var packageDependencies = [
            "        .package(url: \"https://github.com/apache/cordova-ios.git\", branch: \"master\")"
        ]
        var targetDependencies = [
            "                .product(name: \"Cordova\", package: \"cordova-ios\")"
        ]
        if let resolvedDeps = resolvedDependencies {
            addResolvedDependencies(
                resolvedDeps: resolvedDeps,
                packageDependencies: &packageDependencies,
                targetDependencies: &targetDependencies
            )
        } else {
            addUnresolvedDependencyComments(
                dependencies: metadata.dependencies,
                packageDependencies: &packageDependencies,
                targetDependencies: &targetDependencies
            )
        }
        if let resolvedPluginDeps = resolvedPluginDependencies {
            addResolvedPluginDependencies(
                resolvedPluginDeps: resolvedPluginDeps,
                packageDependencies: &packageDependencies,
                targetDependencies: &targetDependencies
            )
        } else {
            addUnresolvedPluginDependencyComments(
                dependencies: metadata.pluginDependencies,
                packageDependencies: &packageDependencies,
                targetDependencies: &targetDependencies
            )
        }
        for framework in metadata.localFrameworks {
            targetDependencies.append("                .target(name: \"\(framework.name)\")")
        }
        return (packageDependencies.joined(separator: ",\n"), targetDependencies.joined(separator: ",\n"))
    }

    /// Build the content inside `targets: [...]`, including `.binaryTarget` entries
    /// for local xcframeworks followed by the main source target.
    private static func buildTargetsContent(
        targetName: String,
        localFrameworks: [LocalXCFramework],
        targetDependenciesString: String,
        sourcePath: String,
        publicHeadersPath: String,
        explicitSources: [String] = [],
        cSettings: [CCompilerSetting] = [],
        linkerSettings: [LinkerSetting] = []
    ) -> String {
        var result = ""

        for framework in localFrameworks {
            result += "        .binaryTarget(\n"
            result += "            name: \"\(framework.name)\",\n"
            result += "            path: \"\(framework.path)\"\n"
            result += "        ),\n"
        }

        // When explicit sources are provided (multi-dir case) xcframeworks are not included
        // in explicitSources, so no exclude: block is needed. In the single-dir case use
        // the existing exclude mechanism for xcframeworks nested inside the source path.
        let excludePaths: [String] = explicitSources.isEmpty
            ? localFrameworks.compactMap { fw in
                let prefix = sourcePath + "/"
                guard fw.path.hasPrefix(prefix) else { return nil }
                return String(fw.path.dropFirst(prefix.count))
            }
            : []

        result += "        .target(\n"
        result += "            name: \"\(targetName)\",\n"
        result += "            dependencies: [\n"
        result += targetDependenciesString + "\n"
        result += "            ],\n"
        result += "            path: \"\(sourcePath)\""

        if !explicitSources.isEmpty {
            let sourcesLines = explicitSources
                .map { "                \"\($0)\"" }
                .joined(separator: ",\n")
            result += ",\n            sources: [\n\(sourcesLines)\n            ]"
        }

        if !excludePaths.isEmpty {
            let excludeLines = excludePaths
                .map { "                \"\($0)\"" }
                .joined(separator: ",\n")
            result += ",\n            exclude: [\n\(excludeLines)\n            ]"
        }

        if !publicHeadersPath.isEmpty {
            result += ",\n            publicHeadersPath: \"\(publicHeadersPath)\""
        }

        if !cSettings.isEmpty {
            let settingsLines = cSettings
                .map { "                \($0.spmCode)" }
                .joined(separator: ",\n")
            result += ",\n            cSettings: [\n\(settingsLines)\n            ]"
        }

        if !linkerSettings.isEmpty {
            let linkerLines = linkerSettings
                .map { "                \($0.spmCode)" }
                .joined(separator: ",\n")
            result += ",\n            linkerSettings: [\n\(linkerLines)\n            ]"
        }

        result += ")"

        return result
    }

    /// Extract package name from Git URL for use in target dependencies
    /// - Parameter url: Git repository URL
    /// - Returns: Package name (typically repository name)
    private static func extractPackageName(from url: String) -> String {
        // Extract repository name from URL (handles github.com/owner/repo.git format)
        let components = url.components(separatedBy: "/")
        if let lastComponent = components.last {
            // Remove .git extension if present
            return lastComponent.hasSuffix(".git")
                ? String(lastComponent.dropLast(4))
                : lastComponent
        }
        return "UnknownPackage"
    }

    // MARK: - Native Source Layout Helpers

    /// Check that generated Package.swift contains all required top-level elements.
    /// This is a structural presence check, not a Swift syntax validator.
    /// - Parameter content: Package.swift content to check
    /// - Returns: true if all required elements are present
    public static func hasRequiredPackageElements(_ content: String) -> Bool {
        let requiredElements = [
            "swift-tools-version",
            "import PackageDescription",
            "let package = Package(",
            "name:",
            "targets:"
        ]

        return requiredElements.allSatisfy { content.contains($0) }
    }
}

// MARK: - Dependency Generation Helpers

extension PackageGenerator {
    fileprivate static func addResolvedDependencies(
        resolvedDeps: [ResolvedDependency],
        packageDependencies: inout [String],
        targetDependencies: inout [String]
    ) {
        for resolvedDep in resolvedDeps {
            if let spmDep = resolvedDep.spmDependency {
                let packageEntry = "        .package(url: \"\(spmDep.url)\", \(spmDep.requirement.description))"
                packageDependencies.append(packageEntry)
                let productName = spmDep.productName ?? resolvedDep.originalPod.name
                let pkgName = spmDep.packageName ?? extractPackageName(from: spmDep.url)
                let targetEntry = "                .product(name: \"\(productName)\", package: \"\(pkgName)\")"
                targetDependencies.append(targetEntry)
            } else {
                let todoPackage = "        // TODO: Convert CocoaPods dependency: " +
                    "\(resolvedDep.originalPod.description) (\(resolvedDep.status.description))"
                packageDependencies.append(todoPackage)
                let todoTarget = "                // TODO: Add Swift Package equivalent for: " +
                    "\(resolvedDep.originalPod.description)"
                targetDependencies.append(todoTarget)
            }
        }
    }

    fileprivate static func addUnresolvedDependencyComments(
        dependencies: [PodDependency],
        packageDependencies: inout [String],
        targetDependencies: inout [String]
    ) {
        for dependency in dependencies {
            packageDependencies.append("        // TODO: Convert CocoaPods dependency: \(dependency.description)")
            targetDependencies
                .append("                // TODO: Add Swift Package equivalent for: \(dependency.description)")
        }
    }

    fileprivate static func addResolvedPluginDependencies(
        resolvedPluginDeps: [ResolvedPluginDependency],
        packageDependencies: inout [String],
        targetDependencies: inout [String]
    ) {
        for resolved in resolvedPluginDeps {
            if let spmDep = resolved.spmDependency {
                packageDependencies.append(
                    "        .package(url: \"\(spmDep.url)\", \(spmDep.requirement.description))"
                )
                let productName = spmDep.productName ?? resolved.original.id
                let pkgName = spmDep.packageName ?? extractPackageName(from: spmDep.url)
                targetDependencies.append(
                    "                .product(name: \"\(productName)\", package: \"\(pkgName)\")"
                )
            } else {
                let reason = resolved.status.description
                packageDependencies.append(
                    "        // TODO: Cordova plugin dependency (\(reason)): \(resolved.original.description)"
                )
                targetDependencies.append(
                    "                // TODO: Add SPM equivalent for Cordova plugin: \(resolved.original.id)"
                )
            }
        }
    }

    fileprivate static func addUnresolvedPluginDependencyComments(
        dependencies: [CordovaPluginDependency],
        packageDependencies: inout [String],
        targetDependencies: inout [String]
    ) {
        for dep in dependencies {
            packageDependencies.append(
                "        // TODO: Cordova plugin dependency (run --auto-resolve to check): \(dep.description)"
            )
            targetDependencies.append(
                "                // TODO: Add SPM equivalent for Cordova plugin: \(dep.id)"
            )
        }
    }
}
