//
//  IntelligenceToolboxTests.swift
//  MygraServicesTests
//
//  The pure lookups behind the assistant's tools, and the guardrails in its prompts.
//

import Foundation
import Testing
import MygraCore
@testable import MygraServices

@Suite("IntelligenceToolbox")
@MainActor
struct IntelligenceToolboxTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var snapshots: [MigraineSnapshot] {
        [
            MigraineSnapshot(startDate: date(2026, 11, 2), endDate: date(2026, 11, 2, hour: 13), painLevel: 8, stressLevel: 6, triggerNames: ["Stress", "Lack of sleep"], medications: ["Sumatriptan (50 mg)"], note: "Aura first"),
            MigraineSnapshot(startDate: date(2026, 11, 10), painLevel: 4, stressLevel: 2, triggerNames: ["Chocolate"]),
            MigraineSnapshot(startDate: date(2026, 10, 20), endDate: date(2026, 10, 20, hour: 11), painLevel: 6, triggerNames: ["Stress"]),
        ]
    }

    @Test func parsesDays() {
        #expect(IntelligenceToolbox.parseDay("2026-11-02", calendar: calendar) == date(2026, 11, 2, hour: 0))
        #expect(IntelligenceToolbox.parseDay("2026-11-02T10:00:00Z", calendar: calendar) == date(2026, 11, 2, hour: 0))
        #expect(IntelligenceToolbox.parseDay("last week", calendar: calendar) == nil)
        #expect(IntelligenceToolbox.parseDay(nil, calendar: calendar) == nil)
        #expect(IntelligenceToolbox.parseDay("", calendar: calendar) == nil)
    }

    @Test func findsByDateRangeInclusiveOfTheLastDay() {
        let text = IntelligenceToolbox.findRows(in: snapshots, from: "2026-11-01", to: "2026-11-02", calendar: calendar)
        #expect(text.contains("1 matching entries"))
        #expect(text.contains("2026-11-02"))
        #expect(!text.contains("2026-11-10"))
    }

    @Test func filtersByPainTriggerAndMedication() {
        #expect(IntelligenceToolbox.findRows(in: snapshots, minimumPain: 7, calendar: calendar).contains("2026-11-02"))
        #expect(IntelligenceToolbox.findRows(in: snapshots, trigger: "stress", calendar: calendar).contains("2 matching entries"))
        let meds = IntelligenceToolbox.findRows(in: snapshots, medication: "suma", calendar: calendar)
        #expect(meds.contains("doses: Sumatriptan (50 mg)"))
        #expect(meds.contains("note: Aura first"))
        #expect(IntelligenceToolbox.findRows(in: snapshots, trigger: "weather", calendar: calendar) == "No matching entries.")
    }

    @Test func rowsAreMostRecentFirstAndCapped() {
        let many = (0..<30).map { MigraineSnapshot(startDate: date(2026, 10, 1).addingTimeInterval(Double($0) * 86_400), painLevel: 3) }
        let text = IntelligenceToolbox.findRows(in: many, limit: 100, calendar: calendar)
        let rows = text.components(separatedBy: "\n").filter { $0.hasPrefix("- ") }
        #expect(rows.count == IntelligenceToolbox.maximumRows)
        #expect(text.contains("18 more matching entries"))
        #expect(rows.first!.contains("2026-10-30"))
    }

    @Test func rowShowsOngoingAndDuration() {
        let ongoing = IntelligenceToolbox.row(for: MigraineSnapshot(startDate: date(2026, 11, 10), painLevel: 4), calendar: calendar)
        #expect(ongoing.contains("ongoing"))
        let finished = IntelligenceToolbox.row(for: snapshots[0], calendar: calendar)
        #expect(finished.contains("4.0 h"))
    }

    @Test func summaryCoversAPeriod() {
        let now = date(2026, 11, 18)
        let month = IntelligenceToolbox.summaryText(of: snapshots, period: .thisMonth, now: now, calendar: calendar)
        #expect(month.contains("Migraines: 2"))
        #expect(month.contains("Most logged triggers:"))
        #expect(month.contains("Days since the latest entry: 8"))
        let empty = IntelligenceToolbox.summaryText(of: snapshots, period: .last7Days, now: now, calendar: calendar)
        #expect(empty.contains("Migraines: 0"))
        #expect(empty.contains("No entries in this period."))
    }

    @Test func chatInstructionsKeepTheGuardrails() {
        let text = IntelligencePrompts.chatInstructions(userSummary: "name=Nick", historySummary: "count=3", now: date(2026, 11, 18), calendar: calendar)
        #expect(text.contains("findMigraines"))
        #expect(text.contains("summarizePeriod"))
        #expect(text.contains("Today is 2026-11-18"))
        #expect(text.contains("Never diagnose"))
        #expect(text.contains("never predict"))
        #expect(text.contains("Profile: name=Nick"))
        #expect(text.contains("History overview: count=3"))
    }

    @Test func promptsStayDescriptive() {
        for text in [IntelligencePrompts.analysisInstructions, IntelligencePrompts.explanationInstructions] {
            #expect(text.localizedCaseInsensitiveContains("do not diagnose") || text.localizedCaseInsensitiveContains("never diagnose"))
            #expect(!text.localizedCaseInsensitiveContains("mitigation"))
            #expect(!text.localizedCaseInsensitiveContains("likely contributing"))
        }
        #expect(IntelligencePrompts.analysisInstructions.contains(IntelligencePrompts.analysisDisclaimer))
        #expect(IntelligencePrompts.starterQuestions.count == 4)
    }
}
