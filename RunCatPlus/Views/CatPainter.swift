import AppKit

/// Dessin du chat, deux poses :
/// - course (speed >= seuil) : foulée articulée, voûte du dos, queue en S
/// - assise (CPU au repos) : pattes avant droites, arrière-train posé,
///   queue enroulée autour des pattes, ondulation lente de la queue
///
/// `draw` dessine dans le contexte courant, y vers le haut, boîte 22×22,
/// le sol à y=3. `catImage` encapsule dans une NSImage pour la barre.
enum CatPainter {
    static let designBox: CGFloat = 22
    static let groundY: CGFloat = 3
    /// En dessous de cette vitesse, le chat s'assied.
    static let sitThreshold: Double = 0.04

    // MARK: - Cœur de dessin (contexte courant, y vers le haut)

    /// - unit : taille en points d'une unité de design
    /// - origin : coin BAS-GAUCHE de la boîte 22×22 dans le contexte courant
    static func draw(phase: Double, speed: Double, color: NSColor,
                     unit u: CGFloat, origin o: NSPoint) {
        if speed < Self.sitThreshold {
            drawSitting(phase: phase, color: color, unit: u, origin: o)
        } else {
            drawRunning(phase: phase, speed: speed, color: color, unit: u, origin: o)
        }
        color.setFill()
        color.setStroke()
    }

    // MARK: - Pose course

    private static func drawRunning(phase: Double, speed: Double, color: NSColor,
                                    unit u: CGFloat, origin o: NSPoint) {
        let angle = phase * 2 * .pi
        let bob = abs(sin(angle)) * (0.4 + speed * 0.5) * u
        let lean = speed * 0.9 * u
        // Contenu x 2…20.3 étiré pour remplir la boîte (finit les marges mortes)
        let sx: CGFloat = 22.0 / 18.3
        func px(_ x: CGFloat) -> CGFloat { o.x + (x - 2.0) * sx * u }
        func py(_ y: CGFloat) -> CGFloat { o.y + y * u }
        color.setFill()
        color.setStroke()

        // Pattes : hanches sous le corps, pieds au sol
        let legs: [(x: CGFloat, off: CGFloat)] = [
            (8.0, 0), (9.7, .pi), (13.3, .pi), (15.0, 0),
        ]
        for leg in legs {
            let a = angle + leg.off
            let strideX = sin(a) * (1.7 + speed * 1.1) * sx * u
            let lift = max(0, cos(a)) * (2.1 + speed * 1.5) * u
            let hip = NSPoint(x: px(leg.x), y: py(9.4) - bob)
            var foot = NSPoint(x: px(leg.x), y: py(Self.groundY))
            foot.x += strideX; foot.y += lift
            let knee = NSPoint(x: (hip.x + foot.x) / 2 - lift * 0.3,
                               y: (hip.y + foot.y) / 2)
            let limb = NSBezierPath()
            limb.move(to: hip)
            limb.curve(to: foot, controlPoint1: knee, controlPoint2: knee)
            limb.lineWidth = 1.7 * u
            limb.lineCapStyle = .round
            limb.stroke()
        }

        // Corps : voûte douce, poitrine pleine, arrière fuselé
        let body = NSBezierPath()
        body.move(to: NSPoint(x: px(7.0), y: py(9.8) - bob))
        body.curve(to: NSPoint(x: px(14.9), y: py(10.4) - bob),
                   controlPoint1: NSPoint(x: px(9.2), y: py(9.2) - bob),
                   controlPoint2: NSPoint(x: px(13.0), y: py(9.5) - bob))
        body.curve(to: NSPoint(x: px(15.4), y: py(12.3) - bob),
                   controlPoint1: NSPoint(x: px(15.7), y: py(11.4) - bob),
                   controlPoint2: NSPoint(x: px(15.7), y: py(12.0) - bob))
        body.curve(to: NSPoint(x: px(7.4), y: py(12.6) - bob),
                   controlPoint1: NSPoint(x: px(12.6), y: py(13.7) - bob),
                   controlPoint2: NSPoint(x: px(9.6), y: py(13.5) - bob))
        body.curve(to: NSPoint(x: px(7.0), y: py(9.8) - bob),
                   controlPoint1: NSPoint(x: px(6.6), y: py(11.4) - bob),
                   controlPoint2: NSPoint(x: px(6.5), y: py(10.4) - bob))
        body.close()
        body.fill()

        // Queue : longue courbe en S, ondulation portée par le mouvement
        let sway = sin(angle) * (0.9 + speed * 0.5) * u
        func tp(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat = 0) -> NSPoint {
            NSPoint(x: px(x), y: py(y) - bob + s)
        }
        let tail = NSBezierPath()
        tail.move(to: tp(7.2, 12.0))
        tail.curve(to: tp(4.3, 15.2, sway * 0.4),
                   controlPoint1: tp(5.2, 13.2),
                   controlPoint2: tp(4.0, 13.8, sway * 0.15))
        tail.curve(to: tp(5.0, 18.0, sway * 0.9),
                   controlPoint1: tp(3.7, 16.8, sway * 0.5),
                   controlPoint2: tp(3.9, 17.9, sway * 0.7))
        tail.lineWidth = 2.5 * u
        tail.lineCapStyle = .round
        tail.stroke()

        // Tête : ronde, portée haut, légèrement penchée vers l'avant
        var head = NSPoint(x: px(17.3), y: py(12.6))
        head.x += lean * 0.15; head.y += -bob - lean * 0.3
        let headR = 3.0 * u
        NSBezierPath(ovalIn: NSRect(x: head.x - headR, y: head.y - headR,
                                    width: headR * 2, height: headR * 2)).fill()

        // Oreilles : hautes, écartées, pointes légèrement arrondies
        let earTilt = speed * 0.5 * u
        for sign in [-CGFloat(1), CGFloat(1)] {
            let ear = NSBezierPath()
            let inner = NSPoint(x: head.x + sign * 0.9 * u, y: head.y + 1.3 * u)
            let apex = NSPoint(x: head.x + sign * 1.7 * u + earTilt, y: head.y + 3.2 * u)
            let outer = NSPoint(x: head.x + sign * 2.6 * u, y: head.y + 1.0 * u)
            ear.move(to: inner)
            ear.line(to: apex)
            ear.curve(to: outer, controlPoint1: NSPoint(x: apex.x + sign * 0.6 * u,
                                                        y: apex.y - 0.6 * u),
                      controlPoint2: NSPoint(x: outer.x, y: outer.y + 0.6 * u))
            ear.close()
            ear.fill()
        }
    }

