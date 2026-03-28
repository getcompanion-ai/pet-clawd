import AppKit

class ScreenContext {
    static var enabled = true

    static func captureScreenshot(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let path = NSTemporaryDirectory() + "clawd-screen.png"
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

            let base64 = jpeg.base64EncodedString()
            DispatchQueue.main.async { completion(base64) }
        }
    }
}
