import Foundation

/// A throwaway git repo in a temp dir, isolated from the user's git config.
final class TestRepo {
    let url: URL
    private var clock = 1_700_000_000

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("gitview-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try git("init", "-q", "-b", "main")
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func write(_ path: String, _ content: String) throws {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: file, atomically: true, encoding: .utf8)
    }

    /// Writes the file and commits it. Returns the new commit hash.
    @discardableResult
    func commit(_ message: String, file: String = "file.txt", content: String? = nil) throws -> String {
        try write(file, content ?? message + "\n")
        try git("add", "-A")
        try git("commit", "-q", "-m", message)
        return try git("rev-parse", "HEAD")
    }

    @discardableResult
    func git(_ args: String...) throws -> String {
        clock += 60
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git"] + args
        p.currentDirectoryURL = url
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_NOSYSTEM"] = "1"
        env["GIT_AUTHOR_NAME"] = "Test Author"
        env["GIT_AUTHOR_EMAIL"] = "author@example.com"
        env["GIT_COMMITTER_NAME"] = "Test Author"
        env["GIT_COMMITTER_EMAIL"] = "author@example.com"
        env["GIT_AUTHOR_DATE"] = "\(clock) +0000"
        env["GIT_COMMITTER_DATE"] = "\(clock) +0000"
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "TestRepo", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "git \(args) failed"])
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
