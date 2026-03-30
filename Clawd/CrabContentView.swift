import AppKit

class CrabContentView: NSView {
    weak var character: CrabCharacter?
    private var isDragging = false
    private var dragOffset = NSPoint.zero

    override var isFlipped: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let renderer = character?.spriteRenderer else { return nil }
        return renderer.isOpaqueAt(point: point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        guard let win = window else { return }
        let screenLoc = NSEvent.mouseLocation
        dragOffset = NSPoint(
            x: screenLoc.x - win.frame.origin.x,
            y: screenLoc.y - win.frame.origin.y
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        if !isDragging {
            isDragging = true
            character?.stopForDrag()
        }
        let screenLoc = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: screenLoc.x - dragOffset.x,
            y: screenLoc.y - dragOffset.y
        )
        win.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            character?.startFalling()
        } else {
            character?.handleClick()
        }
    }
}
