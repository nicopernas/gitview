import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let repo: URL
    private let workDir: URL
    private let args: [String]
    private var controller: MainWindowController?

    init(repo: URL, workDir: URL, args: [String]) {
        self.repo = repo
        self.workDir = workDir
        self.args = args
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        let c = MainWindowController(repo: repo, workDir: workDir, args: args)
        controller = c
        c.showWindow(nil)
        // For testing: open behind other windows without taking focus.
        if ProcessInfo.processInfo.environment["GITVIEW_NO_ACTIVATE"] != nil { return }
        // Plain activate() is refused when started from a terminal; this one works.
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()

        let app = submenu(main, "gitview")
        app.addItem(withTitle: "Hide gitview", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit gitview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let edit = submenu(main, "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Find…", action: #selector(MainWindowController.gvFind(_:)), keyEquivalent: "f")
        edit.addItem(withTitle: "Find Next", action: #selector(MainWindowController.gvFindNext(_:)), keyEquivalent: "g")
        edit.addItem(withTitle: "Find Previous", action: #selector(MainWindowController.gvFindPrevious(_:)), keyEquivalent: "G")

        let format = submenu(main, "Format")
        let fonts = NSFontManager.shared
        format.addItem(withTitle: "Show Fonts", action: #selector(NSFontManager.orderFrontFontPanel(_:)), keyEquivalent: "t").target = fonts
        let bigger = format.addItem(withTitle: "Bigger", action: #selector(NSFontManager.modifyFont(_:)), keyEquivalent: "=")
        bigger.target = fonts
        bigger.tag = Int(NSFontAction.sizeUpFontAction.rawValue)
        let smaller = format.addItem(withTitle: "Smaller", action: #selector(NSFontManager.modifyFont(_:)), keyEquivalent: "-")
        smaller.target = fonts
        smaller.tag = Int(NSFontAction.sizeDownFontAction.rawValue)
        format.addItem(withTitle: "Reset Font", action: #selector(MainWindowController.gvResetFont(_:)), keyEquivalent: "0")

        let view = submenu(main, "View")
        view.addItem(withTitle: "Reload", action: #selector(MainWindowController.gvReload(_:)), keyEquivalent: "r")

        let window = submenu(main, "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        return main
    }

    private func submenu(_ main: NSMenu, _ title: String) -> NSMenu {
        let item = main.addItem(withTitle: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu
        return menu
    }
}
