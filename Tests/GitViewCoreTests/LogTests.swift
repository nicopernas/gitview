import Foundation
import Testing
@testable import GitViewCore

@Suite(.serialized) struct LogTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gitview-logs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func writesLinesWithPidToDailyFile() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = Log.setup(dir: dir)
        Log.info("hello there")

        #expect(file.deletingLastPathComponent().path == dir.path)
        #expect(file.lastPathComponent.range(of: #"^\d{4}-\d{2}-\d{2}\.log$"#, options: .regularExpression) != nil)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("[\(getpid())] INFO hello there"))
    }

    @Test func deletesFilesOlderThanTwoWeeks() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("2000-01-01.log")
        let recent = dir.appendingPathComponent("2000-01-02.log")
        for f in [old, recent] { try "x".write(to: f, atomically: true, encoding: .utf8) }
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-15 * 86400)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-13 * 86400)], ofItemAtPath: recent.path)

        _ = Log.setup(dir: dir)

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
    }
}
