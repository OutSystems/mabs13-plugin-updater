import Foundation

// MARK: - Platform Floor

extension CordovaToSPMConverter {
    /// Resolve the manifest's iOS floor and log how it was reached.
    func decideMinimumIOSVersion(
        metadata: PluginMetadata,
        resolvedDependencies: [ResolvedDependency]?,
        resolvedPluginDependencies: [ResolvedPluginDependency]?
    )
        -> IOSPlatformVersion {
        let platform = IOSPlatformResolver.resolve(
            metadata: metadata,
            resolvedDependencies: resolvedDependencies,
            resolvedPluginDependencies: resolvedPluginDependencies,
            requested: options.minimumIOSVersion
        )

        logger.info("Minimum iOS version for the generated manifest: \(platform.version)")
        for reason in platform.reasons {
            logger.debug("  \(reason)")
        }

        if let requested = platform.overriddenRequest {
            logger.warn(
                "--min-ios asked for iOS \(requested), but iOS \(platform.version) is required: " +
                    platform.reasons.joined(separator: "; ")
            )
        }

        if platform.exceedsMABS13AppDeploymentTarget {
            logger.warn(
                "iOS \(platform.version) is above the iOS \(IOSPlatformVersion.mabs13AppDeploymentTarget) " +
                    "deployment target of a MABS 13 application, which will not build against this " +
                    "package unless something raises its own target: " +
                    platform.reasons.joined(separator: "; ")
            )
        }

        return platform.version
    }
}
