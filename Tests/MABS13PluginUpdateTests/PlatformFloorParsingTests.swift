import XCTest
@testable import MABS13PluginUpdate

/// Reading a dependency's iOS floor out of the two sources the tool already fetches: the
/// dependency's own Package.swift and its podspec.
final class PlatformFloorParsingTests: XCTestCase {
    private var parser: SPMPackageParser!
    private var podSpecResolver: PodSpecResolver!

    override func setUp() {
        super.setUp()
        let logger = Logger(verbose: false)
        parser = SPMPackageParser(logger: logger)
        podSpecResolver = PodSpecResolver(logger: logger)
    }

    // MARK: - Package.swift

    func testPackageSwiftSinglePlatform() {
        let content = """
        // swift-tools-version: 5.9
        import PackageDescription
        
        let package = Package(
            name: "IONFilesystemLib",
            platforms: [.iOS(.v15)],
            products: [
                .library(name: "IONFilesystemLib", targets: ["IONFilesystemLib"])
            ]
        )
        """

        XCTAssertEqual(parser.extractIOSPlatform(content), IOSPlatformVersion(major: 15))
        XCTAssertEqual(parser.parsePackageSwift(content)?.iosPlatform, IOSPlatformVersion(major: 15))
    }

    func testPackageSwiftMultilinePlatformsWithOtherPlatforms() {
        let content = """
        let package = Package(
            name: "Cordova",
            platforms: [
                .macOS(.v13),
                .iOS(.v13),
                .macCatalyst(.v13)
            ],
            products: [
                .library(name: "Cordova", targets: ["Cordova"])
            ]
        )
        """

        XCTAssertEqual(parser.extractIOSPlatform(content), IOSPlatformVersion(major: 13))
    }

    func testPackageSwiftStringPlatformForm() {
        let content = """
        let package = Package(
            name: "Example",
            platforms: [.iOS("16.4")],
            products: []
        )
        """

        XCTAssertEqual(parser.extractIOSPlatform(content), IOSPlatformVersion(major: 16, minor: 4))
    }

    func testPackageSwiftWithoutPlatforms() {
        let content = """
        let package = Package(
            name: "Example",
            products: [
                .library(name: "Example", targets: ["Example"])
            ]
        )
        """

        XCTAssertNil(parser.extractIOSPlatform(content))
        XCTAssertNil(parser.parsePackageSwift(content)?.iosPlatform)
    }

    func testPackageSwiftWithoutIOSPlatform() {
        let content = """
        let package = Package(
            name: "Example",
            platforms: [.macOS(.v13)],
            products: []
        )
        """

        XCTAssertNil(parser.extractIOSPlatform(content))
    }

    // MARK: - Podspec

    func testPodspecDeploymentTargetAsString() {
        let json: [String: Any] = ["platforms": ["ios": "15.0"]]

        XCTAssertEqual(podSpecResolver.extractIOSDeploymentTarget(from: json), IOSPlatformVersion(major: 15))
    }

    func testPodspecDeploymentTargetAsNumber() {
        let json: [String: Any] = ["platforms": ["ios": NSNumber(value: 16)]]

        XCTAssertEqual(podSpecResolver.extractIOSDeploymentTarget(from: json), IOSPlatformVersion(major: 16))
    }

    func testPodspecWithoutIOSPlatform() {
        XCTAssertNil(podSpecResolver.extractIOSDeploymentTarget(from: ["platforms": ["osx": "13.0"]]))
        XCTAssertNil(podSpecResolver.extractIOSDeploymentTarget(from: [:]))
        XCTAssertNil(podSpecResolver.extractIOSDeploymentTarget(from: ["platforms": ["ios": "latest"]]))
    }
}
