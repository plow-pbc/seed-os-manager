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

final class CLIOsaTests: XCTestCase {
    /// A spawner that simulates a successful AppleScript execution by
    /// writing the expected handoff files into `reqDir` before returning.
    final class FakeSpawner: Spawner {
        var capturedScript: String?
        var capturedMeta: String?
        let stdout: String
        let stderr: String
        let exit: Int32

        init(stdout: String = "2", stderr: String = "", exit: Int32 = 0) {
            self.stdout = stdout
            self.stderr = stderr
            self.exit = exit
        }

        func spawn(reqDir: URL) throws -> SpawnResult {
            capturedScript = try String(contentsOf: reqDir.appendingPathComponent("in.scpt"))
            capturedMeta = try String(contentsOf: reqDir.appendingPathComponent("meta.json"))
            try stdout.write(to: reqDir.appendingPathComponent("out"), atomically: true, encoding: .utf8)
            try stderr.write(to: reqDir.appendingPathComponent("err"), atomically: true, encoding: .utf8)
            try "\(exit)\n".write(to: reqDir.appendingPathComponent("exit"), atomically: true, encoding: .utf8)
            return SpawnResult(exitCode: 0, stdout: "", stderr: "")
        }
    }

    func testOsaInlineScriptIsForwardedToSpawner() {
        let spawner = FakeSpawner(stdout: "hello", exit: 0)
        let result = CLIMode.parseAndExecute(args: ["osa", "tell app \"Foo\" to bar"], spawner: spawner)
        XCTAssertEqual(spawner.capturedScript, "tell app \"Foo\" to bar")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello")
    }

    func testOsaPropagatesNonZeroExit() {
        let spawner = FakeSpawner(stderr: "AppleScript error: ...", exit: 1)
        let result = CLIMode.parseAndExecute(args: ["osa", "garbage"], spawner: spawner)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("AppleScript error"))
    }

    func testOsaDefaultTimeoutIsThirty() {
        let spawner = FakeSpawner()
        _ = CLIMode.parseAndExecute(args: ["osa", "x"], spawner: spawner)
        XCTAssertTrue(spawner.capturedMeta?.contains("\"timeout\":30") ?? false)
    }

    func testOsaRespectsCustomTimeout() {
        let spawner = FakeSpawner()
        _ = CLIMode.parseAndExecute(args: ["osa", "--timeout", "5", "x"], spawner: spawner)
        XCTAssertTrue(spawner.capturedMeta?.contains("\"timeout\":5") ?? false)
    }

    func testOsaFromFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("seedctl-test-\(UUID()).scpt")
        try "say hi".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let spawner = FakeSpawner()
        _ = CLIMode.parseAndExecute(args: ["osa", "--file", tmp.path], spawner: spawner)
        XCTAssertEqual(spawner.capturedScript, "say hi")
    }
}
