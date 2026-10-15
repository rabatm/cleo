import AppKit

// Test du composite sprite exact (mêmes coordonnées que updateIcon, espace pixel).
let S: CGFloat = 2
let dotW: CGFloat = 4, gapDot: CGFloat = 4
let catH: CGFloat = 23
let frame0 = NSImage(contentsOfFile: "RunCatPlus/CatFrames/frame0.png")!
let catW = catH * (frame0.size.width / frame0.size.height)
let width: CGFloat = 60

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: Int(width * S), pixelsHigh: Int(24 * S),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// fond clair (barre claire)
NSColor(red: 0.98, green: 0.85, blue: 0.95, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width * S, height: 24 * S)).fill()

NSColor.systemGreen.setFill()
NSBezierPath(ovalIn: NSRect(x: 0, y: 2 * S, width: dotW * S, height: dotW * S)).fill()

for i in 0..<3 {
    let img = NSImage(contentsOfFile: "RunCatPlus/CatFrames/frame\(i * 2).png")!
    img.draw(in: NSRect(x: (dotW + gapDot) * S + CGFloat(i) * 8 * S,
                        y: ((24 - catH) / 2) * S,
                        width: catW * S, height: catH * S))
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "render_cat.png"))
print("OK")
