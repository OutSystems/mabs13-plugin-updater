import Foundation
import XCTest
@testable import MABS13PluginUpdate

/// Regression coverage for the corrections that had to be made by hand after converting
/// cordova-outsystems-file: the platform floor, the target name, the source directory scanned for
/// the Cordova guard, and the missing `import Foundation`.
///
/// The layout mirrors that plugin: sources under `packages/cordova-plugin/ios`, the iOS class
/// declared through `<param name="ios-package">`, and a pod with an iOS 15 floor.
final class FilePluginRegressionTests: XCTestCase {
    private var tempDirectory: String!
    private var pluginXMLPath: String!
    private var sourceDirectory: String!

    private let pluginXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <plugin id="com.outsystems.plugins.filesystem" version="1.1.3" xmlns="http://apache.org/cordova/ns/plugins/1.0">
        <name>OSFilePlugin</name>
        <platform name="ios">
            <config-file parent="/*" target="config.xml">
                <feature name="OSFilePlugin">
                    <param name="ios-package" value="OSFilePlugin"/>
                </feature>
                <preference name="SwiftVersion" value="5"/>
            </config-file>
            <source-file src="packages/cordova-plugin/ios/OSFilePlugin.swift"/>
            <source-file src="packages/cordova-plugin/ios/IONFILEStructures+Converters.swift"/>
            <podspec>
                <config>
                    <source url="https://cdn.cocoapods.org/"/>
                </config>
                <pods use-frameworks="true">
                    <pod name="IONFilesystemLib" spec="2.0.0"/>
                </pods>
            </podspec>
        </platform>
    </plugin>
    """

    override func setUp() {
        super.setUp()

        tempDirectory = NSTemporaryDirectory() + "mabs13-plugin-update-file-regression-" + UUID().uuidString
        sourceDirectory = tempDirectory.appendingPathComponent("packages/cordova-plugin/ios")
        pluginXMLPath = tempDirectory.appendingPathComponent("plugin.xml")

        do {
            try Foundation.FileManager.default.createDirectory(
                atPath: sourceDirectory,
                withIntermediateDirectories: true
            )
            try pluginXML.write(toFile: pluginXMLPath, atomically: true, encoding: .utf8)
            try """
            @objc(OSFilePlugin)
            class OSFilePlugin: CDVPlugin {
                @objc func readFile(_ command: CDVInvokedUrlCommand) {}
            }
            """.write(
                toFile: sourceDirectory.appendingPathComponent("OSFilePlugin.swift"),
                atomically: true,
                encoding: .utf8
            )
            try """
            extension IONFILEInfoResult {
                var payload: Data {
                    Data()
                }
            }
            """.write(
                toFile: sourceDirectory.appendingPathComponent("IONFILEStructures+Converters.swift"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            XCTFail("Failed to lay out the plugin: \(error)")
        }
    }

    override func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    /// Convert with no network access: dependency resolution is off, so the floor comes from the
    /// MABS 13 minimum rather than from IONFilesystemLib's own manifest.
    private func convert() async -> Bool {
        let options = ConversionOptions(
            force: true,
            dryRun: false,
            verbose: false,
            noGitignore: true,
            backup: false,
            autoResolve: false,
            inputPath: pluginXMLPath
        )
        return await CordovaToSPMConverter(options: options).convert()
    }

    private func generatedPackage() throws -> String {
        try String(contentsOfFile: tempDirectory.appendingPathComponent("Package.swift"))
    }

    private func source(_ fileName: String) throws -> String {
        try String(contentsOfFile: sourceDirectory.appendingPathComponent(fileName))
    }

    func testManifestDeclaresTheMABS13PlatformFloor() async throws {
        let converted = await convert()
        XCTAssertTrue(converted)

        XCTAssertTrue(try generatedPackage().contains("platforms: [.iOS(.v15)]"))
    }

    func testManifestNamesTheTargetAfterThePluginClass() async throws {
        let converted = await convert()
        XCTAssertTrue(converted)

        let package = try generatedPackage()
        XCTAssertTrue(package.contains("name: \"com.outsystems.plugins.filesystem\""))
        XCTAssertTrue(package.contains("targets: [\"OSFilePlugin\"]"))
        XCTAssertTrue(package.contains("path: \"packages/cordova-plugin/ios\""))
    }

    func testCordovaGuardReachesSourcesOutsideSrcIOS() async throws {
        let converted = await convert()
        XCTAssertTrue(converted)

        let plugin = try source("OSFilePlugin.swift")
        XCTAssertTrue(plugin.contains("#if canImport(Cordova)"))
        XCTAssertTrue(plugin.contains("import Cordova"))
        XCTAssertTrue(plugin.contains("#endif"))
    }

    func testMissingFoundationImportIsAdded() async throws {
        let converted = await convert()
        XCTAssertTrue(converted)

        XCTAssertTrue(try source("IONFILEStructures+Converters.swift").contains("import Foundation"))
    }

    func testCocoaPodsPathIsPreserved() async throws {
        let converted = await convert()
        XCTAssertTrue(converted)

        let updatedXML = try String(contentsOfFile: pluginXMLPath)
        XCTAssertTrue(updatedXML.contains("package=\"swift\""))
        XCTAssertTrue(updatedXML.contains("nospm=\"true\""))
    }

    /// With resolution on, IONFilesystemLib's own iOS 15 floor is what sets the platform — and a
    /// dependency asking for more raises it further. Exercised through the resolver, so the test
    /// needs no network.
    func testDependencyFloorRaisesThePlatformAboveTheDefault() throws {
        let metadata = try XMLParser.parsePluginXML(content: pluginXML)
        let resolved = ResolvedDependency(
            originalPod: PodDependency(name: "IONFilesystemLib", spec: "2.0.0"),
            spmDependency: SPMDependency(
                url: "https://github.com/ionic-team/ion-ios-filesystem.git",
                requirement: .exact("2.0.0"),
                productName: "IONFilesystemLib",
                packageName: "ion-ios-filesystem",
                minimumIOSVersion: IOSPlatformVersion(major: 16, minor: 4)
            ),
            status: .resolved
        )

        let decision = IOSPlatformResolver.resolve(metadata: metadata, resolvedDependencies: [resolved])
        let package = PackageGenerator.generatePackageSwift(
            from: metadata,
            resolvedDependencies: [resolved],
            minimumIOSVersion: decision.version
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 16, minor: 4))
        XCTAssertTrue(package.contains("platforms: [.iOS(\"16.4\")]"))
        XCTAssertTrue(package.contains(".product(name: \"IONFilesystemLib\", package: \"ion-ios-filesystem\")"))
    }
}
