import XCTest
@testable import seedctl

final class CLIModeTests: XCTestCase {
    func testVersionPrintsAndExitsZero() throws {
        let result = CLIMode.parseAndExecute(args: ["--version"], spawner: NoopSpawner())
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.hasPrefix("seedctl "))
    }

    func testHelpPrintsAndExitsZero() throws {
        let result = CLIMode.parseAndExecute(args: ["--help"], spawner: NoopSpawner())
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("seedctl osa"))
    }

    func testUnknownVerbExitsTwo() throws {
        let result = CLIMode.parseAndExecute(args: ["banana"], spawner: NoopSpawner())
        XCTAssertEqual(result.exitCode, 2)
        XCTAssertTrue(result.stderr.contains("unknown"))
    }
}

struct NoopSpawner: Spawner {
    func spawn(reqDir: URL) throws -> SpawnResult {
        return SpawnResult(exitCode: 0, stdout: "", stderr: "")
    }
}
