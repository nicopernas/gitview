import AppKit
import GitViewCore

let env = ProcessInfo.processInfo.environment
let foreground = env["GITVIEW_FOREGROUND"] != nil
let detached = env["GITVIEW_DETACHED"] != nil
let logFile = Log.setup(echo: foreground)
let args = Array(CommandLine.arguments.dropFirst())

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let top = Git.run(["rev-parse", "--show-toplevel"], in: cwd)
guard top.status == 0 else {
    FileHandle.standardError.write(Data(top.stderr.utf8))
    exit(1)
}
let repo = URL(fileURLWithPath: top.stdout.trimmingCharacters(in: .whitespacesAndNewlines))

if !foreground && !detached {
    exit(detach(logFile: logFile) ? 0 : 1)
}

Log.info("start repo=\(repo.path) args=\(args)")
NSSetUncaughtExceptionHandler { e in
    Log.error("uncaught exception: \(e)\n\(e.callStackSymbols.joined(separator: "\n"))")
}
let app = NSApplication.shared
let delegate = AppDelegate(repo: repo, args: args)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

/// Starts a copy of this binary in its own session, so the terminal is free.
func detach(logFile: URL) -> Bool {
    guard let exe = Bundle.main.executablePath else { return false }

    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))

    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 1, logFile.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
    posix_spawn_file_actions_adddup2(&actions, 1, 2)

    let argv: [UnsafeMutablePointer<CChar>?] = ([exe] + args).map { strdup($0) } + [nil]
    let envStrings = env.map { "\($0.key)=\($0.value)" } + ["GITVIEW_DETACHED=1"]
    let envp: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) } + [nil]
    defer { (argv + envp).forEach { free($0) } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, exe, &actions, &attr, argv, envp)
    guard rc == 0 else {
        let msg = "gitview: failed to start: \(String(cString: strerror(rc)))"
        Log.error(msg)
        FileHandle.standardError.write(Data((msg + "\n").utf8))
        return false
    }
    Log.info("detached as pid \(pid)")
    return true
}
