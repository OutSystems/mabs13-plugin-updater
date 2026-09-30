import XCTest
@testable import MABS13PluginUpdate

final class IOSPlatformVersionTests: XCTestCase {
    func testToolchainMinimumIsIOS15() {
        XCTAssertEqual(IOSPlatformVersion.toolchainMinimum, IOSPlatformVersion(major: 15, minor: 0))
        XCTAssertEqual(IOSPlatformVersion.toolchainMinimum.spmCode, ".iOS(.v15)")
    }

    func testMABS13AppDeploymentTargetIsIOS16AndAboveTheToolchainFloor() {
        XCTAssertEqual(IOSPlatformVersion.mabs13AppDeploymentTarget, IOSPlatformVersion(major: 16, minor: 0))
        XCTAssertGreaterThan(IOSPlatformVersion.mabs13AppDeploymentTarget, .toolchainMinimum)
    }

    func testParsePlainVersions() {
        XCTAssertEqual(IOSPlatformVersion("15"), IOSPlatformVersion(major: 15))
        XCTAssertEqual(IOSPlatformVersion("15.0"), IOSPlatformVersion(major: 15, minor: 0))
        XCTAssertEqual(IOSPlatformVersion("16.4"), IOSPlatformVersion(major: 16, minor: 4))
        XCTAssertEqual(IOSPlatformVersion("  17.2  "), IOSPlatformVersion(major: 17, minor: 2))
    }

    func testParseSPMLiterals() {
        XCTAssertEqual(IOSPlatformVersion(".v15"), IOSPlatformVersion(major: 15))
        XCTAssertEqual(IOSPlatformVersion("v13"), IOSPlatformVersion(major: 13))
        XCTAssertEqual(IOSPlatformVersion("\"16.4\""), IOSPlatformVersion(major: 16, minor: 4))
    }

    func testParseRejectsNonVersions() {
        XCTAssertNil(IOSPlatformVersion(""))
        XCTAssertNil(IOSPlatformVersion("latest"))
        XCTAssertNil(IOSPlatformVersion("15."))
        XCTAssertNil(IOSPlatformVersion("15.0.1"))
        XCTAssertNil(IOSPlatformVersion("0"))
        XCTAssertNil(IOSPlatformVersion(".vNext"))
    }

    func testSPMCodeUsesEnumCaseForWholeVersions() {
        XCTAssertEqual(IOSPlatformVersion(major: 13).spmCode, ".iOS(.v13)")
        XCTAssertEqual(IOSPlatformVersion(major: 17).spmCode, ".iOS(.v17)")
    }

    func testSPMCodeUsesStringFormWhenNoEnumCaseApplies() {
        // Minor versions have no .vNN case
        XCTAssertEqual(IOSPlatformVersion(major: 16, minor: 4).spmCode, ".iOS(\"16.4\")")
        // Versions newer than the cases PackageDescription 5.9 defines
        XCTAssertEqual(IOSPlatformVersion(major: 18).spmCode, ".iOS(\"18.0\")")
    }

    func testComparison() {
        XCTAssertLessThan(IOSPlatformVersion(major: 14), IOSPlatformVersion(major: 15))
        XCTAssertLessThan(IOSPlatformVersion(major: 15), IOSPlatformVersion(major: 15, minor: 4))
        XCTAssertGreaterThan(IOSPlatformVersion(major: 16), IOSPlatformVersion(major: 15, minor: 9))
        XCTAssertEqual(
            [IOSPlatformVersion(major: 15), IOSPlatformVersion(major: 16, minor: 4)].max(),
            IOSPlatformVersion(major: 16, minor: 4)
        )
    }

    func testDescription() {
        XCTAssertEqual(IOSPlatformVersion(major: 15).description, "15.0")
        XCTAssertEqual(IOSPlatformVersion(major: 16, minor: 4).description, "16.4")
    }
}
