// Renders the Mygra 3.0 store backgrounds. Usage: swiftc -O bg.swift -o /tmp/mygra-bg && /tmp/mygra-bg <outdir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Optional: bg <outdir> <name> <w> <h> <centreX 0-1> <centreY 0-1> <ring diameter px> renders one custom canvas
// (the App Store header and search assets centre the glow and halo on their art safe areas).
let A = CommandLine.arguments
var sizes: [(String, Int, Int)] = [("iphone", 1320, 2868), ("ipad", 2064, 2752), ("duo-outer", 1398, 2034), ("duo-unfolded", 2853, 2007)]
var custom: (cx: CGFloat, cy: CGFloat, ring: CGFloat)? = nil
if A.count > 7 { sizes = [(A[2], Int(A[3])!, Int(A[4])!)]; custom = (CGFloat(Double(A[5])!), CGFloat(Double(A[6])!), CGFloat(Double(A[7])!)) }
let outDir = A.count > 1 ? A[1] : "."
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
for (name, w, h) in sizes {
    let W = CGFloat(w), H = CGFloat(h)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Core Graphics origin is bottom-left; flip so y grows downward like a design canvas.
    ctx.translateBy(x: 0, y: H); ctx.scaleBy(x: 1, y: -1)
    // Vertical gradient: #FBFAFE top to #ECEAF4 bottom.
    let grad = CGGradient(colorsSpace: space, colors: [rgb(0xFBFAFE), rgb(0xECEAF4)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H), options: [])
    let centre = custom.map { CGPoint(x: W * $0.cx, y: H * $0.cy) } ?? CGPoint(x: W / 2, y: H * 0.45)
    let base = custom?.ring ?? W * 1.25   // ring diameter; the glow and stroke scale with it
    // Lilac glow, ~35% at the centre fading to nothing at 70% of the width.
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xAEA7FF, 0.35), rgb(0xAEA7FF, 0.14), rgb(0xAEA7FF, 0)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: base * 0.56, options: [])
    // Segmented halo: 8 arcs, 7 degree gaps, one centred at 12 o'clock, ring diameter 1.25x width.
    let radius = base / 2
    let seg = 45.0, gap = 7.0
    ctx.setStrokeColor(rgb(0xAEA7FF, 0.18))
    ctx.setLineWidth(base * 0.0096)
    ctx.setLineCap(.round)
    for i in 0..<8 {
        let mid = -90.0 + Double(i) * seg // -90 degrees is 12 o'clock with y pointing down
        let a0 = (mid - seg / 2 + gap / 2) * .pi / 180, a1 = (mid + seg / 2 - gap / 2) * .pi / 180
        ctx.beginPath()
        ctx.addArc(center: centre, radius: radius, startAngle: a0, endAngle: a1, clockwise: false)
        ctx.strokePath()
    }
    let image = ctx.makeImage()!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png") as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}
