import AppKit
import GitViewCore

let env = ProcessInfo.processInfo.environment
let args = Array(CommandLine.arguments.dropFirst())
/// Set only on the app process that `launchApp` asks macOS to start.
let isApp = env["GITVIEW_CWD"] != nil
let appBundle = Bundle.main.executableURL.flatMap(AppBundle.locate)
/// Outside an .app (e.g. a dev build) there's nothing to launch, so run in the terminal.
let runHere = isApp || env["GITVIEW_FOREGROUND"] != nil || appBundle == nil
let logFile = Log.setup(echo: runHere && !isApp)
if isApp { redirectOutput(to: logFile) }

// Apps started by macOS run in "/", so the launcher passes its working directory.
let cwd = URL(fileURLWithPath: env["GITVIEW_CWD"] ?? FileManager.default.currentDirectoryPath)
let top = Git.run(["rev-parse", "--show-toplevel"], in: cwd)
guard top.status == 0 else {
    FileHandle.standardError.write(Data(top.stderr.utf8))
    exit(1)
}
let repo = URL(fileURLWithPath: top.stdout.trimmingCharacters(in: .whitespacesAndNewlines))

if !runHere, let appBundle {
    exit(launchApp(appBundle) ? 0 : 1)
}

Log.info("start repo=\(repo.path) cwd=\(cwd.path) args=\(args)")
NSSetUncaughtExceptionHandler { e in
    Log.error("uncaught exception: \(e)\n\(e.callStackSymbols.joined(separator: "\n"))")
}
let app = NSApplication.shared
let delegate = AppDelegate(repo: repo, workDir: cwd, args: args)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

/// Asks macOS to start a new instance of the app. Started this way it gets its own
/// process group; started from the shell, macOS thinks it keeps running after quit.
func launchApp(_ bundle: URL) -> Bool {
    let config = NSWorkspace.OpenConfiguration()
    config.arguments = args
    config.environment = env.merging(["GITVIEW_CWD": cwd.path]) { $1 }
    config.createsNewApplicationInstance = true
    config.activates = env["GITVIEW_NO_ACTIVATE"] == nil

    var failure: Error?
    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: bundle, configuration: config) { running, error in
        failure = error
        if let running { Log.info("launched as pid \(running.processIdentifier)") }
        done.signal()
    }
    done.wait()
    if let failure {
        let msg = "gitview: failed to start: \(failure.localizedDescription)"
        Log.error(msg)
        FileHandle.standardError.write(Data((msg + "\n").utf8))
        return false
    }
    return true
}

/// Sends stdout/stderr (crash messages) to the log file.
func redirectOutput(to file: URL) {
    let fd = open(file.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
    guard fd >= 0 else { return }
    dup2(fd, STDOUT_FILENO)
    dup2(fd, STDERR_FILENO)
    close(fd)
}
