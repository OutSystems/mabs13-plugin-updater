// swiftlint:disable file_length
import XCTest
@testable import cdv2spm

// swiftlint:disable:next type_body_length
final class PackageGeneratorTests: XCTestCase {
    func testGeneratePackageSwiftFromMetadata() {
        let dependencies = [
            PodDependency(name: "AFNetworking", spec: "~> 4.0"),
            PodDependency(name: "SDWebImage", spec: "~> 5.0")
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.testplugin",
            dependencies: dependencies,
            hasPodspec: true,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("name: \"com.example.testplugin\""))
        XCTAssertTrue(packageContent.contains("cordova-ios.git"))
        XCTAssertTrue(packageContent.contains("// TODO: Convert CocoaPods dependency: AFNetworking (~> 4.0)"))
        XCTAssertTrue(packageContent.contains("// TODO: Convert CocoaPods dependency: SDWebImage (~> 5.0)"))
        XCTAssertTrue(packageContent.contains("// TODO: Add Swift Package equivalent for: AFNetworking (~> 4.0)"))
        XCTAssertTrue(packageContent.contains("// TODO: Add Swift Package equivalent for: SDWebImage (~> 5.0)"))
    }

    func testGeneratePackageSwiftWithoutDependencies() {
        let metadata = PluginMetadata(
            pluginId: "com.example.simple",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("name: \"com.example.simple\""))
        XCTAssertTrue(packageContent.contains("cordova-ios.git"))
        XCTAssertFalse(packageContent.contains("TODO: Convert CocoaPods dependency"))
        XCTAssertFalse(packageContent.contains("TODO: Add Swift Package equivalent"))
    }

    func testValidatePackageSwiftSyntax() {
        let validPackage = """
        // swift-tools-version:5.9
        import PackageDescription
        
        let package = Package(
            name: "TestPackage",
            targets: [
                .target(name: "TestPackage")
            ]
        )
        """

        let invalidPackage = """
        This is not a valid Package.swift file
        """

        let incompletePackage = """
        // swift-tools-version:5.9
        import PackageDescription
        
        let package = Package(
            name: "TestPackage"
            // Missing targets
        )
        """

        XCTAssertTrue(PackageGenerator.hasRequiredPackageElements(validPackage))
        XCTAssertFalse(PackageGenerator.hasRequiredPackageElements(invalidPackage))
        XCTAssertFalse(PackageGenerator.hasRequiredPackageElements(incompletePackage))
    }

