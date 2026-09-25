import AppKit

private let tabKey: UInt16 = 48

/// Moves focus with Tab / Shift+Tab. Returns true if handled.
private func handleTab(_ event: NSEvent, in window: NSWindow?) -> Bool {
    guard event.keyCode == tabKey else { return false }
    if event.modifierFlags.contains(.shift) {
        window?.selectPreviousKeyView(nil)
    } else {
        window?.selectNextKeyView(nil)
    }
    return true
}

/// "/" acts like Cmd+F (Find). Returns true if handled.
private func handleSlash(_ event: NSEvent, from sender: NSResponder) -> Bool {
    guard event.characters == "/", event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return false }
    NSApp.sendAction(#selector(MainWindowController.gvFind(_:)), to: nil, from: sender)
    return true
}

/// Table that sends Space to the diff, Tab to the next pane, and Cmd+C to `onCopy`.
final class KeyTableView: NSTableView {
    var onSpace: ((_ up: Bool) -> Void)?
    var onCopy: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if handleTab(event, in: window) || handleSlash(event, from: self) { return }
        if event.charactersIgnoringModifiers == " " {
            onSpace?(event.modifierFlags.contains(.shift))
            return
        }
        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        onCopy?()
    }
}

final class DiffTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if handleTab(event, in: window) || handleSlash(event, from: self) { return }
        if event.charactersIgnoringModifiers == " " {
            if event.modifierFlags.contains(.shift) { scrollPageUp(nil) } else { scrollPageDown(nil) }
            return
        }
        super.keyDown(with: event)
    }

    func finderAction(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        performTextFinderAction(item)
    }
}

/// A plain text cell for view-based tables.
func textCell(_ table: NSTableView, _ id: NSUserInterfaceItemIdentifier, _ text: String, font: NSFont,
              truncate: NSLineBreakMode = .byTruncatingTail) -> NSTableCellView {
    if let cell = table.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = text
        cell.textField?.font = font
        return cell
    }
    let cell = NSTableCellView()
    cell.identifier = id
    let field = NSTextField(labelWithString: text)
    field.font = font
    field.lineBreakMode = truncate
    field.translatesAutoresizingMaskIntoConstraints = false
    cell.addSubview(field)
    cell.textField = field
    NSLayoutConstraint.activate([
        field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
        field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
        field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])
    return cell
}

/// Window that reports first responder changes.
final class MainWindow: NSWindow {
    var onFirstResponderChange: (() -> Void)?

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let ok = super.makeFirstResponder(responder)
        onFirstResponderChange?()
        return ok
    }
}

/// Wraps a pane and draws a thin border around it while it has focus.
final class PaneView: NSView {
    enum Focus { case none, active, inactive }

    var focus = Focus.none {
        didSet { if focus != oldValue { updateBorder() } }
    }

    init(_ content: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorder()
    }

    private func updateBorder() {
        guard let layer else { return }
        // A layer border is drawn above sublayers, so it shows over the scroll view.
        layer.borderWidth = focus == .none ? 0 : 1.5
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor = focus == .active ? .controlAccentColor : .tertiaryLabelColor
            layer.borderColor = color.cgColor
        }
    }
}
