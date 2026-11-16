//
//  MedicationOveruseTests.swift
//  MygraCoreTests
//
//  Rolling 30-day medication days, thresholds, and the once-per-crossing alert ledger.
//

import Foundation
import Testing
@testable import MygraCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
private let now = Date(timeIntervalSince1970: 1_794_052_800) // 2026-11-07 12:00 UTC

@MainActor
private func doses(_ cls: MedicationClass, daysAgo: [Int], perDay: Int = 1) -> [MedicationDose] {
    daysAgo.flatMap { offset in
        (0..<perDay).map { n in
            MedicationDose(name: cls.rawValue, medicationClass: cls, takenAt: now.addingTimeInterval(-Double(offset) * 86_400 - Double(n) * 3_600))
        }
    }
}

@Suite("MedicationOveruse")
@MainActor
struct MedicationOveruseTests {

    @Test func thresholdsFollowICHD3() {
        #expect(MedicationClass.triptan.overuseThresholdDays == 10)
        #expect(MedicationClass.combinationAnalgesic.overuseThresholdDays == 10)
        #expect(MedicationClass.opioid.overuseThresholdDays == 10)
        #expect(MedicationClass.ergot.overuseThresholdDays == 10)
        #expect(MedicationClass.simpleAnalgesic.overuseThresholdDays == 15)
        #expect(MedicationClass.gepant.overuseThresholdDays == nil)
        #expect(MedicationClass.other.overuseThresholdDays == nil)
    }

    @Test func statusBoundaries() {
        #expect(MedicationOveruse.status(days: 7, threshold: 10) == .ok)
        #expect(MedicationOveruse.status(days: 8, threshold: 10) == .approaching)
        #expect(MedicationOveruse.status(days: 9, threshold: 10) == .approaching)
        #expect(MedicationOveruse.status(days: 10, threshold: 10) == .threshold)
        #expect(MedicationOveruse.status(days: 14, threshold: 15) == .approaching)
        #expect(MedicationOveruse.status(days: 15, threshold: 15) == .threshold)
        #expect(MedicationOveruse.status(days: 30, threshold: nil) == .ok)
    }

    @Test func multipleDosesOnOneDayCountOnce() {
        let list = doses(.triptan, daysAgo: [0, 1, 2], perDay: 3)
        let usage = MedicationOveruse.usage(of: list, now: now, calendar: utc)
        #expect(usage.count == 1)
        #expect(usage.first?.days == 3)
    }

    @Test func windowIsTodayPlusPrevious29Days() {
        // 29 days ago is inside, 30 days ago is outside.
        let inside = doses(.triptan, daysAgo: [29])
        let outside = doses(.triptan, daysAgo: [30])
        #expect(MedicationOveruse.usage(of: inside, now: now, calendar: utc).first?.days == 1)
        #expect(MedicationOveruse.usage(of: outside, now: now, calendar: utc).isEmpty)
    }

    @Test func alertsSortedWorstFirstAndSkipUnlimitedClasses() {
        let list = doses(.triptan, daysAgo: Array(0..<8))               // approaching
            + doses(.opioid, daysAgo: Array(0..<10))                    // threshold
            + doses(.gepant, daysAgo: Array(0..<20))                    // no limit
        let alerts = MedicationOveruse.alerts(for: list, now: now, calendar: utc)
        // opioid + triptan + overall row (both limited classes overlap on 10 distinct days).
        #expect(alerts.first?.usage.medicationClass == .opioid || alerts.first?.usage.isOverall == true)
        #expect(alerts.allSatisfy { $0.usage.medicationClass != .gepant })
        #expect(alerts.contains { $0.usage.medicationClass == .triptan && $0.status == .approaching })
        #expect(alerts.contains { $0.usage.medicationClass == .opioid && $0.status == .threshold })
    }

    @Test func overallRowNeedsTwoLimitedClasses() {
        let single = doses(.simpleAnalgesic, daysAgo: Array(0..<12))
        #expect(MedicationOveruse.usage(of: single, now: now, calendar: utc).allSatisfy { !$0.isOverall })

        // 6 + 6 distinct days across two classes = 12 combined days: over the 10-day combined mark.
        let mixed = doses(.simpleAnalgesic, daysAgo: Array(0..<6)) + doses(.triptan, daysAgo: Array(6..<12))
        let overall = MedicationOveruse.usage(of: mixed, now: now, calendar: utc).first(where: \.isOverall)
        #expect(overall?.days == 12)
        #expect(overall?.status == .threshold)
    }

