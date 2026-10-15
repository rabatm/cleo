import SwiftUI

/// Menu déroulant affiché au clic sur l'icône de la barre des menus.
struct MenuContentView: View {
    @ObservedObject var cpu: CPUProvider
    @ObservedObject var memory: MemoryProvider
    @ObservedObject var claude: ClaudeProvider
    @ObservedObject var kimi: KimiProvider

    var body: some View {
        Group {
            Section("Système") {
                LabeledContent("CPU") {
                    Text("\(Int(cpu.usage * 100)) %")
                        .monospacedDigit()
                }
                LabeledContent("Mémoire") {
                    Text(String(format: "%.1f / %.0f Go — swap %.0f Mo",
                                memory.snapshot.usedGB,
                                memory.snapshot.totalGB,
                                memory.snapshot.swapUsedMB))
                    .monospacedDigit()
                }
                LabeledContent("Pression") {
                    Text(pressureLabel(memory.snapshot.pressure))
                }
            }

            Section("Claude Code") {
                quotaRow(label: "7 jours", window: claude.state.primary)
                quotaRow(label: "5 heures", window: claude.state.secondary)
                if claude.state.connectivity != .connected {
                    Text(claude.state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Kimi Code") {
                quotaRow(label: "Mensuel", window: kimi.state.primary)
                quotaRow(label: "5 heures", window: kimi.state.secondary)
                if kimi.state.connectivity != .connected {
                    Text(kimi.state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Actualiser les quotas") {
                Task {
                    await claude.refresh()
                    await kimi.refresh()
                }
            }
            Divider()
            Button("Quitter RunCatPlus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 300)
    }

    private func pressureLabel(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: return "Normale"
        case .warning: return "Élevée"
        case .critical: return "Critique"
        case .unknown: return "Inconnue"
        }
    }

    @ViewBuilder
    private func quotaRow(label: String, window: QuotaWindow?) -> some View {
        if let window {
            LabeledContent(label) {
                HStack(spacing: 6) {
                    ProgressView(value: min(window.percent, 100), total: 100)
                        .progressViewStyle(.linear)
                        .frame(width: 90)
                    Text("\(Int(window.percent)) % · RAZ \(window.countdownText)")
                        .monospacedDigit()
                        .font(.caption)
                }
            }
        } else {
            LabeledContent(label) { Text("—").foregroundStyle(.secondary) }
        }
    }
}
