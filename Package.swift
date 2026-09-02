// swift-tools-version:5.9
import PackageDescription

// The executable product name is the command users type; the target name is the Swift
// module name, so it must be a valid identifier (SwiftPM would otherwise mangle the
// hyphens to underscores when deriving the module name from the target name).
let package = Package(
    name: "mabs13-plugin-update",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "mabs13-plugin-update",
            targets: ["MABS13PluginUpdate"]
        )
    ],
    dependencies: [
        // ArgumentParser for CLI handling
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        // SWXMLHash for XML parsing
        .package(url: "https://github.com/drmohundro/SWXMLHash.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MABS13PluginUpdate",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SWXMLHash", package: "SWXMLHash")
            ],
            path: "Sources/MABS13PluginUpdate"
        ),
        .testTarget(
            name: "MABS13PluginUpdateTests",
            dependencies: ["MABS13PluginUpdate"],
            path: "Tests/MABS13PluginUpdateTests"
        )
    ]
)
