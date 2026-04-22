import Foundation

// MARK: - CocoaPods Models

/// Represents a CocoaPods dependency from plugin.xml
public struct PodDependency: Equatable, Codable {
    public let name: String
    /// CocoaPods version spec (e.g. "~> 4.0"). Nil when the pod is defined with git/tag attributes.
    public let spec: String?
    /// Direct git URL (from `git` attribute on the `<pod>` element)
    public let git: String?
    /// Git tag (from `tag` attribute on the `<pod>` element)
    public let tag: String?
    /// Git branch (from `branch` attribute on the `<pod>` element)
    public let branch: String?

    public init(name: String, spec: String? = nil, git: String? = nil, tag: String? = nil, branch: String? = nil) {
        self.name = name
        self.spec = spec
        self.git = git
        self.tag = tag
        self.branch = branch
    }

    /// Human-readable description
    public var description: String {
        if let git {
            return "\(name) (git: \(git)\(tag.map { ", tag: \($0)" } ?? ""))"
        }
        return "\(name) (\(spec ?? ""))"
    }
}

/// Types of CocoaPods source configurations
public enum PodSourceType: Equatable {
    case git(url: String, tag: String?, branch: String?)
    case http(url: String)
    case local(path: String)
    case unknown
    
    public var description: String {
        switch self {
        case let .git(url, tag, branch):
            var desc = "Git: \(url)"
            if let tag { desc += " (tag: \(tag))" }
            if let branch { desc += " (branch: \(branch))" }
            return desc
        case let .http(url):
            return "HTTP: \(url)"
        case let .local(path):
            return "Local: \(path)"
        case .unknown:
            return "Unknown source type"
        }
    }
}

/// Represents information extracted from a CocoaPods specification
public struct PodSpecInfo: Equatable {
    public let name: String
    public let version: String
    public let sourceType: PodSourceType
    public let homepage: String?
    public let vendoredFrameworks: String?

    public init(
        name: String,
        version: String,
        sourceType: PodSourceType,
        homepage: String? = nil,
        vendoredFrameworks: String? = nil
    ) {
        self.name = name
        self.version = version
        self.sourceType = sourceType
        self.homepage = homepage
        self.vendoredFrameworks = vendoredFrameworks
    }
}

// MARK: - Native Source Models

/// A C compiler setting for an SPM target's cSettings block
public enum CCompilerSetting: Equatable, Hashable {
    case define(String)
    case defineWithValue(String, String)
    case headerSearchPath(String)

    public var spmCode: String {
        switch self {
        case let .define(key):
            return ".define(\"\(key)\")"
        case let .defineWithValue(key, value):
            return ".define(\"\(key)\", to: \"\(value)\")"
        case let .headerSearchPath(path):
            return ".headerSearchPath(\"\(path)\")"
        }
    }
}

/// A linker setting for an SPM target's linkerSettings block
public enum LinkerSetting: Equatable {
    case linkedFramework(String)
    case linkedLibrary(String)

    public var spmCode: String {
        switch self {
        case let .linkedFramework(name):
            return ".linkedFramework(\"\(name)\")"
        case let .linkedLibrary(name):
            return ".linkedLibrary(\"\(name)\")"
        }
    }
}

/// A native source file declared via <source-file> in the iOS platform block
public struct NativeSourceFile: Equatable {
    /// Path relative to plugin root, e.g. "src/ios/SQLitePlugin.m"
    public let path: String
    /// Raw compiler-flags attribute value, e.g. "-DSQLITE_HAS_CODEC -DHAVE_USLEEP=1"
    public let rawCompilerFlags: String

    public init(path: String, rawCompilerFlags: String = "") {
        self.path = path
        self.rawCompilerFlags = rawCompilerFlags.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The directory containing this source file, e.g. "src/ios"
    public var directory: String {
        (path as NSString).deletingLastPathComponent
    }
}

/// A system framework declared via <framework src="X.framework"/> in the iOS platform block
public struct SystemFramework: Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

// MARK: - Local XCFramework Models

/// Represents a local .xcframework bundle referenced in plugin.xml via <framework custom="true">
public struct LocalXCFramework: Equatable, Codable {
    /// Framework module name, e.g. "OSKeyStoreLib"
    public let name: String
    /// Path relative to plugin root, e.g. "src/ios/frameworks/OSKeyStoreLib.xcframework"
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

// MARK: - Swift Package Manager Models

/// Represents different types of SPM dependency requirements
public enum SPMRequirement: Equatable {
    case exact(String)
    case from(String)
    case upToNextMajor(String)
    case upToNextMinor(String)
    case branch(String)
    case tag(String)
    
