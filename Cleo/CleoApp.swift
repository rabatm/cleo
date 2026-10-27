import AppKit
import Combine
import SwiftUI

/// Point d'entrée : application accessoire (LSUIElement) pilotée par un
/// AppDelegate qui installe le NSStatusItem. Tout s'exécute sur le thread
/// principal (callbacks AppKit + timers du runloop) : PAS de @MainActor —
/// l'exécuteur Swift Concurrency du main actor ne fonctionne pas dans ce
/// binaire (les sauts @MainActor ne s'exécutent jamais, constaté en debug).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private let statusBar = StatusBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Évite un doublon quand launchd lance l'app alors qu'elle tourne déjà.
        let id = Bundle.main.bundleIdentifier ?? ""
        if NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains(where: { $0 != NSRunningApplication.current }) {
            NSApp.terminate(nil)
            return
        }
        statusBar.install(appState: appState)
    }
}

final class AppState: ObservableObject {
    let cpu = CPUProvider()
    let memory = MemoryProvider()
    let claude = ClaudeProvider()
    let kimi = KimiProvider()
    let launchAgent = LaunchAgentManager()
    let display = DisplaySettings()

    private var systemTimer: Timer?
    private var quotaTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        cpu.sample()
        memory.sample()

        // Les timers sont programmés sur le runloop principal : les rappels
        // s'exécutent sur le thread principal, inutile de sauter d'acteur.
        systemTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.cpu.sample()
            self.memory.sample()
        }

        // Quotas : immédiat puis toutes les 60 s — uniquement les fournisseurs affichés.
        refreshQuotas()
        quotaTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.refreshQuotas()
        }

        // Un fournisseur qu'on réaffiche est rafraîchi sans attendre le timer.
        display.$showClaude.dropFirst().filter { $0 }
            .sink { [weak self] _ in Task { await self?.claude.refresh() } }
            .store(in: &cancellables)
        display.$showKimi.dropFirst().filter { $0 }
            .sink { [weak self] _ in Task { await self?.kimi.refresh() } }
            .store(in: &cancellables)
    }

    private func refreshQuotas() {
        Task {
            if display.showClaude { await claude.refresh() }
            if display.showKimi { await kimi.refresh() }
        }
    }

    deinit {
        systemTimer?.invalidate()
        quotaTimer?.invalidate()
    }
}
