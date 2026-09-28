import Foundation

/// The platform floor chosen for a generated manifest, with the reasons that produced it.
public struct IOSPlatformDecision: Equatable {
    public let version: IOSPlatformVersion
    /// One line per input that contributed, in the order they were considered. Meant for logging,
    /// so the operator can see why the manifest asks for the version it asks for.
    public let reasons: [String]
    /// Set when an explicit `--min-ios` was raised because something demanded more
    public let overriddenRequest: IOSPlatformVersion?

    public init(version: IOSPlatformVersion, reasons: [String], overriddenRequest: IOSPlatformVersion? = nil) {
        self.version = version
        self.reasons = reasons
        self.overriddenRequest = overriddenRequest
    }

    /// True when the chosen version is above the deployment target MABS 13 applications are built
    /// with, so an unmodified MABS 13 app will refuse to compile against the generated package.
    /// Worth a warning rather than an error: the version was demanded by something real, and a
    /// Cordova hook can raise the application's target.
    public var exceedsMABS13AppDeploymentTarget: Bool {
        version > .mabs13AppDeploymentTarget
    }
}

/// Decides the `platforms: [.iOS(...)]` entry of a generated manifest.
///
/// A plugin cannot build with a deployment target lower than any of its dependencies', and the
/// toolchain itself has a floor, so the answer is the highest of everything known: the toolchain
/// minimum, what the plugin declares in plugin.xml, what each resolved dependency declares, and an
/// explicit request from `--min-ios`. Nothing lowers the result, including `--min-ios`.
public enum IOSPlatformResolver {
    public static func resolve(
        metadata: PluginMetadata,
        resolvedDependencies: [ResolvedDependency]? = nil,
        resolvedPluginDependencies: [ResolvedPluginDependency]? = nil,
        requested: IOSPlatformVersion? = nil
    )
        -> IOSPlatformDecision {
        var candidates: [(version: IOSPlatformVersion, reason: String)] = [
            (
                .toolchainMinimum,
                "MABS 13 builds with Xcode 27, which rejects a package below " +
                    "iOS \(IOSPlatformVersion.toolchainMinimum)"
            )
        ]

        if let requested {
            candidates.append((requested, "--min-ios requested iOS \(requested)"))
        }

        if let declared = metadata.deploymentTarget {
            candidates.append((declared, "plugin.xml declares a deployment target of iOS \(declared)"))
        }

        for dependency in resolvedDependencies ?? [] {
            guard let floor = dependency.spmDependency?.minimumIOSVersion else { continue }
            candidates.append((floor, "\(dependency.originalPod.name) requires iOS \(floor) or later"))
        }

        for dependency in resolvedPluginDependencies ?? [] {
            guard let floor = dependency.spmDependency?.minimumIOSVersion else { continue }
            candidates.append((floor, "\(dependency.original.id) requires iOS \(floor) or later"))
        }

        let version = candidates.map(\.version).max() ?? .toolchainMinimum
        let reasons = candidates.filter { $0.version == version }.map(\.reason)
        let overriddenRequest = requested.flatMap { $0 < version ? $0 : nil }

        return IOSPlatformDecision(version: version, reasons: reasons, overriddenRequest: overriddenRequest)
    }
}
