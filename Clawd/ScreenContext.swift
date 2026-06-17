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
        if CGPreflightScreenCaptureAccess() { return true }
        // CGPreflightScreenCaptureAccess returns false on macOS 26 even when
        // permission is granted. Fall back to attempting a 1x1 capture.
        return CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly, kCGNullWindowID, []
        ) != nil
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

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let pidKey = kCGWindowOwnerPID as String
        let numKey = kCGWindowNumber as String
        let ownWindowIDs: Set<CGWindowID> = {
            guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
            var ids = Set<CGWindowID>()
            for info in list {
                guard let pid = info[pidKey] as? Int32, pid == ownPID,
                      let wid = info[numKey] as? CGWindowID else { continue }
                ids.insert(wid)
            }
            return ids
        }()

        DispatchQueue.global(qos: .utility).async {
            let cgImage: CGImage?
            if !ownWindowIDs.isEmpty {
                let allWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
                let filtered: [CGWindowID] = allWindows.compactMap { info in
                    guard let wid = info[numKey] as? CGWindowID, !ownWindowIDs.contains(wid) else { return nil }
                    return wid
                }
                // CGImage(windowListFromArrayScreenBounds:) returns nil on macOS 26.
                // Fall back to CGWindowListCreateImage which still works.
                cgImage = CGImage(windowListFromArrayScreenBounds: CGRect.null, windowArray: filtered as CFArray, imageOption: .bestResolution)
                    ?? CGWindowListCreateImage(.null, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
            } else {
                cgImage = CGWindowListCreateImage(
                    CGRect.null,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    [.bestResolution]
                )
            }
            guard let cgImage = cgImage else {
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
