//
//  MygraLogIntents.swift
//  Mygra
//
//  Hands-free logging for the things people do mid-attack: a dose taken, a trigger
//  noticed, water or caffeine. Doses and triggers are recorded on the migraine in
//  progress, through the session's data model (which runs the use-cases and toasts on
//  failure); intake goes to Health like the Today card's Quick Add. These stay free:
//  Plus gates only the Apple Intelligence features.
//

import AppIntents
import Foundation
import MygraComposition
import MygraCore
import MygraServices

// MARK: - Medication class (AppEnum)

enum MygraMedicationClass: String, AppEnum {
    case triptan
    case simpleAnalgesic
    case combinationAnalgesic
    case opioid
    case gepant
    case ergot
    case other

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Medication Type" }

    nonisolated static var caseDisplayRepresentations: [MygraMedicationClass: DisplayRepresentation] {
        [
            .triptan: "Triptan",
            .simpleAnalgesic: "Simple analgesic",
            .combinationAnalgesic: "Combination analgesic",
            .opioid: "Opioid",
            .gepant: "Gepant",
            .ergot: "Ergot",
            .other: "Other",
        ]
    }

    var medicationClass: MedicationClass { MedicationClass(rawValue: rawValue) ?? .other }
}

/// Suggests medications the person has recorded before; any other name can still be typed or spoken.
struct MedicationNameOptions: DynamicOptionsProvider {
    @Dependency private var session: SessionController

    @MainActor
    func results() async throws -> [String] {
        MedicationMemory.known(from: try session.loadMigraines()).map(\.name)
    }
}

// MARK: - Log a dose

struct LogMedicationIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Medication"
    static let description = IntentDescription("Records a dose you took on the migraine in progress.", categoryName: "Logging")

    @Parameter(title: "Medication", requestValueDialog: "What did you take?", optionsProvider: MedicationNameOptions())
    var medication: String

    @Parameter(title: "Dose", description: "For example 50 mg.")
    var dose: String?

    @Parameter(title: "Type", description: "Defaults to the type you recorded for this medication before.")
    var type: MygraMedicationClass?

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$medication)") {
            \.$dose
            \.$type
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let migraines = try session.loadMigraines()
        guard let ongoing = migraines.first(where: \.isOngoing) else {
            return .result(dialog: "You don't have a migraine in progress, so there's nothing to attach this to. Start one first.")
        }
        let known = MedicationMemory.resolve(medication, in: MedicationMemory.known(from: migraines))
        let name = known?.name ?? medication.trimmingCharacters(in: .whitespacesAndNewlines)
        let recorded = session.recordDose(
            on: ongoing,
            name: name,
            medicationClass: type?.medicationClass ?? known?.medicationClass ?? .other,
            dose: (dose ?? known?.dose ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard recorded else {
            return .result(dialog: "I couldn't record that. Open Mygra and try again.")
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: String(localized: "Recorded \(name) on your migraine."))))
    }
}

// MARK: - Trigger entity

/// A trigger from Mygra's built-in list.
struct TriggerEntity: AppEntity {
    let id: String
    let name: String

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Trigger" }
    static let defaultQuery = TriggerEntityQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name)) }

    init(_ trigger: MigraineTrigger) {
        id = trigger.rawValue
        name = trigger.displayName
    }
}

struct TriggerEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TriggerEntity] {
        identifiers.compactMap(MigraineTrigger.init(rawValue:)).map(TriggerEntity.init)
    }

    func entities(matching string: String) async throws -> [TriggerEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MigraineTrigger.allCases
            .filter { $0.displayName.lowercased().contains(needle) }
            .map(TriggerEntity.init)
    }

    func suggestedEntities() async throws -> [TriggerEntity] {
        MigraineTrigger.allCases.map(TriggerEntity.init)
    }
}

// MARK: - Log a trigger

struct LogTriggerIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Trigger"
    static let description = IntentDescription("Adds a trigger you noticed to the migraine in progress.", categoryName: "Logging")

    @Parameter(title: "Trigger", requestValueDialog: "Which trigger did you notice?")
    var trigger: TriggerEntity

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$trigger) as a trigger")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let ongoing = try session.loadMigraines().first(where: \.isOngoing) else {
            return .result(dialog: "You don't have a migraine in progress, so there's nothing to attach this to. Start one first.")
        }
        guard let selected = MigraineTrigger(rawValue: trigger.id) else {
            return .result(dialog: "I couldn't find that trigger.")
        }
        guard session.addTrigger(selected, to: ongoing) else {
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: String(localized: "\(trigger.name) is already on your migraine."))))
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: String(localized: "Added \(trigger.name) to your migraine."))))
    }
}

// MARK: - Water and caffeine (Health)

#if canImport(HealthKit)
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Saves water you drank to Health, where Mygra reads it for your entries.", categoryName: "Logging")

    @Parameter(title: "Amount", requestValueDialog: "How much water?")
    var amount: Measurement<UnitVolume>

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let liters = amount.converted(to: .liters).value
        guard liters > 0, liters <= 5 else {
            return .result(dialog: "That amount doesn't look right. Try again with a smaller number.")
        }
        do {
            try await session.healthManager.saveWater(liters: liters)
        } catch {
            return .result(dialog: "I couldn't save to Health. Check that Mygra can write water in Health settings, and that your phone is unlocked.")
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: String(localized: "Saved \(amount.formatted()) of water to Health."))))
    }
}

struct LogCaffeineIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Caffeine"
    static let description = IntentDescription("Saves caffeine you had to Health, where Mygra reads it for your entries.", categoryName: "Logging")

    @Parameter(title: "Milligrams", default: 95, inclusiveRange: (1, 1000), requestValueDialog: "How many milligrams of caffeine?")
    var milligrams: Int

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$milligrams) mg of caffeine")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await session.healthManager.saveCaffeine(mg: Double(milligrams))
        } catch {
            return .result(dialog: "I couldn't save to Health. Check that Mygra can write caffeine in Health settings, and that your phone is unlocked.")
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: String(localized: "Saved \(milligrams) mg of caffeine to Health."))))
    }
}
#endif
