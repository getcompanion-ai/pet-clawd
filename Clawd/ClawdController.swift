import AppKit

class ClawdController {
    var crab: CrabCharacter!
    private var displayLink: CVDisplayLink?

    func start() {
        crab = CrabCharacter()
        crab.controller = self
        crab.setup()
        startDisplayLink()
    }

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let dl = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let ctrl = Unmanaged<ClawdController>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async { ctrl.tick() }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(dl, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(dl)
    }

    func tick() {
        guard let screen = NSScreen.main else { return }
        let floorY = screen.visibleFrame.origin.y - 10
        let screenWidth = screen.frame.width
        crab.update(floorY: floorY, screenLeft: screen.frame.origin.x, screenWidth: screenWidth)
    }

    deinit {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }
}
