import Foundation

public struct GitResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
    /// We ended the process early (callback returned false, or cancelled).
    public let stopped: Bool
}

/// Lets another thread stop a running git process.
public final class GitCancel: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let p = process
        lock.unlock()
        if let p, p.isRunning { p.terminate() }
    }

    /// Returns false if already cancelled.
    fileprivate func attach(_ p: Process) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        process = p
        return !cancelled
    }
}

public enum Git {
    /// Runs git and collects stdout.
    public static func run(_ args: [String], in dir: URL) -> GitResult {
        var out = ""
        let r = stream(args, in: dir) { line in
            out += line
            out += "\n"
            return true
        }
        return GitResult(status: r.status, stdout: out, stderr: r.stderr, stopped: r.stopped)
    }

    /// Runs git and calls `onLine` for each stdout line on the calling thread.
    /// Return false from `onLine` to stop git early.
    public static func stream(_ args: [String], in dir: URL, cancel: GitCancel? = nil,
                              onLine: (String) -> Bool) -> GitResult {
        let start = Date()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git"] + args
        p.currentDirectoryURL = dir
        p.standardInput = FileHandle.nullDevice
        let out = Pipe()
        p.standardOutput = out
        // stderr goes to a temp file: reading a second pipe needs another thread,
        // and those can starve when many git calls block at once.
        let errURL = FileManager.default.temporaryDirectory.appendingPathComponent("gitview-\(UUID().uuidString).err")
        defer { try? FileManager.default.removeItem(at: errURL) }

        do {
            FileManager.default.createFile(atPath: errURL.path, contents: nil)
            p.standardError = try FileHandle(forWritingTo: errURL)
            try p.run()
        } catch {
            Log.error("git \(args.joined(separator: " ")) failed to start: \(error)")
            return GitResult(status: -1, stdout: "", stderr: "\(error)", stopped: false)
        }

        var stopped = false
        if let cancel, !cancel.attach(p) {
            stopped = true
            p.terminate()
        }

        let reader = out.fileHandleForReading
        var buffer: [UInt8] = []
        while let chunk = try? reader.read(upToCount: 65536), !chunk.isEmpty {
            if stopped { continue }
            buffer.append(contentsOf: chunk)
            var lineStart = 0
            while let nl = buffer[lineStart...].firstIndex(of: 10) {
                let line = String(decoding: buffer[lineStart..<nl], as: UTF8.self)
                lineStart = nl + 1
                if !onLine(line) {
                    stopped = true
                    p.terminate()
                    break
                }
            }
            buffer.removeFirst(lineStart)
        }
        if !stopped && !buffer.isEmpty {
            _ = onLine(String(decoding: buffer, as: UTF8.self))
        }

        p.waitUntilExit()
        try? (p.standardError as? FileHandle)?.close()
        stopped = stopped || (cancel?.isCancelled ?? false)
        let stderr = String(decoding: (try? Data(contentsOf: errURL)) ?? Data(), as: UTF8.self)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        var msg = "git \(args.joined(separator: " ")) -> \(p.terminationStatus) in \(ms)ms"
        if stopped { msg += " (stopped)" }
        if !stderr.isEmpty { msg += " stderr: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))" }
        if p.terminationStatus != 0 && !stopped { Log.error(msg) } else { Log.info(msg) }
        return GitResult(status: p.terminationStatus, stdout: "", stderr: stderr, stopped: stopped)
    }
}
