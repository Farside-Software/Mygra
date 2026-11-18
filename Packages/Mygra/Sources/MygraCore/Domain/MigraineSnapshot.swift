//
//  MigraineSnapshot.swift
//  MygraCore
//
//  A plain, Sendable copy of the fields of a migraine that Siri answers and the on-device
//  model's tools read, plus the period summary both use. Pure and host-tested: the
//  SwiftData models stay on the main actor; everything downstream works on snapshots.
//

import Foundation

/// A Sendable value copy of one migraine record.
nonisolated public struct MigraineSnapshot: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let painLevel: Int
    public let stressLevel: Int
    public let triggerNames: [String]
    /// "Name" or "Name (dose)" for each dose, in the order taken.
    public let medications: [String]
    public let note: String?

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        painLevel: Int,
        stressLevel: Int = 0,
        triggerNames: [String] = [],
        medications: [String] = [],
        note: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.painLevel = painLevel
        self.stressLevel = stressLevel
        self.triggerNames = triggerNames
        self.medications = medications
        self.note = note
    }

    public var isOngoing: Bool { endDate == nil }

    public var durationHours: Double? {
        endDate.map { max(0, $0.timeIntervalSince(startDate)) / 3600.0 }
    }
}

extension MigraineSnapshot {
    public init(_ migraine: Migraine) {
        self.init(
            id: migraine.id,
            startDate: migraine.startDate,
            endDate: migraine.endDate,
            painLevel: migraine.painLevel,
            stressLevel: migraine.stressLevel,
            triggerNames: migraine.allTriggerNames,
            medications: migraine.sortedMedications.map { $0.dose.isEmpty ? $0.name : "\($0.name) (\($0.dose))" },
            note: migraine.note
        )
    }
}

// MARK: - Periods

/// The spans Siri and the assistant can be asked about ("this month", "last 30 days").
nonisolated public enum MigrainePeriod: String, CaseIterable, Sendable {
    case last7Days
    case last30Days
    case last90Days
    case thisMonth
    case thisYear
    case allTime

    /// The half-open span `[start, end)` ending at `now`; nil for `.allTime`.
    public func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .last7Days: return Self.trailing(days: 7, now: now, calendar: calendar)
        case .last30Days: return Self.trailing(days: 30, now: now, calendar: calendar)
        case .last90Days: return Self.trailing(days: 90, now: now, calendar: calendar)
        case .thisMonth: return calendar.dateInterval(of: .month, for: now).map { DateInterval(start: $0.start, end: max(now, $0.start)) }
        case .thisYear: return calendar.dateInterval(of: .year, for: now).map { DateInterval(start: $0.start, end: max(now, $0.start)) }
        case .allTime: return nil
        }
    }

    /// Whole days ending today, today included.
    private static func trailing(days: Int, now: Date, calendar: Calendar) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
        return DateInterval(start: start, end: max(now, start))
    }

    /// Migraines that began inside the period.
    public func filter(_ snapshots: [MigraineSnapshot], now: Date = Date(), calendar: Calendar = .current) -> [MigraineSnapshot] {
        guard let span = interval(now: now, calendar: calendar) else { return snapshots }
        return snapshots.filter { $0.startDate >= span.start && $0.startDate <= span.end }
    }
}

// MARK: - Summary

/// Counts and averages over the migraines in a period. Descriptive only.
nonisolated public struct PeriodSummary: Equatable, Sendable {
    public let count: Int
    /// Distinct calendar days with a migraine start.
    public let migraineDays: Int
    public let averagePain: Double?
    public let averageDurationHours: Double?
    public let highestPain: Int?
    /// Most-logged triggers, most frequent first (ties alphabetical).
    public let topTriggers: [TriggerCount]
    /// Doses recorded across the period.
    public let medicationDoseCount: Int

    public struct TriggerCount: Equatable, Sendable {
        public let name: String
        public let count: Int
        public init(name: String, count: Int) {
            self.name = name
            self.count = count
        }
    }

    public init(_ snapshots: [MigraineSnapshot], calendar: Calendar = .current, triggerLimit: Int = 3) {
        count = snapshots.count
        migraineDays = Set(snapshots.map { calendar.startOfDay(for: $0.startDate) }).count
        averagePain = snapshots.isEmpty ? nil : Double(snapshots.reduce(0) { $0 + $1.painLevel }) / Double(snapshots.count)
        let durations = snapshots.compactMap(\.durationHours)
        averageDurationHours = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
        highestPain = snapshots.map(\.painLevel).max()
        var counts: [String: (name: String, count: Int)] = [:]
        for name in snapshots.flatMap(\.triggerNames) {
            let key = name.lowercased()
            counts[key] = (counts[key]?.name ?? name, (counts[key]?.count ?? 0) + 1)
        }
        topTriggers = counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(triggerLimit)
            .map { TriggerCount(name: $0.name, count: $0.count) }
        medicationDoseCount = snapshots.reduce(0) { $0 + $1.medications.count }
    }
}
