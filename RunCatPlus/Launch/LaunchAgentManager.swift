import Foundation

final class LaunchAgentManager: ObservableObject {
    static let label = "com.runCatPlus.startup"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var lastError: String?

    private let plistURL: URL

    init() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        plistURL = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            enable()
        } else {
            disable()
        }
    }

    private func enable() {
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: plistURL, options: .atomic)
        } catch {
            lastError = "Impossible d'écrire le fichier de démarrage : \(error.localizedDescription)"
            return
        }

        runLaunchCtl(arguments: ["load", plistURL.path])
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    private func disable() {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            runLaunchCtl(arguments: ["unload", plistURL.path])
        }
        do {
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            lastError = "Impossible de supprimer le fichier de démarrage : \(error.localizedDescription)"
        }
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }

    private func runLaunchCtl(arguments: [String]) {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            lastError = "launchctl a échoué : \(error.localizedDescription)"
            return
        }

        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "code \(task.terminationStatus)"
            lastError = "launchctl : \(message)"
        }
    }
}
