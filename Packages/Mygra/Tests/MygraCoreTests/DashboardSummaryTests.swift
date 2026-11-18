//
//  DashboardSummaryTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("DashboardSummary")
@MainActor
struct DashboardSummaryTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Indiana/Indianapolis")!
        c.firstWeekday = 1
        return c
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var now: Date { date(11, 18, 12) }

    @Test func emptyHasNothing() {
        let summary = DashboardSummary([], now: now, calendar: cal)
        #expect(summary.isEmpty)
        #expect(summary.thisMonth == .empty)
        #expect(summary.recentDays.count == 30)
        #expect(summary.migraineDaysInLast30 == 0)
        #expect(summary.longestFreeStretchInLast30 == 30)
        #expect(summary.topTriggers.isEmpty)
    }

    @Test func monthsSplitByStartDate() {
        let items = [
            makeMigraine(start: date(11, 2), end: date(11, 2, 13), pain: 6),
            makeMigraine(start: date(11, 10), end: date(11, 10, 11), pain: 8),
            makeMigraine(start: date(10, 31, 23), end: date(11, 1, 3), pain: 4),
            makeMigraine(start: date(10, 5), end: date(10, 5, 10), pain: 5),
        ]
        let summary = DashboardSummary(items, now: now, calendar: cal)
        #expect(summary.thisMonth.count == 2)
        #expect(summary.lastMonth.count == 2)
        #expect(summary.thisMonth.averagePeakPain == 7)
        #expect(summary.thisMonth.averageDurationHours == 3)
        #expect(summary.thisMonth.longestDurationHours == 4)
    }

    @Test func daysWithMigraineCoverMultiDayAttacks() {
        let items = [
            makeMigraine(start: date(11, 3, 22), end: date(11, 4, 6)),
            makeMigraine(start: date(11, 4, 15), end: date(11, 4, 17)),
        ]
        let summary = DashboardSummary(items, now: now, calendar: cal)
        #expect(summary.thisMonth.count == 2)
        #expect(summary.thisMonth.daysWithMigraine == 2)
    }

    @Test func peakPainUsesIntensitySamples() {
        let migraine = makeMigraine(start: date(11, 3), end: date(11, 3, 12), pain: 4)
        migraine.intensitySamples = [IntensitySample(timestamp: date(11, 3, 10), painLevel: 9, stressLevel: 2)]
        let summary = DashboardSummary([migraine], now: now, calendar: cal)
        #expect(summary.thisMonth.averagePeakPain == 9)
    }

    @Test func ongoingMigraineMarksTodayAndHasNoDuration() {
        let ongoing = makeMigraine(start: date(11, 17, 20), end: nil)
        let summary = DashboardSummary([ongoing], now: now, calendar: cal)
        #expect(summary.recentDays.last?.hadMigraine == true)
        #expect(summary.recentDays[28].hadMigraine == true)
        #expect(summary.thisMonth.averageDurationHours == nil)
    }

    @Test func stripCoversThirtyDaysEndingToday() {
        let items = [makeMigraine(start: date(10, 20), end: date(10, 20, 12)), makeMigraine(start: date(11, 18, 8), end: date(11, 18, 10))]
        let summary = DashboardSummary(items, now: now, calendar: cal)
        #expect(summary.recentDays.first?.date == cal.startOfDay(for: date(10, 20)))
        #expect(summary.recentDays.last?.date == cal.startOfDay(for: now))
        #expect(summary.migraineDaysInLast30 == 2)
        #expect(summary.longestFreeStretchInLast30 == 28)
    }

    @Test func migrainesOlderThanThirtyDaysStayOffTheStrip() {
        let summary = DashboardSummary([makeMigraine(start: date(9, 1), end: date(9, 1, 5))], now: now, calendar: cal)
        #expect(summary.migraineDaysInLast30 == 0)
    }

    @Test func topTriggersGroupCaseInsensitivelyAndCountOncePerMigraine() {
        let items = [
            makeMigraine(start: date(11, 2), triggers: [.stress, .lackOfSleep], customTriggers: ["Late dinner"]),
            makeMigraine(start: date(11, 5), triggers: [.stress], customTriggers: ["late dinner", "Late Dinner"]),
            makeMigraine(start: date(11, 9), triggers: [.stress]),
            makeMigraine(start: date(10, 9), triggers: [.chocolate]),
        ]
        let summary = DashboardSummary(items, now: now, calendar: cal)
        #expect(summary.topTriggers.map(\.count) == [3, 2, 1])
        #expect(summary.topTriggers.first?.name == MigraineTrigger.stress.displayName)
        #expect(summary.topTriggers[1].name == "Late dinner")
        #expect(!summary.topTriggers.contains { $0.name == MigraineTrigger.chocolate.displayName })
    }

    @Test func topMedicationsCountThisMonthDoses() {
        let a = makeMigraine(start: date(11, 2))
        a.medications = [MedicationDose(name: "Ibuprofen", medicationClass: .simpleAnalgesic), MedicationDose(name: "ibuprofen", medicationClass: .simpleAnalgesic)]
        let b = makeMigraine(start: date(11, 6))
        b.medications = [MedicationDose(name: "Sumatriptan", medicationClass: .triptan)]
        let old = makeMigraine(start: date(9, 6))
        old.medications = [MedicationDose(name: "Rizatriptan", medicationClass: .triptan)]
        let summary = DashboardSummary([a, b, old], now: now, calendar: cal)
        #expect(summary.topMedications.map(\.name) == ["Ibuprofen", "Sumatriptan"])
        #expect(summary.topMedications.map(\.count) == [2, 1])
    }

    @Test func dayPartBoundaries() {
        #expect(DashboardDayPart.of(hour: 0) == .night)
        #expect(DashboardDayPart.of(hour: 4) == .night)
        #expect(DashboardDayPart.of(hour: 5) == .morning)
        #expect(DashboardDayPart.of(hour: 11) == .morning)
        #expect(DashboardDayPart.of(hour: 12) == .afternoon)
        #expect(DashboardDayPart.of(hour: 16) == .afternoon)
        #expect(DashboardDayPart.of(hour: 17) == .evening)
        #expect(DashboardDayPart.of(hour: 23) == .evening)
    }

    @Test func patternsCountStartsByPartAndWeekday() {
        // 2026-11-16 is a Monday.
        let items = [
            makeMigraine(start: date(11, 16, 7)),
            makeMigraine(start: date(11, 9, 8)),
            makeMigraine(start: date(11, 12, 14)),
            makeMigraine(start: date(11, 14, 22)),
        ]
        let summary = DashboardSummary(items, now: now, calendar: cal)
        #expect(summary.dayPartCounts[.morning] == 2)
        #expect(summary.dayPartCounts[.afternoon] == 1)
        #expect(summary.dayPartCounts[.evening] == 1)
        #expect(summary.dayPartCounts[.night] == nil)
        // Sunday-first: Monday index 1, Thursday 4, Saturday 6.
        #expect(summary.weekdayCounts == [0, 2, 0, 0, 1, 0, 1])
        #expect(summary.hasPatterns)
        #expect(!DashboardSummary(Array(items.prefix(3)), now: now, calendar: cal).hasPatterns)
    }

    @Test func weekdayIndexFollowsFirstWeekday() {
        var monday = cal
        monday.firstWeekday = 2
        let items = [makeMigraine(start: date(11, 16, 7))]
        #expect(DashboardSummary(items, now: now, calendar: monday).weekdayCounts[0] == 1)
    }
}
