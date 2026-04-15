import Foundation

/// Handles automatic resolution of CocoaPods dependencies to Swift Package Manager equivalents
public class DependencyResolver {
    private let podSpecResolver: PodSpecResolver
    private let gitChecker: GitRepositoryChecker
    private let spmParser: SPMPackageParser
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
        self.podSpecResolver = PodSpecResolver(logger: logger)
        self.gitChecker = GitRepositoryChecker(logger: logger)
        self.spmParser = SPMPackageParser(logger: logger)
    }
    
    /// Attempt to automatically resolve CocoaPods dependencies to SPM equivalents
    /// - Parameters:
    ///   - dependencies: Array of CocoaPods dependencies to resolve
    ///   - timeout: Maximum time to spend on resolution (default: 30 seconds)
    /// - Returns: Array of resolved SPM dependencies
    public func resolveCocoaPodDependencies(
        _ dependencies: [PodDependency],
        timeout: TimeInterval = 30.0
    ) async
        -> [ResolvedDependency] {
        logger.info("Attempting to automatically resolve \(dependencies.count) CocoaPods dependencies...")
        
        var resolvedDependencies: [ResolvedDependency] = []
        
        // Process dependencies concurrently with timeout
        await withTaskGroup(of: ResolvedDependency?.self) { group in
            for dependency in dependencies {
                group.addTask {
                    await self.resolveSingleDependency(dependency, timeout: timeout)
                }
            }
            
            for await result in group {
                if let resolved = result {
                    resolvedDependencies.append(resolved)
                }
            }
        }
        
        let successCount = resolvedDependencies.filter { $0.spmDependency != nil }.count
        logger.info("Successfully resolved \(successCount) out of \(dependencies.count) dependencies")
        
        return resolvedDependencies
    }
    
    /// Resolve a single CocoaPods dependency
    /// - Parameters:
    ///   - dependency: The CocoaPods dependency to resolve
    ///   - timeout: Maximum time to spend on this dependency
    /// - Returns: ResolvedDependency with SPM equivalent if found
    private func resolveSingleDependency(
        _ dependency: PodDependency,
        timeout: TimeInterval
    ) async
        -> ResolvedDependency? {
        await withTaskGroup(of: ResolvedDependency?.self) { group in
            group.addTask {
                await self.performResolution(for: dependency)
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1000000000))
                return ResolvedDependency(
                    originalPod: dependency,
                    spmDependency: nil,
                    status: .timeout
                )
            }
            
            // Return the first result (either success or timeout)
            for await result in group {
                if let resolved = result {
                    group.cancelAll()
                    return resolved
                }
            }
            
            return nil
        }
    }
    
    /// Perform the actual resolution process for a dependency
    /// - Parameter dependency: The CocoaPods dependency to resolve
    /// - Returns: ResolvedDependency with results
    private func performResolution(for dependency: PodDependency) async -> ResolvedDependency {
        logger.debug("Starting resolution for dependency: \(dependency.name)")

        // If the pod element already carries a git URL (from plugin.xml attributes),
        // skip the CocoaPods registry lookup and resolve directly.
        if let gitUrl = dependency.git {
            logger.debug("Pod \(dependency.name) has direct git URL, bypassing CocoaPods lookup")
            let podSpecInfo = PodSpecInfo(
                name: dependency.name,
                version: dependency.tag ?? dependency.spec ?? "",
                sourceType: .git(url: gitUrl, tag: dependency.tag, branch: dependency.branch)
            )
            return await handleSourceType(podSpecInfo: podSpecInfo, dependency: dependency)
        }

        // Step 1: Get pod specification from CocoaPods registry
        guard let podSpecInfo = await podSpecResolver.resolvePodSpec(for: dependency) else {
            logger.debug("Pod spec not found for: \(dependency.name)")
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .podSpecNotFound
            )
        }

        // Step 2: Handle different source types
        return await handleSourceType(podSpecInfo: podSpecInfo, dependency: dependency)
    }
    
    private func handleSourceType(podSpecInfo: PodSpecInfo, dependency: PodDependency) async -> ResolvedDependency {
        switch podSpecInfo.sourceType {
        case let .git(url, tag, branch):
            return await handleGitSource(
                url: url,
                tag: tag,
                branch: branch,
                podSpecInfo: podSpecInfo,
                dependency: dependency
            )
            
        case let .http(url):
            return await handleHttpSource(
                url: url,
                podSpecInfo: podSpecInfo,
                dependency: dependency
            )
            
        case let .local(path):
            logger.debug("Local source not supported for SPM conversion: \(dependency.name) at \(path)")
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .requiresManualIntegration(reason: "Local source path: \(path)")
            )
            
        case .unknown:
            logger.debug("Unknown source type for: \(dependency.name)")
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .noGitSource
            )
        }
    }
    
    private func handleGitSource(
        url: String,
        tag: String?,
        branch: String?,
        podSpecInfo: PodSpecInfo,
        dependency: PodDependency
    ) async -> ResolvedDependency {
        let reference = tag ?? branch ?? "main"
        
        // Step 4: Check if Package.swift exists in the repository
        let hasPackageSwift = await gitChecker.hasPackageSwift(in: url, at: reference)
        
        if !hasPackageSwift {
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .noPackageSwift
            )
        }
        
        // Step 5: Fetch and parse Package.swift content
        guard let packageContent = await gitChecker.fetchPackageSwiftContent(from: url, at: reference) else {
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .packageSwiftNotAccessible
            )
        }
        
        // Step 6: Parse Package.swift to extract library information
        guard let packageInfo = spmParser.parsePackageSwift(packageContent),
              spmParser.isLibraryPackage(packageContent) else {
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .notALibrary
            )
        }
        
        // Step 7: Create SPM dependency
        let requirement = PodSpecResolver.convertSpecToSPMRequirement(
            dependency.spec,
            sourceTag: tag
        )
        
        // Use the parsed package info to get the main library name and the declared package name
        let productName = packageInfo.products.first(where: { $0.type == .library })?.name ?? packageInfo.name

        let spmDependency = SPMDependency(
            url: url,
            requirement: requirement,
            productName: productName,
            packageName: packageInfo.name
        )
        
        return ResolvedDependency(
            originalPod: dependency,
            spmDependency: spmDependency,
            status: .resolved
        )
    }
    
    private func handleHttpSource(
        url: String,
        podSpecInfo: PodSpecInfo,
        dependency: PodDependency
    ) async -> ResolvedDependency {
        logger.debug("Handling HTTP source for \(dependency.name): \(url)")
        
        // Try to infer Git repository from HTTP URL
        let inferredGitUrl = await inferGitUrlFromHttpSource(url, podSpecInfo: podSpecInfo)
        
        // If we inferred a Git URL, try to resolve it as a Git source first
        if let gitUrl = inferredGitUrl {
            logger.debug("Attempting Git resolution for \(dependency.name) using inferred URL")
            
            // Try to use the pod version as a tag first
            let versionTag = extractVersionTag(from: dependency.spec)
            let gitResult = await handleGitSource(
                url: gitUrl,
                tag: versionTag,
                branch: nil,
                podSpecInfo: podSpecInfo,
                dependency: dependency
            )
            
            // If Git resolution succeeded, return it
            if gitResult.status == ResolutionStatus.resolved {
                logger.debug("Successfully resolved \(dependency.name) using inferred Git URL")
                return gitResult
            }
            
            // If Git resolution failed but we have an XCFramework, provide that info
            if let vendoredFrameworks = podSpecInfo.vendoredFrameworks,
               vendoredFrameworks.hasSuffix(".xcframework") {
                logger.debug("Git resolution failed but found XCFramework for \(dependency.name): \(vendoredFrameworks)")
                return ResolvedDependency(
                    originalPod: dependency,
                    spmDependency: nil,
                    status: .xcframeworkFound(gitUrl: gitUrl, downloadUrl: url)
                )
            }
            
            // Git resolution failed and no XCFramework fallback
            return gitResult
        }
        
        // No Git URL could be inferred
        // Check if this is an XCFramework without Git repository
        if let vendoredFrameworks = podSpecInfo.vendoredFrameworks,
           vendoredFrameworks.hasSuffix(".xcframework") {
            logger.debug("Found XCFramework without Git repository for \(dependency.name): \(vendoredFrameworks)")
            return ResolvedDependency(
                originalPod: dependency,
                spmDependency: nil,
                status: .xcframeworkFound(gitUrl: nil, downloadUrl: url)
            )
        }
        
        // Otherwise, return HTTP source found status
        return ResolvedDependency(
            originalPod: dependency,
            spmDependency: nil,
            status: .httpSourceFound(gitUrl: inferredGitUrl)
        )
    }
    
    private func inferGitUrlFromHttpSource(_ httpUrl: String, podSpecInfo: PodSpecInfo) async -> String? {
        // Strategy 1: Extract from GitHub releases URL
        if httpUrl.contains("github.com") {
            let pattern = #"https://github\.com/([^/]+/[^/]+)/releases/download/.*"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: httpUrl, range: NSRange(httpUrl.startIndex..., in: httpUrl)),
               let range = Range(match.range(at: 1), in: httpUrl) {
                let repoPath = String(httpUrl[range])
                let gitUrl = "https://github.com/\(repoPath).git"
                logger.debug("Inferred Git URL from GitHub releases: \(gitUrl)")
                return gitUrl
            }
        }
        
        // Strategy 2: Use homepage if it's a GitHub URL
        if let homepage = podSpecInfo.homepage, homepage.contains("github.com") {
            let gitUrl = homepage.hasSuffix(".git") ? homepage : "\(homepage).git"
            logger.debug("Using homepage as Git URL: \(gitUrl)")
            return gitUrl
        }
        
        logger.debug("Could not infer Git URL from HTTP source: \(httpUrl)")
        return nil
    }
    
    private func extractVersionTag(from spec: String?) -> String? {
        guard let spec else { return nil }
        // Extract version from CocoaPods spec patterns
        // Examples: "2.2.1", "~> 4.0", ">= 1.0", "1.0.0"

        // Remove common CocoaPods operators
        let cleanSpec = spec
            .replacingOccurrences(of: "~>", with: "")
            .replacingOccurrences(of: ">=", with: "")
            .replacingOccurrences(of: "<=", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "<", with: "")
            .trimmingCharacters(in: .whitespaces)

        // If it looks like a version number, return it
        if cleanSpec.range(of: #"^\d+(\.\d+)*"#, options: .regularExpression) != nil {
            return cleanSpec
        }

        return nil
    }
}
