import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let repo: URL
    private let args: [String]
    private var controller: MainWindowController?

    init(repo: URL, args: [String]) {
        self.repo = repo
        self.args = args
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        let c = MainWindowController(repo: repo, args: args)
        controller = c
        c.showWindow(nil)
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
