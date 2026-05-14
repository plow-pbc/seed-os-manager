import XCTest
@testable import seedctl

final class ModeDispatchTests: XCTestCase {
    func testDispatchesToAppModeWhenParentIsLaunchd() {
        XCTAssertEqual(Mode.from(parentPID: 1), .app)
    }

    func testDispatchesToCLIModeWhenParentIsAnythingElse() {
        XCTAssertEqual(Mode.from(parentPID: 12345), .cli)
        XCTAssertEqual(Mode.from(parentPID: 2), .cli)
    }
}