    public var description: String {
        switch self {
        case let .exact(version):
            "exact: \"\(version)\""
        case let .from(version):
            "from: \"\(version)\""
        case let .upToNextMajor(version):
            ".upToNextMajor(from: \"\(version)\")"
        case let .upToNextMinor(version):
            ".upToNextMinor(from: \"\(version)\")"
        case let .branch(branch):
            "branch: \"\(branch)\""
        case let .tag(tag):
            "exact: \"\(tag)\""
        }
    }
}

/// Represents a resolved Swift Package Manager dependency
public struct SPMDependency: Equatable {
    public let url: String
    public let requirement: SPMRequirement
    /// Product name to use in target dependencies (e.g. "Alamofire")
    public let productName: String?
    /// Package name as declared in the dependency's Package.swift `name:` field.
    /// Used for the `package:` label in `.product(name:package:)`.
    /// Falls back to the repository name extracted from the URL when nil.
    public let packageName: String?

    public init(url: String, requirement: SPMRequirement, productName: String? = nil, packageName: String? = nil) {
        self.url = url
        self.requirement = requirement
        self.productName = productName
        self.packageName = packageName
    }
}

/// Represents package information extracted from a Package.swift file
public struct SPMPackageInfo: Equatable {
    public let name: String
    public let dependencies: [SPMDependency]
    public let products: [SPMProduct]
    public let targets: [SPMTarget]
    
    public init(
        name: String,
        dependencies: [SPMDependency] = [],
        products: [SPMProduct] = [],
        targets: [SPMTarget] = []
    ) {
        self.name = name
        self.dependencies = dependencies
        self.products = products
        self.targets = targets
    }
}

/// Types of SPM products
public enum SPMProductType: Equatable {
    case library
    case executable
    
    public var description: String {
        switch self {
        case .library: "library"
        case .executable: "executable"
        }
    }
}

/// Represents a Swift Package Manager product
public struct SPMProduct: Equatable {
    public let name: String
    public let type: SPMProductType
    public let targets: [String]
    
    public init(name: String, type: SPMProductType, targets: [String]) {
        self.name = name
        self.type = type
        self.targets = targets
    }
}

/// Represents a Swift Package Manager target
public struct SPMTarget: Equatable {
    public let name: String
    public let dependencies: [String]

    public init(name: String, dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }
}

// MARK: - Cordova Plugin Dependency Models

/// Represents a top-level Cordova plugin dependency declared with <dependency> in plugin.xml
public struct CordovaPluginDependency: Equatable {
    public let id: String
    public let gitUrl: String
    public let branch: String?
    public let tag: String?

    public init(id: String, gitUrl: String, branch: String? = nil, tag: String? = nil) {
        self.id = id
        self.gitUrl = gitUrl
        self.branch = branch
        self.tag = tag
    }

    public var reference: String { tag ?? branch ?? "main" }

    public var description: String {
        var desc = "\(id) (\(gitUrl)"
        if let tag { desc += "#\(tag)" } else if let branch { desc += "#\(branch)" }
        return desc + ")"
    }
}

/// Result of resolving a Cordova plugin dependency to an SPM package
public struct ResolvedPluginDependency: Equatable {
    public let original: CordovaPluginDependency
    public let spmDependency: SPMDependency?
    public let status: ResolutionStatus

    public init(original: CordovaPluginDependency, spmDependency: SPMDependency?, status: ResolutionStatus) {
        self.original = original
        self.spmDependency = spmDependency
        self.status = status
    }

    public var isResolved: Bool { status == .resolved && spmDependency != nil }
}

// MARK: - Dependency Resolution Models

/// Status of dependency resolution attempt
public enum ResolutionStatus: Equatable {
    case resolved
    case podSpecNotFound
    case noGitSource
    case noPackageSwift
    case packageSwiftNotAccessible
    case notALibrary
    case timeout
    case error(String)
    case httpSourceFound(gitUrl: String?) // HTTP source found, optionally with inferred Git URL
    case xcframeworkFound(gitUrl: String?, downloadUrl: String) // XCFramework found
    case requiresManualIntegration(reason: String) // Cannot be automatically converted
    
