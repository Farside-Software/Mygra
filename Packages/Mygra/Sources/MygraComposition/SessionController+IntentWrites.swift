//
//  SessionController+IntentWrites.swift
//  MygraComposition
//
//  The writes the logging App Intents make on the migraine in progress. They go through
//  the data model's verbs (use-cases underneath, failures toasted) so the app target
//  never touches a repository or the feature-shared module directly.
//

import Foundation
import MygraCore
import MygraFeatureShared

extension SessionController {
    /// Records a dose on `migraine`. Returns whether it was saved.
    @discardableResult
    public func recordDose(on migraine: Migraine, name: String, medicationClass: MedicationClass, dose: String) -> Bool {
        migraineData.logMedication(for: migraine, name: name, medicationClass: medicationClass, dose: dose)
    }

    /// Adds a trigger to `migraine` if it is not already there. Returns whether it was added.
    @discardableResult
    public func addTrigger(_ trigger: MigraineTrigger, to migraine: Migraine) -> Bool {
        guard !migraine.triggers.contains(trigger) else { return false }
        migraineData.update(migraine) { $0.triggers.append(trigger) }
        return true
    }
}
