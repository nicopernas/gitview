import Foundation
import Testing
@testable import GitViewCore

@Suite struct AppBundleTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gitview-bundle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.resolvingSymlinksInPath()
    }

    private func makeApp(in dir: URL) throws -> URL {
        let app = dir.appendingPathComponent("gitview.app")
        let macos = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: macos.appendingPathComponent("gitview").path, contents: Data())
        return app
    }

    @Test func findsBundleFromExecutableInside() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = try makeApp(in: dir)
        #expect(AppBundle.locate(executable: app.appendingPathComponent("Contents/MacOS/gitview"))?.path == app.path)
    }

    @Test func followsSymlinkToExecutable() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = try makeApp(in: dir)
        let link = dir.appendingPathComponent("gitview-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app.appendingPathComponent("Contents/MacOS/gitview"))
        #expect(AppBundle.locate(executable: link)?.path == app.path)
    }

    @Test func plainExecutableHasNoBundle() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let exe = dir.appendingPathComponent("gitview")
        FileManager.default.createFile(atPath: exe.path, contents: Data())
        #expect(AppBundle.locate(executable: exe) == nil)
    }
}
