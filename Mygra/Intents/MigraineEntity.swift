//
//  MigraineEntity.swift
//  Mygra
//
//  An App Intents entity mirroring a logged migraine. Conforms to IndexedEntity so
//  migraines are surfaced in Spotlight semantic search, and backs intents that take a
//  specific migraine as a parameter.
//

import AppIntents
import CoreSpotlight
import Foundation
import MygraComposition
import CoreTransferable
import MygraCore

struct MigraineEntity: AppEntity, IndexedEntity, Transferable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let painLevel: Int
    let note: String?
    let triggerNames: [String]

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Migraine")
    }

    static let defaultQuery = MigraineEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        let dateText = startDate.formatted(date: .abbreviated, time: .shortened)
        let subtitle: LocalizedStringResource = (note?.isEmpty == false)
            ? LocalizedStringResource(stringLiteral: note!)
            : "Pain \(painLevel)/10"
        return DisplayRepresentation(title: "Migraine — \(dateText)", subtitle: subtitle)
    }

    /// What Siri and Shortcuts hand to other apps when this migraine is shared or copied:
    /// a plain-text description of the record.
    var summaryText: String {
        var parts = [startDate.formatted(date: .abbreviated, time: .shortened), String(localized: "Pain \(painLevel) of 10")]
        if let endDate {
            parts.append(MigraineDates.durationString(endDate.timeIntervalSince(startDate)))
        } else {
            parts.append(String(localized: "In progress"))
        }
        if !triggerNames.isEmpty { parts.append(triggerNames.joined(separator: ", ")) }
        if let note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.summaryText)
    }

    /// Spotlight metadata enabling semantic, on-device search.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = "Migraine on \(startDate.formatted(date: .abbreviated, time: .omitted))"
        var parts: [String] = ["Pain level \(painLevel) out of 10"]
        if let note, !note.isEmpty { parts.append(note) }
        if !triggerNames.isEmpty { parts.append("Triggers: " + triggerNames.joined(separator: ", ")) }
        set.contentDescription = parts.joined(separator: ". ")
        set.keywords = ["migraine", "headache"] + triggerNames
        set.startDate = startDate
        set.endDate = endDate
        return set
    }
}

extension MigraineEntity {
    @MainActor
    init(_ migraine: Migraine) {
        id = migraine.id
        startDate = migraine.startDate
        endDate = migraine.endDate
        painLevel = migraine.painLevel
        note = migraine.note
        triggerNames = migraine.allTriggerNames
    }
}

// MARK: - Query

/// Resolves migraines by identifier, suggests recent ones, and searches by typed or spoken
/// text ("the one with the weather trigger", "November 3") across notes, triggers and dates.
struct MigraineEntityQuery: EntityStringQuery {
    @Dependency private var session: SessionController

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [MigraineEntity] {
        try session.loadMigraines()
            .filter { identifiers.contains($0.id) }
            .map(MigraineEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [MigraineEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return try await suggestedEntities() }
        return try session.loadMigraines()
            .sorted { $0.startDate > $1.startDate }
            .filter { migraine in
                let dateText = migraine.startDate.formatted(date: .complete, time: .omitted).lowercased()
                    + " " + migraine.startDate.formatted(date: .abbreviated, time: .omitted).lowercased()
                return dateText.contains(needle)
                    || (migraine.note?.lowercased().contains(needle) ?? false)
                    || migraine.allTriggerNames.contains { $0.lowercased().contains(needle) }
                    || migraine.sortedMedications.contains { $0.name.lowercased().contains(needle) }
            }
            .prefix(20)
            .map(MigraineEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [MigraineEntity] {
        try session.loadMigraines()
            .prefix(10)
            .map(MigraineEntity.init)
    }
}

// MARK: - View a specific migraine

struct ViewMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Migraine"
    static let description = IntentDescription("Opens a specific migraine's details in Mygra.")
    static let openAppWhenRun = true

    @Parameter(title: "Migraine")
    var migraine: MigraineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$migraine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.migraine(migraine.id).storePending(in: AppGroup.defaults)
        return .result()
    }
}
