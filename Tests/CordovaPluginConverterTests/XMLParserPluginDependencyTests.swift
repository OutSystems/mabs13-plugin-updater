import XCTest
@testable import cdv2spm

// swiftlint:disable:next type_body_length
final class XMLParserPluginDependencyTests: XCTestCase {
    // MARK: - Basic parsing

    func testParsesDependencyWithUrlAttributeAndBranch() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="cordova-plugin-camera"
                        url="https://github.com/apache/cordova-plugin-camera.git#main" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.pluginDependencies.count, 1)
        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.id, "cordova-plugin-camera")
        XCTAssertEqual(dep.gitUrl, "https://github.com/apache/cordova-plugin-camera.git")
        XCTAssertEqual(dep.branch, "main")
        XCTAssertNil(dep.tag)
        XCTAssertEqual(dep.reference, "main")
        XCTAssertTrue(metadata.hasPluginDependencies)
    }

    func testParsesDependencyWithUrlAttributeAndVersionTag() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="cordova-sqlcipher-adapter"
                        url="https://github.com/OutSystems/cordova-sqlcipher-adapter.git#0.1.7-OS11" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.pluginDependencies.count, 1)
        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.id, "cordova-sqlcipher-adapter")
        XCTAssertEqual(dep.gitUrl, "https://github.com/OutSystems/cordova-sqlcipher-adapter.git")
        XCTAssertEqual(dep.tag, "0.1.7-OS11")
        XCTAssertNil(dep.branch)
        XCTAssertEqual(dep.reference, "0.1.7-OS11")
    }

    func testParsesDependencyWithPathAttributeAndBranch() throws {
        // cordova-plugin-secure-storage uses path= instead of url=
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="cordova-plugin-secure-storage"
                        path="https://github.com/OutSystems/cordova-plugin-secure-storage.git#spm" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.pluginDependencies.count, 1)
        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.id, "cordova-plugin-secure-storage")
        XCTAssertEqual(dep.gitUrl, "https://github.com/OutSystems/cordova-plugin-secure-storage.git")
        XCTAssertEqual(dep.branch, "spm")
        XCTAssertNil(dep.tag)
        XCTAssertEqual(dep.reference, "spm")
    }

    func testParsesDependencyWithNumericVersionTag() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="outsystems-plugin-disable-backup"
                        url="https://github.com/OutSystems/outsystems-plugin-disable-backup.git#1.0.2" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.tag, "1.0.2")
        XCTAssertNil(dep.branch)
    }

    func testParsesDependencyWithVPrefixedTag() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="some-plugin"
                        url="https://github.com/example/some-plugin.git#v2.3.0" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.tag, "v2.3.0")
        XCTAssertNil(dep.branch)
    }

    func testParsesDependencyWithoutFragment() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="some-plugin"
                        url="https://github.com/example/some-plugin.git" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        let dep = try XCTUnwrap(metadata.pluginDependencies.first)
        XCTAssertEqual(dep.gitUrl, "https://github.com/example/some-plugin.git")
        XCTAssertNil(dep.branch)
        XCTAssertNil(dep.tag)
        XCTAssertEqual(dep.reference, "main")
    }

    // MARK: - Filtering

    func testIgnoresDependencyWithLocalPath() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="local-plugin" path="../some/local/path" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.pluginDependencies.count, 0)
        XCTAssertFalse(metadata.hasPluginDependencies)
    }

    func testIgnoresDependencyWithNpmStyleId() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="cordova-plugin-camera" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.pluginDependencies.count, 0)
    }

    func testIgnoresDuplicateDependencies() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.plugin" version="1.0.0">
            <dependency id="some-plugin"
                        url="https://github.com/example/some-plugin.git#1.0.0" />
            <dependency id="some-plugin"
                        url="https://github.com/example/some-plugin.git#1.0.0" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.pluginDependencies.count, 1)
    }

    // MARK: - SecureSQLiteBundle scenario

    func testParsesSecureSQLiteBundleScenario() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
            xmlns:android="http://schemas.android.com/apk/res/android"
            id="com.outsystems.plugins.SecureSQLiteBundle"
            version="2.2.7">
            <dependency id="cordova-sqlcipher-adapter"
                        url="https://github.com/OutSystems/cordova-sqlcipher-adapter.git#0.1.7-OS11" />
            <dependency id="cordova-plugin-secure-storage"
                        path="https://github.com/OutSystems/cordova-plugin-secure-storage.git#spm" />
            <dependency id="outsystems-plugin-disable-backup"
                        url="https://github.com/OutSystems/outsystems-plugin-disable-backup.git#1.0.2" />
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.pluginDependencies.count, 3)
        XCTAssertTrue(metadata.hasPluginDependencies)

        let sqlcipher = try XCTUnwrap(metadata.pluginDependencies.first { $0.id == "cordova-sqlcipher-adapter" })
        XCTAssertEqual(sqlcipher.tag, "0.1.7-OS11")
        XCTAssertNil(sqlcipher.branch)

        let secureStorage = try XCTUnwrap(
            metadata.pluginDependencies.first { $0.id == "cordova-plugin-secure-storage" }
        )
        XCTAssertEqual(secureStorage.branch, "spm")
        XCTAssertNil(secureStorage.tag)
        XCTAssertEqual(secureStorage.gitUrl, "https://github.com/OutSystems/cordova-plugin-secure-storage.git")

        let disableBackup = try XCTUnwrap(
            metadata.pluginDependencies.first { $0.id == "outsystems-plugin-disable-backup" }
        )
        XCTAssertEqual(disableBackup.tag, "1.0.2")
        XCTAssertNil(disableBackup.branch)
    }

    // MARK: - Coexistence with CocoaPods

    func testPluginDepsCoexistWithPods() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin xmlns="http://www.phonegap.com/ns/plugins/1.0"
                id="com.example.hybrid" version="1.0.0">
            <dependency id="some-dep"
                        url="https://github.com/example/some-dep.git#spm" />
            <platform name="ios">
                <podspec>
                    <pods>
                        <pod name="Alamofire" spec="~> 5.0"/>
                    </pods>
                </podspec>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.dependencies.count, 1)
        XCTAssertEqual(metadata.dependencies.first?.name, "Alamofire")
        XCTAssertEqual(metadata.pluginDependencies.count, 1)
        XCTAssertEqual(metadata.pluginDependencies.first?.id, "some-dep")
    }

    // MARK: - CordovaPluginDependency model

    func testReferenceReturnsTagWhenBothSet() {
        let dep = CordovaPluginDependency(
            id: "test",
            gitUrl: "https://github.com/example/test.git",
            branch: "main",
            tag: "1.0.0"
        )
        XCTAssertEqual(dep.reference, "1.0.0")
    }

    func testReferenceReturnsBranchWhenNoTag() {
        let dep = CordovaPluginDependency(
            id: "test",
            gitUrl: "https://github.com/example/test.git",
            branch: "spm",
            tag: nil
        )
        XCTAssertEqual(dep.reference, "spm")
    }

    func testReferenceReturnsMainWhenBothNil() {
        let dep = CordovaPluginDependency(
            id: "test",
            gitUrl: "https://github.com/example/test.git"
        )
        XCTAssertEqual(dep.reference, "main")
    }

    func testDescriptionIncludesTag() {
        let dep = CordovaPluginDependency(
            id: "my-plugin",
            gitUrl: "https://github.com/example/my-plugin.git",
            tag: "2.0.0"
        )
        XCTAssertTrue(dep.description.contains("my-plugin"))
        XCTAssertTrue(dep.description.contains("#2.0.0"))
    }

    func testDescriptionIncludesBranch() {
        let dep = CordovaPluginDependency(
            id: "my-plugin",
            gitUrl: "https://github.com/example/my-plugin.git",
            branch: "develop"
        )
        XCTAssertTrue(dep.description.contains("#develop"))
    }
}
