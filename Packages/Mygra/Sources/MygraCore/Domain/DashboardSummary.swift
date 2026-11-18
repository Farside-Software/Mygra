//
//  DashboardSummary.swift
//  MygraCore
//
//  The counts behind the free Dashboard cards, computed on device from the migraines the
//  app already holds: this month against last month, a 30-day strip, the most-logged
//  triggers and medications, and plain time-of-day and day-of-week counts. Facts only:
//  nothing here predicts, advises or implies a cause.
//

import Foundation

/// One calendar month at a glance.
nonisolated public struct MonthGlance: Equatable, Sendable {
    /// Migraines that started in the month.
    public var count: Int
    /// Calendar days in the month on which a migraine was under way (a long attack covers
    /// every day it touched).
    public var daysWithMigraine: Int
    /// Average length of the month's completed migraines, in hours.
    public var averageDurationHours: Double?
    /// Length of the month's longest completed migraine, in hours.
    public var longestDurationHours: Double?
    /// Average of each migraine's highest recorded pain (the logged level or any intensity sample).
    public var averagePeakPain: Double?

    public static let empty = MonthGlance(count: 0, daysWithMigraine: 0, averageDurationHours: nil, longestDurationHours: nil, averagePeakPain: nil)
}

/// One day of the 30-day strip.
nonisolated public struct DashboardDayMark: Equatable, Sendable, Identifiable {
    public var date: Date
    /// Migraines under way on this day.
    public var migraineCount: Int
    public var id: Date { date }
    public var hadMigraine: Bool { migraineCount > 0 }
}

/// A name with how often it was logged.
nonisolated public struct DashboardCount: Equatable, Sendable, Identifiable {
    public var name: String
    public var count: Int
    public var id: String { name.lowercased() }
}

/// Part of the day a migraine started in.
nonisolated public enum DashboardDayPart: String, CaseIterable, Sendable {
    case night, morning, afternoon, evening

    /// Night is midnight to 5 AM, morning 5 AM to noon, afternoon noon to 5 PM, evening 5 PM to midnight.
    public static func of(hour: Int) -> DashboardDayPart {
        switch hour {
        case 0..<5: .night
        case 5..<12: .morning
        case 12..<17: .afternoon
        default: .evening
        }
    }
}

nonisolated public struct DashboardSummary: Equatable, Sendable {
    public var thisMonth: MonthGlance
    public var lastMonth: MonthGlance
    /// The last 30 days, oldest first, ending today.
    public var recentDays: [DashboardDayMark]
    /// Most-logged triggers this month (at most `topLimit`).
    public var topTriggers: [DashboardCount]
    /// Most-logged medications this month (at most `topLimit`).
    public var topMedications: [DashboardCount]
    /// Migraine starts by part of the day, across everything logged.
    public var dayPartCounts: [DashboardDayPart: Int]
    /// Migraine starts by weekday, indexed 0...6 in the calendar's weekday order starting at
    /// `calendar.firstWeekday`.
    public var weekdayCounts: [Int]
    /// First weekday used for `weekdayCounts` (1 = Sunday).
    public var firstWeekday: Int
    public var totalLogged: Int

    public static let topLimit = 3
    /// Patterns need a few migraines before counts mean anything to show.
    public static let patternMinimum = 4

    public var migraineDaysInLast30: Int { recentDays.filter(\.hadMigraine).count }

    /// The longest run of days without a migraine inside the last 30 days.
    public var longestFreeStretchInLast30: Int {
        var best = 0, run = 0
        for day in recentDays {
            run = day.hadMigraine ? 0 : run + 1
            best = max(best, run)
        }
        return best
    }

    public var hasPatterns: Bool { totalLogged >= Self.patternMinimum }
    public var hasAnyThisMonthOrLastMonth: Bool { thisMonth.count > 0 || lastMonth.count > 0 }
    public var isEmpty: Bool { totalLogged == 0 }

    public init(_ migraines: [Migraine], now: Date = Date(), calendar: Calendar = .current) {
        totalLogged = migraines.count
        firstWeekday = calendar.firstWeekday

        let today = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? today
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now

        let thisMonthItems = migraines.filter { $0.startDate >= monthStart && $0.startDate < nextMonthStart }
        let lastMonthItems = migraines.filter { $0.startDate >= lastMonthStart && $0.startDate < monthStart }
        let coveredDays = Self.dayCounts(migraines, now: now, calendar: calendar)
        thisMonth = Self.glance(thisMonthItems, from: monthStart, to: nextMonthStart, coveredDays: coveredDays, calendar: calendar)
        lastMonth = Self.glance(lastMonthItems, from: lastMonthStart, to: monthStart, coveredDays: coveredDays, calendar: calendar)

        recentDays = (0..<30).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DashboardDayMark(date: day, migraineCount: coveredDays[day] ?? 0)
        }

        topTriggers = Self.top(thisMonthItems.flatMap { $0.allTriggerNames })
        topMedications = Self.top(thisMonthItems.flatMap { ($0.medications ?? []).map(\.name) })

        var parts: [DashboardDayPart: Int] = [:]
        var weekdays = [Int](repeating: 0, count: 7)
        for migraine in migraines {
            parts[DashboardDayPart.of(hour: calendar.component(.hour, from: migraine.startDate)), default: 0] += 1
            let weekday = calendar.component(.weekday, from: migraine.startDate)
            weekdays[(weekday - calendar.firstWeekday + 7) % 7] += 1
        }
        dayPartCounts = parts
        weekdayCounts = weekdays
    }

    // MARK: - Pieces

    /// Migraines under way on each start-of-day. An ongoing migraine runs through today; a
    /// migraine is capped at 14 days so a forgotten open record cannot paint the whole strip.
    static func dayCounts(_ migraines: [Migraine], now: Date, calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for migraine in migraines {
            let first = calendar.startOfDay(for: migraine.startDate)
            let end = migraine.endDate ?? now
            let last = max(first, calendar.startOfDay(for: end))
            var day = first
            var steps = 0
            while day <= last && steps < 14 {
                counts[day, default: 0] += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                steps += 1
            }
        }
        return counts
    }

    static func glance(_ items: [Migraine], from start: Date, to end: Date, coveredDays: [Date: Int], calendar: Calendar) -> MonthGlance {
        let days = coveredDays.keys.filter { $0 >= start && $0 < end }.count
        let durations = items.compactMap { item -> Double? in
            guard let finished = item.endDate else { return nil }
            return max(0, finished.timeIntervalSince(item.startDate)) / 3600
        }
        let peaks = items.map { item -> Double in
            let sampled = (item.intensitySamples ?? []).map(\.painLevel).max() ?? 0
            return Double(max(item.painLevel, sampled))
        }
        return MonthGlance(
            count: items.count,
            daysWithMigraine: days,
            averageDurationHours: durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count),
            longestDurationHours: durations.max(),
            averagePeakPain: peaks.isEmpty ? nil : peaks.reduce(0, +) / Double(peaks.count)
        )
    }

    /// Counts names case-insensitively (keeping the first spelling seen), most frequent
    /// first, ties alphabetical.
    static func top(_ names: [String], limit: Int = topLimit) -> [DashboardCount] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            counts[key, default: 0] += 1
            if spelling[key] == nil { spelling[key] = name }
        }
        return counts
            .map { DashboardCount(name: spelling[$0.key] ?? $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(limit)
            .map { $0 }
    }
}
