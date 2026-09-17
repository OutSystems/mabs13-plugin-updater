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
    /// iOS deployment target declared by the podspec (`platforms.ios`), when it declares one
    public let iosDeploymentTarget: IOSPlatformVersion?

    public init(
        name: String,
        version: String,
        sourceType: PodSourceType,
        homepage: String? = nil,
        vendoredFrameworks: String? = nil,
        iosDeploymentTarget: IOSPlatformVersion? = nil
    ) {
        self.name = name
        self.version = version
        self.sourceType = sourceType
        self.homepage = homepage
        self.vendoredFrameworks = vendoredFrameworks
        self.iosDeploymentTarget = iosDeploymentTarget
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
            ".define(\"\(key)\")"
        case let .defineWithValue(key, value):
            ".define(\"\(key)\", to: \"\(value)\")"
        case let .headerSearchPath(path):
            ".headerSearchPath(\"\(path)\")"
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
            ".linkedFramework(\"\(name)\")"
        case let .linkedLibrary(name):
            ".linkedLibrary(\"\(name)\")"
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

/// A system library declared via <framework src="libX.dylib"/> or <framework src="libX.tbd"/>
/// in the iOS platform block. Maps to SPM's `.linkedLibrary` linker setting.
public struct SystemLibrary: Equatable {
    /// Library name without the `lib` prefix and without the extension, e.g. "sqlite3" for "libsqlite3.dylib"
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// A resource file declared via <resource-file src="..." /> in the iOS platform block.
/// Maps to SPM's `resources:` block on the target.
public struct ResourceFile: Equatable {
    /// Path relative to the plugin root, e.g. "src/ios/CDVEcho.bundle"
    public let path: String

    public init(path: String) {
        self.path = path
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

    public var reference: String {
        tag ?? branch ?? "main"
    }

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

    public var isResolved: Bool {
        status == .resolved && spmDependency != nil
    }
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
    /// System libraries declared via <framework src="libX.dylib"/> or <framework src="libX.tbd"/>
    public let systemLibraries: [SystemLibrary]
    /// Header file paths declared via <header-file> in the iOS platform
    public let headerPaths: [String]
    /// Top-level Cordova plugin dependencies declared with <dependency> in plugin.xml
    public let pluginDependencies: [CordovaPluginDependency]
    /// Resource files declared via <resource-file> in the iOS platform
    public let resources: [ResourceFile]
    /// iOS deployment target the plugin itself asks for, from a `deployment-target` or
    /// `IPHONEOS_DEPLOYMENT_TARGET` preference in the iOS platform
    public let deploymentTarget: IOSPlatformVersion?

    public init(
        pluginId: String,
        dependencies: [PodDependency],
        hasPodspec: Bool,
        originalXmlContent: String,
        localFrameworks: [LocalXCFramework] = [],
        nativeSources: [NativeSourceFile] = [],
        systemFrameworks: [SystemFramework] = [],
        systemLibraries: [SystemLibrary] = [],
        headerPaths: [String] = [],
        pluginDependencies: [CordovaPluginDependency] = [],
        resources: [ResourceFile] = [],
        deploymentTarget: IOSPlatformVersion? = nil
    ) {
        self.pluginId = pluginId
        self.dependencies = dependencies
        self.hasPodspec = hasPodspec
        self.originalXmlContent = originalXmlContent
        self.localFrameworks = localFrameworks
        self.nativeSources = nativeSources
        self.systemFrameworks = systemFrameworks
        self.systemLibraries = systemLibraries
        self.headerPaths = headerPaths
        self.pluginDependencies = pluginDependencies
        self.resources = resources
        self.deploymentTarget = deploymentTarget
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

    /// Unique directories holding the plugin's declared native sources, in declaration order.
    /// These are the directories the tool must scan, which is not necessarily `src/ios`.
    public var nativeSourceDirectories: [String] {
        var seen = Set<String>()
        return nativeSources.map(\.directory).filter { seen.insert($0).inserted }
    }

    /// Dependency descriptions for logging
    public var dependencyDescriptions: [String] {
        dependencies.map(\.description)
    }
}
