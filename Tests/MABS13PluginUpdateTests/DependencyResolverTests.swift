import XCTest
@testable import MABS13PluginUpdate

final class DependencyResolverTests: XCTestCase {
    private var logger: Logger!
    private var resolver: DependencyResolver!
    
    override func setUp() {
        super.setUp()
        logger = Logger(verbose: false)
        resolver = DependencyResolver(logger: logger)
    }
    
    func testPodSpecResolverCreation() {
        let podResolver = PodSpecResolver(logger: logger)
        XCTAssertNotNil(podResolver)
    }
    
    func testGitRepositoryCheckerCreation() {
        let gitChecker = GitRepositoryChecker(logger: logger)
        XCTAssertNotNil(gitChecker)
    }
    
    func testSPMPackageParserCreation() {
        let spmParser = SPMPackageParser(logger: logger)
        XCTAssertNotNil(spmParser)
    }
    
    func testDependencyResolverCreation() {
        XCTAssertNotNil(resolver)
    }
    
    func testPodSpecInfoEquality() {
        let info1 = PodSpecInfo(
            name: "TestPod",
            version: "1.0.0",
            sourceType: .git(url: "https://github.com/test/pod.git", tag: "1.0.0", branch: nil)
        )
        
        let info2 = PodSpecInfo(
            name: "TestPod",
            version: "1.0.0",
            sourceType: .git(url: "https://github.com/test/pod.git", tag: "1.0.0", branch: nil)
        )
        
        let info3 = PodSpecInfo(
            name: "DifferentPod",
            version: "1.0.0",
            sourceType: .git(url: "https://github.com/test/pod.git", tag: "1.0.0", branch: nil)
        )
        
        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
    
    func testSPMRequirementDescription() {
        let exactReq = SPMRequirement.exact("1.0.0")
        XCTAssertEqual(exactReq.description, "exact: \"1.0.0\"")
        
        let fromReq = SPMRequirement.from("1.0.0")
        XCTAssertEqual(fromReq.description, "from: \"1.0.0\"")
        
        let branchReq = SPMRequirement.branch("main")
        XCTAssertEqual(branchReq.description, "branch: \"main\"")
        
        let tagReq = SPMRequirement.tag("v1.0.0")
        XCTAssertEqual(tagReq.description, "exact: \"v1.0.0\"")
    }
    
    func testSPMDependencyEquality() {
        let dep1 = SPMDependency(
            url: "https://github.com/test/package.git",
            requirement: .from("1.0.0"),
            productName: "TestPackage"
        )
        
        let dep2 = SPMDependency(
            url: "https://github.com/test/package.git",
            requirement: .from("1.0.0"),
            productName: "TestPackage"
        )
        
        let dep3 = SPMDependency(
            url: "https://github.com/other/package.git",
            requirement: .from("1.0.0"),
            productName: "TestPackage"
        )
        
        XCTAssertEqual(dep1, dep2)
        XCTAssertNotEqual(dep1, dep3)
    }
    
    func testResolvedDependencyStatus() {
        let podDep = PodDependency(name: "TestPod", spec: "1.0.0")
        let spmDep = SPMDependency(url: "https://github.com/test/package.git", requirement: .from("1.0.0"))
        
        let resolvedSuccess = ResolvedDependency(
            originalPod: podDep,
            spmDependency: spmDep,
            status: .resolved
        )
        
        let resolvedFailure = ResolvedDependency(
            originalPod: podDep,
            spmDependency: nil,
            status: .podSpecNotFound
        )
        
        XCTAssertTrue(resolvedSuccess.isResolved)
        XCTAssertFalse(resolvedFailure.isResolved)
        XCTAssertTrue(resolvedSuccess.status.isSuccess)
        XCTAssertFalse(resolvedFailure.status.isSuccess)
    }
    
    func testConvertSpecToSPMRequirement() {
        // Test ~> pattern (compatible version)
        let compatibleReq = PodSpecResolver.convertSpecToSPMRequirement("~> 4.0")
        XCTAssertEqual(compatibleReq, .upToNextMajor("4.0"))
        
        // Test >= pattern
        let greaterEqualReq = PodSpecResolver.convertSpecToSPMRequirement(">= 1.0")
        XCTAssertEqual(greaterEqualReq, .from("1.0"))
        
        // Test = pattern (exact)
        let exactReq = PodSpecResolver.convertSpecToSPMRequirement("= 2.0.0")
        XCTAssertEqual(exactReq, .exact("2.0.0"))
        
        // Test > pattern
        let greaterReq = PodSpecResolver.convertSpecToSPMRequirement("> 1.5")
        XCTAssertEqual(greaterReq, .from("1.5"))
        
        // Test plain version
        let plainReq = PodSpecResolver.convertSpecToSPMRequirement("3.0.0")
        XCTAssertEqual(plainReq, .exact("3.0.0"))
        
        // Test with source tag preference
        let tagReq = PodSpecResolver.convertSpecToSPMRequirement("~> 4.0", sourceTag: "v4.0.1")
        XCTAssertEqual(tagReq, .tag("v4.0.1"))
    }
}
