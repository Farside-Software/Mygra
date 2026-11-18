//
//  MigraineSnapshotTests.swift
//  MygraCoreTests
//
//  The Sendable snapshots and period summaries behind Siri answers and the assistant's tools.
//

import Foundation
import Testing
import MygraCore

@Suite("MigraineSnapshot")
@MainActor
struct MigraineSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-11-18 12:00 UTC.
    private var now: Date { Date(timeIntervalSince1970: 1_795_003_200) }

    private func daysAgo(_ days: Int, hour: Int = 9) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    @Test func snapshotCopiesTheRecord() {
        let migraine = Migraine(startDate: daysAgo(1), endDate: daysAgo(1, hour: 12), painLevel: 7, stressLevel: 3, note: "Aura first", triggers: [.stress], customTriggers: ["Deadline"])
        migraine.medications = [MedicationDose(name: "Ibuprofen", medicationClass: .simpleAnalgesic, dose: "400 mg")]
        let snapshot = MigraineSnapshot(migraine)
        #expect(snapshot.id == migraine.id)
        #expect(snapshot.painLevel == 7)
        #expect(snapshot.triggerNames == ["Stress", "Deadline"])
        #expect(snapshot.medications == ["Ibuprofen (400 mg)"])
        #expect(snapshot.durationHours == 3)
        #expect(!snapshot.isOngoing)
    }

    @Test func periodsCoverTheRightDays() {
        let snapshots = [0, 3, 6, 7, 29, 30, 120].map { MigraineSnapshot(startDate: daysAgo($0), painLevel: 5) }
        #expect(MigrainePeriod.last7Days.filter(snapshots, now: now, calendar: calendar).count == 3)
        #expect(MigrainePeriod.last30Days.filter(snapshots, now: now, calendar: calendar).count == 5)
        #expect(MigrainePeriod.last90Days.filter(snapshots, now: now, calendar: calendar).count == 6)
        #expect(MigrainePeriod.allTime.filter(snapshots, now: now, calendar: calendar).count == 7)
    }

    @Test func thisMonthStartsOnTheFirst() {
        // now is Nov 18: Nov 1 is 17 days ago, Oct 31 is 18 days ago.
        let snapshots = [MigraineSnapshot(startDate: daysAgo(17), painLevel: 4), MigraineSnapshot(startDate: daysAgo(18), painLevel: 4)]
        #expect(MigrainePeriod.thisMonth.filter(snapshots, now: now, calendar: calendar).count == 1)
        #expect(MigrainePeriod.thisYear.filter(snapshots, now: now, calendar: calendar).count == 2)
    }

    @Test func futureStartsAreNotCounted() {
        let future = MigraineSnapshot(startDate: now.addingTimeInterval(3600), painLevel: 4)
        #expect(MigrainePeriod.last7Days.filter([future], now: now, calendar: calendar).isEmpty)
    }

    @Test func summaryCountsAndAverages() {
        let snapshots = [
            MigraineSnapshot(startDate: daysAgo(1, hour: 8), endDate: daysAgo(1, hour: 10), painLevel: 8, triggerNames: ["Stress", "Chocolate"], medications: ["A"]),
            MigraineSnapshot(startDate: daysAgo(1, hour: 20), endDate: daysAgo(1, hour: 24), painLevel: 4, triggerNames: ["stress"], medications: ["B", "C"]),
            MigraineSnapshot(startDate: daysAgo(3), painLevel: 6),
        ]
        let summary = PeriodSummary(snapshots, calendar: calendar)
        #expect(summary.count == 3)
        #expect(summary.migraineDays == 2)
        #expect(summary.averagePain == 6)
        #expect(summary.averageDurationHours == 3)
        #expect(summary.highestPain == 8)
        #expect(summary.medicationDoseCount == 3)
        #expect(summary.topTriggers.first == PeriodSummary.TriggerCount(name: "Stress", count: 2))
        #expect(summary.topTriggers.count == 2)
    }

    @Test func emptySummaryHasNoAverages() {
        let summary = PeriodSummary([], calendar: calendar)
        #expect(summary.count == 0)
        #expect(summary.averagePain == nil)
        #expect(summary.averageDurationHours == nil)
        #expect(summary.highestPain == nil)
        #expect(summary.topTriggers.isEmpty)
    }
}

@Suite("MedicationMemory")
@MainActor
struct MedicationMemoryTests {
    private func migraine(_ doses: [MedicationDose]) -> Migraine {
        let migraine = Migraine(startDate: Date(), painLevel: 5, stressLevel: 5)
        migraine.medications = doses
        return migraine
    }

    @Test func knownIsDistinctAndNewestFirst() {
        let now = Date()
        let old = MedicationDose(name: "Sumatriptan", medicationClass: .other, dose: "25 mg", takenAt: now.addingTimeInterval(-9000))
        let newer = MedicationDose(name: "sumatriptan", medicationClass: .triptan, dose: "50 mg", takenAt: now.addingTimeInterval(-100))
        let other = MedicationDose(name: "Ibuprofen", medicationClass: .simpleAnalgesic, takenAt: now.addingTimeInterval(-500))
        let known = MedicationMemory.known(from: [migraine([old, other]), migraine([newer])])
        #expect(known.map(\.name) == ["sumatriptan", "Ibuprofen"])
        #expect(known.first?.medicationClass == .triptan)
        #expect(known.first?.dose == "50 mg")
    }

    @Test func resolveMatchesExactThenUniquePartial() {
        let known = [
            KnownMedication(name: "Sumatriptan", medicationClass: .triptan, dose: "50 mg"),
            KnownMedication(name: "Ibuprofen", medicationClass: .simpleAnalgesic),
            KnownMedication(name: "Ibuprofen PM", medicationClass: .combinationAnalgesic),
        ]
        #expect(MedicationMemory.resolve("sumatriptan", in: known)?.medicationClass == .triptan)
        #expect(MedicationMemory.resolve("suma", in: known)?.name == "Sumatriptan")
        #expect(MedicationMemory.resolve("ibuprofen", in: known)?.medicationClass == .simpleAnalgesic)
        #expect(MedicationMemory.resolve("ibu", in: known) == nil)
        #expect(MedicationMemory.resolve("aspirin", in: known) == nil)
        #expect(MedicationMemory.resolve("  ", in: known) == nil)
    }
}
