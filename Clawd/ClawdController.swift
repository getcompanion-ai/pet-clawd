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

    // MARK: - Dock Geometry

    private func getDockIconArea(screenWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25

        let persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0

        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) { dividers += 1 }
        if persistentOthers > 0 && recentApps > 0 { dividers += 1 }
        if showRecents && recentApps > 0 { dividers += 1 }

        let dividerWidth: CGFloat = 12.0
        var dockWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth
        dockWidth *= 1.1

        let dockX = (screenWidth - dockWidth) / 2.0
        return (dockX, dockWidth)
    }

    func tick() {
        guard let screen = NSScreen.main else { return }
        let floorY = screen.visibleFrame.origin.y - 10
        let screenWidth = screen.frame.width
        let (dockX, dockWidth) = getDockIconArea(screenWidth: screenWidth)
        crab.update(floorY: floorY, dockX: dockX + screen.frame.origin.x, dockWidth: dockWidth)
    }

    deinit {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }
}
