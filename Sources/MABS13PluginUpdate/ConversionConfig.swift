import Foundation

/// Configuration options for the conversion process
public struct ConversionOptions {
    public let force: Bool
    public let dryRun: Bool
    public let verbose: Bool
    public let noGitignore: Bool
    public let backup: Bool
    public let autoResolve: Bool
    public let inputPath: String?
    /// Explicit minimum iOS version for the generated manifest. Nil means the tool decides:
    /// the MABS 13 floor, raised when the plugin's own declarations or dependencies demand more.
    public let minimumIOSVersion: IOSPlatformVersion?
    /// Load the generated manifest and build the package for iOS once the conversion is done
    public let verify: Bool

    public init(
        force: Bool = false,
        dryRun: Bool = false,
        verbose: Bool = false,
        noGitignore: Bool = false,
        backup: Bool = false,
        autoResolve: Bool = false,
        inputPath: String? = nil,
        minimumIOSVersion: IOSPlatformVersion? = nil,
        verify: Bool = false
    ) {
        self.force = force
        self.dryRun = dryRun
        self.verbose = verbose
        self.noGitignore = noGitignore
        self.backup = backup
        self.autoResolve = autoResolve
        self.inputPath = inputPath
        self.minimumIOSVersion = minimumIOSVersion
        self.verify = verify
    }
}

/// Result of a conversion operation
public enum ConversionResult {
    case success(String)
    case skipped(String)
    case error(String)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
