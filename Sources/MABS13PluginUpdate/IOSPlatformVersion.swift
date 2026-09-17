import Foundation

/// A minimum iOS deployment version for the `platforms:` block of a generated Package.swift.
public struct IOSPlatformVersion: Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int

    /// The lowest deployment target MABS 13 accepts. Xcode 26 and later reject anything below
    /// iOS 15 during project validation, before any source file is compiled, so a generated
    /// manifest must never declare less than this.
    public static let mabs13Minimum = IOSPlatformVersion(major: 15, minor: 0)

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
