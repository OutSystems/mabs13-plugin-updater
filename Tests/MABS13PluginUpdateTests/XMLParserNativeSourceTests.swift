import XCTest
@testable import MABS13PluginUpdate

// swiftlint:disable:next type_body_length
final class XMLParserNativeSourceTests: XCTestCase {
    // MARK: - <source-file> parsing

    func testParseSourceFilesWithoutFlags() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.nativeSources.count, 1)
        XCTAssertEqual(metadata.nativeSources[0].path, "src/ios/Plugin.m")
        XCTAssertEqual(metadata.nativeSources[0].rawCompilerFlags, "")
    }

    func testParseSourceFilesWithCompilerFlags() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m" compiler-flags="-DSQLITE_HAS_CODEC"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.nativeSources.count, 1)
        XCTAssertEqual(metadata.nativeSources[0].rawCompilerFlags, "-DSQLITE_HAS_CODEC")
    }

    func testParseMultipleSourceFiles() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m" compiler-flags="-DFOO"/>
                <source-file src="src/ios/Helper.m"/>
                <source-file src="src/common/lib.c" compiler-flags="-DBAR=1"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.nativeSources.count, 3)
        XCTAssertEqual(metadata.nativeSources[0].path, "src/ios/Plugin.m")
        XCTAssertEqual(metadata.nativeSources[1].path, "src/ios/Helper.m")
        XCTAssertEqual(metadata.nativeSources[2].path, "src/common/lib.c")
        XCTAssertEqual(metadata.nativeSources[2].rawCompilerFlags, "-DBAR=1")
    }

    func testAndroidSourceFilesAreIgnored() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="android">
                <source-file src="src/android/Plugin.java"/>
            </platform>
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.nativeSources.count, 1)
        XCTAssertEqual(metadata.nativeSources[0].path, "src/ios/Plugin.m")
    }

    // MARK: - <header-file> parsing

    func testParseHeaderFiles() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <header-file src="src/ios/Plugin.h"/>
                <header-file src="src/common/sqlite3.h"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.headerPaths, ["src/ios/Plugin.h", "src/common/sqlite3.h"])
    }

    func testNoHeaderFilesProducesEmptyArray() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <source-file src="src/ios/Plugin.m"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertTrue(metadata.headerPaths.isEmpty)
    }

    // MARK: - <framework> system frameworks

    func testParseSystemFrameworkWithDotFrameworkSuffix() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <framework src="Security.framework"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.systemFrameworks, [SystemFramework(name: "Security")])
    }

    func testParseSystemFrameworkWithoutSuffix() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <framework src="CoreLocation"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.systemFrameworks, [SystemFramework(name: "CoreLocation")])
    }

    func testParseMultipleSystemFrameworks() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <framework src="Security.framework"/>
                <framework src="CoreLocation.framework"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.systemFrameworks.count, 2)
        XCTAssertTrue(metadata.systemFrameworks.contains(SystemFramework(name: "Security")))
        XCTAssertTrue(metadata.systemFrameworks.contains(SystemFramework(name: "CoreLocation")))
    }

    func testCustomXCFrameworkIsNotASystemFramework() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="ios">
                <framework src="src/ios/MyLib.xcframework" custom="true"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertTrue(metadata.systemFrameworks.isEmpty)
        XCTAssertEqual(metadata.localFrameworks.count, 1)
    }

    func testAndroidFrameworksAreIgnored() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="com.example.plugin" version="1.0.0">
            <platform name="android">
                <framework src="net.zetetic:sqlcipher-android:4.10.0"/>
                <framework src="src/android/build.gradle" custom="true" type="gradleReference"/>
            </platform>
            <platform name="ios">
                <framework src="Security.framework"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)
        XCTAssertEqual(metadata.systemFrameworks, [SystemFramework(name: "Security")])
    }

    // MARK: - Full SQLCipher-like plugin.xml

    func testParseSQLCipherLikePlugin() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plugin id="cordova-sqlcipher-adapter" version="0.1.7">
            <platform name="ios">
                <header-file src="src/ios/SQLitePlugin.h"/>
                <source-file src="src/ios/SQLitePlugin.m" compiler-flags="-DSQLITE_HAS_CODEC"/>
                <source-file src="src/ios/Helper.m" compiler-flags="-w"/>
                <header-file src="src/common/sqlite3.h"/>
                <source-file src="src/common/sqlite3.c"
                             compiler-flags="-DSQLITE_HAS_CODEC -DHAVE_USLEEP=1 -DSQLITE_TEMP_STORE=3"/>
                <framework src="Security.framework"/>
            </platform>
        </plugin>
        """
        let metadata = try XMLParser.parsePluginXML(content: xml)

        XCTAssertEqual(metadata.pluginId, "cordova-sqlcipher-adapter")
        XCTAssertFalse(metadata.hasPodspec)
        XCTAssertTrue(metadata.isNativeOnly)

        XCTAssertEqual(metadata.nativeSources.count, 3)
        XCTAssertEqual(metadata.headerPaths, ["src/ios/SQLitePlugin.h", "src/common/sqlite3.h"])
        XCTAssertEqual(metadata.systemFrameworks, [SystemFramework(name: "Security")])

        let sqliteC = metadata.nativeSources.first { $0.path == "src/common/sqlite3.c" }
        XCTAssertNotNil(sqliteC)
        XCTAssertTrue(sqliteC?.rawCompilerFlags.contains("SQLITE_HAS_CODEC") ?? false)
        XCTAssertTrue(sqliteC?.rawCompilerFlags.contains("HAVE_USLEEP=1") ?? false)
    }

    // MARK: - NativeSourceFile helpers

    func testNativeSourceFileDirectory() {
        let source = NativeSourceFile(path: "src/ios/Plugin.m")
        XCTAssertEqual(source.directory, "src/ios")
    }

    func testNativeSourceFileDirectoryForCommonPath() {
        let source = NativeSourceFile(path: "src/common/sqlite3.c")
        XCTAssertEqual(source.directory, "src/common")
    }

    func testPluginMetadataIsNativeOnly() {
        let metadata = PluginMetadata(
            pluginId: "test",
            dependencies: [],
            hasPodspec: false,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")]
        )
        XCTAssertTrue(metadata.isNativeOnly)
        XCTAssertTrue(metadata.hasNativeSources)
    }

    func testPluginMetadataIsNotNativeOnlyWhenHasDependencies() {
        let metadata = PluginMetadata(
            pluginId: "test",
            dependencies: [PodDependency(name: "SQLCipher", spec: "~> 4.0")],
            hasPodspec: true,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")]
        )
        XCTAssertFalse(metadata.isNativeOnly)
        XCTAssertTrue(metadata.hasNativeSources)
    }

    func testPluginMetadataIsNativeOnlyWhenPodspecHasNoPods() {
        // A <podspec> block with no parseable <pod> children: hasPodspec=true, dependencies=[]
        // The plugin is still effectively native-only since there are no real CocoaPods deps.
        let metadata = PluginMetadata(
            pluginId: "test",
            dependencies: [],
            hasPodspec: true,
            originalXmlContent: "",
            nativeSources: [NativeSourceFile(path: "src/ios/Plugin.m")]
        )
        XCTAssertTrue(metadata.isNativeOnly)
        XCTAssertTrue(metadata.hasNativeSources)
    }
}
