//
//  MygraSnippets.swift
//  Mygra
//
//  An interactive snippet (iOS 26+): "Show my migraine summary" answers in place, in
//  Siri or Shortcuts, with a live timer while an attack is in progress and buttons that
//  run intents without opening the app. The snippet reads the same use-cases as every
//  other intent and describes the record only.
//

import AppIntents
import Foundation
import MygraComposition
import MygraCore
import SwiftUI

@available(iOS 26.0, *)
struct ShowMigraineSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Migraine Summary"
    static let description = IntentDescription("Shows whether a migraine is in progress, your streak, and this month's count, with quick actions.", categoryName: "Your Log")

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        .result(snippetIntent: MigraineSummarySnippetIntent())
    }
}

@available(iOS 26.0, *)
struct MigraineSummarySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Migraine Summary"

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let migraines = try session.loadMigraines()
        let snapshots = migraines.map(MigraineSnapshot.init)
        let ongoing = snapshots.first(where: \.isOngoing)
        let month = PeriodSummary(MigrainePeriod.thisMonth.filter(snapshots))
        let lastDate = MigraineStatistics.lastMigraineDate(migraines)
        return .result(view: MigraineSummarySnippetView(
            ongoing: ongoing,
            daysSinceLast: lastDate.map { MigraineDates.daysSince($0) },
            monthCount: month.count
        ))
    }
}

@available(iOS 26.0, *)
struct MigraineSummarySnippetView: View {
    let ongoing: MigraineSnapshot?
    let daysSinceLast: Int?
    let monthCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ongoing {
                Text("Migraine in progress")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label {
                        Text(ongoing.startDate, style: .timer)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    Label("Pain \(ongoing.painLevel) of 10", systemImage: "gauge.medium")
                }
                .font(.subheadline)
                Button(intent: EndMigraineIntent()) {
                    Label("End Migraine", systemImage: "checkmark.circle")
                }
            } else {
                if let daysSinceLast {
                    Text(daysSinceLast == 0 ? "Latest migraine: today" : "\(daysSinceLast) days since your last migraine")
                        .font(.headline)
                } else {
                    Text("No migraines logged yet")
                        .font(.headline)
                }
                Text(monthCount == 1 ? "1 migraine this month" : "\(monthCount) migraines this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(intent: StartAttackIntent()) {
                    Label("Start Migraine", systemImage: "bolt.heart")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
