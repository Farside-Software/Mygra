//
//  MygraWidgetsLiveActivity.swift
//  MygraWidgets
//
//  The ongoing-migraine Live Activity: Lock Screen / banner, Dynamic Island (compact,
//  minimal, expanded, and its reduced-width form on iPhone Duo and in landscape), StandBy,
//  and the small family that Apple Watch's Smart Stack and CarPlay use.
//
//  It is shown while someone has a migraine, so it is deliberately quiet: one muted
//  palette on a near-black ground, no severity colour-coding, no flashing, and updates
//  never alert. The pain level and elapsed time are the two things readable at a glance;
//  the buttons (pain -/+, end) run as App Intents in the app without opening it.
//

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI
import MygraCore
import MygraServices

struct MygraWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MigraineActivityAttributes.self) { context in
            MigraineLockScreenView(state: context.state)
                .activityBackgroundTint(ActivityPalette.ground.opacity(0.94))
                .widgetURL(DeepLink.migraine(context.state.migraineID).url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PainFigure(pain: context.state.severity, size: 34)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedFigure(start: context.state.startDate, size: 26, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MigraineControls(pain: context.state.severity, showsEnd: true)
                        .padding(.top, 4)
                }
            } compactLeading: {
                PainBadge(pain: context.state.severity)
            } compactTrailing: {
                CompactTrailing(start: context.state.startDate)
            } minimal: {
                PainBadge(pain: context.state.severity)
            }
            .widgetURL(DeepLink.migraine(context.state.migraineID).url)
            .keylineTint(ActivityPalette.accent.opacity(0.5))
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Palette

private enum ActivityPalette {
    /// Near-black with a touch of indigo; the Lock Screen presentation is dark by default
    /// on iOS 27 and this keeps it dim in a dark room.
    static let ground = Color(red: 0.055, green: 0.055, blue: 0.095)
    static let ink = Color(white: 0.93)
    static let inkSecondary = Color(white: 0.93).opacity(0.62)
    static let control = Color.white.opacity(0.13)
    static let meterEmpty = Color.white.opacity(0.14)
    /// One soft accent for the meter and icon; never changes with severity.
    static let accent = Color.mygraPurple
    static let meterGradient = LinearGradient(
        colors: [Color.mygraBlue.opacity(0.85), Color.mygraPurple.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Lock Screen / banner / StandBy / small family

private struct MigraineLockScreenView: View {
    let state: MigraineActivityAttributes.ContentState

    @Environment(\.activityFamily) private var family
    @Environment(\.isActivityFullscreen) private var isFullscreen
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            if family == .small {
                smallLayout
            } else {
                fullLayout
            }
        }
        .foregroundStyle(ActivityPalette.ink)
        .opacity(isLuminanceReduced ? 0.75 : 1)
    }

    /// Apple Watch Smart Stack and CarPlay: time and pain, no buttons (they do nothing
    /// in CarPlay, and the Watch opens the app on tap).
    private var smallLayout: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile.fill")
                .foregroundStyle(ActivityPalette.accent)
                .accessibilityHidden(true)
            ElapsedFigure(start: state.startDate, size: 20, alignment: .leading)
            Spacer(minLength: 4)
            PainBadge(pain: state.severity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: isFullscreen ? 20 : 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Ongoing Migraine", systemImage: "brain.head.profile.fill")
                        .font(isFullscreen ? .title3.weight(.medium) : .footnote.weight(.medium))
                        .foregroundStyle(ActivityPalette.inkSecondary)
                        .labelStyle(.titleAndIcon)
                    ElapsedFigure(start: state.startDate, size: isFullscreen ? 72 : 34, alignment: .leading)
                }
                Spacer(minLength: 8)
                PainFigure(pain: state.severity, size: isFullscreen ? 72 : 34)
            }
            MigraineControls(pain: state.severity, showsEnd: true, large: isFullscreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Pieces

/// Elapsed time as a running timer. Laid out so the timer text does not claim the whole
/// row (a bare `Text(style: .timer)` expands to the available width).
private struct ElapsedFigure: View {
    let start: Date
    let size: CGFloat
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(start, style: .timer)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .frame(maxWidth: 220, alignment: alignment == .trailing ? .trailing : .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elapsed time")
        .accessibilityValue(Text(start, style: .timer))
    }
}

/// The current pain level as a large number with its caption.
private struct PainFigure: View {
    let pain: Int
    let size: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(pain)")
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("Pain")
                .font(.caption2.weight(.medium))
                .foregroundStyle(ActivityPalette.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pain level \(pain) out of 10")
    }
}

/// Small round pain number for the compact and minimal Dynamic Island presentations.
private struct PainBadge: View {
    let pain: Int

    var body: some View {
        Text("\(pain)")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(ActivityPalette.ink)
            .frame(minWidth: 22, minHeight: 22)
            .background(Circle().fill(ActivityPalette.accent.opacity(0.55)))
            .accessibilityLabel("Pain level \(pain) out of 10")
    }
}

/// Timer on the trailing side of the compact island; the brain mark instead when the
/// island is narrow (landscape, iPhone Duo, or several activities; iOS 27 and later).
private struct CompactTrailing: View {
    let start: Date

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedAwareTrailing(start: start)
        } else {
            CompactTimer(start: start)
        }
    }
}

@available(iOS 27.0, *)
private struct LimitedAwareTrailing: View {
    let start: Date
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimited

