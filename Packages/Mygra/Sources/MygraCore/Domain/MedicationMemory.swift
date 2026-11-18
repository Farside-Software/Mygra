//
//  MedicationMemory.swift
//  MygraCore
//
//  What the user has recorded before, so a spoken "I took my sumatriptan" can reuse the
//  class and dose last recorded for that name instead of asking again. Pure and host-tested.
//

import Foundation

/// A medication the user has recorded before, with the class and dose it was last recorded with.
nonisolated public struct KnownMedication: Equatable, Sendable {
    public let name: String
    public let medicationClass: MedicationClass
    public let dose: String

    public init(name: String, medicationClass: MedicationClass, dose: String = "") {
        self.name = name
        self.medicationClass = medicationClass
        self.dose = dose
    }
}

public enum MedicationMemory {
    /// Distinct medications (case-insensitive by name), the most recently taken first.
    public static func known(from migraines: [Migraine]) -> [KnownMedication] {
        let doses = migraines
            .flatMap { $0.medications ?? [] }
            .sorted { $0.takenAt > $1.takenAt }
        var seen = Set<String>()
        var result: [KnownMedication] = []
        for dose in doses {
            let name = dose.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(KnownMedication(name: name, medicationClass: dose.medicationClass, dose: dose.dose))
        }
        return result
    }

    /// The known medication whose name matches `spoken` exactly (ignoring case), or else
    /// the only one that contains it. Ambiguous or unknown names resolve to nil.
    public static func resolve(_ spoken: String, in known: [KnownMedication]) -> KnownMedication? {
        let needle = spoken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        if let exact = known.first(where: { $0.name.lowercased() == needle }) { return exact }
        let partial = known.filter { $0.name.lowercased().contains(needle) || needle.contains($0.name.lowercased()) }
        return partial.count == 1 ? partial[0] : nil
    }
}
