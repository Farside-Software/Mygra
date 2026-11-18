import AppKit
import CoreText
// usage: clock <in.png> <out.png> <oldText> <newText> <left|right>
// Replaces the system clock in a watchOS capture. Calibrates by rendering <oldText> in SF Compact
// until it matches the pixels, then draws <newText> with the same font, size and baseline.
let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let W = src.width, H = src.height
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func makeCtx(_ w: Int, _ h: Int) -> CGContext { CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)! }
let ctx = makeCtx(W, H); ctx.draw(src, in: CGRect(x: 0, y: 0, width: W, height: H))
let px = ctx.data!.bindMemory(to: UInt8.self, capacity: W * H * 4)
func lum(_ x: Int, _ y: Int) -> Int { let i = (y * W + x) * 4; return min(Int(px[i]), Int(px[i + 1]), Int(px[i + 2])) }  // y from top
let left = a[5] == "left"
let xr = left ? 0..<(W / 2) : (W / 2)..<W
var x0 = W, x1 = 0, y0 = H, y1 = 0
for y in 0..<70 { for x in xr where lum(x, y) > 215 { x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) } }
print("ink bbox", x0, y0, x1, y1)
let bw = x1 - x0 + 1, bh = y1 - y0 + 1, pad = 6
// Renders text white on black into a (bw+2pad)x(bh+2pad) buffer with its ink's top-left at (pad+dx, pad+dy).
func render(_ text: String, _ font: CTFont, _ dx: CGFloat, _ dy: CGFloat, anchorRight: Bool = false, width: Int, height: Int) -> ([UInt8], CGRect) {
    let c = makeCtx(width, height)
    c.setFillColor(CGColor(gray: 0, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white]))
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    // ink.minX/minY are relative to the pen origin/baseline (y up).
    let ox = anchorRight ? CGFloat(width - pad) + dx - ink.maxX : CGFloat(pad) + dx - ink.minX
    let oy = CGFloat(height - pad) - dy - ink.maxY
    c.textPosition = CGPoint(x: ox, y: oy)
    CTLineDraw(line, c)
    let d = c.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
    return ((0..<(width * height)).map { d[$0 * 4] }, ink)
}
let rw = bw + pad * 2, rh = bh + pad * 2
var ref = [UInt8](repeating: 0, count: rw * rh)
for y in 0..<rh { for x in 0..<rw { let sx = x0 - pad + x, sy = y0 - pad + y; if sx >= 0, sx < W, sy >= 0, sy < H { ref[y * rw + x] = UInt8(max(0, lum(sx, sy))) } } }
var best: (err: Int, name: String, size: CGFloat, dx: CGFloat, dy: CGFloat) = (Int.max, "", 0, 0, 0)
let names = ["SFCompactText-Medium", "SFCompactText-Semibold", "SFCompactText-Regular", "SFCompactDisplay-Medium", "SFCompactDisplay-Semibold", "SFCompactDisplay-Regular", "SFCompactRounded-Medium", "SFCompactRounded-Semibold"]
for name in names {
    var size: CGFloat = 26
    while size <= 44 {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        for dx in stride(from: CGFloat(-1), through: 1, by: 0.5) { for dy in stride(from: CGFloat(-1), through: 1, by: 0.5) {
            let (buf, _) = render(a[3], font, dx, dy, width: rw, height: rh)
            var e = 0; for i in 0..<(rw * rh) { e += abs(Int(buf[i]) - Int(ref[i])) }
            if e < best.err { best = (e, name, size, dx, dy) }
        } }
        size += 0.5
    }
}
print("best", best, "mean abs err per px", Double(best.err) / Double(rw * rh))
// Erase the old clock (the bar behind it is black) and draw the new one on the same baseline.
let font = CTFontCreateWithName(best.name as CFString, best.size, nil)
let oldLine = CTLineCreateWithAttributedString(NSAttributedString(string: a[3], attributes: [.font: font]))
let oldInk = CTLineGetBoundsWithOptions(oldLine, .useGlyphPathBounds)
let newLine = CTLineCreateWithAttributedString(NSAttributedString(string: a[4], attributes: [.font: font, .foregroundColor: NSColor.white]))
let newInk = CTLineGetBoundsWithOptions(newLine, .useGlyphPathBounds)
// Baseline in top-down pixels: ink top (y0 + dy) corresponds to oldInk.maxY above the baseline.
let baselineTop = CGFloat(y0) + best.dy + oldInk.maxY
let penOldX = CGFloat(x0) + best.dx - oldInk.minX
let oldAdvance = CGFloat(CTLineGetTypographicBounds(oldLine, nil, nil, nil)), newAdvance = CGFloat(CTLineGetTypographicBounds(newLine, nil, nil, nil))
let penNewX = left ? penOldX : penOldX + oldAdvance - newAdvance
ctx.setFillColor(CGColor(gray: 0, alpha: 1))
ctx.fill(CGRect(x: CGFloat(x0 - 4), y: CGFloat(H - y1 - 1 - 4), width: CGFloat(bw + 8), height: CGFloat(bh + 8)))
ctx.textPosition = CGPoint(x: penNewX, y: CGFloat(H) - baselineTop)
CTLineDraw(newLine, ctx)
print("new ink x", penNewX + newInk.minX, "to", penNewX + newInk.maxX)
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
