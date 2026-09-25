// Draws the app icon as a PNG. Usage: swift app/make-icon.swift <size> <out.png>
// `make icon` turns it into app/AppIcon.icns.
import AppKit

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let blue = rgb(0x0A84FF), orange = rgb(0xFF9F0A), green = rgb(0x30D158), red = rgb(0xFF453A)
let ring = rgb(0x1E2331)

func draw(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
        let k = size / 1024
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * k, y: y * k) }

        // macOS icon grid: 824pt body centered on a 1024pt canvas.
        let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
        let shape = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)
        NSGradient(starting: rgb(0x2B3245), ending: rgb(0x161A24))!.draw(in: shape, angle: 90)

        func line(_ a: NSPoint, _ b: NSPoint, _ c: NSColor) {
            let path = NSBezierPath()
            path.lineWidth = 44 * k
            path.lineCapStyle = .round
            path.move(to: a)
            if a.x == b.x {
                path.line(to: b)
            } else {
                let mid = (a.y + b.y) / 2
                path.curve(to: b, controlPoint1: NSPoint(x: a.x, y: mid), controlPoint2: NSPoint(x: b.x, y: mid))
            }
            c.setStroke()
            path.stroke()
        }
        func dot(_ c: NSPoint, _ color: NSColor) {
            let r = 58 * k
            let o = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            color.setFill()
            o.fill()
            ring.setStroke()
            o.lineWidth = 18 * k
            o.stroke()
        }

        // Newest at the top: a merge commit, a two-commit branch, and the fork point.
        let x0: CGFloat = 320, x1 = x0 + 220
        line(p(x0, 230), p(x0, 800), blue)
        line(p(x0, 230), p(x1, 420), orange)
        line(p(x1, 420), p(x1, 610), orange)
        line(p(x1, 610), p(x0, 800), orange)
        dot(p(x0, 230), blue)
        dot(p(x1, 420), orange)
        dot(p(x1, 610), orange)
        dot(p(x0, 515), blue)
        dot(p(x0, 800), blue)

        // Diff lines.
        for (y, w, c) in [(410, 170, green), (480, 120, red), (550, 150, green), (620, 90, green)] as [(CGFloat, CGFloat, NSColor)] {
            c.setFill()
            NSBezierPath(roundedRect: NSRect(x: 640 * k, y: y * k, width: w * k, height: 34 * k), xRadius: 17 * k, yRadius: 17 * k).fill()
        }
        return true
    }
}

let size = Int(CommandLine.arguments[1])!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
draw(size: CGFloat(size)).draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
