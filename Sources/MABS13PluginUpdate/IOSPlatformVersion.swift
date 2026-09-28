import Foundation

/// A minimum iOS deployment version for the `platforms:` block of a generated Package.swift.
public struct IOSPlatformVersion: Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int

    /// The lowest deployment target a generated package can declare. Xcode 27, the toolchain
    /// MABS 13 builds with, rejects a Swift package below iOS 15 during validation, before any
    /// source file is compiled. Xcode 26 applies the same rule to applications but not to
    /// packages, which is why MABS 12 never hit this.
    ///
    /// This is deliberately the toolchain floor and not ``mabs13AppDeploymentTarget``: iOS 15
    /// still resolves under MABS 12.1 ODC, where a Cordova build can be asked for a Swift package
    /// with `spmPreview: true`.
    public static let toolchainMinimum = IOSPlatformVersion(major: 15, minor: 0)

    /// The deployment target MABS 13 applications are built with. A package that demands more
    /// than this will not compile into an unmodified MABS 13 app, so the generator warns when the
    /// resolved floor goes above it. It does not cap: the demand comes from a real dependency, and
    /// capping would only produce a manifest that cannot resolve. A plugin can also raise the
    /// application's own target through a Cordova hook, in which case the warning is noise.
    public static let mabs13AppDeploymentTarget = IOSPlatformVersion(major: 16, minor: 0)

    public init(major: Int, minor: Int = 0) {
        self.major = major
        self.minor = minor
    }

    /// Parse a deployment target written as a podspec/plugin.xml value (`"15"`, `"15.0"`, `"16.4"`)
    /// or as an SPM literal (`".v15"`, `"\"16.4\""`). Returns nil when the value is not a version.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if text.hasPrefix(".v") {
            text = String(text.dropFirst(2))
        } else if text.hasPrefix("v") {
            text = String(text.dropFirst())
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1 ... 2).contains(parts.count),
              let major = Int(parts[0]), major > 0 else { return nil }

        if parts.count == 2 {
            guard let minor = Int(parts[1]), minor >= 0 else { return nil }
            self.init(major: major, minor: minor)
        } else {
            self.init(major: major, minor: 0)
        }
    }

    /// The `platforms:` entry for this version. Whole versions use the `.vNN` enum case where
    /// PackageDescription defines one; everything else uses the string form, which accepts any
    /// version but must always carry a minor component.
    public var spmCode: String {
        minor == 0 && (8 ... 17).contains(major)
            ? ".iOS(.v\(major))"
            : ".iOS(\"\(major).\(minor)\")"
    }

    public var description: String {
        "\(major).\(minor)"
    }

    public static func < (lhs: IOSPlatformVersion, rhs: IOSPlatformVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}
