import Foundation

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
    /// Minimum iOS version this dependency declares, when it declares one. The generated manifest
    /// cannot ask for less than the highest floor among its dependencies.
    public let minimumIOSVersion: IOSPlatformVersion?

    public init(
        url: String,
        requirement: SPMRequirement,
        productName: String? = nil,
        packageName: String? = nil,
        minimumIOSVersion: IOSPlatformVersion? = nil
    ) {
        self.url = url
        self.requirement = requirement
        self.productName = productName
        self.packageName = packageName
        self.minimumIOSVersion = minimumIOSVersion
    }
}

/// Represents package information extracted from a Package.swift file
public struct SPMPackageInfo: Equatable {
    public let name: String
    public let dependencies: [SPMDependency]
    public let products: [SPMProduct]
    public let targets: [SPMTarget]
    /// Minimum iOS version from the package's `platforms:` block, when it declares one
    public let iosPlatform: IOSPlatformVersion?

    public init(
        name: String,
        dependencies: [SPMDependency] = [],
        products: [SPMProduct] = [],
        targets: [SPMTarget] = [],
        iosPlatform: IOSPlatformVersion? = nil
    ) {
        self.name = name
        self.dependencies = dependencies
        self.products = products
        self.targets = targets
        self.iosPlatform = iosPlatform
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
