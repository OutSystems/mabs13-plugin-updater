import XCTest
@testable import MABS13PluginUpdate

final class PackageGeneratorPlatformTests: XCTestCase {
    private func makeMetadata() -> PluginMetadata {
        PluginMetadata(
            pluginId: "com.example.testplugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )
    }

    func testDefaultPlatformIsMABS13Floor() {
        let packageContent = PackageGenerator.generatePackageSwift(from: makeMetadata())

        XCTAssertTrue(packageContent.contains("platforms: [.iOS(.v15)]"))
        XCTAssertFalse(packageContent.contains(".iOS(.v14)"))
    }

    func testExplicitWholePlatformVersion() {
        let packageContent = PackageGenerator.generatePackageSwift(
            from: makeMetadata(),
            minimumIOSVersion: IOSPlatformVersion(major: 16)
        )

        XCTAssertTrue(packageContent.contains("platforms: [.iOS(.v16)]"))
    }

    func testExplicitMinorPlatformVersionUsesStringForm() {
        let packageContent = PackageGenerator.generatePackageSwift(
            from: makeMetadata(),
            minimumIOSVersion: IOSPlatformVersion(major: 16, minor: 4)
        )

        XCTAssertTrue(packageContent.contains("platforms: [.iOS(\"16.4\")]"))
    }
}
