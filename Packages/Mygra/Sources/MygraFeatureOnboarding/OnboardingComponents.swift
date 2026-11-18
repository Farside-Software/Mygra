//
//  OnboardingComponents.swift
//  MygraFeatureOnboarding
//
//  The page building blocks shared by every onboarding step: the hero header (a tinted
//  symbol tile, title, subtitle), the feature row, the feature card, and `OnboardingColumns`,
//  which keeps content off an unfolded iPhone Duo's hinge.
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

// MARK: - Header

/// Hero symbol on a tinted tile, then the title and subtitle.
struct OnboardingHeader: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// The tighter hero for short windows (the folded iPhone Duo, iPhone landscape).
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var symbolBox: CGFloat = 96
    @ScaledMetric(relativeTo: .largeTitle) private var compactSymbolSize: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var compactSymbolBox: CGFloat = 56

    var body: some View {
        let box = compact ? compactSymbolBox : symbolBox
        VStack(spacing: compact ? Brand.Space.sm : Brand.Space.lg) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? compactSymbolSize : symbolSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
                .frame(width: box, height: box)
                .background(
                    RoundedRectangle(cornerRadius: box * 0.26, style: .continuous)
                        .fill(tint.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: box * 0.26, style: .continuous)
                        .strokeBorder(.quaternary)
                )
                .accessibilityHidden(true)

            VStack(spacing: compact ? Brand.Space.xs : Brand.Space.sm) {
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            bounce.toggle()
        }
    }
}

// MARK: - Feature row

/// A tinted glyph, a title and a one-line detail. One accessibility element.
struct OnboardingFeatureRow: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var compact = false

    @ScaledMetric(relativeTo: .body) private var glyphBox: CGFloat = 36

    var body: some View {
        HStack(alignment: .center, spacing: Brand.Space.md) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: glyphBox, height: glyphBox)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                        .fill(tint.opacity(0.18))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Brand.Space.sm)
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, compact ? Brand.Space.sm + 2 : Brand.Space.md)
        .accessibilityElement(children: .combine)
    }
}

/// The card that holds a page's feature rows.
struct OnboardingFeatureCard<Rows: View>: View {
    private let rows: Rows

    // The rows are built here, once, on the main actor (not in a closure the layout may call
    // later): `ViewThatFits` measures its alternatives on SwiftUI's async renderer, and a
    // main-actor closure evaluated there trips libdispatch's queue assertion.
    init(@ContentBuilder rows: () -> Rows) {
        self.rows = rows()
    }

    var body: some View {
        VStack(spacing: 0) { rows }
            .frame(maxWidth: .infinity)
            .cardSurface()
    }
}

/// An inset divider between feature rows.
struct OnboardingRowDivider: View {
    var body: some View {
        Divider().padding(.leading, Brand.Space.lg)
    }
}

// MARK: - Fold-aware columns

/// Stacks a page's header over its body; on an unfolded iPhone Duo puts the header in the
/// leading half and the body in the trailing half, with a gap around the hinge.
struct OnboardingColumns<Lead: View, Trail: View>: View {
    let probe: LayoutProbe
    private let lead: Lead
    private let trail: Trail

    init(probe: LayoutProbe, @ContentBuilder lead: () -> Lead, @ContentBuilder trail: () -> Trail) {
        self.probe = probe
        self.lead = lead()
        self.trail = trail()
    }

    var body: some View {
        if let split = OnboardingSplit(probe) {
            HStack(spacing: 0) {
                lead
                    .padding(.horizontal, Brand.Space.lg)
                    .frame(width: split.leadingWidth)
                Spacer(minLength: 0)
                // The card (and, below it, the buttons) fill the half's readable width, the same
                // on every page.
                trail
                    .frame(maxWidth: Brand.readableWidth)
                    .padding(.horizontal, Brand.Space.lg)
                    .frame(width: split.trailingWidth)
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Brand.Space.xl) {
                lead
                trail
            }
        }
    }
}

/// The two column widths either side of a vertical hardware fold.
struct OnboardingSplit {
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    /// Distance from the container's leading edge to where the trailing column starts.
    let trailingOffset: CGFloat

    init?(_ probe: LayoutProbe) {
        guard probe.hasFold, let x = probe.foldCenterX else { return nil }
        // Keep clear of the hinge: a wider gap while the device is partially open.
        let gap = probe.isFoldActive ? Brand.Space.xxl * 2 : Brand.Space.xxl
        leadingWidth = max(0, x - gap)
        trailingWidth = max(0, probe.width - x - gap)
        trailingOffset = x + gap
    }
}
#endif
