import XCTest
@testable import MABS13PluginUpdate

final class ModelsTests: XCTestCase {
    func testPodDependencyDescription() {
        let pod = PodDependency(name: "AFNetworking", spec: "~> 4.0")
        XCTAssertEqual(pod.description, "AFNetworking (~> 4.0)")
    }

    func testPodDependencyEquality() {
        let pod1 = PodDependency(name: "AFNetworking", spec: "~> 4.0")
        let pod2 = PodDependency(name: "AFNetworking", spec: "~> 4.0")
        let pod3 = PodDependency(name: "SDWebImage", spec: "~> 5.0")

        XCTAssertEqual(pod1, pod2)
        XCTAssertNotEqual(pod1, pod3)
    }

    func testPluginMetadataPackageName() {
        let metadata1 = PluginMetadata(
            pluginId: "com.example.plugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )
        XCTAssertEqual(metadata1.packageName, "com.example.plugin")

        let metadata2 = PluginMetadata(
            pluginId: "",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )
        XCTAssertEqual(metadata2.packageName, "UnknownPlugin")
    }

    func testPluginMetadataHasDependencies() {
        let pod = PodDependency(name: "AFNetworking", spec: "~> 4.0")

        let metadataWithDeps = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [pod],
            hasPodspec: true,
            originalXmlContent: ""
        )
        XCTAssertTrue(metadataWithDeps.hasDependencies)

        let metadataWithoutDeps = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: ""
        )
        XCTAssertFalse(metadataWithoutDeps.hasDependencies)
    }

    func testPluginMetadataDependencyDescriptions() {
        let pod1 = PodDependency(name: "AFNetworking", spec: "~> 4.0")
        let pod2 = PodDependency(name: "SDWebImage", spec: "~> 5.0")

        let metadata = PluginMetadata(
            pluginId: "test.plugin",
            dependencies: [pod1, pod2],
            hasPodspec: true,
            originalXmlContent: ""
        )

        let descriptions = metadata.dependencyDescriptions
        XCTAssertEqual(descriptions.count, 2)
        XCTAssertTrue(descriptions.contains("AFNetworking (~> 4.0)"))
        XCTAssertTrue(descriptions.contains("SDWebImage (~> 5.0)"))
    }

    func testConversionResultIsSuccess() {
        let success = ConversionResult.success("Success")
        let skipped = ConversionResult.skipped("Skipped")
        let error = ConversionResult.error("Error")

        XCTAssertTrue(success.isSuccess)
        XCTAssertFalse(skipped.isSuccess)
        XCTAssertFalse(error.isSuccess)
    }

    func testConversionOptionsDefaults() {
        let options = ConversionOptions()

        XCTAssertFalse(options.force)
        XCTAssertFalse(options.dryRun)
        XCTAssertFalse(options.verbose)
        XCTAssertFalse(options.noGitignore)
        XCTAssertNil(options.inputPath)
    }

    func testConversionOptionsCustom() {
        let options = ConversionOptions(
            force: true,
            dryRun: true,
            verbose: true,
            noGitignore: true,
            inputPath: "/custom/path"
        )

        XCTAssertTrue(options.force)
        XCTAssertTrue(options.dryRun)
        XCTAssertTrue(options.verbose)
        XCTAssertTrue(options.noGitignore)
        XCTAssertEqual(options.inputPath, "/custom/path")
    }
}
