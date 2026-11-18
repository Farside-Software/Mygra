//
//  MygraWidgetsDaysSinceLastMigraine.swift
//  MygraWidgets
//
//  Days since the last migraine, from the App Group status the app keeps in sync.
//  Refreshes at local midnight so the count bumps naturally.
//

import Foundation
import WidgetKit
import SwiftUI
import MygraCore

struct DaysSinceLastMigraineEntry: TimelineEntry {
    let date: Date
    let daysSince: Int
}

private struct DaysSinceLastMigraineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysSinceLastMigraineEntry {
        DaysSinceLastMigraineEntry(date: Date(), daysSince: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysSinceLastMigraineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysSinceLastMigraineEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(MigraineDates.nextMidnight())))
    }

    private func makeEntry() -> DaysSinceLastMigraineEntry {
        let status = SharedMigraineStatus(defaults: AppGroup.defaults)
        return DaysSinceLastMigraineEntry(date: Date(), daysSince: MigraineDates.daysSince(status.lastMigraineStart))
    }
}

private struct DaysSinceLastMigraineView: View {
    let entry: DaysSinceLastMigraineEntry

    @Environment(\.widgetFamily) private var family

    /// One calm, fixed line per range. No random copy, so the widget does not change its
    /// wording on every refresh.
    private var caption: String {
        switch entry.daysSince {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Day since your last migraine")
        default: return String(localized: "Days since your last migraine")
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Text(String(entry.daysSince))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .widgetAccentable()
                        Text("days")
                            .font(.caption2)
                    }
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(entry.daysSince))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .widgetAccentable()
                    Text("Days since last migraine")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                Text("\(entry.daysSince) days since last migraine")
            default:
                homeScreenLayout
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Days since last migraine: \(entry.daysSince)")
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.mygraPurple.opacity(0.22), Color.mygraBlue.opacity(0.22)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    private var homeScreenLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Mygra", systemImage: "brain.head.profile.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.mygraPurple)
            Spacer(minLength: 0)
            Text(String(entry.daysSince))
                .font(.system(size: family == .systemSmall ? 64 : 76, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MygraWidgetsDaysSinceLastMigraine: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.daysSinceLastMigraine, provider: DaysSinceLastMigraineProvider()) { entry in
            DaysSinceLastMigraineView(entry: entry)
        }
        .configurationDisplayName("Days Since Last Migraine")
        .description("Shows how many days it has been since your last migraine.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#if DEBUG
#Preview("Widget – Small", as: .systemSmall) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 3)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 14)
}
#endif

#if DEBUG
#Preview("Widget – Medium", as: .systemMedium) {
    MygraWidgetsDaysSinceLastMigraine()
} timeline: {
    DaysSinceLastMigraineEntry(date: .now, daysSince: 0)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 2)
    DaysSinceLastMigraineEntry(date: .now, daysSince: 21)
}
#endif
