import Foundation

enum LaunchDiagnostics {
    static func recordLaunch() {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("AudioMixerClone", isDirectory: true)

        guard let supportDirectory else {
            return
        }

        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        let line = "Launched \(formatter.string(from: Date()))\n"
        let url = supportDirectory.appendingPathComponent("launch.log")

        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: Data(line.utf8))
            _ = try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
