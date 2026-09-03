import XCTest
@testable import MABS13PluginUpdate

final class CompilerFlagsParserTests: XCTestCase {
    // MARK: - parse()

    func testParseSimpleDefine() {
        let result = CompilerFlagsParser.parse("-DSQLITE_HAS_CODEC")
        XCTAssertEqual(result, [.define("SQLITE_HAS_CODEC")])
    }

    func testParseDefineWithValue() {
        let result = CompilerFlagsParser.parse("-DSQLITE_TEMP_STORE=3")
        XCTAssertEqual(result, [.defineWithValue("SQLITE_TEMP_STORE", "3")])
    }

    func testParseDefineWithStringValue() {
        let result = CompilerFlagsParser.parse("-DSQLITE_EXTRA_INIT=sqlcipher_extra_init")
        XCTAssertEqual(result, [.defineWithValue("SQLITE_EXTRA_INIT", "sqlcipher_extra_init")])
    }

    func testParseMultipleFlags() {
        let raw = "-DSQLITE_HAS_CODEC -DHAVE_USLEEP=1 -DSQLITE_TEMP_STORE=3"
        let result = CompilerFlagsParser.parse(raw)
        XCTAssertEqual(result, [
            .define("SQLITE_HAS_CODEC"),
            .defineWithValue("HAVE_USLEEP", "1"),
            .defineWithValue("SQLITE_TEMP_STORE", "3")
        ])
    }

    func testParseIgnoresNonDefineFlags() {
        let result = CompilerFlagsParser.parse("-w -DSQLITE_HAS_CODEC -O2")
        XCTAssertEqual(result, [.define("SQLITE_HAS_CODEC")])
    }

    func testParseMultilineFlags() {
        let raw = """
        -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1
        -DSQLITE_TEMP_STORE=3
        -DNDEBUG
        """
        let result = CompilerFlagsParser.parse(raw)
        XCTAssertEqual(result, [
            .define("SQLITE_HAS_CODEC"),
            .defineWithValue("HAVE_USLEEP", "1"),
            .defineWithValue("SQLITE_TEMP_STORE", "3"),
            .define("NDEBUG")
        ])
    }

    func testParseEmptyString() {
        XCTAssertEqual(CompilerFlagsParser.parse(""), [])
    }

    func testParseOnlyWarningFlag() {
        XCTAssertEqual(CompilerFlagsParser.parse("-w"), [])
    }

    func testParseSQLCipherFullFlags() {
        let raw = """
        -w
        -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1
        -DSQLITE_TEMP_STORE=3
        -DSQLITE_EXTRA_INIT=sqlcipher_extra_init
        -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown
        -DSQLCIPHER_CRYPTO_CC -DSQLITE_LOCKING_STYLE=1 -DNDEBUG
        -DSQLITE_THREADSAFE=1
        -DSQLITE_DEFAULT_SYNCHRONOUS=3
        """
        let result = CompilerFlagsParser.parse(raw)
        XCTAssertTrue(result.contains(.define("SQLITE_HAS_CODEC")))
        XCTAssertTrue(result.contains(.defineWithValue("HAVE_USLEEP", "1")))
        XCTAssertTrue(result.contains(.defineWithValue("SQLITE_TEMP_STORE", "3")))
        XCTAssertTrue(result.contains(.define("NDEBUG")))
        XCTAssertTrue(result.contains(.define("SQLCIPHER_CRYPTO_CC")))
        // -w must be excluded
        XCTAssertFalse(result.contains(.define("w")))
    }

    // MARK: - merge()

    func testMergeDeduplicates() {
        let firstSet: [CCompilerSetting] = [.define("SQLITE_HAS_CODEC"), .define("NDEBUG")]
        let secondSet: [CCompilerSetting] = [.define("SQLITE_HAS_CODEC"), .define("HAVE_USLEEP")]
        let result = CompilerFlagsParser.merge([firstSet, secondSet])
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains(.define("SQLITE_HAS_CODEC")))
        XCTAssertTrue(result.contains(.define("NDEBUG")))
        XCTAssertTrue(result.contains(.define("HAVE_USLEEP")))
    }

    func testMergePreservesOrder() {
        let firstSet: [CCompilerSetting] = [.define("A"), .define("B")]
        let secondSet: [CCompilerSetting] = [.define("C"), .define("A")]
        let result = CompilerFlagsParser.merge([firstSet, secondSet])
        XCTAssertEqual(result, [.define("A"), .define("B"), .define("C")])
    }

    func testMergeEmpty() {
        XCTAssertEqual(CompilerFlagsParser.merge([[], []]), [])
    }

    // MARK: - CCompilerSetting.spmCode

    func testSpmCodeForDefine() {
        XCTAssertEqual(CCompilerSetting.define("SQLITE_HAS_CODEC").spmCode, ".define(\"SQLITE_HAS_CODEC\")")
    }

    func testSpmCodeForDefineWithValue() {
        XCTAssertEqual(
            CCompilerSetting.defineWithValue("SQLITE_TEMP_STORE", "3").spmCode,
            ".define(\"SQLITE_TEMP_STORE\", to: \"3\")"
        )
    }

    func testSpmCodeForHeaderSearchPath() {
        XCTAssertEqual(
            CCompilerSetting.headerSearchPath("common").spmCode,
            ".headerSearchPath(\"common\")"
        )
    }

    // MARK: - LinkerSetting.spmCode

    func testLinkerSettingSpmCodeLinkedFramework() {
        XCTAssertEqual(LinkerSetting.linkedFramework("Security").spmCode, ".linkedFramework(\"Security\")")
    }

    func testLinkerSettingSpmCodeLinkedLibrary() {
        XCTAssertEqual(LinkerSetting.linkedLibrary("z").spmCode, ".linkedLibrary(\"z\")")
    }
}
