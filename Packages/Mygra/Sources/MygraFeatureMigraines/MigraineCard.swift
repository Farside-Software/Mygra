//
//  MigraineCard.swift
//  MygraFeatureMigraines
//
//  The one card look for the migraine screens (shared surface, icon + title header, Brand.Space
//  padding) and the layout pieces the detail page and the sheets use to sit around the
//  iPhone Duo's hinge.
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

/// A titled card: a symbol-and-title header (with an optional quiet trailing control) over
/// the content, on the shared card surface.
struct MigraineCard<Content: View, Trailing: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let trailing: Trailing
    let content: Content

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color = .mygraPurple,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Brand.Space.sm)
                trailing
            }
            content
        }
        .padding(Brand.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// A small borderless header action ("Add", "Update"): present, but never competing with
/// the page's one primary action.
struct MigraineQuietAction: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .mygraPurple
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.lightImpact()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .tint(tint)
    }
}

// MARK: - Layout

/// Width rules shared by the detail page, the calendar and the sheets.
enum MigraineLayout {
    static let singleColumnMaxWidth: CGFloat = 760
    static let wideMaxWidth: CGFloat = 1200

    /// Two panes: the unfolded Duo (once the window is wide enough to hold two phone-width
    /// columns) or a regular-width iPad window.
    ///
    /// The decision uses only what cannot change when the content switches between one and
    /// two panes: the container's width, whether the device is a Duo (a constant), and the
    /// size class. It deliberately ignores safe-area insets and reserved regions, which the
    /// switch itself (toolbar items, nested navigation, inline search) can alter. A hysteresis
    /// band around the threshold keeps a width that hovers near it from flipping the layout.
    static func isWide(width: CGFloat, isDuo: Bool, isRegularWidth: Bool, wasWide: Bool) -> Bool {
        guard isDuo || isRegularWidth else { return false }
        let threshold: CGFloat = isDuo ? 600 : 700
        return width >= (wasWide ? threshold - 40 : threshold)
    }

    static func isWide(_ probe: LayoutProbe, isRegularWidth: Bool, wasWide: Bool = false) -> Bool {
        isWide(width: probe.width, isDuo: PhoneDuo.isDuo || probe.hasFold, isRegularWidth: isRegularWidth, wasWide: wasWide)
    }

    /// The gap between two panes; wider while a fold is active so the hinge sits in it.
    static func columnGap(_ probe: LayoutProbe) -> CGFloat {
        probe.isFoldActive ? Brand.Space.xxl * 2 : Brand.Space.xl
    }
}

/// Two equal columns for fixed groups of cards, so no card jumps between sides.
struct MigraineTwoColumns: Layout {
    var spacing: CGFloat

    private func columnWidth(_ width: CGFloat) -> CGFloat { max((width - spacing) / 2, 0) }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        let column = columnWidth(width)
        let heights = subviews.prefix(2).map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = columnWidth(bounds.width)
        for (index, subview) in subviews.prefix(2).enumerated() {
            let x = bounds.minX + CGFloat(index) * (column + spacing)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: column, height: nil))
        }
    }
}

extension View {
    /// Hides the scroll view's top edge effect (Duo detail pages start flush with the top).
    @ViewBuilder
    func migraineTopEdgeEffectHidden(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .top)
        } else {
            self
        }
    }

    /// Sheet sizing for the full-height editors: a page, so on the unfolded Duo they span both
    /// halves (the editors split into two panes there) instead of a narrow strip beside the hinge.
    func migraineEditorSheet() -> some View {
        presentationSizing(.page)
    }
}
#endif
