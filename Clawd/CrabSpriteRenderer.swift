import AppKit

/// Layered Core Animation rig for the official Clawd mascot.
///
/// Geometry comes from Anthropic's Clawd-CrabWalking.gif quantized to its
/// native 24x17 art-pixel grid (see art/clawd-official/). Parts render as
/// separate layers — torso (with claw arms), legs, two eyes — so eyes can
/// track the cursor, blink, and swap expressions while the official walk
/// gait plays underneath, the same rig structure clawd-on-desk uses with
/// per-state SVGs.
///
/// Keeps the legacy renderer API (`layer`, `setFrame`, `setFlipped`,
/// `isOpaqueAt`, `scale`) so CrabCharacter's emotion combos, window
/// primitives, and pixel effects keep working unchanged.
class CrabSpriteRenderer {
    // Legacy effect-coordinate space: CrabCharacter places emotion effect
    // pixels on a 16-cell grid at this scale (a ~80px box at the window's
    // bottom-left, which sits above/around the head at the new size).
    let scale = 5
    let displaySize: CGFloat = 120

    // Internal art geometry: 24x17 art pixels, 4px each = 96x68, centered
    // horizontally, feet on the window floor.
    private let cell: CGFloat = 4
    private let gridW = 24
    private let gridH = 17
    private var offsetX: CGFloat { (displaySize - CGFloat(gridW) * cell) / 2 }

