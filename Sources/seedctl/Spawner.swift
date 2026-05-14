import Foundation

struct SpawnResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol Spawner {
    func spawn(reqDir: URL) throws -> SpawnResult
}
