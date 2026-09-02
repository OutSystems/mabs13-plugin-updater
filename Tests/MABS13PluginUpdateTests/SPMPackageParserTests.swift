import XCTest
@testable import MABS13PluginUpdate

final class SPMPackageParserTests: XCTestCase {
    private var logger: Logger!
    private var parser: SPMPackageParser!
    
    override func setUp() {
        super.setUp()
        logger = Logger(verbose: false)
        parser = SPMPackageParser(logger: logger)
    }
    
    func testParseMultipleLibraryProducts() {
        let firebaseLikePackage = """
        // swift-tools-version:5.9
        import PackageDescription
        
        let package = Package(
            name: "Firebase",
            products: [
                .library(name: "Firebase", targets: ["Firebase"]),
                .library(name: "FirebaseMessaging", targets: ["FirebaseMessaging"]),
                .library(name: "FirebaseAuth", targets: ["FirebaseAuth"])
            ],
            targets: []
        )
        """

        let parsed = parser.parsePackageSwift(firebaseLikePackage)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "Firebase")
        let productNames = parsed?.products.map(\.name) ?? []
        XCTAssertTrue(productNames.contains("Firebase"))
        XCTAssertTrue(productNames.contains("FirebaseMessaging"))
        XCTAssertTrue(productNames.contains("FirebaseAuth"))
    }

    func testIsLibraryPackage() {
        let libraryPackage = """
        products: [
            .library(name: "MyLibrary", targets: ["MyLibrary"])
        ]
        """
        
        let executablePackage = """
        products: [
            .executable(name: "MyExecutable", targets: ["MyExecutable"])
        ]
        """
        
        XCTAssertTrue(parser.isLibraryPackage(libraryPackage))
        XCTAssertFalse(parser.isLibraryPackage(executablePackage))
    }
}
