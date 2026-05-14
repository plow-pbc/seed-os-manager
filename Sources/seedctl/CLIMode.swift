import Foundation

enum CLIMode {
    struct ExecuteResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    static let version = "seedctl 0.1.0"

    static let helpText = """
    seedctl — TCC-attributable AppleScript runner.

    Usage:
      seedctl --version
      seedctl --help
      seedctl osa <script>          Run AppleScript inline
      seedctl osa --file <path>     Run AppleScript from file
      seedctl osa --stdin           Run AppleScript from stdin

    Options:
      --timeout <sec>   Kill script if it exceeds this (default 30).
      --quiet           Suppress helper-side stderr.
      --cwd <path>      Working directory for the .app process.
    """

    static func run(args: [String]) -> Int32 {
        let result = parseAndExecute(args: args, spawner: OpenSpawner())
        FileHandle.standardOutput.write(Data(result.stdout.utf8))
        FileHandle.standardError.write(Data(result.stderr.utf8))
        return result.exitCode
    }

    static func parseAndExecute(args: [String], spawner: Spawner) -> ExecuteResult {
        guard let first = args.first else {
            return ExecuteResult(exitCode: 2, stdout: "", stderr: "usage: seedctl --help\n")
        }
        switch first {
        case "--version":
            return ExecuteResult(exitCode: 0, stdout: version + "\n", stderr: "")
        case "--help":
            return ExecuteResult(exitCode: 0, stdout: helpText + "\n", stderr: "")
        case "osa":
            // Implemented in Task C.3
            return ExecuteResult(exitCode: 2, stdout: "", stderr: "osa: not yet implemented\n")
        default:
            return ExecuteResult(exitCode: 2, stdout: "", stderr: "unknown verb: \(first)\n")
        }
    }
}

// Real spawner used in production. Implementation lands in Task C.3.
struct OpenSpawner: Spawner {
    func spawn(reqDir: URL) throws -> SpawnResult {
        fatalError("OpenSpawner.spawn not yet implemented")
    }
}
