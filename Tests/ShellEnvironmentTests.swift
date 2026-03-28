import XCTest
@testable import Clawd

final class ShellEnvironmentTests: XCTestCase {

    func testCLAUDECODEStripped() {
        let env = ShellEnvironment.processEnvironment()
        XCTAssertNil(env["CLAUDECODE"], "CLAUDECODE env var should be stripped")
    }

    func testHOMEIsSet() {
        let env = ShellEnvironment.processEnvironment()
        XCTAssertNotNil(env["HOME"])
        XCTAssertFalse(env["HOME"]!.isEmpty)
    }

    func testPATHIsSet() {
        let env = ShellEnvironment.processEnvironment()
        XCTAssertNotNil(env["PATH"])
        XCTAssertFalse(env["PATH"]!.isEmpty)
    }

    func testPATHContainsLocalBin() {
        let env = ShellEnvironment.processEnvironment()
        let path = env["PATH"] ?? ""
        XCTAssertTrue(path.contains(".local/bin"), "PATH should include ~/.local/bin")
    }

    func testLANGIsSet() {
        let env = ShellEnvironment.processEnvironment()
        XCTAssertNotNil(env["LANG"])
    }
}
