import SwiftUI

/// Panneau affiché au clic sur l'icône de la barre des menus.
struct MenuContentView: View {
    @ObservedObject var cpu: CPUProvider
    @ObservedObject var memory: MemoryProvider
    @ObservedObject var claude: ClaudeProvider
    @ObservedObject var kimi: KimiProvider
    @ObservedObject var launchAgent: LaunchAgentManager
    @ObservedObject var display: DisplaySettings

    private static let claudeColor = Color(red: 0.96, green: 0.62, blue: 0.20)
    private static let kimiColor = Color(red: 0.25, green: 0.56, blue: 0.98)
    private static let background = Color(red: 0.075, green: 0.078, blue: 0.125)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 18)

            VStack(spacing: 12) {
                metricRow(label: "CPU",
                          fraction: cpu.usage,
                          value: "\(Int((cpu.usage * 100).rounded())) %",
                          gradient: [Color(red: 0.30, green: 0.45, blue: 0.98),
                                     Color(red: 0.36, green: 0.66, blue: 1.0)])
                metricRow(label: "Mémoire",
                          fraction: memory.snapshot.usedFraction,
                          value: String(format: "%.1f / %.0f Go",
                                        memory.snapshot.usedGB, memory.snapshot.totalGB),
                          gradient: [Color(red: 0.62, green: 0.25, blue: 0.95),
                                     Color(red: 0.82, green: 0.38, blue: 0.98)])
            }

            if display.showClaude || display.showKimi {
                divider
                VStack(alignment: .leading, spacing: 18) {
                    if display.showClaude {
                        providerBlock(name: "Claude Code", state: claude.state, color: Self.claudeColor,
                                      rows: [("Fenêtre 5 h", claude.state.secondary),
                                             ("Fenêtre 7 j", claude.state.primary)])
                    }
                    if display.showKimi {
                        providerBlock(name: "Kimi Code", state: kimi.state, color: Self.kimiColor,
                                      rows: [("Fenêtre 5 h", kimi.state.secondary),
                                             ("Mensuel", kimi.state.primary)])
                    }
                }
            }

            divider
            VStack(spacing: 4) {
                toggleRow(title: "Afficher Claude Code", isOn: $display.showClaude)
                toggleRow(title: "Afficher Kimi Code", isOn: $display.showKimi)
                toggleRow(title: "Démarrage au login", isOn: Binding(
                    get: { launchAgent.isEnabled },
                    set: { launchAgent.setEnabled($0) }
                ))

                if let error = launchAgent.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                actionRow(icon: "gearshape", title: "Ouvrir au démarrage") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }

                actionRow(icon: "power", title: "Quitter Cleo") {
                    Text("⌘ Q")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } action: {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(20)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(Self.background)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleo")
                    .font(.system(size: 17, weight: .semibold))
                Text(mood)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.55, green: 0.62, blue: 0.95))
            }
            Spacer()
        }
    }

    /// Humeur de Cleo selon la charge système et la consommation des quotas affichés.
    private var mood: String {
        let worstQuota = [display.showClaude ? claude.state.mostCritical : nil,
                          display.showKimi ? kimi.state.mostCritical : nil]
            .compactMap { $0?.percent }.max() ?? 0
        if memory.snapshot.pressure == .critical || cpu.usage > 0.9 || worstQuota >= 95 {
            return "Cleo a chaud…"
        }
        if memory.snapshot.pressure == .warning || cpu.usage > 0.75 || worstQuota >= 85 {
            return "Ça s'agite un peu"
        }
        return "En pleine forme !"
    }

    // MARK: - Métriques système

    private func metricRow(label: String, fraction: Double, value: String, gradient: [Color]) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 8)
            Text(value)
                .font(.system(size: 12))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    // MARK: - Quotas

    private func providerBlock(name: String, state: QuotaState, color: Color,
                               rows: [(String, QuotaWindow?)]) -> some View {
        let critical = state.mostCritical
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: min(max((critical?.percent ?? 0) / 100, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                if let critical {
                    Text("\(critical.remainingText) restantes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                } else {
                    Text(state.statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.1.map { "\(Int($0.percent.rounded())) %" } ?? "—")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Pièces communes

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 16)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(red: 0.36, green: 0.35, blue: 0.95))
        }
        .padding(.vertical, 4)
    }

    private func actionRow<Trailing: View>(icon: String, title: String,
                                           @ViewBuilder trailing: () -> Trailing,
                                           action: @escaping () -> Void) -> some View {
        let trailingView = trailing()
        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                trailingView
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
