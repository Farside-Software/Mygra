//
//  DashboardGlanceCards.swift
//  MygraFeatureDashboard
//
//  The free Dashboard cards: this month against last month, the last 30 days, what was
//  logged most this month, and plain start-time counts. Each is computed on device from
//  the migraine log (see `DashboardSummary`) and states counts only: no advice, no
//  predictions, no causes.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

// MARK: - Welcome (nothing logged yet)

/// What a brand-new user sees in place of the statistic cards: what will appear here,
/// not a set of empty boxes.
struct DashboardWelcomeCard: View {
    var body: some View {
        InsightCard(title: String(localized: "Your dashboard fills in as you log"), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: Brand.Space.md) {
                row("chart.bar.fill", String(localized: "This month at a glance"), String(localized: "Counts, length and peak pain, next to last month."))
                row("calendar", String(localized: "The last 30 days"), String(localized: "A small calendar of the days you had a migraine."))
                row("list.bullet", String(localized: "What you log most"), String(localized: "Triggers and medications you record often."))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Color.mygraBlue)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - This month

struct MonthGlanceCard: View {
    let summary: DashboardSummary
    let now: Date

    private var month: String { now.formatted(.dateTime.month(.wide)) }

    var body: some View {
        InsightCard(title: month, systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Brand.Space.md) {
                HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                    Text("\(summary.thisMonth.count)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                        .contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(summary.thisMonth.count == 1 ? "migraine this month" : "migraines this month")
                            .font(.subheadline.weight(.semibold))
                        Text("Last month: \(summary.lastMonth.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: Brand.Space.lg, verticalSpacing: Brand.Space.md) {
                    GridRow {
                        stat(String(localized: "Days with a migraine"), "\(summary.thisMonth.daysWithMigraine)", last: "\(summary.lastMonth.daysWithMigraine)")
                        stat(String(localized: "Average peak pain"), pain(summary.thisMonth.averagePeakPain) ?? "–", last: nil)
                    }
                    GridRow {
                        stat(String(localized: "Average length"), hours(summary.thisMonth.averageDurationHours) ?? "–", last: nil)
                        stat(String(localized: "Longest"), hours(summary.thisMonth.longestDurationHours) ?? "–", last: nil)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: String, _ value: String, last: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            if let last {
                Text("Last month: \(last)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pain(_ value: Double?) -> String? {
        guard let value else { return nil }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) / 10"
    }

    private func hours(_ value: Double?) -> String? {
        guard let value else { return nil }
        if value < 1 { return "\(Int((value * 60).rounded())) min" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) h"
    }
}

// MARK: - Last 30 days

struct LastThirtyDaysCard: View {
    let summary: DashboardSummary
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    var body: some View {
        InsightCard(title: String(localized: "Last 30 days"), systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Brand.Space.md) {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(summary.recentDays.enumerated()), id: \.element.id) { index, day in
                        cell(day, isToday: index == summary.recentDays.count - 1)
                    }
                }
                .accessibilityHidden(true)

                HStack(alignment: .top, spacing: Brand.Space.lg) {
                    footnote(String(localized: "Days with a migraine"), "\(summary.migraineDaysInLast30)")
                    footnote(String(localized: "Longest clear stretch"), String(localized: "\(summary.longestFreeStretchInLast30) days"))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Last 30 days"))
        .accessibilityValue(Text("\(summary.migraineDaysInLast30) days with a migraine. Longest stretch without one: \(summary.longestFreeStretchInLast30) days."))
    }

    private func cell(_ day: DashboardDayMark, isToday: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(day.hadMigraine ? AnyShapeStyle(LinearGradient.mygraHorizontal) : AnyShapeStyle(Color.secondary.opacity(0.14)))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                }
            }
    }

    private func footnote(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Logged most this month

struct MostLoggedCard: View {
    let summary: DashboardSummary

    var body: some View {
        InsightCard(title: String(localized: "Logged most this month"), systemImage: "list.bullet") {
            VStack(alignment: .leading, spacing: Brand.Space.lg) {
                if !summary.topTriggers.isEmpty {
                    list(String(localized: "Triggers you noted"), summary.topTriggers)
                }
                if !summary.topMedications.isEmpty {
                    list(String(localized: "Medications taken"), summary.topMedications)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func list(_ title: String, _ items: [DashboardCount]) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(items) { item in
                HStack {
                    Text(item.name).font(.subheadline).lineLimit(1)
                    Spacer(minLength: Brand.Space.sm)
                    Text("\(item.count)×")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Start-time counts

struct StartPatternsCard: View {
    let summary: DashboardSummary

    private var calendar: Calendar { .current }

    var body: some View {
        InsightCard(title: String(localized: "When they started"), systemImage: "clock") {
            VStack(alignment: .leading, spacing: Brand.Space.lg) {
                VStack(alignment: .leading, spacing: Brand.Space.sm) {
                    ForEach(DashboardDayPart.allCases, id: \.self) { part in
                        bar(label(for: part), count: summary.dayPartCounts[part] ?? 0, maximum: maxPart)
                    }
                }
                weekdays
                Text("Across the \(summary.totalLogged) migraines you have logged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var maxPart: Int { max(summary.dayPartCounts.values.max() ?? 0, 1) }

    private func label(for part: DashboardDayPart) -> String {
        switch part {
        case .night: String(localized: "Night (12 to 5 AM)")
        case .morning: String(localized: "Morning (5 AM to noon)")
        case .afternoon: String(localized: "Afternoon (noon to 5 PM)")
        case .evening: String(localized: "Evening (5 PM to 12)")
        }
    }

    private func bar(_ title: String, count: Int, maximum: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
            }
            GeometryReader { proxy in
                Capsule().fill(Color.secondary.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule().fill(LinearGradient.mygraHorizontal)
                            .frame(width: proxy.size.width * CGFloat(count) / CGFloat(maximum))
                    }
            }
            .frame(height: 6)
        }
    }

    private var weekdays: some View {
        let maximum = max(summary.weekdayCounts.max() ?? 0, 1)
        let symbols = calendar.veryShortWeekdaySymbols
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let count = summary.weekdayCounts[index]
                VStack(spacing: 4) {
                    Text("\(count)").font(.caption2.weight(.semibold)).monospacedDigit()
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(count == 0 ? AnyShapeStyle(Color.secondary.opacity(0.14)) : AnyShapeStyle(LinearGradient.mygraHorizontal))
                        .frame(height: 4 + 36 * CGFloat(count) / CGFloat(maximum))
                    Text(symbols[(summary.firstWeekday - 1 + index) % 7]).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Plus teaser

/// The one calm hint at what Mygra Plus adds, shown to free users in place of several large
/// locked cards. Opens the paywall with the first locked feature as context.
struct PlusTeaserRow: View {
    let features: [PlusFeature]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Brand.Space.md) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(LinearGradient.mygraHorizontal)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mygra Plus").font(.subheadline.weight(.semibold))
                    Text(summaryLine).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.md)
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityHint(Text("Shows what Mygra Plus includes."))
    }

    private var summaryLine: String {
        if features.contains(.assistant) {
            String(localized: "Quick Bits and the Migraine Assistant")
        } else {
            String(localized: "Quick Bits and trigger analysis")
        }
    }
}

// MARK: - Two columns

/// Exactly two children in two top-aligned columns of equal width, with a fixed assignment
/// so no card jumps between columns. A widened gap keeps the hinge between the columns
/// when a fold divides the screen.
struct DashboardTwoColumns: Layout {
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
#endif
