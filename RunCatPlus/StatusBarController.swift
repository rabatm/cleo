import AppKit
import SwiftUI

/// Gère l'icône de la barre des menus avec NSStatusItem — le mécanisme
/// historique de RunCat, fiable contrairement au label SwiftUI de MenuBarExtra.
/// L'image est recomposée à 30 im/s : chat animé + pastille mémoire + anneaux.
/// Thread principal uniquement (callbacks AppKit + timers), pas de @MainActor :
/// l'exécuteur Swift Concurrency du main actor ne fonctionne pas dans ce binaire.
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private weak var appState: AppState?
    private var displayTimer: Timer?
    private var ringCache: [String: NSImage] = [:]
    private var popover: NSPopover?

    // Géométrie de l'icône composée (points, échelle 2 en rendu).
    private let barHeight: CGFloat = 24
    private let catSize = NSSize(width: 30, height: 23)
    private let ringSize: CGFloat = 20

    func install(appState: AppState) {
        self.appState = appState
        _ = CatSprite.load()
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.imagePosition = .imageOnly
        updateIcon()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            // Timer programmé sur le runloop principal : rappel sur le thread
            // principal, appel direct (les sauts @MainActor sont inertes ici).
            self?.updateIcon()
        }
    }

    // MARK: - Clic

    @objc private func togglePopover() {
        guard let appState, let button = statusItem.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let content = MenuContentView(cpu: appState.cpu,
                                      memory: appState.memory,
                                      claude: appState.claude,
                                      kimi: appState.kimi)
        let hosting = NSHostingController(rootView: content)
        hosting.preferredContentSize = NSSize(width: 300, height: 400)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - Rendu de l'icône

    private var isDark: Bool {
        let appearance = statusItem.button?.effectiveAppearance ?? NSAppearance.currentDrawing()
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func updateIcon() {
        guard let button = statusItem.button, let appState else { return }
        let dark = isDark

        // Largeur totale : pastille (4) + espaces + chat + 2 anneaux + intercalaires.
        let dotWidth: CGFloat = 4, gapAfterDot: CGFloat = 4
        let gapBeforeRing: CGFloat = 6, gapBetweenRings: CGFloat = 4
        let width = dotWidth + gapAfterDot
            + catSize.width + gapBeforeRing
            + ringSize + gapBetweenRings + ringSize
        let size = NSSize(width: width, height: barHeight)

        // Un seul bitmap explicite + NSGraphicsContext : fiable partout,
        // contrairement au trio lockFocus/draw(at:)/NSImage à répétitions
        // (comportement erratique selon l'échelle des représentations).
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        // Espace utilisateur en PIXELS (rep.size non défini) : c'est la
        // combinaison qui se comporte de façon déterministe. Validé par le
        // harnais reproduisant cette composition à l'identique.
        let S: CGFloat = 2
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        // Origine en bas à gauche, y vers le haut (contexte non retourné).

        // Pastille de pression mémoire (à gauche, bas de ligne)
        memoryDotColor(appState.memory.snapshot.pressure).setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 2 * S, width: dotWidth * S, height: dotWidth * S)).fill()

        // Chat animé (sprites PNG) ; repli vectoriel si ressources absentes.
        let speed = max(appState.cpu.usage, 0.06) // l'anim ne gèle jamais
        let phase = Date().timeIntervalSince1970 / strideDuration(speed: speed)
        if let frame = CatSprite.frame(at: Int(phase.truncatingRemainder(dividingBy: 1)
                                                * Double(CatSprite.frameCount))) {
            let catH = catSize.height
            let catW = catH * CatSprite.aspect
            frame.draw(in: NSRect(x: (dotWidth + gapAfterDot) * S,
                                  y: ((barHeight - catH) / 2) * S,
                                  width: catW * S, height: catH * S))
        } else {
            CatPainter.draw(phase: phase, speed: speed,
                            color: dark ? .white : .black,
                            unit: catSize.height * S / CatPainter.designBox,
                            origin: NSPoint(x: (dotWidth + gapAfterDot) * S,
                                            y: ((barHeight - catSize.height) / 2) * S))
        }

        // Anneaux de quota (rendus SwiftUI cachés), composites par draw(in:)
        let ringH = ringSize + 3 // hauteur rendue : cadre + pastille de marque
        let ringY = (barHeight - ringH) / 2
        var ringX = dotWidth + gapAfterDot + catSize.width + gapBeforeRing
        let claudeRing = ringImage(
            state: appState.claude.state, providerName: "Claude Code",
            primaryLabel: "7 j", secondaryLabel: "5 h",
            brandColor: NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1), // coral Claude
            dark: dark)
        claudeRing.draw(in: NSRect(x: ringX * S, y: ringY * S,
                                  width: ringSize * S, height: ringH * S))
        ringX += ringSize + gapBetweenRings
        let kimiRing = ringImage(
            state: appState.kimi.state, providerName: "Kimi Code",
            primaryLabel: "Mensuel", secondaryLabel: "5 h",
            brandColor: NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1), // bleu Kimi
            dark: dark)
        kimiRing.draw(in: NSRect(x: ringX * S, y: ringY * S,
                                 width: ringSize * S, height: ringH * S))

        NSGraphicsContext.restoreGraphicsState()
        // NSImage en points + rep 2x : la barre des menus l'affiche en Retina.
        let icon = NSImage(size: size)
        icon.addRepresentation(rep)
        button.image = icon
    }

    private func strideDuration(speed: Double) -> Double {
        // Secondes par cycle complet de foulée, ton très posé : 2,2 s au repos
        // (marche tranquille) → 0,2 s à plein régime. À 15 % CPU : ~2 s.
        max(0.2, 2.2 - speed * 2.0)
    }

    private func memoryDotColor(_ pressure: MemoryPressure) -> NSColor {
        switch pressure {
        case .normal, .unknown: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    /// Rend une QuotaRingView en NSImage, avec cache (le texte du compte à
    /// rebours change rarement, on ne re-rend pas 60×/s pour rien).
    private func ringImage(state: QuotaState, providerName: String,
                           primaryLabel: String, secondaryLabel: String,
                           brandColor: NSColor, dark: Bool) -> NSImage {
        let key = "\(providerName)|\(Int(state.primary?.percent ?? -1))|\(Int(state.secondary?.percent ?? -1))"
            + "|\(state.mostCritical?.countdownText ?? "")|\(dark ? "d" : "l")"
        if let hit = ringCache[key] { return hit }
        let view = QuotaRingView(state: state,
                                 providerName: providerName,
                                 primaryLabel: primaryLabel,
                                 secondaryLabel: secondaryLabel,
                                 brandColor: Color(nsColor: brandColor),
                                 size: ringSize)
            .environment(\.colorScheme, dark ? .dark : .light)
        // On est déjà sur le thread principal (appel depuis le timer du
        // runloop) : assumeIsolated est une assertion statique, sans saut
        // d'exécuteur — fiable contrairement au vrai @MainActor.
        let image = MainActor.assumeIsolated { () -> NSImage in
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            return renderer.nsImage ?? NSImage(size: NSSize(width: ringSize, height: ringSize + 3))
        }
        if ringCache.count > 200 { ringCache.removeAll() }
        ringCache[key] = image
        return image
    }
}