    static let bodyColor = NSColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1.0) // #D97757 official
    static let eyeColor = NSColor.black
    static let heartColor = NSColor(red: 1.0, green: 0.36, blue: 0.54, alpha: 1.0)

    let layer = CALayer()
    private let bodyGroup = CALayer()
    private let torsoLayer = CALayer()
    private let legsLayer = CALayer()
    private let eyeLeft = CALayer()
    private let eyeRight = CALayer()

    enum Frame: Int {
        case idle = 0, walkA, walkB, blink, happy, surprised, angry, sad,
             love, sleepy, smug, scared, dead, wink
    }

    // MARK: - Official art data (from walk-frames.json, frame 0)

    // Torso cells include the claw-arm band (rows 5-8 spanning full width).
    // Eye holes in the source are backfilled with body color below so
    // tracked eyes never expose the desktop through the head.
    private static let torsoCells: [Int] = [4,1,4,2,4,3,4,4,4,5,4,6,4,7,4,8,4,9,4,10,4,11,4,12,5,1,5,2,5,3,5,4,5,5,5,6,5,7,5,8,5,9,5,10,5,11,5,12,6,1,6,2,6,5,6,6,6,7,6,8,6,9,6,10,6,11,6,12,7,1,7,2,7,5,7,6,7,7,7,8,7,9,7,10,7,11,7,12,8,1,8,2,8,3,8,4,8,5,8,6,8,7,8,8,8,9,8,10,8,11,8,12,9,1,9,2,9,3,9,4,9,5,9,6,9,7,9,8,9,9,9,10,9,11,9,12,10,1,10,2,10,3,10,4,10,5,10,6,10,7,10,8,10,9,10,10,10,11,10,12,11,1,11,2,11,3,11,4,11,5,11,6,11,7,11,8,11,9,11,10,11,11,11,12,12,1,12,2,12,3,12,4,12,5,12,6,12,7,12,8,12,9,12,10,12,11,12,12,13,1,13,2,13,3,13,4,13,5,13,6,13,7,13,8,13,9,13,10,13,11,13,12,14,1,14,2,14,3,14,4,14,5,14,6,14,7,14,8,14,9,14,10,14,11,14,12,15,1,15,2,15,3,15,4,15,5,15,6,15,7,15,8,15,9,15,10,15,11,15,12,16,1,16,2,16,5,16,6,16,7,16,8,16,9,16,10,16,11,16,12,17,1,17,2,17,5,17,6,17,7,17,8,17,9,17,10,17,11,17,12,18,1,18,2,18,3,18,4,18,5,18,6,18,7,18,8,18,9,18,10,18,11,18,12,19,1,19,2,19,3,19,4,19,5,19,6,19,7,19,8,19,9,19,10,19,11,19,12,
        0,5,0,6,0,7,0,8,1,5,1,6,1,7,1,8,2,5,2,6,2,7,2,8,3,5,3,6,3,7,3,8,
        20,5,20,6,20,7,20,8,21,5,21,6,21,7,21,8,22,5,22,6,22,7,22,8,23,5,23,6,23,7,23,8,
        6,3,6,4,7,3,7,4,16,3,16,4,17,3,17,4] // eye-hole backfill

    private static let idleLegCells: [Int] = [4,13,4,14,4,15,4,16,5,13,5,14,5,15,5,16,8,13,8,14,8,15,8,16,9,13,9,14,9,15,9,16,14,13,14,14,14,15,14,16,15,13,15,14,15,15,15,16,18,13,18,14,18,15,18,16,19,13,19,14,19,15,19,16]

    // 16-frame stride cycle from official frames 4-19 (80ms/frame).
    private static let walkLegFrames: [[Int]] = [
        [4,13,4,14,4,15,4,16,5,13,5,14,5,15,5,16,8,13,8,14,8,15,9,13,9,14,9,15,14,13,14,14,14,15,14,16,15,13,15,14,15,15,15,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,5,13,7,13,7,14,7,15,7,16,8,13,8,14,8,15,8,16,15,13,15,14,16,13,16,14,18,13,19,13,19,14,19,15,19,16,20,13,20,14,20,15,20,16],
        [3,13,3,14,3,15,3,16,4,13,4,14,4,15,4,16,5,13,7,13,7,14,7,15,8,13,8,14,8,15,16,13,16,14,16,15,16,16,17,13,17,14,17,15,17,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,8,13,8,14,8,15,8,16,9,13,9,14,9,15,9,16,15,13,15,14,15,15,15,16,16,13,16,14,16,15,16,16,18,13,18,14,18,15,18,16,19,13,19,14,19,15,19,16],
        [4,13,4,14,4,15,4,16,5,13,5,14,5,15,5,16,8,13,8,14,8,15,9,13,9,14,9,15,14,13,14,14,14,15,14,16,15,13,15,14,15,15,15,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,5,13,7,13,7,14,7,15,7,16,8,13,8,14,8,15,8,16,15,13,15,14,16,13,16,14,19,13,19,14,19,15,19,16,20,13,20,14,20,15,20,16],
        [3,13,3,14,3,15,3,16,4,13,4,14,4,15,4,16,7,13,7,14,7,15,8,13,8,14,8,15,16,13,16,14,16,15,16,16,17,13,17,14,17,15,17,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,8,13,8,14,8,15,8,16,9,13,9,14,9,15,9,16,15,13,15,14,15,15,15,16,16,13,16,14,16,15,16,16,18,13,18,14,18,15,18,16,19,13,19,14,19,15,19,16],
        [4,13,4,14,4,15,4,16,5,13,5,14,5,15,5,16,8,13,8,14,8,15,9,13,9,14,9,15,14,13,14,14,14,15,14,16,15,13,15,14,15,15,15,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,5,13,7,13,7,14,7,15,7,16,8,13,8,14,8,15,8,16,15,13,15,14,16,13,16,14,18,13,19,13,19,14,19,15,19,16,20,13,20,14,20,15,20,16],
        [3,13,3,14,3,15,3,16,4,13,4,14,4,15,4,16,5,13,7,13,7,14,7,15,8,13,8,14,8,15,16,13,16,14,16,15,16,16,17,13,17,14,17,15,17,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,8,13,8,14,8,15,8,16,9,13,9,14,9,15,9,16,15,13,15,14,15,15,15,16,16,13,16,14,16,15,16,16,18,13,18,14,18,15,18,16,19,13,19,14,19,15,19,16],
        [4,13,4,14,4,15,4,16,5,13,5,14,5,15,5,16,8,13,8,14,8,15,9,13,9,14,9,15,14,13,14,14,14,15,14,16,15,13,15,14,15,15,15,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,5,13,7,13,7,14,7,15,7,16,8,13,8,14,8,15,8,16,15,13,15,14,16,13,16,14,19,13,19,14,19,15,19,16,20,13,20,14,20,15,20,16],
        [3,13,3,14,3,15,3,16,4,13,4,14,4,15,4,16,7,13,7,14,7,15,8,13,8,14,8,15,16,13,16,14,16,15,16,16,17,13,17,14,17,15,17,16,19,13,19,14,19,15,20,13,20,14,20,15],
        [3,13,3,14,3,15,4,13,4,14,4,15,8,13,8,14,8,15,8,16,9,13,9,14,9,15,9,16,15,13,15,14,15,15,15,16,16,13,16,14,16,15,16,16,18,13,18,14,18,15,18,16,19,13,19,14,19,15,19,16],
    ]
    // Body lifts 1 art-pixel on these stride frames (from official top-row data).
    private static let walkBob: [Int] = [0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0]

    // Eye origins: top-left art cell of each 2x2 eye.
    private static let eyeLeftOrigin = (col: 6, row: 3)
    private static let eyeRightOrigin = (col: 16, row: 3)

    // MARK: - Eye expressions
    // Cells are (dx, dy, colorIndex) relative to the eye origin, dy grows
    // downward. Colors: 1 black, 2 heart-pink.
    private typealias EyeCells = [(Int, Int, Int)]
    private static let eyesNormal: EyeCells = [(0,0,1),(1,0,1),(0,1,1),(1,1,1)]
    private static let eyesClosed: EyeCells = [(0,1,1),(1,1,1)]
    private static let eyesHappy: EyeCells = [(-1,1,1),(0,0,1),(1,0,1),(2,1,1)]
    private static let eyesWide: EyeCells = [(0,-1,1),(1,-1,1),(0,0,1),(1,0,1),(0,1,1),(1,1,1)]
    private static let eyesAngryL: EyeCells = [(0,0,1),(1,0,1),(1,1,1),(2,1,1)]
    private static let eyesAngryR: EyeCells = [(-1,1,1),(0,1,1),(0,0,1),(1,0,1)]
    private static let eyesSadL: EyeCells = [(0,0,1),(0,1,1),(1,1,1)]
    private static let eyesSadR: EyeCells = [(1,0,1),(0,1,1),(1,1,1)]
    private static let eyesLove: EyeCells = [(-1,0,2),(1,0,2),(-1,1,2),(0,1,2),(1,1,2),(0,2,2)]
    private static let eyesDead: EyeCells = [(-1,-1,1),(1,-1,1),(0,0,1),(-1,1,1),(1,1,1)]
    private static let eyesSmug: EyeCells = [(0,1,1),(1,1,1),(0,0,1)]

    private struct Expression {
        let left: EyeCells
        let right: EyeCells
        init(_ both: EyeCells) { left = both; right = both }
        init(left: EyeCells, right: EyeCells) { self.left = left; self.right = right }
    }

    private static let expressions: [Frame: Expression] = [
        .idle: Expression(eyesNormal),
        .walkA: Expression(eyesNormal),
        .walkB: Expression(eyesNormal),
        .blink: Expression(eyesClosed),
        .happy: Expression(eyesHappy),
        .surprised: Expression(eyesWide),
        .angry: Expression(left: eyesAngryL, right: eyesAngryR),
        .sad: Expression(left: eyesSadL, right: eyesSadR),
        .love: Expression(eyesLove),
        .sleepy: Expression(eyesClosed),
        .smug: Expression(eyesSmug),
        .scared: Expression(eyesWide),
        .dead: Expression(eyesDead),
        .wink: Expression(left: eyesNormal, right: eyesClosed),
    ]

    // MARK: - State

    private var currentFrame: Frame = .idle
    private var currentlyFlipped = false
    private var walkTimer: Timer?
    private var gaitIndex = 0
    private var eyeTimer: Timer?
    private weak var trackedWindow: NSWindow?
    private var occupiedCells = Set<Int>()
    private var legTextures: [CGImage] = []
    private var idleLegTexture: CGImage!
    private var eyeBaseLeft = CGPoint.zero
    private var eyeBaseRight = CGPoint.zero

    // MARK: - Init

    init() {
        layer.frame = CGRect(x: 0, y: 0, width: displaySize, height: displaySize)
        layer.magnificationFilter = .nearest

        // Torso (with arms) — breathes; eyes ride on it.
        torsoLayer.frame = layer.bounds
        torsoLayer.contents = renderCells(pairList: Self.torsoCells, color: Self.bodyColor)
        torsoLayer.magnificationFilter = .nearest

        bodyGroup.frame = layer.bounds
        // Anchor at the feet so breathing grows upward.
        bodyGroup.anchorPoint = CGPoint(x: 0.5, y: 0)
        bodyGroup.position = CGPoint(x: displaySize / 2, y: 0)
        bodyGroup.addSublayer(torsoLayer)

        // Eyes
        for (eye, origin) in [(eyeLeft, Self.eyeLeftOrigin), (eyeRight, Self.eyeRightOrigin)] {
            // Frame is a 5x5-cell canvas centered on the eye so expressions
            // can extend beyond the 2x2 base.
            let base = cellRect(col: origin.col - 1, row: origin.row - 1, w: 5, h: 5)
            eye.frame = base
            eye.magnificationFilter = .nearest
            bodyGroup.addSublayer(eye)
        }
        eyeBaseLeft = eyeLeft.position
        eyeBaseRight = eyeRight.position

        // Legs (ground layer, exempt from breathe/bob)
        legsLayer.frame = layer.bounds
        legsLayer.magnificationFilter = .nearest
        bodyGroupBobOffset = 0

        idleLegTexture = renderCells(pairList: Self.idleLegCells, color: Self.bodyColor)
        legTextures = Self.walkLegFrames.map { renderCells(pairList: $0, color: Self.bodyColor) }
        legsLayer.contents = idleLegTexture

        layer.addSublayer(legsLayer)
        layer.addSublayer(bodyGroup)

        // Occupancy for hit testing: torso + idle legs.
        var occupied = Set<Int>()
        for list in [Self.torsoCells, Self.idleLegCells] {
            for i in stride(from: 0, to: list.count, by: 2) {
                occupied.insert(list[i] * 100 + list[i + 1])
            }
        }
        occupiedCells = occupied

        applyExpression(for: .idle)
        startBreathing()
        startEyeTracking()
    }

    /// Lets the rig know its host window so eye tracking can compare the
    /// cursor against the crab's on-screen position.
    func attach(window: NSWindow) {
        trackedWindow = window
    }

    // MARK: - Legacy API

    func setFrame(_ frame: Frame) {
        guard frame != currentFrame else { return }
        let wasWalking = currentFrame == .walkA || currentFrame == .walkB
        let isWalking = frame == .walkA || frame == .walkB
        currentFrame = frame

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyExpression(for: frame)
        if isWalking && !wasWalking {
            startGait()
        } else if !isWalking && wasWalking {
            stopGait()
        }
        CATransaction.commit()
    }

    func setFlipped(_ flipped: Bool) {
        guard flipped != currentlyFlipped else { return }
        currentlyFlipped = flipped
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = flipped ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    func isOpaqueAt(point: NSPoint) -> Bool {
        let col = Int((point.x - offsetX) / cell)
        let rowFromBottom = Int(point.y / cell)
        let row = gridH - 1 - rowFromBottom
        guard col >= 0, col < gridW, row >= 0, row < gridH else { return false }
        return occupiedCells.contains(col * 100 + row)
    }

    // MARK: - Gait

    private func startGait() {
        gaitIndex = 0
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.stepGait()
        }
        if let walkTimer { RunLoop.main.add(walkTimer, forMode: .common) }
    }

    private func stopGait() {
        walkTimer?.invalidate()
        walkTimer = nil
        legsLayer.contents = idleLegTexture
        bodyGroupBobOffset = 0
    }

    private func stepGait() {
        gaitIndex = (gaitIndex + 1) % legTextures.count
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        legsLayer.contents = legTextures[gaitIndex]
        bodyGroupBobOffset = CGFloat(Self.walkBob[gaitIndex]) * cell
        CATransaction.commit()
    }

    private var bodyGroupBobOffset: CGFloat = 0 {
        didSet { bodyGroup.position = CGPoint(x: displaySize / 2, y: bodyGroupBobOffset) }
    }

    // MARK: - Breathing (idle life, like clawd-on-desk's 3.2s breathe)

    private func startBreathing() {
        let breathe = CABasicAnimation(keyPath: "transform.scale.y")
        breathe.fromValue = 1.0
        breathe.toValue = 1.018
        breathe.duration = 1.6
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bodyGroup.add(breathe, forKey: "breathe")
    }

    // MARK: - Eye tracking (idle/walk only; offsets like clawd-on-desk:
    // eyes full, body subtle at 0.33x)

    private func startEyeTracking() {
        eyeTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.updateEyeTracking()
        }
        if let eyeTimer { RunLoop.main.add(eyeTimer, forMode: .common) }
    }

    private func updateEyeTracking() {
        guard currentFrame == .idle || currentFrame == .walkA || currentFrame == .walkB,
              let window = trackedWindow else { return }
        let mouse = NSEvent.mouseLocation
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY + 20)
        var dx = mouse.x - center.x
        let dy = mouse.y - center.y
        if currentlyFlipped { dx = -dx }
        let dist = max(sqrt(dx * dx + dy * dy), 0.001)
        let reach = min(dist / 250.0, 1.0)
        let maxOffset = cell * 1.25
        let ox = dx / dist * maxOffset * reach
        let oy = dy / dist * maxOffset * reach * 0.6

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        eyeLeft.position = CGPoint(x: eyeBaseLeft.x + ox, y: eyeBaseLeft.y + oy)
        eyeRight.position = CGPoint(x: eyeBaseRight.x + ox, y: eyeBaseRight.y + oy)
        torsoLayer.position = CGPoint(x: layer.bounds.midX + ox * 0.33,
                                      y: layer.bounds.midY)
        CATransaction.commit()
    }

    // MARK: - Rendering

    private func applyExpression(for frame: Frame) {
        let expr = Self.expressions[frame] ?? Self.expressions[.idle]!
        eyeLeft.contents = renderEye(expr.left)
        eyeRight.contents = renderEye(expr.right)
    }

    /// Renders (col,row) pairs into a full-grid image (bottom-left origin
    /// flip handled here; rows grow downward in the data).
    private func renderCells(pairList: [Int], color: NSColor) -> CGImage {
        let w = Int(displaySize), h = Int(displaySize)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(color.cgColor)
        for i in stride(from: 0, to: pairList.count, by: 2) {
            let rect = cellRect(col: pairList[i], row: pairList[i + 1], w: 1, h: 1)
            ctx.fill(rect)
        }
        return ctx.makeImage()!
    }

    /// Renders an eye expression into its 5x5-cell canvas. The eye origin
    /// sits at canvas cell (1,1).
    private func renderEye(_ cells: EyeCells) -> CGImage {
        let size = Int(cell) * 5
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        for (dx, dy, colorIndex) in cells {
            let color = colorIndex == 2 ? Self.heartColor : Self.eyeColor
            ctx.setFillColor(color.cgColor)
            let cx = 1 + dx
            let cy = 1 + dy
            guard cx >= 0, cx < 5, cy >= 0, cy < 5 else { continue }
            // Flip vertically for CG bottom-left origin.
            ctx.fill(CGRect(x: CGFloat(cx) * cell, y: CGFloat(5 - 1 - cy) * cell,
                            width: cell, height: cell))
        }
        return ctx.makeImage()!
    }

    /// Art-grid cell → layer-space rect (bottom-left origin).
    private func cellRect(col: Int, row: Int, w: Int, h: Int) -> CGRect {
        CGRect(x: offsetX + CGFloat(col) * cell,
               y: CGFloat(gridH - row - h) * cell,
               width: CGFloat(w) * cell,
               height: CGFloat(h) * cell)
    }
}
