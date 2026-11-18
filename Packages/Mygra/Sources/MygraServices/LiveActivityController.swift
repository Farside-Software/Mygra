//
//  LiveActivityController.swift
//  MygraServices
//
//  Production `MigraineActivityControlling` over ActivityKit (iOS only).
//
//  Lifecycle rules:
//  - One activity per ongoing migraine; duplicates are folded.
//  - Updates are silent (no alert): the activity is shown during a migraine, so it never
//    expands or makes a sound on its own.
//  - If the person swipes the activity away while the migraine is still ongoing, it is
//    not put back for that migraine.
//  - `endAll(except:)` removes activities whose migraine is over, even after a relaunch.
//

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import MygraCore
import os

public struct LiveActivityController: MigraineActivityControlling, MigraineActivityReconciling {
    nonisolated private static let dismissedKey = "liveActivityDismissedMigraineIDs"

    nonisolated public init() {}

    public func ensureStarted(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let matching = Self.activities(for: migraineID)
        if matching.isEmpty {
            // Respect a swipe-away: the person chose to hide this one.
            guard !Self.wasDismissedByUser(migraineID) else {
                Log.liveActivity.info("Not restarting the Live Activity: it was dismissed from the Lock Screen")
                return
            }
            start(for: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note)
            return
        }
        // Fold duplicates: keep the newest, end the rest, refresh the kept one.
        guard matching.count > 1 else { return }
        Task.detached {
            let sorted = Self.activities(for: migraineID).sorted { $0.content.state.startDate > $1.content.state.startDate }
            for activity in sorted.dropFirst() {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if let keep = sorted.first {
                await keep.update(Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note))
            }
        }
    }

    public func update(for migraineID: UUID, painLevel: Int, stressLevel: Int, note: String) {
        Task.detached {
            guard let activity = Self.activities(for: migraineID).first else { return }
            let startDate = activity.content.state.startDate
            let next = Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note)
            // The change stream fires for every edit; only touch the activity when what
            // it shows actually changed.
            guard next.state != activity.content.state else { return }
            Log.liveActivity.info("Updating the Live Activity: pain \(painLevel)")
            await activity.update(next)
        }
    }

    public func end(for migraineID: UUID) {
        Log.liveActivity.info("Ending the Live Activity: the migraine ended")
        Task.detached {
            for activity in Self.activities(for: migraineID) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            Self.forgetDismissal(migraineID)
        }
    }

    public func endAll(except migraineID: UUID?) {
        guard Activity<MigraineActivityAttributes>.activities.contains(where: { $0.content.state.migraineID != migraineID }) else { return }
        Log.liveActivity.info("Ending Live Activities that do not belong to the ongoing migraine")
        Task.detached {
            for activity in Activity<MigraineActivityAttributes>.activities where activity.content.state.migraineID != migraineID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Private

    private func start(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) {
        do {
            let activity = try Activity<MigraineActivityAttributes>.request(
                attributes: MigraineActivityAttributes(),
                content: Self.content(migraineID: migraineID, startDate: startDate, painLevel: painLevel, stressLevel: stressLevel, note: note),
                pushType: nil
            )
            Self.watchForUserDismissal(activityID: activity.id, migraineID: migraineID)
        } catch {
            Log.liveActivity.error("Failed to start migraine Live Activity: \(error.localizedDescription)")
        }
    }

    nonisolated private static func activities(for migraineID: UUID) -> [Activity<MigraineActivityAttributes>] {
        Activity<MigraineActivityAttributes>.activities.filter { $0.content.state.migraineID == migraineID }
    }

    /// No stale date: the timer is computed on screen and every change to the levels is
    /// pushed immediately, so there is nothing the system should mark as outdated.
    nonisolated private static func content(migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) -> ActivityContent<MigraineActivityAttributes.ContentState> {
        let state = MigraineActivityAttributes.ContentState(
            migraineID: migraineID,
            startDate: startDate,
            severity: painLevel,
            stressLevel: stressLevel,
            notes: note.isEmpty ? nil : note
        )
        return ActivityContent(state: state, staleDate: nil, relevanceScore: 100)
    }

    // MARK: - Swipe-away tracking

    /// Remembers a migraine whose activity went active -> dismissed without the app or
    /// the system ending it first (the system's own 8-hour end passes through `.ended`).
    nonisolated private static func watchForUserDismissal(activityID: String, migraineID: UUID) {
        Task.detached {
            guard let activity = Activity<MigraineActivityAttributes>.activities.first(where: { $0.id == activityID }) else { return }
            var sawEnded = false
            for await state in activity.activityStateUpdates {
                Log.liveActivity.info("Live Activity state: \(String(describing: state))")
                switch state {
                case .ended: sawEnded = true
                case .dismissed:
                    if !sawEnded { markDismissed(migraineID) }
                    return
                default: break
                }
            }
        }
    }

    nonisolated private static func dismissedIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
    }

    nonisolated private static func wasDismissedByUser(_ id: UUID) -> Bool {
        dismissedIDs().contains(id.uuidString)
    }

    nonisolated private static func markDismissed(_ id: UUID) {
        var ids = dismissedIDs()
        guard !ids.contains(id.uuidString) else { return }
        ids.append(id.uuidString)
        UserDefaults.standard.set(Array(ids.suffix(20)), forKey: dismissedKey)
    }

    nonisolated private static func forgetDismissal(_ id: UUID) {
        let ids = dismissedIDs().filter { $0 != id.uuidString }
        UserDefaults.standard.set(ids, forKey: dismissedKey)
    }
}
#endif
