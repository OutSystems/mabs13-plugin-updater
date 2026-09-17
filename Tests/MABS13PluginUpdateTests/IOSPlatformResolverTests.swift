import XCTest
@testable import MABS13PluginUpdate

final class IOSPlatformResolverTests: XCTestCase {
    private func makeMetadata(deploymentTarget: IOSPlatformVersion? = nil) -> PluginMetadata {
        PluginMetadata(
            pluginId: "com.example.plugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            deploymentTarget: deploymentTarget
        )
    }

    private func makeResolvedPod(
        name: String,
        minimumIOSVersion: IOSPlatformVersion?
    )
        -> ResolvedDependency {
        ResolvedDependency(
            originalPod: PodDependency(name: name, spec: "1.0.0"),
            spmDependency: SPMDependency(
                url: "https://github.com/example/\(name).git",
                requirement: .exact("1.0.0"),
                productName: name,
                packageName: name,
                minimumIOSVersion: minimumIOSVersion
            ),
            status: .resolved
        )
    }

    func testFallsBackToMABS13Floor() {
        let decision = IOSPlatformResolver.resolve(metadata: makeMetadata())

        XCTAssertEqual(decision.version, .mabs13Minimum)
        XCTAssertEqual(decision.reasons.count, 1)
        XCTAssertTrue(decision.reasons[0].contains("MABS 13"))
        XCTAssertNil(decision.overriddenRequest)
    }

    func testDependencyFloorRaisesTheVersion() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            resolvedDependencies: [
                makeResolvedPod(name: "IONFilesystemLib", minimumIOSVersion: IOSPlatformVersion(major: 16, minor: 4))
            ]
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 16, minor: 4))
        XCTAssertEqual(decision.reasons, ["IONFilesystemLib requires iOS 16.4 or later"])
    }

    func testDependencyBelowTheFloorDoesNotLowerIt() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            resolvedDependencies: [
                makeResolvedPod(name: "LegacyLib", minimumIOSVersion: IOSPlatformVersion(major: 12))
            ]
        )

        XCTAssertEqual(decision.version, .mabs13Minimum)
    }

    func testHighestDependencyFloorWins() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            resolvedDependencies: [
                makeResolvedPod(name: "LibA", minimumIOSVersion: IOSPlatformVersion(major: 16)),
                makeResolvedPod(name: "LibB", minimumIOSVersion: IOSPlatformVersion(major: 17)),
                makeResolvedPod(name: "LibC", minimumIOSVersion: nil)
            ]
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 17))
        XCTAssertEqual(decision.reasons, ["LibB requires iOS 17.0 or later"])
    }

    func testPluginXMLDeploymentTargetIsHonoured() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(deploymentTarget: IOSPlatformVersion(major: 16))
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 16))
        XCTAssertTrue(decision.reasons[0].contains("plugin.xml"))
    }

    func testCordovaPluginDependencyFloorIsHonoured() {
        let pluginDependency = ResolvedPluginDependency(
            original: CordovaPluginDependency(
                id: "cordova-plugin-example",
                gitUrl: "https://github.com/example/cordova-plugin-example.git",
                branch: "spm"
            ),
            spmDependency: SPMDependency(
                url: "https://github.com/example/cordova-plugin-example.git",
                requirement: .branch("spm"),
                minimumIOSVersion: IOSPlatformVersion(major: 18)
            ),
            status: .resolved
        )

        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            resolvedPluginDependencies: [pluginDependency]
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 18))
        XCTAssertEqual(decision.reasons, ["cordova-plugin-example requires iOS 18.0 or later"])
    }

    func testExplicitRequestIsUsedWhenItIsTheHighest() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            requested: IOSPlatformVersion(major: 17)
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 17))
        XCTAssertTrue(decision.reasons[0].contains("--min-ios"))
        XCTAssertNil(decision.overriddenRequest)
    }

    func testExplicitRequestBelowWhatIsRequiredIsReportedAsOverridden() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(),
            resolvedDependencies: [
                makeResolvedPod(name: "IONFilesystemLib", minimumIOSVersion: IOSPlatformVersion(major: 15))
            ],
            requested: IOSPlatformVersion(major: 14)
        )

        XCTAssertEqual(decision.version, .mabs13Minimum)
        XCTAssertEqual(decision.overriddenRequest, IOSPlatformVersion(major: 14))
    }

    func testReasonsListEveryInputThatSetTheChosenVersion() {
        let decision = IOSPlatformResolver.resolve(
            metadata: makeMetadata(deploymentTarget: IOSPlatformVersion(major: 16)),
            resolvedDependencies: [
                makeResolvedPod(name: "LibA", minimumIOSVersion: IOSPlatformVersion(major: 16))
            ],
            requested: IOSPlatformVersion(major: 16)
        )

        XCTAssertEqual(decision.version, IOSPlatformVersion(major: 16))
        XCTAssertEqual(decision.reasons.count, 3)
    }
}
