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
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let base64 = data.base64EncodedString()
            DispatchQueue.main.async { completion(base64) }
        }
    }
}
