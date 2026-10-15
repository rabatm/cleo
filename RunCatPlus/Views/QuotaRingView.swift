import SwiftUI

/// Anneau de quota : arc extérieur = fenêtre principale (7 j),
/// arc intérieur = fenêtre secondaire (5 h), compte à rebours au centre.
struct QuotaRingView: View {
    var state: QuotaState
    var providerName: String = "Claude Code"
    var primaryLabel: String = "7 j"
    var secondaryLabel: String = "5 h"
    /// Pastille de marque à midi pour distinguer les providers d'un coup d'œil.
    var brandColor: Color = .orange
    var size: CGFloat = 20

    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 1.2, dy: 1.2)
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

                // Pastille de marque à midi (hors de l'anneau, ne gêne pas la lecture)
                let dotRadius: CGFloat = 1.6
                let dot = Circle().path(in: CGRect(x: center.x - dotRadius,
                                                   y: rect.minY - dotRadius - 0.8,
                                                   width: dotRadius * 2, height: dotRadius * 2))
                context.fill(dot, with: .color(brandColor))

                // Fonds des anneaux (très discret)
                context.stroke(Circle().path(in: rect),
                               with: .color(.primary.opacity(0.15)), lineWidth: 2)
                let inner = CGRect(x: rect.midX - rect.width * 0.30, y: rect.midY - rect.width * 0.30,
                                   width: rect.width * 0.60, height: rect.height * 0.60)
                context.stroke(Circle().path(in: inner),
                               with: .color(.primary.opacity(0.12)), lineWidth: 1.4)

                // Arcs de consommation (midi, sens horaire)
                if let primary = state.primary {
                    drawArc(context: &context, center: center, radius: rect.width / 2,
                            percent: primary.percent, lineWidth: 2, color: color(for: primary.percent))
                }
                if let secondary = state.secondary {
                    drawArc(context: &context, center: center, radius: inner.width / 2,
                            percent: secondary.percent, lineWidth: 1.4, color: color(for: secondary.percent))
                }
            }

            // Compte à rebours avant RAZ de la limite la plus consommée
            Text(state.mostCritical?.countdownText ?? "—")
                .font(.system(size: size * 0.30, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
        .padding(.top, 3) // espace pour la pastille de marque
        .help(tooltip)
    }

    private func drawArc(context: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                         percent: Double, lineWidth: CGFloat, color: Color) {
        let clamped = min(max(percent, 0), 100)
        guard clamped > 0.5 else { return }
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + clamped * 3.6)
        let path = Path { p in
            p.addArc(center: center, radius: radius,
                     startAngle: start, endAngle: end, clockwise: false)
        }
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    private func color(for percent: Double) -> Color {
        switch percent {
        case ..<60: return .green
        case ..<85: return .orange
        default: return .red
        }
    }

    private var tooltip: String {
        var lines = [providerName]
        if let primary = state.primary {
            lines.append("\(primaryLabel) : \(Int(primary.percent)) % — RAZ dans \(primary.countdownText)")
        }
        if let secondary = state.secondary {
            lines.append("\(secondaryLabel) : \(Int(secondary.percent)) % — RAZ dans \(secondary.countdownText)")
        }
        if state.primary == nil && state.secondary == nil {
            lines.append(state.statusText)
        }
        return lines.joined(separator: "\n")
    }
}
