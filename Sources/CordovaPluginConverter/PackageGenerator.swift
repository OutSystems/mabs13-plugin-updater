import Foundation

/// Handles generation of Swift Package Manager Package.swift files
public class PackageGenerator {
    /// Generate Package.swift content based on plugin metadata
    /// - Parameters:
    ///   - metadata: Plugin metadata containing dependencies
    ///   - sourcePath: Path to check for header files (defaults to "src/ios")
    ///   - fileManager: FileSystemManager for header detection (optional)
    ///   - resolvedDependencies: Optional array of resolved dependencies (for auto-resolution)
    /// - Returns: Complete Package.swift content as string
    public static func generatePackageSwift(
        from metadata: PluginMetadata,
        sourcePath: String = "src/ios",
        fileManager: FileSystemManager? = nil,
        resolvedDependencies: [ResolvedDependency]? = nil
    ) -> String {
        let packageName = metadata.packageName
        let (packageDepsString, targetDepsString) = buildDependencyStrings(
            from: metadata,
            resolvedDependencies: resolvedDependencies
        )
        let publicHeadersPath = fileManager?.findPublicHeadersPath(in: sourcePath) ?? ""
        let targetsContent = buildTargetsContent(
            targetName: packageName,
            localFrameworks: metadata.localFrameworks,
            targetDependenciesString: targetDepsString,
            sourcePath: sourcePath,
            publicHeadersPath: publicHeadersPath
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
        resolvedDependencies: [ResolvedDependency]?
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
        publicHeadersPath: String
    ) -> String {
        var result = ""

        for framework in localFrameworks {
            result += "        .binaryTarget(\n"
            result += "            name: \"\(framework.name)\",\n"
            result += "            path: \"\(framework.path)\"\n"
            result += "        ),\n"
        }

        // Xcframeworks nested inside the source path must be excluded from source
        // scanning — otherwise SPM warns about "unhandled files" and Xcode can fail
        // to resolve the module. Paths are relative to the target's own path.
        let excludePaths: [String] = localFrameworks.compactMap { fw in
            let prefix = sourcePath + "/"
            guard fw.path.hasPrefix(prefix) else { return nil }
            return String(fw.path.dropFirst(prefix.count))
        }

        result += "        .target(\n"
        result += "            name: \"\(targetName)\",\n"
        result += "            dependencies: [\n"
        result += targetDependenciesString + "\n"
        result += "            ],\n"
        result += "            path: \"\(sourcePath)\""

        if !excludePaths.isEmpty {
            let excludeLines = excludePaths
                .map { "                \"\($0)\"" }
                .joined(separator: ",\n")
            result += ",\n            exclude: [\n\(excludeLines)\n            ]"
        }

        if !publicHeadersPath.isEmpty {
            result += ",\n            publicHeadersPath: \"\(publicHeadersPath)\""
        }

        result += ")"

        return result
    }

    /// Add resolved SPM dependencies to package and target dependencies
    /// - Parameters:
    ///   - resolvedDeps: Array of resolved dependencies
    ///   - packageDependencies: Package-level dependencies array (modified in place)
    ///   - targetDependencies: Target-level dependencies array (modified in place)
    private static func addResolvedDependencies(
        resolvedDeps: [ResolvedDependency],
        packageDependencies: inout [String],
        targetDependencies: inout [String]
    ) {
        for resolvedDep in resolvedDeps {
            if let spmDep = resolvedDep.spmDependency {
                // Add resolved SPM dependency
                let packageEntry = "        .package(url: \"\(spmDep.url)\", \(spmDep.requirement.description))"
                packageDependencies.append(packageEntry)

                // Add target dependency
                let productName = spmDep.productName ?? resolvedDep.originalPod.name
                let pkgName = spmDep.packageName ?? extractPackageName(from: spmDep.url)
                let targetEntry = "                .product(name: \"\(productName)\", " +
                    "package: \"\(pkgName)\")"
                targetDependencies.append(targetEntry)
            } else {
                // Add comment for unresolved dependency
                let todoPackage = "        // TODO: Convert CocoaPods dependency: " +
                    "\(resolvedDep.originalPod.description) (\(resolvedDep.status.description))"
                packageDependencies.append(todoPackage)

                let todoTarget = "                // TODO: Add Swift Package equivalent for: " +
                    "\(resolvedDep.originalPod.description)"
                targetDependencies.append(todoTarget)
            }
        }
    }

    /// Add traditional comments for unresolved dependencies
    /// - Parameters:
    ///   - dependencies: Array of CocoaPods dependencies
    ///   - packageDependencies: Package-level dependencies array (modified in place)
    ///   - targetDependencies: Target-level dependencies array (modified in place)
    private static func addUnresolvedDependencyComments(
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
