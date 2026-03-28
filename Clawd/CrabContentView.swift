import AppKit

class CrabContentView: NSView {
    weak var character: CrabCharacter?
    private var isDragging = false
    private var dragStart: NSPoint = .zero
    private var windowStart: NSPoint = .zero
    private var samples: [(pos: NSPoint, time: CFTimeInterval)] = []

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

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStart = NSEvent.mouseLocation
        windowStart = character?.window.frame.origin ?? .zero
        samples = [(pos: dragStart, time: CACurrentMediaTime())]
    }

    override func mouseDragged(with event: NSEvent) {
        guard let crab = character else { return }
        isDragging = true
        crab.isWalking = false
        crab.isPaused = true
        crab.spriteRenderer.stopWalkAnimation()

        let mouse = NSEvent.mouseLocation
        let now = CACurrentMediaTime()

        samples.append((pos: mouse, time: now))
        if samples.count > 6 { samples.removeFirst() }

        let dx = mouse.x - dragStart.x
        let dy = mouse.y - dragStart.y
        crab.window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
        crab.isDragged = true
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            character?.snapToSurface()
            isDragging = false
        } else {
            character?.handleClick()
        }
    }
}
