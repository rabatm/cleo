import AppKit

/// Charge les 8 frames du chat (PNG du bundle) et fournit la frame courante.
/// Chat blanc au contour foncé : visible sur barre claire ET sombre, pas de
/// teinte à appliquer. Au repos (speed ~0), l'animation continue doucement
/// au lieu de geler (l'art fourni n'a pas de pose assise).
enum CatSprite {
    static let maxFrames = 64
    private static var frames: [NSImage] = []
    private static var frameAspect: CGFloat = 1

    static var frameCount: Int { frames.count }

    /// Chargement paresseux : toutes les ressources frame<N>.png du bundle,
    /// jusqu'à la première manquante. Retourne false si aucune n'est trouvée.
    @discardableResult
    static func load() -> Bool {
        guard frames.isEmpty else { return !frames.isEmpty }
        var loaded: [NSImage] = []
        for i in 0..<maxFrames {
            guard let url = Bundle.main.url(forResource: "frame\(i)", withExtension: "png"),
                  let img = NSImage(contentsOf: url) else {
                break
            }
            loaded.append(img)
        }
        frames = loaded
        if let first = frames.first {
            frameAspect = first.size.width / first.size.height
        }
        return !frames.isEmpty
    }

    static var isLoaded: Bool { !frames.isEmpty }

    static var aspect: CGFloat { frameAspect }

    static func frame(at index: Int) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[index % frames.count]
    }
}
