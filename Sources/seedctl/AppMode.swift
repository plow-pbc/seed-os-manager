import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum AppMode {
    static func run(args: [String]) -> Int32 {
        // argv shape from `open -W -a … --args osa --req <dir>` is exactly
        // ["osa", "--req", "<path>"].
        guard args.count == 3, args[0] == "osa", args[1] == "--req" else {
            // Fail loudly. Not user-facing.
            return 2
        }
        let reqDir = URL(fileURLWithPath: args[2])
        return execute(reqDir: reqDir)
    }

    static func execute(reqDir: URL) -> Int32 {
        let scriptURL = reqDir.appendingPathComponent("in.scpt")
        let metaURL = reqDir.appendingPathComponent("meta.json")
        let outURL = reqDir.appendingPathComponent("out")
        let errURL = reqDir.appendingPathComponent("err")
        let exitURL = reqDir.appendingPathComponent("exit")

        let scriptSource: String
        do {
            scriptSource = try String(contentsOf: scriptURL, encoding: .utf8)
        } catch {
            try? "could not read in.scpt: \(error)\n".write(to: errURL, atomically: true, encoding: .utf8)
            try? "1\n".write(to: exitURL, atomically: true, encoding: .utf8)
            return 0
        }

        let timeout = readTimeout(from: metaURL)

        // Run NSAppleScript on a background queue so we can time it out.
        let scriptResult = runWithTimeout(seconds: timeout) { () -> (out: String, err: String, exit: Int32) in
            guard let script = NSAppleScript(source: scriptSource) else {
                return ("", "could not parse AppleScript source\n", 1)
            }
            var errInfo: NSDictionary? = nil
            let descriptor = script.executeAndReturnError(&errInfo)
            if let e = errInfo {
                let msg = e[NSAppleScript.errorMessage] as? String ?? "unknown error"
                let line = e[NSAppleScript.errorAppName] as? String ?? ""
                return ("", "AppleScript error: \(msg) [\(line)]\n", 1)
            }
            return (descriptor.stringValue ?? "", "", 0)
        }

        let (out, err, code): (String, String, Int32)
        switch scriptResult {
        case .completed(let r):
            (out, err, code) = r
        case .timedOut:
            (out, err, code) = ("", "timeout exceeded (\(timeout)s)\n", 4)
        }

        try? out.write(to: outURL, atomically: true, encoding: .utf8)
        try? err.write(to: errURL, atomically: true, encoding: .utf8)
        try? "\(code)\n".write(to: exitURL, atomically: true, encoding: .utf8)
        appendToAuditLog(script: scriptSource, exit: code, errSummary: err)
        return 0
    }

    private static func appendToAuditLog(script: String, exit: Int32, errSummary: String) {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Seed OS Manager")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logURL = logDir.appendingPathComponent("seedctl.log")

        // Rotate at 10 MB.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attrs[.size] as? Int64, size > 10 * 1024 * 1024 {
            let rotated = logDir.appendingPathComponent("seedctl.log.1")
            try? FileManager.default.removeItem(at: rotated)
            try? FileManager.default.moveItem(at: logURL, to: rotated)
        }

        let ts = ISO8601DateFormatter().string(from: Date())
        let ppid = getppid()
        let entry = """
        --- \(ts) ppid=\(ppid) exit=\(exit) ---
        \(script)
        \(errSummary.isEmpty ? "" : "stderr: " + errSummary)

        """
        if let data = entry.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    private static func readTimeout(from url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = json["timeout"] as? Int else {
            return 30
        }
        return t
    }

    private enum TimeoutResult<T> {
        case completed(T)
        case timedOut
    }

    private static func runWithTimeout<T>(seconds: Int, block: @escaping () -> T) -> TimeoutResult<T> {
        let queue = DispatchQueue(label: "seedctl.osa")
        var result: T? = nil
        let group = DispatchGroup()
        group.enter()
        queue.async {
            result = block()
            group.leave()
        }
        if group.wait(timeout: .now() + .seconds(seconds)) == .timedOut {
            return .timedOut
        }
        return .completed(result!)
    }
}
