import AppKit

class CrabContentView: NSView {
    weak var character: CrabCharacter?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let shadowRect = NSRect(x: 18, y: 4, width: bounds.width - 36, height: 12)
        let shadowPath = NSBezierPath(ovalIn: shadowRect)
        NSColor.black.withAlphaComponent(0.13).setFill()
        shadowPath.fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let renderer = character?.spriteRenderer else { return nil }
        return renderer.isOpaqueAt(point: point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        character?.handleClick()
    }
}
