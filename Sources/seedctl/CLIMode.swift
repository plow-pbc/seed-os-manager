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
            return runOsa(args: Array(args.dropFirst()), spawner: spawner)
        default:
            return ExecuteResult(exitCode: 2, stdout: "", stderr: "unknown verb: \(first)\n")
        }
    }

    private static func runOsa(args: [String], spawner: Spawner) -> ExecuteResult {
        var script: String? = nil
        var timeout: Int = 30
        var cwd: String = "/"
        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "--file":
                guard i + 1 < args.count else {
                    return ExecuteResult(exitCode: 2, stdout: "", stderr: "--file needs a path\n")
                }
                do {
                    script = try String(contentsOfFile: args[i + 1], encoding: .utf8)
                } catch {
                    return ExecuteResult(exitCode: 2, stdout: "", stderr: "cannot read \(args[i + 1]): \(error)\n")
                }
                i += 2
            case "--stdin":
                script = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
                i += 1
            case "--timeout":
                guard i + 1 < args.count, let t = Int(args[i + 1]) else {
                    return ExecuteResult(exitCode: 2, stdout: "", stderr: "--timeout needs an integer\n")
                }
                timeout = t
                i += 2
            case "--cwd":
                guard i + 1 < args.count else {
                    return ExecuteResult(exitCode: 2, stdout: "", stderr: "--cwd needs a path\n")
                }
                cwd = args[i + 1]
                i += 2
            case "--quiet":
                // Reserved; handled at output-write time. Tests do not exercise this.
                i += 1
            default:
                // Positional script body.
                if script == nil {
                    script = a
                } else {
                    return ExecuteResult(exitCode: 2, stdout: "", stderr: "unexpected argument: \(a)\n")
                }
                i += 1
            }
        }

        guard let scriptBody = script else {
            return ExecuteResult(exitCode: 2, stdout: "", stderr: "osa: no script provided\n")
        }

        let reqDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("seedctl.\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: reqDir, withIntermediateDirectories: true)
            try scriptBody.write(to: reqDir.appendingPathComponent("in.scpt"), atomically: true, encoding: .utf8)
            let meta = #"{"timeout":\#(timeout),"cwd":"\#(cwd)"}"#
            try meta.write(to: reqDir.appendingPathComponent("meta.json"), atomically: true, encoding: .utf8)
            _ = try spawner.spawn(reqDir: reqDir)
            let out = (try? String(contentsOf: reqDir.appendingPathComponent("out"))) ?? ""
            let err = (try? String(contentsOf: reqDir.appendingPathComponent("err"))) ?? ""
            let exitStr = (try? String(contentsOf: reqDir.appendingPathComponent("exit"))) ?? "1\n"
            let exitCode = Int32(exitStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            try? FileManager.default.removeItem(at: reqDir)
            return ExecuteResult(exitCode: exitCode, stdout: out, stderr: err)
        } catch {
            try? FileManager.default.removeItem(at: reqDir)
            return ExecuteResult(exitCode: 3, stdout: "", stderr: "spawn failed: \(error)\n")
        }
    }
}

// Real spawner used in production. Implementation lands in Task C.3.
struct OpenSpawner: Spawner {
    func spawn(reqDir: URL) throws -> SpawnResult {
        fatalError("OpenSpawner.spawn not yet implemented")
    }
}
