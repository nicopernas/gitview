import Foundation

/// Appends lines to ~/.gitview/logs/YYYY-MM-DD.log. Thread safe.
public enum Log {
    public static let defaultDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".gitview/logs")
    static let maxAge: TimeInterval = 14 * 86400

    private static let lock = NSLock()
    private static var handle: FileHandle?
    private static var echo = false
    private static let timeFormatter = formatter("yyyy-MM-dd HH:mm:ss.SSS")

    /// Opens today's file, deleting old ones. Returns the file's URL.
    /// `echo` also copies lines to stderr.
    @discardableResult
    public static func setup(dir: URL = defaultDir, echo: Bool = false) -> URL {
        lock.lock()
        defer { lock.unlock() }
        self.echo = echo
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        prune(dir)
        let url = dir.appendingPathComponent(formatter("yyyy-MM-dd").string(from: Date()) + ".log")
        try? handle?.close()
        let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        handle = fd >= 0 ? FileHandle(fileDescriptor: fd, closeOnDealloc: true) : nil
        return url
    }

    public static func info(_ message: String) { write("INFO", message) }
    public static func error(_ message: String) { write("ERROR", message) }

    private static func write(_ level: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = "\(timeFormatter.string(from: Date())) [\(getpid())] \(level) \(message)\n"
        handle?.write(Data(line.utf8))
        if echo { FileHandle.standardError.write(Data(line.utf8)) }
    }

    private static func prune(_ dir: URL) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let cutoff = Date().addingTimeInterval(-maxAge)
        for f in files where f.pathExtension == "log" {
            let modified = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? fm.removeItem(at: f) }
        }
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}
