import Foundation

enum Mode: Equatable {
    case cli
    case app

    static func from(parentPID: pid_t) -> Mode {
        return parentPID == 1 ? .app : .cli
    }
}

let mode = Mode.from(parentPID: getppid())
let args = Array(CommandLine.arguments.dropFirst())

switch mode {
case .cli:
    exit(CLIMode.run(args: args))
case .app:
    exit(AppMode.run(args: args))
}
