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
