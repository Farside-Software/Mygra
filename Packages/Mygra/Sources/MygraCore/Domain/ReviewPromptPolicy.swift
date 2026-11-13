//
//  ReviewPromptPolicy.swift
//  MygraCore
//
//  When to ask for an App Store rating. The prompt is only ever shown at calm moments
//  (never while logging, in Attack Mode, with a migraine ongoing, or from the paywall):
//    - at most once per app version, and never within 3 days of first launch;
//    - after a PDF or CSV report export;
//    - when the dashboard opens, the latest migraine ended 7+ days ago and 3+ are logged;
//    - when viewing the summary of a migraine that ended 24+ hours ago.
//  Pure logic over an injected clock and key-value store, so every rule is host-tested.
//

import Foundation

nonisolated public struct ReviewPromptPolicy {
    /// A moment the app may ask for a rating. Anything not listed here never asks.
    public enum Moment: Equatable, Sendable {
        case reportExported
        case insightsOpened(totalMigraines: Int, mostRecentEnd: Date?)
        case summaryViewed(endedAt: Date?)
    }

    public static let minimumDaysSinceFirstLaunch = 3
    public static let insightsMinimumDaysSinceLastMigraine = 7
    public static let insightsMinimumMigraines = 3
    public static let summaryMinimumHoursSinceEnd = 24

    private let store: any KeyValueStoring
    private let now: () -> Date
    private let appVersion: String

    public init(store: any KeyValueStoring, appVersion: String, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.appVersion = appVersion
        self.now = now
    }

    /// Call once at launch: stamps the first-launch date and carries the old Bool flags
    /// over, so someone already prompted on an earlier build is not prompted again on this version.
    public func recordLaunch() {
        if store.object(forKey: AppStorageKeys.firstLaunchDate) == nil {
            store.set(now().timeIntervalSince1970, forKey: AppStorageKeys.firstLaunchDate)
        }
        let legacy = store.bool(forKey: AppStorageKeys.hasPromptedForFifthReview)
            || store.bool(forKey: AppStorageKeys.hasPromptedForExportReview)
        if legacy, store.string(forKey: AppStorageKeys.lastPromptedVersion) == nil {
            store.set(appVersion, forKey: AppStorageKeys.lastPromptedVersion)
        }
    }

    /// Whether a rating prompt may be shown now. `hasOngoingMigraine` vetoes every moment.
    public func shouldPrompt(for moment: Moment, hasOngoingMigraine: Bool) -> Bool {
        guard !hasOngoingMigraine else { return false }
        guard store.string(forKey: AppStorageKeys.lastPromptedVersion) != appVersion else { return false }
        guard store.object(forKey: AppStorageKeys.firstLaunchDate) != nil else { return false }
        let firstLaunch = Date(timeIntervalSince1970: store.double(forKey: AppStorageKeys.firstLaunchDate))
        guard now().timeIntervalSince(firstLaunch) >= Double(Self.minimumDaysSinceFirstLaunch) * 86_400 else { return false }

        switch moment {
        case .reportExported:
            return true
        case let .insightsOpened(total, mostRecentEnd):
            guard total >= Self.insightsMinimumMigraines, let mostRecentEnd else { return false }
            return now().timeIntervalSince(mostRecentEnd) >= Double(Self.insightsMinimumDaysSinceLastMigraine) * 86_400
        case let .summaryViewed(endedAt):
            guard let endedAt else { return false }
            return now().timeIntervalSince(endedAt) >= Double(Self.summaryMinimumHoursSinceEnd) * 3_600
        }
    }

    /// Records that the prompt was shown on this version.
    public func markPrompted() {
        store.set(appVersion, forKey: AppStorageKeys.lastPromptedVersion)
    }
}