    public var description: String {
        switch self {
        case .resolved:
            return "Successfully resolved"
        case .podSpecNotFound:
            return "Pod spec not found"
        case .noGitSource:
            return "No Git source URL"
        case .noPackageSwift:
            return "No Package.swift found"
        case .packageSwiftNotAccessible:
            return "Package.swift not accessible"
        case .notALibrary:
            return "Not a library package"
        case .timeout:
            return "Resolution timed out"
        case let .error(message):
            return "Error: \(message)"
        case let .httpSourceFound(gitUrl):
            if let url = gitUrl {
                return "HTTP source found, Git repository inferred: \(url)"
            } else {
                return "HTTP source found, no Git repository could be inferred"
            }
        case let .xcframeworkFound(gitUrl, downloadUrl):
            var desc = "XCFramework found at: \(downloadUrl)"
            if let url = gitUrl {
                desc += ", Git repository: \(url)"
            }
            return desc
        case let .requiresManualIntegration(reason):
            return "Requires manual integration: \(reason)"
        }
    }
    
    /// Whether this status indicates a successful resolution
    public var isSuccess: Bool {
        self == .resolved
    }
}

/// Result of resolving a single CocoaPods dependency to SPM
public struct ResolvedDependency: Equatable {
    public let originalPod: PodDependency
    public let spmDependency: SPMDependency?
    public let status: ResolutionStatus
    
    public init(
        originalPod: PodDependency,
        spmDependency: SPMDependency?,
        status: ResolutionStatus
    ) {
        self.originalPod = originalPod
        self.spmDependency = spmDependency
        self.status = status
    }
    
    /// Whether this dependency was successfully resolved
    public var isResolved: Bool {
        status == .resolved && spmDependency != nil
    }
}

/// Represents the complete metadata extracted from plugin.xml
public struct PluginMetadata: Equatable {
    public let pluginId: String
    public let dependencies: [PodDependency]
    public let hasPodspec: Bool
    public let originalXmlContent: String
    /// Local .xcframework bundles declared with <framework custom="true"> in the iOS platform
    public let localFrameworks: [LocalXCFramework]
    /// Native source files declared via <source-file> in the iOS platform
    public let nativeSources: [NativeSourceFile]
    /// System frameworks declared via <framework src="X.framework"/> in the iOS platform
    public let systemFrameworks: [SystemFramework]
    /// Header file paths declared via <header-file> in the iOS platform
    public let headerPaths: [String]
    /// Top-level Cordova plugin dependencies declared with <dependency> in plugin.xml
    public let pluginDependencies: [CordovaPluginDependency]

    public init(
        pluginId: String,
        dependencies: [PodDependency],
        hasPodspec: Bool,
        originalXmlContent: String,
        localFrameworks: [LocalXCFramework] = [],
        nativeSources: [NativeSourceFile] = [],
        systemFrameworks: [SystemFramework] = [],
        headerPaths: [String] = [],
        pluginDependencies: [CordovaPluginDependency] = []
    ) {
        self.pluginId = pluginId
        self.dependencies = dependencies
        self.hasPodspec = hasPodspec
        self.originalXmlContent = originalXmlContent
        self.localFrameworks = localFrameworks
        self.nativeSources = nativeSources
        self.systemFrameworks = systemFrameworks
        self.headerPaths = headerPaths
        self.pluginDependencies = pluginDependencies
    }

    /// Package name derived from plugin ID
    public var packageName: String {
        pluginId.isEmpty ? "UnknownPlugin" : pluginId
    }

    /// Whether this plugin has any CocoaPods dependencies
    public var hasDependencies: Bool {
        !dependencies.isEmpty
    }

    /// Whether this plugin has any top-level Cordova plugin dependencies
    public var hasPluginDependencies: Bool {
        !pluginDependencies.isEmpty
    }

    /// Whether this plugin has native source files (Obj-C/C) but no CocoaPods
    public var isNativeOnly: Bool {
        !hasDependencies && !nativeSources.isEmpty
    }

    /// Whether this plugin has any native source files declared
    public var hasNativeSources: Bool {
        !nativeSources.isEmpty
    }

    /// Dependency descriptions for logging
    public var dependencyDescriptions: [String] {
        dependencies.map(\.description)
    }
}

/// Configuration options for the conversion process
public struct ConversionOptions {
    public let force: Bool
    public let dryRun: Bool
    public let verbose: Bool
    public let noGitignore: Bool
    public let backup: Bool
    public let autoResolve: Bool
    public let inputPath: String?

    public init(
        force: Bool = false,
        dryRun: Bool = false,
        verbose: Bool = false,
        noGitignore: Bool = false,
        backup: Bool = false,
        autoResolve: Bool = false,
        inputPath: String? = nil
    ) {
        self.force = force
        self.dryRun = dryRun
        self.verbose = verbose
        self.noGitignore = noGitignore
        self.backup = backup
        self.autoResolve = autoResolve
        self.inputPath = inputPath
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
