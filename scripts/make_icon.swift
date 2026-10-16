// Genere Cleo/AppIcon.icns depuis une image carree (tuile arrondie sur fond sombre).
// Usage: swift scripts/make_icon.swift <source.png> <out.icns>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("usage: make_icon.swift <source.png> <out.icns>"); exit(1)
}
let w = cg.width, h = cg.height

// Localise la tuile : premiers pixels nettement plus clairs que le fond, sur la ligne/colonne mediane.
let rep = NSBitmapImageRep(cgImage: cg)
func lum(_ x: Int, _ y: Int) -> CGFloat {
    let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    return (c.redComponent + c.greenComponent + c.blueComponent) / 3
}
func edge(_ pts: [(Int, Int)]) -> Int? { pts.firstIndex { lum($0.0, $0.1) > 0.25 } }
let left = edge((0..<w).map { ($0, h / 2) })!
let right = w - 1 - edge((0..<w).reversed().map { ($0, h / 2) })!
let top = edge((0..<h).map { (w / 2, $0) })!
let bottom = h - 1 - edge((0..<h).reversed().map { (w / 2, $0) })!
let inset = 3
let tile = CGRect(x: left + inset, y: top + inset,
                  width: right - left - 2 * inset, height: bottom - top - 2 * inset)
print("tuile:", tile)

func render(_ size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let s = CGFloat(size)
    let dst = CGRect(x: s * 0.0977, y: s * 0.0977, width: s * 0.8046, height: s * 0.8046) // grille Apple 824/1024
    let radius = dst.width * 0.2237
    ctx.addPath(CGPath(roundedRect: dst, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    // CGImage.cropping travaille en coordonnees image (origine en haut a gauche).
    let crop = cg.cropping(to: tile)!
    ctx.draw(crop, in: dst)
    let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return out.representation(using: .png, properties: [:])!
}

let iconset = NSTemporaryDirectory() + "Cleo.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", args[2]]
try! p.run(); p.waitUntilExit()
exit(p.terminationStatus)