    @Test func alertWordingIsInformationalNotAdvice() {
        let alert = OveruseAlert(usage: ClassUsage(medicationClass: .triptan, days: 10, threshold: 10, status: .threshold))
        #expect(alert.message.contains("not medical advice"))
        #expect(alert.message.contains("10"))
        #expect(MedicationOveruse.guidanceURL.host == "americanmigrainefoundation.org")
    }

    @Test func ledgerAlertsOncePerCrossingAndResets() {
        let ledger = MedicationAlertLedger(defaults: FakeKeyValueStore())
        func usage(_ days: Int) -> [ClassUsage] {
            [ClassUsage(medicationClass: .triptan, days: days, threshold: 10, status: MedicationOveruse.status(days: days, threshold: 10))]
        }
        #expect(ledger.newAlerts(from: usage(7)).isEmpty)
        #expect(ledger.newAlerts(from: usage(8)).map(\.status) == [.approaching])
        #expect(ledger.newAlerts(from: usage(9)).isEmpty)            // same level: quiet
        #expect(ledger.newAlerts(from: usage(10)).map(\.status) == [.threshold])
        #expect(ledger.newAlerts(from: usage(11)).isEmpty)
        #expect(ledger.newAlerts(from: usage(5)).isEmpty)            // dropped: resets
        #expect(ledger.newAlerts(from: usage(8)).map(\.status) == [.approaching])
    }

    @Test func presetsCoverEveryClassWithALimit() {
        for cls in MedicationClass.allCases where cls.overuseThresholdDays != nil {
            #expect(!MedicationPreset.presets(for: cls).isEmpty)
        }
    }

    // MARK: - OveruseSummary

    @Test func summaryIsNilWhenNothingNearALimit() {
        let d = doses(.triptan, daysAgo: Array(0..<5))
        #expect(OveruseSummary(doses: d, now: now, calendar: utc) == nil)
    }

    @Test func summaryHeadlineAndRowsWhenOverLimit() throws {
        let d = doses(.triptan, daysAgo: Array(0..<11)) + doses(.simpleAnalgesic, daysAgo: Array(0..<9).map { $0 + 12 })
        let summary = try #require(OveruseSummary(doses: d, now: now, calendar: utc))
        #expect(summary.status == .threshold)
        #expect(summary.headline == "Over the medication-overuse limit")
        #expect(summary.rows.first?.usage.medicationClass == .triptan)
        #expect(summary.rows.first?.countText == "11 / 10 days")
        #expect(summary.subtitle == "Triptans on 11 of the last 30 days")
        let analgesic = try #require(summary.rows.first { $0.usage.medicationClass == .simpleAnalgesic })
        #expect(analgesic.status == .approaching)
        #expect(analgesic.countText == "9 / 15 days")
        #expect(analgesic.accessibilityLabel == "Simple analgesics, 9 of the last 30 days, limit 15, approaching the limit")
    }

    @Test func summaryApproachingHeadlineAndCombinedRowLabel() throws {
        let d = doses(.triptan, daysAgo: Array(0..<5)) + doses(.opioid, daysAgo: Array(0..<5).map { $0 + 6 })
        // 10 combined days, each class only 5: only the combined total is at its limit.
        let summary = try #require(OveruseSummary(doses: d, now: now, calendar: utc))
        #expect(summary.rows.count == 1)
        let row = try #require(summary.rows.first)
        #expect(row.usage.isOverall)
        #expect(row.name == "All acute medication, combined")
        #expect(summary.headline == "Over the medication-overuse limit")
        #expect(summary.subtitle == "Acute medication on 10 of the last 30 days")
        #expect(row.accessibilityLabel == "All acute medication, combined, 10 of the last 30 days, limit 10, over the limit")
    }

    @Test func summaryApproachingOnly() throws {
        let d = doses(.triptan, daysAgo: Array(0..<8))
        let summary = try #require(OveruseSummary(doses: d, now: now, calendar: utc))
        #expect(summary.status == .approaching)
        #expect(summary.headline == "Approaching the medication-overuse limit")
    }
}
