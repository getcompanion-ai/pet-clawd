import AppKit

class CrabContentView: NSView {
    weak var character: CrabCharacter?
    private var isDragging = false
    private var dragStart: NSPoint = .zero
    private var windowStart: NSPoint = .zero
    private var samples: [(pos: NSPoint, time: CFTimeInterval)] = []

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
            let vx: CGFloat
            let vy: CGFloat

            if samples.count >= 2 {
                let recent = samples.suffix(4)
                let first = recent.first!
                let last = recent.last!
                let dt = last.time - first.time
                if dt > 0.005 {
                    vx = (last.pos.x - first.pos.x) / CGFloat(dt)
                    vy = (last.pos.y - first.pos.y) / CGFloat(dt)
                } else {
                    vx = 0; vy = 0
                }
            } else {
                vx = 0; vy = 0
            }

            let speed = sqrt(vx * vx + vy * vy)
            if speed > 50 {
                character?.throwWithVelocity(vx: vx, vy: vy)
            } else {
                character?.snapToSurface()
            }
            isDragging = false
        } else {
            character?.handleClick()
        }
    }
}
