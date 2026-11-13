//
//  ReviewPromptPolicyTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
@testable import MygraCore

private final class MemoryStore: KeyValueStoring, @unchecked Sendable {
    var storage: [String: Any] = [:]
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(days: Double = 0, hours: Double = 0) { date.addTimeInterval(days * 86_400 + hours * 3_600) }
}

@Suite("ReviewPromptPolicy")
struct ReviewPromptPolicyTests {
    private func make(version: String = "1.0", store: MemoryStore = MemoryStore(), clock: Clock = Clock()) -> (ReviewPromptPolicy, MemoryStore, Clock) {
        let policy = ReviewPromptPolicy(store: store, appVersion: version, now: { clock.date })
        policy.recordLaunch()
        return (policy, store, clock)
    }

    @Test func neverWithinThreeDaysOfFirstLaunch() {
        let (policy, _, clock) = make()
        #expect(!policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
        clock.advance(days: 2, hours: 23)
        #expect(!policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
        clock.advance(hours: 1)
        #expect(policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
    }

    @Test func firstLaunchIsStampedOnlyOnce() {
        let (policy, store, clock) = make()
        let stamp = store.double(forKey: AppStorageKeys.firstLaunchDate)
        clock.advance(days: 10)
        policy.recordLaunch()
        #expect(store.double(forKey: AppStorageKeys.firstLaunchDate) == stamp)
    }

    @Test func atMostOncePerVersion() {
        let (policy, store, clock) = make()
        clock.advance(days: 4)
        #expect(policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
        policy.markPrompted()
        #expect(!policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
        // A new version is eligible again.
        let next = ReviewPromptPolicy(store: store, appVersion: "1.1", now: { clock.date })
        #expect(next.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
    }

    @Test func ongoingMigraineVetoesEveryMoment() {
        let (policy, _, clock) = make()
        clock.advance(days: 30)
        let old = clock.date.addingTimeInterval(-20 * 86_400)
        #expect(!policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: true))
        #expect(!policy.shouldPrompt(for: .insightsOpened(totalMigraines: 9, mostRecentEnd: old), hasOngoingMigraine: true))
        #expect(!policy.shouldPrompt(for: .summaryViewed(endedAt: old), hasOngoingMigraine: true))
    }

    @Test func insightsNeedSevenQuietDaysAndThreeMigraines() {
        let (policy, _, clock) = make()
        clock.advance(days: 30)
        let sevenDaysAgo = clock.date.addingTimeInterval(-7 * 86_400)
        let sixDaysAgo = clock.date.addingTimeInterval(-6 * 86_400)
        #expect(policy.shouldPrompt(for: .insightsOpened(totalMigraines: 3, mostRecentEnd: sevenDaysAgo), hasOngoingMigraine: false))
        #expect(!policy.shouldPrompt(for: .insightsOpened(totalMigraines: 2, mostRecentEnd: sevenDaysAgo), hasOngoingMigraine: false))
        #expect(!policy.shouldPrompt(for: .insightsOpened(totalMigraines: 3, mostRecentEnd: sixDaysAgo), hasOngoingMigraine: false))
        #expect(!policy.shouldPrompt(for: .insightsOpened(totalMigraines: 3, mostRecentEnd: nil), hasOngoingMigraine: false))
    }

    @Test func summaryNeedsTwentyFourHoursSinceEnd() {
        let (policy, _, clock) = make()
        clock.advance(days: 30)
        #expect(policy.shouldPrompt(for: .summaryViewed(endedAt: clock.date.addingTimeInterval(-24 * 3_600)), hasOngoingMigraine: false))
        #expect(!policy.shouldPrompt(for: .summaryViewed(endedAt: clock.date.addingTimeInterval(-23 * 3_600)), hasOngoingMigraine: false))
        #expect(!policy.shouldPrompt(for: .summaryViewed(endedAt: nil), hasOngoingMigraine: false))
    }

    @Test func exportIsEligibleOnceThreeDaysHavePassed() {
        let (policy, _, clock) = make()
        clock.advance(days: 3)
        #expect(policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
    }

    @Test func legacyFlagsMigrateSoThisVersionDoesNotPromptAgain() {
        for key in [AppStorageKeys.hasPromptedForFifthReview, AppStorageKeys.hasPromptedForExportReview] {
            let store = MemoryStore()
            store.set(true, forKey: key)
            let (policy, _, clock) = make(version: "2.0", store: store)
            clock.advance(days: 10)
            #expect(store.string(forKey: AppStorageKeys.lastPromptedVersion) == "2.0")
            #expect(!policy.shouldPrompt(for: .reportExported, hasOngoingMigraine: false))
        }
    }
}
