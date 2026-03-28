import AppKit

class ScreenContext {
    private static let enabledKey = "screenContextEnabled"

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    static func captureScreenshot(completion: @escaping (String?) -> Void) {
        guard hasPermission else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let path = NSTemporaryDirectory() + "clawd-screen-\(UUID().uuidString).png"
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-x", "-t", "png", "-C", path]
            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let image = NSImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let maxDim: CGFloat = 1024
            let size = image.size
            let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            resized.unlockFocus()

            guard let tiff = resized.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            try? FileManager.default.removeItem(atPath: path)
            let base64 = jpeg.base64EncodedString()
            DispatchQueue.main.async { completion(base64) }
        }
    }
}
