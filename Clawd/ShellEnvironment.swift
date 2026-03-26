import Foundation

class ShellEnvironment {
    private static var cachedEnv: [String: String]?

    static func processEnvironment() -> [String: String] {
        if let cached = cachedEnv { return cached }

        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let extraPaths = [
            "\(home)/.local/bin",
            "\(home)/.claude/local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "\(home)/.nvm/versions/node/v22.0.0/bin",
            "\(home)/.cargo/bin",
        ]

        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        env["HOME"] = home
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"

        if let shellEnv = captureShellEnv() {
            if let path = shellEnv["PATH"] { env["PATH"] = path }
            for (k, v) in shellEnv where env[k] == nil { env[k] = v }
        }

        cachedEnv = env
        return env
    }

    private static func captureShellEnv() -> [String: String]? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "env"]
        proc.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return nil }

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return nil }

        var result: [String: String] = [:]
        for line in output.split(separator: "\n") {
            if let eqIdx = line.firstIndex(of: "=") {
                let key = String(line[line.startIndex..<eqIdx])
                let val = String(line[line.index(after: eqIdx)...])
                result[key] = val
            }
        }
        return result
    }

    static func findBinary(name: String, fallbackPaths: [String], completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            for path in fallbackPaths {
                if FileManager.default.isExecutableFile(atPath: path) {
                    DispatchQueue.main.async { completion(path) }
                    return
                }
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-l", "-c", "which \(name)"]
            proc.environment = processEnvironment()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                proc.waitUntilExit()
                if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                        DispatchQueue.main.async { completion(path) }
                        return
                    }
                }
            } catch {}

            DispatchQueue.main.async { completion(nil) }
        }
    }
}
