//
//  MygraMark.swift
//  MygraDesignSystem
//
//  The Mygra mark, drawn in code: a calm head held in a halo broken into eight segments.
//  Geometry is the app icon's, on a 1024 grid, so the mark scales cleanly at any size. The
//  colours are fixed and look the same in light and dark mode.
//

import SwiftUI

public struct MygraMark: View {
    /// When `false` the pieces are hidden; flipping it to `true` plays a short, calm entrance
    /// (halo segments one after another, then head, then shoulders). Defaults to fully shown.
    private let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isRevealed: Bool = true) {
        self.isRevealed = isRevealed
    }

    public static let halo = Color(red: 0xAE / 255, green: 0xA7 / 255, blue: 0xFF / 255)
    public static let head = Color(red: 0x6E / 255, green: 0x60 / 255, blue: 0xFF / 255)
    public static let shoulders = Color(red: 0x6C / 255, green: 0xB8 / 255, blue: 0xF4 / 255)

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let k = side / 1024
            ZStack(alignment: .topLeading) {
                ForEach(0..<8, id: \.self) { index in
                    piece(HaloSegment(index: index).fill(Self.halo), order: index, k: k)
                }
                piece(Circle().fill(Self.head)
                    .frame(width: 300 * k, height: 300 * k)
                    .position(x: 512 * k, y: 400 * k), order: 8, k: k, center: CGPoint(x: 512 * k, y: 400 * k))
                piece(ShouldersShape().fill(Self.shoulders), order: 9, k: k, center: CGPoint(x: 512 * k, y: 700 * k))
            }
            .frame(width: side, height: side)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func piece<S: View>(_ shape: S, order: Int, k: CGFloat, center: CGPoint? = nil) -> some View {
        // Shapes are drawn on the 1024 grid and scaled with the frame.
        let content = ZStack {
            if let center {
                shape
                    .scaleEffect(isRevealed ? 1 : 0.9, anchor: UnitPoint(x: center.x / (1024 * k), y: center.y / (1024 * k)))
            } else {
                shape
                    .scaleEffect(isRevealed ? 1 : 0.94, anchor: UnitPoint(x: 0.5, y: 400.0 / 1024))
            }
        }
        return content
            .opacity(isRevealed ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(Double(order) * 0.07), value: isRevealed)
    }
}

/// One of the eight halo segments: inner radius 172, outer 300, 38 degrees wide, one every
/// 45 degrees, the first centred straight up. Centre (512, 400) on the 1024 grid.
private struct HaloSegment: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let k = side / 1024
        let center = CGPoint(x: rect.minX + 512 * k, y: rect.minY + 400 * k)
        let mid = -90.0 + Double(index) * 45
        let start = Angle.degrees(mid - 19)
        let end = Angle.degrees(mid + 19)
        func point(_ radius: CGFloat, _ angle: Angle) -> CGPoint {
            CGPoint(x: center.x + radius * k * CGFloat(cos(angle.radians)),
                    y: center.y + radius * k * CGFloat(sin(angle.radians)))
        }
        var path = Path()
        path.addArc(center: center, radius: 300 * k, startAngle: start, endAngle: end, clockwise: false)
        path.addLine(to: point(172, end))
        path.addArc(center: center, radius: 172 * k, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// A half-disc of radius 280 on a short, softly rounded base: 560 wide, bottom edge at y 870.
private struct ShouldersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let k = side / 1024
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        var path = Path()
        path.move(to: p(232, 850))
        path.addLine(to: p(232, 790))
        path.addArc(center: p(512, 790), radius: 280 * k, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: p(792, 850))
        path.addQuadCurve(to: p(772, 870), control: p(792, 870))
        path.addLine(to: p(252, 870))
        path.addQuadCurve(to: p(232, 850), control: p(232, 870))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Mygra mark") {
    MygraMark()
        .frame(width: 240, height: 240)
        .padding()
}
#endif