    // MARK: - Pose assise (repos)

    private static func drawSitting(phase: Double, color: NSColor,
                                    unit u: CGFloat, origin o: NSPoint) {
        let angle = phase * 2 * .pi
        // Respiration discrète + ondulation lente de la queue
        let breathe = sin(angle) * 0.15 * u
        let sway = sin(angle) * 0.5 * u
        // Contenu x 7.5…19.4 centré dans la boîte (chat assis plus compact)
        let shift: CGFloat = (22.0 - 11.9) / 2 - 7.5
        func px(_ x: CGFloat) -> CGFloat { o.x + (x + shift) * u }
        func py(_ y: CGFloat) -> CGFloat { o.y + y * u }
        color.setFill()
        color.setStroke()

        // Arrière-train : grosse cuisse posée au sol
        NSBezierPath(ovalIn: NSRect(x: px(7.5), y: py(3), width: 6.5 * u, height: 7.2 * u + breathe)).fill()

        // Buste droit, poitrine haute
        let chest = NSBezierPath(roundedRect: NSRect(x: px(11.8), y: py(6.2),
                                                     width: 3.4 * u, height: 6.2 * u + breathe),
                                 xRadius: 1.7 * u, yRadius: 1.7 * u)
        chest.fill()

        // Pattes avant : deux colonnes droites jusqu'au sol
        for x in [12.6, 14.0] {
            let leg = NSBezierPath()
            leg.move(to: NSPoint(x: px(x), y: py(7.0)))
            leg.line(to: NSPoint(x: px(x), y: py(Self.groundY)))
            leg.lineWidth = 1.6 * u
            leg.lineCapStyle = .round
            leg.stroke()
        }

        // Tête : haute et fière, légèrement penchée
        let head = NSPoint(x: px(16.6), y: py(13.0) + breathe * 0.5)
        let headR = 2.9 * u
        NSBezierPath(ovalIn: NSRect(x: head.x - headR, y: head.y - headR,
                                    width: headR * 2, height: headR * 2)).fill()

        // Oreilles bien droites
        for sign in [-CGFloat(1), CGFloat(1)] {
            let ear = NSBezierPath()
            let inner = NSPoint(x: head.x + sign * 0.8 * u, y: head.y + 1.2 * u)
            let apex = NSPoint(x: head.x + sign * 1.5 * u, y: head.y + 3.3 * u)
            let outer = NSPoint(x: head.x + sign * 2.4 * u, y: head.y + 0.9 * u)
            ear.move(to: inner)
            ear.line(to: apex)
            ear.curve(to: outer, controlPoint1: NSPoint(x: apex.x + sign * 0.5 * u,
                                                        y: apex.y - 0.5 * u),
                      controlPoint2: NSPoint(x: outer.x, y: outer.y + 0.5 * u))
            ear.close()
            ear.fill()
        }

        // Queue enroulée autour des pattes, pointe qui ondule
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: px(8.2), y: py(4.5)))
        tail.curve(to: NSPoint(x: px(15.2), y: py(3.2)),
                   controlPoint1: NSPoint(x: px(9.5), y: py(2.4)),
                   controlPoint2: NSPoint(x: px(12.5), y: py(2.2)))
        tail.curve(to: NSPoint(x: px(16.4), y: py(4.2) + sway * 0.3),
                   controlPoint1: NSPoint(x: px(16.2), y: py(3.4)),
                   controlPoint2: NSPoint(x: px(16.3), y: py(3.6) + sway * 0.2))
        tail.lineWidth = 2.4 * u
        tail.lineCapStyle = .round
        tail.stroke()
    }

    // MARK: - Image autonome (utilisée par CatFrames / la barre des menus)

    static func catImage(phase: Double, speed: Double, color: NSColor,
                         size: NSSize = NSSize(width: 30, height: 23),
                         scale: CGFloat = 2) -> NSImage {
        let image = NSImage(size: size)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else {
            return image
        }
        image.addRepresentation(rep)
        image.lockFocus()

        // Coordonnées origine en haut à gauche, y vers le bas
        let flip = NSAffineTransform()
        flip.translateX(by: 0, yBy: size.height * scale)
        flip.scaleX(by: 1, yBy: -1)
        flip.concat()

        let u = (size.height * scale) / Self.designBox
        draw(phase: phase, speed: speed, color: color, unit: u, origin: .zero)
        image.unlockFocus()
        return image
    }
}

/// Cache de frames : 8 phases × vitesses quantifiées × 2 teintes.
/// (Non utilisé par le rendu vectoriel direct — conservé pour réutilisation.)
enum CatFrames {
    private static var cache: [String: NSImage] = [:]
    private static let frameCount = 8

    static func image(phase rawPhase: Double, speed: Double, dark: Bool) -> NSImage {
        let bucket = Int((rawPhase.truncatingRemainder(dividingBy: 1)) * Double(frameCount))
            .clamped(to: 0...frameCount - 1)
        let speedBin = Int((speed * 20).rounded())  // pas de 0.05
        let key = "\(bucket)-\(speedBin)-\(dark ? "d" : "l")"
        if let hit = cache[key] { return hit }
        let image = CatPainter.catImage(
            phase: Double(bucket) / Double(frameCount),
            speed: Double(speedBin) / 20,
            color: dark ? .white : .black)
        if cache.count < 500 { cache[key] = image }
        return image
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
