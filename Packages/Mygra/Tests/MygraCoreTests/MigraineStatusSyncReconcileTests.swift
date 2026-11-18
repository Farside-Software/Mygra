//
//  MigraineStatusSyncReconcileTests.swift
//  MygraCoreTests
//
//  An activity left over from a previous launch must be swept once the migraine is over,
//  and a forgotten migraine must not keep getting its Live Activity restarted.
//

import Foundation
import Testing
import MygraCore

@MainActor
private final class SweepingFakeActivity: MigraineActivityControlling, MigraineActivityReconciling {
    private(set) var started: [UUID] = []
    private(set) var swept: [UUID?] = []
    func ensureStarted(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) { started.append(migraineID) }
    func update(for migraineID: UUID, painLevel: Int, stressLevel: Int, note: String) {}
    func end(for migraineID: UUID) {}
    func endAll(except migraineID: UUID?) { swept.append(migraineID) }
}

@Suite("MigraineStatusSync Live Activity sweep")
@MainActor
struct MigraineStatusSyncReconcileTests {

    private func makeSync(_ repository: InMemoryMigraineRepository, _ activity: SweepingFakeActivity) -> MigraineStatusSync {
        MigraineStatusSync(
            loadMigraines: LoadMigrainesUseCase(repository: repository),
            observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
            sharedDefaults: FakeKeyValueStore(),
            liveActivity: activity
        )
    }

    @Test func syncSweepsActivitiesThatNoLongerHaveAnOngoingMigraine() {
        let repository = InMemoryMigraineRepository()
        let activity = SweepingFakeActivity()
        repository.storage = [makeMigraine(start: Date().addingTimeInterval(-3600), end: Date())]

        makeSync(repository, activity).syncNow()

        #expect(activity.swept == [nil])
    }

    @Test func syncKeepsTheOngoingMigrainesActivity() {
        let repository = InMemoryMigraineRepository()
        let activity = SweepingFakeActivity()
        let ongoing = makeMigraine(start: Date())
        repository.storage = [ongoing]

        makeSync(repository, activity).syncNow()

        #expect(activity.swept == [ongoing.id])
    }

    @Test func reassertSkipsAForgottenMigraine() {
        let repository = InMemoryMigraineRepository()
        let activity = SweepingFakeActivity()
        repository.storage = [makeMigraine(start: Date().addingTimeInterval(-5 * 24 * 3600))]

        makeSync(repository, activity).reassertLiveActivity()

        #expect(activity.started.isEmpty)
    }
}
