import AppKit
import CoreGraphics

class ScreenContext {
    private static let chatEnabledKey = "screenContextChatEnabled"
    private static let commentsEnabledKey = "screenContextCommentsEnabled"

    static var chatEnabled: Bool {
        get { UserDefaults.standard.object(forKey: chatEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: chatEnabledKey) }
    }

    static var commentsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: commentsEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: commentsEnabledKey) }
    }

    static var enabled: Bool {
        get { chatEnabled || commentsEnabled }
        set { chatEnabled = newValue; commentsEnabled = newValue }
    }

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() {
        if !CGRequestScreenCaptureAccess() {
            openScreenRecordingSettings()
        }
    }

    static func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    static func captureScreenshot(completion: @escaping (String?) -> Void) {
        guard hasPermission else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        DispatchQueue.global(qos: .utility).async {
            guard let cgImage = CGWindowListCreateImage(
                CGRect.null,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let maxDim: CGFloat = 1024
            let w = CGFloat(cgImage.width)
            let h = CGFloat(cgImage.height)
            let scale = min(maxDim / w, maxDim / h, 1.0)
            let newW = Int(w * scale)
            let newH = Int(h * scale)

            guard let ctx = CGContext(
                data: nil, width: newW, height: newH,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))

            guard let resized = ctx.makeImage() else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let rep = NSBitmapImageRep(cgImage: resized)
            guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let base64 = jpeg.base64EncodedString()
            DispatchQueue.main.async { completion(base64) }
        }
    }
}
