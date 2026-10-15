import Foundation
import Darwin

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
        DispatchQueue.main.async { self.lastError = nil }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if enabled {
                self.enable()
            } else {
                self.disable()
            }
        }
    }

    private func enable() {
        let executablePath = Bundle.main.executableURL?.path
            ?? Bundle.main.bundleURL.path + "/Contents/MacOS/RunCatPlus"

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executablePath],
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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lastError = "Impossible d'écrire le fichier de démarrage : \(error.localizedDescription)"
                self.isEnabled = FileManager.default.fileExists(atPath: self.plistURL.path)
            }
            return
        }

        let result = runLaunchCtl(arguments: [
            "bootstrap",
            "user/\(getuid())",
            plistURL.path,
        ])

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch result {
            case .success:
                self.isEnabled = FileManager.default.fileExists(atPath: self.plistURL.path)
            case .failure(let error):
                self.lastError = "launchctl a échoué : \(error.localizedDescription)"
                try? FileManager.default.removeItem(at: self.plistURL)
                self.isEnabled = FileManager.default.fileExists(atPath: self.plistURL.path)
            }
        }
    }

    private func disable() {
        let plistExists = FileManager.default.fileExists(atPath: plistURL.path)

        let result: Result<Void, Error>
        if plistExists {
            result = runLaunchCtl(arguments: [
                "bootout",
                "user/\(getuid())/\(Self.label)",
            ])
        } else {
            result = .success(())
        }

        let removalError: Error?
        if plistExists {
            do {
                try FileManager.default.removeItem(at: plistURL)
                removalError = nil
            } catch {
                removalError = error
            }
        } else {
            removalError = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch result {
            case .success:
                if let error = removalError {
                    self.lastError = "Impossible de supprimer le fichier de démarrage : \(error.localizedDescription)"
                }
            case .failure(let error):
                self.lastError = "launchctl a échoué : \(error.localizedDescription)"
            }
            self.isEnabled = FileManager.default.fileExists(atPath: self.plistURL.path)
        }
    }

    private func runLaunchCtl(arguments: [String]) -> Result<Void, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .failure(error)
        }

        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "code \(task.terminationStatus)"
            let error = NSError(
                domain: "LaunchAgentManager",
                code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            return .failure(error)
        }

        return .success(())
    }
}
