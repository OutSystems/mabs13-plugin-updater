import XCTest
@testable import cdv2spm

final class PodSpecVersionConversionTests: XCTestCase {
    func testExactVersionConversion() {
        // Test exact versions
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("1.0.0"), .exact("1.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("= 1.0.0"), .exact("1.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("=1.0.0"), .exact("1.0.0"))
    }
    
    func testGreaterThanVersionConversion() {
        // Test greater than versions
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("> 1.0.0"), .from("1.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement(">= 1.0.0"), .from("1.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement(">1.0.0"), .from("1.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement(">=1.0.0"), .from("1.0.0"))
    }
    
    func testPessimisticVersionConversion() {
        // Test pessimistic constraints (~>)
        
        // ~> 2.1 means >= 2.1.0 and < 3.0.0 (upToNextMajor)
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~> 2.1"), .upToNextMajor("2.1"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~>2.1"), .upToNextMajor("2.1"))
        
        // ~> 2.1.0 means >= 2.1.0 and < 2.2.0 (upToNextMinor)
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~> 2.1.0"), .upToNextMinor("2.1.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~> 2.1.3"), .upToNextMinor("2.1.3"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~>2.1.3"), .upToNextMinor("2.1.3"))
        
        // Test with more than 3 components (should still use upToNextMinor)
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~> 2.1.3.4"), .upToNextMinor("2.1.3.4"))
    }
    
    func testLessThanVersionConversion() {
        // Test less than versions (SPM limitations - using upToNextMajor as closest equivalent)
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("< 2.0.0"), .upToNextMajor("2.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("<= 2.0.0"), .upToNextMajor("2.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("<2.0.0"), .upToNextMajor("2.0.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("<=2.0.0"), .upToNextMajor("2.0.0"))
    }
    
    func testSourceTagPrecedence() {
        // Test that source tag takes precedence over version spec
        XCTAssertEqual(
            PodSpecResolver.convertSpecToSPMRequirement("~> 1.0.0", sourceTag: "v1.2.3"),
            .tag("v1.2.3")
        )
    }
    
    func testWhitespaceHandling() {
        // Test whitespace handling
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("  ~>  2.1.0  "), .upToNextMinor("2.1.0"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("\t>=\t1.0.0\t"), .from("1.0.0"))
    }
    
    func testEmptyAndInvalidSpecs() {
        // Test empty and edge cases
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement(""), .exact(""))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("   "), .exact(""))
    }
    
    func testComplexVersionNumbers() {
        // Test complex version numbers (with beta, alpha, etc.)
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("~> 1.0.0-beta.1"), .upToNextMinor("1.0.0-beta.1"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement(">= 2.0.0-alpha"), .from("2.0.0-alpha"))
        XCTAssertEqual(PodSpecResolver.convertSpecToSPMRequirement("= 1.0.0-rc.1"), .exact("1.0.0-rc.1"))
    }

    // MARK: - concreteVersion(from:)

    /// `pod spec cat --version` requires a concrete published version, not an operator form.
    /// These cover the operator-stripping that fixes the "Pod spec not found" false negatives
    /// for specs like `~> 2.0.0` and `= 8.1.5`.
    func testConcreteVersionStripsOperators() {
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "~> 2.0.0"), "2.0.0")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "= 8.1.5"), "8.1.5")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "=8.1.5"), "8.1.5")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: ">= 1.2"), "1.2")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "> 1.0.0"), "1.0.0")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "<= 3.0"), "3.0")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "< 4.0.0"), "4.0.0")
    }

    func testConcreteVersionPassesThroughBareVersions() {
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "1.0.0"), "1.0.0")
        XCTAssertEqual(PodSpecResolver.concreteVersion(from: "  2.1.3  "), "2.1.3")
    }

    func testConcreteVersionReturnsNilWhenNoConcreteVersion() {
        XCTAssertNil(PodSpecResolver.concreteVersion(from: nil))
        XCTAssertNil(PodSpecResolver.concreteVersion(from: ""))
        XCTAssertNil(PodSpecResolver.concreteVersion(from: "   "))
    }
}
