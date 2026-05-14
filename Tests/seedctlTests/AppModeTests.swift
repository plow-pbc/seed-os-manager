import XCTest
@testable import seedctl

final class AppModeTests: XCTestCase {
    func testArithmeticScriptReturnsTwo() throws {
        let req = try makeRequest(script: "return 1 + 1", timeout: 30)
        let exit = AppMode.execute(reqDir: req)
        XCTAssertEqual(exit, 0)
        XCTAssertEqual(try contents(of: req, file: "out"), "2")
        XCTAssertEqual(try contents(of: req, file: "err"), "")
        XCTAssertEqual(try contents(of: req, file: "exit").trimmingCharacters(in: .whitespacesAndNewlines), "0")
    }

    func testSyntaxErrorReturnsOneAndPopulatesErr() throws {
        let req = try makeRequest(script: "this is not applescript", timeout: 30)
        let exit = AppMode.execute(reqDir: req)
        XCTAssertEqual(exit, 0, "AppMode itself exits 0; the script's exit code is in the file")
        XCTAssertEqual(try contents(of: req, file: "exit").trimmingCharacters(in: .whitespacesAndNewlines), "1")
        XCTAssertTrue(try contents(of: req, file: "err").lowercased().contains("error"))
    }

    func testTimeoutKillsLongScript() throws {
        let req = try makeRequest(script: "delay 5", timeout: 1)
        let started = Date()
        let exit = AppMode.execute(reqDir: req)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(exit, 0)
        XCTAssertLessThan(elapsed, 3.0, "should have killed before delay completed")
        XCTAssertEqual(try contents(of: req, file: "exit").trimmingCharacters(in: .whitespacesAndNewlines), "4")
    }

    func testWritesAuditLogEntry() throws {
        let req = try makeRequest(script: "return 7 * 6", timeout: 30)
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Seed OS Manager/seedctl.log")

        let before: Int64 = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? Int64) ?? 0
        _ = AppMode.execute(reqDir: req)
        let after: Int64 = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? Int64) ?? 0

        XCTAssertGreaterThan(after, before)
        let log = try String(contentsOf: logURL)
        XCTAssertTrue(log.contains("return 7 * 6"))
        XCTAssertTrue(log.contains("exit=0"))
    }

    // Helpers
    private func makeRequest(script: String, timeout: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("seedctl-test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try script.write(to: dir.appendingPathComponent("in.scpt"), atomically: true, encoding: .utf8)
        try #"{"timeout":\#(timeout),"cwd":"/"}"#.write(to: dir.appendingPathComponent("meta.json"), atomically: true, encoding: .utf8)
        return dir
    }

    private func contents(of dir: URL, file: String) throws -> String {
        return try String(contentsOf: dir.appendingPathComponent(file))
    }
}