    var body: some View {
        if isLimited {
            Image(systemName: "brain.head.profile.fill")
                .foregroundStyle(ActivityPalette.accent)
                .accessibilityLabel("Ongoing migraine")
        } else {
            CompactTimer(start: start)
        }
    }
}

private struct CompactTimer: View {
    let start: Date

    var body: some View {
        Text(start, style: .timer)
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(ActivityPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 54, alignment: .trailing)
            .accessibilityLabel("Elapsed time")
    }
}

/// Pain - / meter / + and the End button. Every button is an App Intent that runs in the
/// app without opening it.
private struct MigraineControls: View {
    let pain: Int
    let showsEnd: Bool
    var large = false

    var body: some View {
        HStack(spacing: large ? 14 : 10) {
            Button(intent: AdjustMigrainePainIntent(delta: -1)) {
                Image(systemName: "minus")
                    .font(.system(size: large ? 22 : 15, weight: .semibold))
                    .frame(width: large ? 56 : 40, height: large ? 56 : 40)
                    .background(Circle().fill(ActivityPalette.control))
            }
            .buttonStyle(.plain)
            .disabled(pain <= 0)
            .accessibilityLabel("Lower pain level")

            PainMeter(pain: pain)
                .frame(height: large ? 14 : 8)

            Button(intent: AdjustMigrainePainIntent(delta: 1)) {
                Image(systemName: "plus")
                    .font(.system(size: large ? 22 : 15, weight: .semibold))
                    .frame(width: large ? 56 : 40, height: large ? 56 : 40)
                    .background(Circle().fill(ActivityPalette.control))
            }
            .buttonStyle(.plain)
            .disabled(pain >= 10)
            .accessibilityLabel("Raise pain level")

            if showsEnd {
                Button(intent: EndMigraineFromActivityIntent()) {
                    Label("End", systemImage: "checkmark")
                        .font((large ? Font.title3 : Font.subheadline).weight(.semibold))
                        .padding(.horizontal, large ? 22 : 14)
                        .frame(height: large ? 56 : 40)
                        .background(Capsule().fill(ActivityPalette.control))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End migraine")
            }
        }
        .foregroundStyle(ActivityPalette.ink)
    }
}

/// Ten quiet segments; filled count equals the pain level. Colour never changes with the
/// level, the number carries the meaning.
private struct PainMeter: View {
    let pain: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...10, id: \.self) { step in
                Capsule()
                    .fill(step <= pain ? AnyShapeStyle(ActivityPalette.meterGradient) : AnyShapeStyle(ActivityPalette.meterEmpty))
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Lock Screen", as: .content, using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: MigraineActivityAttributes()) {
    MygraWidgetsLiveActivity()
} contentStates: {
    MigraineActivityAttributes.ContentState.sample
}
#endif
