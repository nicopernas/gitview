import Foundation

public enum AppBundle {
    /// The .app containing `executable` (following symlinks), if any.
    public static func locate(executable: URL) -> URL? {
        let exe = executable.resolvingSymlinksInPath()
        let app = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app", exe.deletingLastPathComponent().path == app.appendingPathComponent("Contents/MacOS").path
        else { return nil }
        return app
    }
}
