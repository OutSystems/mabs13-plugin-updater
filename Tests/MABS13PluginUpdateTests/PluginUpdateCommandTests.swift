import ArgumentParser
import XCTest
@testable import MABS13PluginUpdate

final class PluginUpdateCommandTests: XCTestCase {
    func testMinIosDefaultsToNil() throws {
        let command = try PluginUpdateCommand.parse([])

        XCTAssertNil(command.minIos)
    }

    func testMinIosOptionIsParsed() throws {
        let command = try PluginUpdateCommand.parse(["--min-ios", "16.4"])

        XCTAssertEqual(command.minIos, "16.4")
        XCTAssertEqual(try IOSPlatformVersion(XCTUnwrap(command.minIos)), IOSPlatformVersion(major: 16, minor: 4))
    }

    func testInvalidMinIosIsRejectedDuringValidation() {
        XCTAssertThrowsError(try PluginUpdateCommand.parse(["--min-ios", "banana"]))
    }

    func testOptionsCarryNilMinimumIOSVersionByDefault() {
        let options = ConversionOptions()

        XCTAssertNil(options.minimumIOSVersion)
    }
}