    func testPackageContentStructure() {
        let metadata = PluginMetadata(
            pluginId: "com.test.structure",
            dependencies: [PodDependency(name: "TestPod", spec: "1.0.0")],
            hasPodspec: true,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        // Check that the structure is valid Swift Package Manager format
        XCTAssertTrue(packageContent.hasPrefix("// swift-tools-version:5.9"))

        // Check for required sections in correct order
        let swiftToolsIndex = packageContent.range(of: "swift-tools-version")?.lowerBound
        let importIndex = packageContent.range(of: "import PackageDescription")?.lowerBound
        let packageIndex = packageContent.range(of: "let package = Package(")?.lowerBound

        XCTAssertNotNil(swiftToolsIndex)
        XCTAssertNotNil(importIndex)
        XCTAssertNotNil(packageIndex)

        // Verify order
        if let swift = swiftToolsIndex, let imp = importIndex, let pack = packageIndex {
            XCTAssertTrue(swift < imp)
            XCTAssertTrue(imp < pack)
        }
    }

    func testGeneratePackageSwiftWithCustomSourcePath() {
        let metadata = PluginMetadata(
            pluginId: "com.example.custompath",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata, sourcePath: "custom/path")

        // Should use the custom source path
        XCTAssertTrue(packageContent.contains("path: \"custom/path\""))
        XCTAssertFalse(packageContent.contains("path: \"src/ios\""))
    }

    func testGeneratePackageSwiftWithoutHeaderFiles() {
        let metadata = PluginMetadata(
            pluginId: "com.example.noheaders",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        // Use a non-existent path so no headers will be found
        let packageContent = PackageGenerator.generatePackageSwift(from: metadata, sourcePath: "nonexistent/path")

        // Should not contain publicHeadersPath when no headers are found
        XCTAssertFalse(packageContent.contains("publicHeadersPath"))
        XCTAssertTrue(packageContent.contains("path: \"nonexistent/path\""))
    }

    func testPublicHeadersPathDetection() {
        let metadata = PluginMetadata(
            pluginId: "com.example.withheaders",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        // Test with Sources/CordovaPluginConverter which should have .swift files but no .h files
        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            sourcePath: "Sources/CordovaPluginConverter"
        )

        // Should not contain publicHeadersPath for Swift source directory
        XCTAssertFalse(packageContent.contains("publicHeadersPath"))
        XCTAssertTrue(packageContent.contains("path: \"Sources/CordovaPluginConverter\""))
    }

    func testGeneratePackageSwiftWithFileManager() {
        let metadata = PluginMetadata(
            pluginId: "com.example.test",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        // Create a mock FileSystemManager that finds headers
        let logger = Logger(verbose: false)
        let fileManager = MockFileSystemManager(logger: logger)

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            sourcePath: "src/ios",
            fileManager: fileManager
        )

        // Should contain publicHeadersPath when FileSystemManager finds headers
        XCTAssertTrue(packageContent.contains("publicHeadersPath: \".\""))
        XCTAssertTrue(packageContent.contains("path: \"src/ios\""))
    }

    func testGeneratePackageSwiftWithoutFileManager() {
        let metadata = PluginMetadata(
            pluginId: "com.example.test",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        // Without FileSystemManager, no headers should be detected
        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            sourcePath: "src/ios"
        )

        // Should not contain publicHeadersPath when no FileSystemManager is provided
        XCTAssertFalse(packageContent.contains("publicHeadersPath"))
        XCTAssertTrue(packageContent.contains("path: \"src/ios\""))
    }

    func testGeneratePackageSwiftWithLocalXCFramework() {
        let framework = LocalXCFramework(
            name: "OSKeyStoreLib",
            path: "src/ios/frameworks/OSKeyStoreLib.xcframework"
        )
        let metadata = PluginMetadata(
            pluginId: "com.example.xcframework",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            localFrameworks: [framework]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        // Should contain a binaryTarget for the xcframework
        XCTAssertTrue(packageContent.contains(".binaryTarget("))
        XCTAssertTrue(packageContent.contains("name: \"OSKeyStoreLib\""))
        XCTAssertTrue(packageContent.contains("path: \"src/ios/frameworks/OSKeyStoreLib.xcframework\""))

        // Main target should reference the binary target
        XCTAssertTrue(packageContent.contains(".target(name: \"OSKeyStoreLib\")"))

        // The xcframework lives inside src/ios, so it must be excluded from source scanning
        XCTAssertTrue(packageContent.contains("exclude: ["))
        XCTAssertTrue(packageContent.contains("\"frameworks/OSKeyStoreLib.xcframework\""))

        // Should NOT contain publicHeadersPath (xcframework headers are internal to the binary)
        XCTAssertFalse(packageContent.contains("publicHeadersPath"))
    }

    func testGeneratePackageSwiftWithMultipleLocalXCFrameworks() {
        let frameworks = [
            LocalXCFramework(name: "LibA", path: "src/ios/LibA.xcframework"),
            LocalXCFramework(name: "LibB", path: "src/ios/LibB.xcframework")
        ]
        let metadata = PluginMetadata(
            pluginId: "com.example.multifw",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            localFrameworks: frameworks
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("name: \"LibA\""))
        XCTAssertTrue(packageContent.contains("name: \"LibB\""))
        XCTAssertTrue(packageContent.contains(".target(name: \"LibA\")"))
        XCTAssertTrue(packageContent.contains(".target(name: \"LibB\")"))

        // Both binaryTarget declarations should precede the main .target()
        let binaryARange = packageContent.range(of: "name: \"LibA\"")
        let mainTargetRange = packageContent.range(of: ".target(\n            name: \"com.example.multifw\"")
        XCTAssertNotNil(binaryARange)
        XCTAssertNotNil(mainTargetRange)
        if let binA = binaryARange, let main = mainTargetRange {
            XCTAssertTrue(binA.lowerBound < main.lowerBound,
                          "binaryTarget for LibA should appear before the main .target()")
        }
    }

    func testGeneratePackageSwiftWithResolvedDependencies() {
        let pod = PodDependency(name: "Alamofire", spec: "~> 5.0")
        let unresolvedPod = PodDependency(name: "SomePod", spec: "1.0.0")

        let resolvedDeps: [ResolvedDependency] = [
            ResolvedDependency(
                originalPod: pod,
                spmDependency: SPMDependency(
                    url: "https://github.com/Alamofire/Alamofire.git",
                    requirement: .upToNextMajor("5.0.0"),
                    productName: "Alamofire",
                    packageName: "Alamofire"
                ),
                status: .resolved
            ),
            ResolvedDependency(
                originalPod: unresolvedPod,
                spmDependency: nil,
                status: .noPackageSwift
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.resolved",
            dependencies: [pod, unresolvedPod],
            hasPodspec: true,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedDependencies: resolvedDeps
        )

        // Resolved dependency should appear as a real .package entry
        XCTAssertTrue(packageContent.contains("https://github.com/Alamofire/Alamofire.git"))
        XCTAssertTrue(packageContent.contains(".upToNextMajor(from: \"5.0.0\")"))
        XCTAssertTrue(packageContent.contains(".product(name: \"Alamofire\", package: \"Alamofire\")"))

        // Unresolved dependency should appear as placeholder comments
        XCTAssertTrue(packageContent.contains("// TODO: Convert CocoaPods dependency: SomePod (1.0.0)"))
        XCTAssertTrue(packageContent.contains("// TODO: Add Swift Package equivalent for: SomePod (1.0.0)"))

        // Cordova-ios should still be present
        XCTAssertTrue(packageContent.contains("cordova-ios.git"))
        XCTAssertTrue(packageContent.contains(".product(name: \"Cordova\", package: \"cordova-ios\")"))
    }

    func testGeneratePackageSwiftWithFirebaseLikeResolvedDependency() {
        // firebase-ios-sdk Package.swift declares name: "Firebase", but SPM identifies it
        // by the URL-derived identity "firebase-ios-sdk". The pod name "FirebaseMessaging"
        // must match the product name, not the first product "Firebase".
        let pod = PodDependency(name: "FirebaseMessaging", spec: "10.29.0")

        let resolvedDeps: [ResolvedDependency] = [
            ResolvedDependency(
                originalPod: pod,
                spmDependency: SPMDependency(
                    url: "https://github.com/firebase/firebase-ios-sdk.git",
                    requirement: .exact("10.29.0"),
                    productName: "FirebaseMessaging",
                    packageName: "firebase-ios-sdk"
                ),
                status: .resolved
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.fcm",
            dependencies: [pod],
            hasPodspec: true,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedDependencies: resolvedDeps
        )

        XCTAssertTrue(packageContent.contains("https://github.com/firebase/firebase-ios-sdk.git"))
        XCTAssertTrue(packageContent.contains(".product(name: \"FirebaseMessaging\", package: \"firebase-ios-sdk\")"))
        XCTAssertFalse(packageContent.contains(".product(name: \"Firebase\", package: \"Firebase\")"))
    }

    // MARK: - cSettings generation

    func testGeneratePackageSwiftWithSingleDirNativeSources() {
        let metadata = PluginMetadata(
            pluginId: "com.example.native",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [
                NativeSourceFile(path: "src/ios/Plugin.m", rawCompilerFlags: "-DFOO -DBAR=1")
            ]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("path: \"src/ios\""))
        XCTAssertTrue(packageContent.contains("cSettings: ["))
        XCTAssertTrue(packageContent.contains(".define(\"FOO\")"))
        XCTAssertTrue(packageContent.contains(".define(\"BAR\", to: \"1\")"))
        XCTAssertFalse(packageContent.contains("sources: ["))
    }

    func testGeneratePackageSwiftWithMultiDirNativeSources() {
        let metadata = PluginMetadata(
            pluginId: "com.example.multidir",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [
                NativeSourceFile(path: "src/ios/Plugin.m", rawCompilerFlags: "-DFOO"),
                NativeSourceFile(path: "src/common/lib.c", rawCompilerFlags: "-DFOO -DBAR=1")
            ],
            headerPaths: ["src/ios/Plugin.h", "src/common/lib.h"]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        // Target path should be the common ancestor
        XCTAssertTrue(packageContent.contains("path: \"src\""))
        // Explicit sources list required
        XCTAssertTrue(packageContent.contains("sources: ["))
        XCTAssertTrue(packageContent.contains("\"ios/Plugin.m\""))
        XCTAssertTrue(packageContent.contains("\"common/lib.c\""))
        // publicHeadersPath derived from first header
        XCTAssertTrue(packageContent.contains("publicHeadersPath: \"ios\""))
        // Additional header dir as headerSearchPath
        XCTAssertTrue(packageContent.contains(".headerSearchPath(\"common\")"))
        // Deduped defines
        XCTAssertTrue(packageContent.contains(".define(\"FOO\")"))
        XCTAssertTrue(packageContent.contains(".define(\"BAR\", to: \"1\")"))
        // -w flag must NOT produce an entry
        XCTAssertFalse(packageContent.contains(".define(\"w\")"))
    }

    func testGeneratePackageSwiftWithLinkerSettings() {
        let metadata = PluginMetadata(
            pluginId: "com.example.frameworks",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            systemFrameworks: [SystemFramework(name: "Security")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("linkerSettings: ["))
        XCTAssertTrue(packageContent.contains(".linkedFramework(\"Security\")"))
    }

    func testGeneratePackageSwiftMultipleLinkerSettings() {
        let metadata = PluginMetadata(
            pluginId: "com.example.multifw",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            systemFrameworks: [SystemFramework(name: "Security"), SystemFramework(name: "CoreLocation")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains(".linkedFramework(\"Security\")"))
        XCTAssertTrue(packageContent.contains(".linkedFramework(\"CoreLocation\")"))
    }

    func testGeneratePackageSwiftEmitsLinkedLibraryForSystemLibraries() {
        let metadata = PluginMetadata(
            pluginId: "com.example.libs",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            systemLibraries: [SystemLibrary(name: "sqlite3"), SystemLibrary(name: "z")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("linkerSettings: ["))
        XCTAssertTrue(packageContent.contains(".linkedLibrary(\"sqlite3\")"))
        XCTAssertTrue(packageContent.contains(".linkedLibrary(\"z\")"))
        // Must NOT emit .linkedFramework for libraries
        XCTAssertFalse(packageContent.contains(".linkedFramework(\"sqlite3\")"))
        XCTAssertFalse(packageContent.contains(".linkedFramework(\"libsqlite3.dylib\")"))
    }

    func testGeneratePackageSwiftCombinesFrameworksAndLibraries() {
        let metadata = PluginMetadata(
            pluginId: "com.example.mixed",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            systemFrameworks: [SystemFramework(name: "Security")],
            systemLibraries: [SystemLibrary(name: "sqlite3")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains(".linkedFramework(\"Security\")"))
        XCTAssertTrue(packageContent.contains(".linkedLibrary(\"sqlite3\")"))
    }

    func testGeneratePackageSwiftEmitsResourcesCopyForBundle() {
        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            resources: [ResourceFile(path: "src/ios/CDVEcho.bundle")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("resources: ["))
        // Path is normalized to be relative to target path (src/ios)
        XCTAssertTrue(packageContent.contains(".copy(\"CDVEcho.bundle\")"))
    }

    func testGeneratePackageSwiftEmitsResourcesProcessForNonBundle() {
        let metadata = PluginMetadata(
            pluginId: "com.example.privacy",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            resources: [ResourceFile(path: "src/ios/PrivacyInfo.xcprivacy")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains(".process(\"PrivacyInfo.xcprivacy\")"))
    }

    func testGeneratePackageSwiftNoResourcesBlockWhenEmpty() {
        let metadata = PluginMetadata(
            pluginId: "com.example.nores",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertFalse(packageContent.contains("resources:"))
    }

    func testGeneratePackageSwiftSkipsResourcesOutsideTargetPath() {
        // A resource outside the target's path cannot be referenced in SPM; the generator
        // skips it silently rather than emitting an invalid entry.
        let metadata = PluginMetadata(
            pluginId: "com.example.outside",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")],
            resources: [ResourceFile(path: "assets/icon.png")]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertFalse(packageContent.contains("resources:"))
    }

    func testGeneratePackageSwiftNoLinkerSettingsWhenNoSystemFrameworks() {
        let metadata = PluginMetadata(
            pluginId: "com.example.nofw",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertFalse(packageContent.contains("linkerSettings:"))
    }

    func testGeneratePackageSwiftSQLCipherLike() {
        // Reproduces the cordova-sqlcipher-adapter scenario end-to-end
        let metadata = PluginMetadata(
            pluginId: "cordova-sqlcipher-adapter",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [
                NativeSourceFile(path: "src/ios/SQLitePlugin.m", rawCompilerFlags: "-DSQLITE_HAS_CODEC"),
                NativeSourceFile(path: "src/ios/Helper.m", rawCompilerFlags: "-w"),
                NativeSourceFile(
                    path: "src/common/sqlite3.c",
                    rawCompilerFlags: "-DSQLITE_HAS_CODEC -DHAVE_USLEEP=1 -DSQLITE_TEMP_STORE=3"
                )
            ],
            systemFrameworks: [SystemFramework(name: "Security")],
            headerPaths: ["src/ios/SQLitePlugin.h", "src/common/sqlite3.h"]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        // Multi-dir → common ancestor path
        XCTAssertTrue(packageContent.contains("path: \"src\""))
        // Explicit sources
        XCTAssertTrue(packageContent.contains("\"ios/SQLitePlugin.m\""))
        XCTAssertTrue(packageContent.contains("\"ios/Helper.m\""))
        XCTAssertTrue(packageContent.contains("\"common/sqlite3.c\""))
        // publicHeadersPath from first header (src/ios/)
        XCTAssertTrue(packageContent.contains("publicHeadersPath: \"ios\""))
        // headerSearchPath for src/common/
        XCTAssertTrue(packageContent.contains(".headerSearchPath(\"common\")"))
        // Deduplicated defines (SQLITE_HAS_CODEC appears in two source files)
        let occurrences = packageContent.components(separatedBy: ".define(\"SQLITE_HAS_CODEC\")").count - 1
        XCTAssertEqual(occurrences, 1, "SQLITE_HAS_CODEC must appear exactly once after deduplication")
        XCTAssertTrue(packageContent.contains(".define(\"HAVE_USLEEP\", to: \"1\")"))
        XCTAssertTrue(packageContent.contains(".define(\"SQLITE_TEMP_STORE\", to: \"3\")"))
        // linkerSettings
        XCTAssertTrue(packageContent.contains(".linkedFramework(\"Security\")"))
        // -w must not produce an entry
        XCTAssertFalse(packageContent.contains(".define(\"w\")"))
    }

    // MARK: - PackageGenerator layout helpers

    func testCommonAncestorPathTwoDirs() {
        let result = PackageGenerator.commonAncestorPath(of: ["src/ios", "src/common"])
        XCTAssertEqual(result, "src")
    }

    func testCommonAncestorPathSingleDir() {
        let result = PackageGenerator.commonAncestorPath(of: ["src/ios"])
        XCTAssertEqual(result, "src/ios")
    }

    func testCommonAncestorPathDeepCommon() {
        let result = PackageGenerator.commonAncestorPath(of: ["a/b/c", "a/b/d"])
        XCTAssertEqual(result, "a/b")
    }

    func testCommonAncestorPathNoCommon() {
        let result = PackageGenerator.commonAncestorPath(of: ["ios", "android"])
        XCTAssertEqual(result, ".")
    }

    func testRelativePath() {
        XCTAssertEqual(PackageGenerator.relativePath("src/ios/Plugin.m", to: "src"), "ios/Plugin.m")
        XCTAssertEqual(PackageGenerator.relativePath("src/common/lib.c", to: "src"), "common/lib.c")
    }

    func testComputePublicHeadersPathFirstHeaderInSubdir() {
        let result = PackageGenerator.computePublicHeadersPath(
            from: ["src/ios/Plugin.h", "src/common/sqlite3.h"],
            targetPath: "src"
        )
        XCTAssertEqual(result, "ios")
    }

    func testComputePublicHeadersPathHeaderInSameDir() {
        let result = PackageGenerator.computePublicHeadersPath(
            from: ["src/ios/Plugin.h"],
            targetPath: "src/ios"
        )
        XCTAssertEqual(result, ".")
    }

    func testComputeHeaderSearchPathsExcludesPublicDir() {
        let result = PackageGenerator.computeHeaderSearchPaths(
            headerPaths: ["src/ios/Plugin.h", "src/common/sqlite3.h"],
            targetPath: "src",
            excludingDir: "ios"
        )
        XCTAssertEqual(result, ["common"])
    }
}

/// Mock FileSystemManager for testing
class MockFileSystemManager: FileSystemManager {
    override func findPublicHeadersPath(in _: String) -> String {
        // Mock behavior: always return "." to simulate headers in same directory
        "."
    }
}

// MARK: - Cordova Plugin Dependency generation tests

extension PackageGeneratorTests {
    func testGeneratePackageSwiftWithUnresolvedPluginDependencies() {
        let pluginDeps = [
            CordovaPluginDependency(
                id: "cordova-plugin-secure-storage",
                gitUrl: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
                branch: "spm"
            ),
            CordovaPluginDependency(
                id: "cordova-sqlcipher-adapter",
                gitUrl: "https://github.com/OutSystems/cordova-sqlcipher-adapter.git",
                tag: "0.1.7-OS11"
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            pluginDependencies: pluginDeps
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("// TODO: Cordova plugin dependency (run --auto-resolve to check):"))
        XCTAssertTrue(packageContent.contains("cordova-plugin-secure-storage"))
        XCTAssertTrue(packageContent.contains("cordova-sqlcipher-adapter"))
        let todoSecureStorage = "// TODO: Add SPM equivalent for Cordova plugin: cordova-plugin-secure-storage"
        let todoSQLCipher = "// TODO: Add SPM equivalent for Cordova plugin: cordova-sqlcipher-adapter"
        XCTAssertTrue(packageContent.contains(todoSecureStorage))
        XCTAssertTrue(packageContent.contains(todoSQLCipher))
        XCTAssertFalse(packageContent.contains(".package(url: \"https://github.com/OutSystems"))
    }

    func testGeneratePackageSwiftWithResolvedPluginDependencyBranch() {
        let pluginDep = CordovaPluginDependency(
            id: "cordova-plugin-secure-storage",
            gitUrl: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
            branch: "spm"
        )

        let resolvedPluginDeps = [
            ResolvedPluginDependency(
                original: pluginDep,
                spmDependency: SPMDependency(
                    url: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
                    requirement: .branch("spm"),
                    productName: "cordova-plugin-secure-storage",
                    packageName: "cordova-plugin-secure-storage"
                ),
                status: .resolved
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            pluginDependencies: [pluginDep]
        )

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedPluginDependencies: resolvedPluginDeps
        )

        XCTAssertTrue(packageContent.contains(
            ".package(url: \"https://github.com/OutSystems/cordova-plugin-secure-storage.git\", branch: \"spm\")"
        ))
        XCTAssertTrue(packageContent.contains(
            ".product(name: \"cordova-plugin-secure-storage\", package: \"cordova-plugin-secure-storage\")"
        ))
        XCTAssertFalse(packageContent.contains("// TODO: Cordova plugin dependency"))
    }

    func testGeneratePackageSwiftWithResolvedPluginDependencyTag() {
        let pluginDep = CordovaPluginDependency(
            id: "outsystems-plugin-disable-backup",
            gitUrl: "https://github.com/OutSystems/outsystems-plugin-disable-backup.git",
            tag: "1.0.2"
        )

        let resolvedPluginDeps = [
            ResolvedPluginDependency(
                original: pluginDep,
                spmDependency: SPMDependency(
                    url: "https://github.com/OutSystems/outsystems-plugin-disable-backup.git",
                    requirement: .tag("1.0.2"),
                    productName: "outsystems-plugin-disable-backup",
                    packageName: "outsystems-plugin-disable-backup"
                ),
                status: .resolved
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            pluginDependencies: [pluginDep]
        )

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedPluginDependencies: resolvedPluginDeps
        )

        XCTAssertTrue(packageContent.contains("exact: \"1.0.2\""))
        XCTAssertTrue(packageContent.contains("outsystems-plugin-disable-backup"))
        XCTAssertFalse(packageContent.contains("// TODO: Cordova plugin dependency"))
    }

    func testGeneratePackageSwiftWithMixedPluginDependencyResolution() {
        let resolved = CordovaPluginDependency(
            id: "cordova-plugin-secure-storage",
            gitUrl: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
            branch: "spm"
        )
        let unresolved = CordovaPluginDependency(
            id: "cordova-sqlcipher-adapter",
            gitUrl: "https://github.com/OutSystems/cordova-sqlcipher-adapter.git",
            tag: "0.1.7-OS11"
        )

        let resolvedPluginDeps = [
            ResolvedPluginDependency(
                original: resolved,
                spmDependency: SPMDependency(
                    url: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
                    requirement: .branch("spm"),
                    productName: "cordova-plugin-secure-storage",
                    packageName: "cordova-plugin-secure-storage"
                ),
                status: .resolved
            ),
            ResolvedPluginDependency(
                original: unresolved,
                spmDependency: nil,
                status: .noPackageSwift
            )
        ]

        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            pluginDependencies: [resolved, unresolved]
        )

        let packageContent = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedPluginDependencies: resolvedPluginDeps
        )

        XCTAssertTrue(packageContent.contains("branch: \"spm\""))
        XCTAssertTrue(packageContent.contains(".product(name: \"cordova-plugin-secure-storage\""))
        let todoSQLCipherPkg = "// TODO: Cordova plugin dependency (No Package.swift found): cordova-sqlcipher-adapter"
        let todoSQLCipherTarget = "// TODO: Add SPM equivalent for Cordova plugin: cordova-sqlcipher-adapter"
        XCTAssertTrue(packageContent.contains(todoSQLCipherPkg))
        XCTAssertTrue(packageContent.contains(todoSQLCipherTarget))
    }

    func testGeneratePackageSwiftWithNoPluginDepsHasNoPluginComments() {
        let metadata = PluginMetadata(
            pluginId: "com.example.simple",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertFalse(packageContent.contains("TODO: Cordova plugin dependency"))
        XCTAssertFalse(packageContent.contains("TODO: Add SPM equivalent for Cordova plugin"))
    }

    func testGeneratePackageSwiftCordovaIosAlwaysPresent() {
        let pluginDep = CordovaPluginDependency(
            id: "cordova-plugin-secure-storage",
            gitUrl: "https://github.com/OutSystems/cordova-plugin-secure-storage.git",
            branch: "spm"
        )

        let metadata = PluginMetadata(
            pluginId: "com.example.bundle",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            pluginDependencies: [pluginDep]
        )

        let packageContent = PackageGenerator.generatePackageSwift(from: metadata)

        XCTAssertTrue(packageContent.contains("cordova-ios.git"))
        XCTAssertTrue(packageContent.contains(".product(name: \"Cordova\", package: \"cordova-ios\")"))
    }
}
