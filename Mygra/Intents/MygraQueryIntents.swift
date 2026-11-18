//
//  MygraQueryIntents.swift
//  Mygra
//
//  Read-only questions Siri, Spotlight and Shortcuts can ask about the user's own log:
//  "how many migraines this month", "when was my last migraine". Answers are computed
//  from the session's use-cases through the pure snapshot/summary types in MygraCore and
//  describe the record only. Result views are static snippets (iOS 18+); the interactive
//  summary snippet lives in MygraSnippets.swift.
//

import AppIntents
import Foundation
import MygraComposition
import MygraCore
import SwiftUI

// MARK: - Period (AppEnum)

enum MygraPeriod: String, AppEnum {
    case last7Days
    case last30Days
    case thisMonth
    case thisYear
    case allTime

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Time Period" }

    nonisolated static var caseDisplayRepresentations: [MygraPeriod: DisplayRepresentation] {
        [
            .last7Days: "Last 7 Days",
            .last30Days: "Last 30 Days",
            .thisMonth: "This Month",
            .thisYear: "This Year",
            .allTime: "All Time",
        ]
    }

    var period: MigrainePeriod {
        switch self {
        case .last7Days: .last7Days
        case .last30Days: .last30Days
        case .thisMonth: .thisMonth
        case .thisYear: .thisYear
        case .allTime: .allTime
        }
    }

    /// The phrase that ends the spoken answer ("… in the last 7 days.").
    var spokenPhrase: String {
        switch self {
        case .last7Days: String(localized: "in the last 7 days")
        case .last30Days: String(localized: "in the last 30 days")
        case .thisMonth: String(localized: "this month")
        case .thisYear: String(localized: "this year")
        case .allTime: String(localized: "in total")
        }
    }
}

// MARK: - How many migraines

struct CountMigrainesIntent: AppIntent {
    static let title: LocalizedStringResource = "Count Migraines"
    static let description = IntentDescription("Tells you how many migraines you logged in a period, with the average pain level.", categoryName: "Your Log")

    @Parameter(title: "Period", default: .thisMonth)
    var period: MygraPeriod

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Count migraines \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetView {
        let snapshots = try session.loadMigraines().map(MigraineSnapshot.init)
        let inPeriod = period.period.filter(snapshots)
        let summary = PeriodSummary(inPeriod)
        let phrase = period.spokenPhrase
        let sentence: String
        switch summary.count {
        case 0: sentence = String(localized: "You haven't logged any migraines \(phrase).")
        case 1: sentence = String(localized: "You logged 1 migraine \(phrase).")
        default: sentence = String(localized: "You logged \(summary.count) migraines \(phrase).")
        }
        return .result(
            value: summary.count,
            dialog: IntentDialog(LocalizedStringResource(stringLiteral: sentence)),
            view: PeriodSummaryCard(summary: summary, caption: phrase)
        )
    }
}

struct PeriodSummaryCard: View {
    let summary: PeriodSummary
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(summary.count == 1 ? "migraine" : "migraines")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let pain = summary.averagePain {
                Label("Average pain \(pain, format: .number.precision(.fractionLength(1))) of 10", systemImage: "gauge.medium")
                    .font(.footnote)
            }
            if let trigger = summary.topTriggers.first {
                Label("Most logged trigger: \(trigger.name)", systemImage: "bolt")
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

// MARK: - Last migraine (card + date)

struct LastMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Migraine"
    static let description = IntentDescription("Tells you when your last migraine was and what you logged for it.", categoryName: "Your Log")

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let migraines = try session.loadMigraines().sorted { $0.startDate > $1.startDate }
        guard let last = migraines.first else {
            return .result(dialog: "You haven't logged any migraines yet.", view: LastMigraineCard(snapshot: nil))
        }
        let snapshot = MigraineSnapshot(last)
        let when = snapshot.startDate.formatted(date: .complete, time: .omitted)
        let sentence: String
        if snapshot.isOngoing {
            sentence = String(localized: "Your migraine started \(when) and is still in progress.")
        } else {
            let days = MigraineDates.daysSince(snapshot.startDate)
            sentence = days == 0
                ? String(localized: "Your last migraine was today.")
                : String(localized: "Your last migraine was \(when), \(days) days ago, at pain level \(snapshot.painLevel) of 10.")
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: sentence)), view: LastMigraineCard(snapshot: snapshot))
    }
}

struct LastMigraineCard: View {
    let snapshot: MigraineSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot {
                Text(snapshot.startDate, format: .dateTime.weekday(.wide).month().day().year())
                    .font(.headline)
                Label("Pain \(snapshot.painLevel) of 10", systemImage: "gauge.medium")
                    .font(.subheadline)
                if let hours = snapshot.durationHours {
                    Label("\(MigraineDates.durationString(hours * 3600))", systemImage: "clock")
                        .font(.subheadline)
                } else {
                    Label("In progress", systemImage: "clock")
                        .font(.subheadline)
                }
                if !snapshot.triggerNames.isEmpty {
                    Label(snapshot.triggerNames.prefix(3).joined(separator: ", "), systemImage: "bolt")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !snapshot.medications.isEmpty {
                    Label(snapshot.medications.joined(separator: ", "), systemImage: "pills")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No migraines logged yet")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
