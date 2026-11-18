//
//  IntelligenceTools.swift
//  MygraServices
//
//  Tool calling for the on-device assistant. Instead of pasting the whole history into
//  the model's small context window, the assistant looks entries up on demand through
//  two read-only tools that run over Sendable snapshots of the user's own records. The
//  lookup and formatting logic is pure (host-tested); the `Tool` wrappers are gated to
//  the OS versions that ship Foundation Models. Nothing leaves the device.
//

import Foundation
import MygraCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The pure lookups behind the assistant's tools.
nonisolated public enum IntelligenceToolbox {

    /// Most rows a single lookup returns, so one tool call cannot flood the context window.
    public static let maximumRows = 12

    /// Parses `yyyy-MM-dd` (the model is told to use it) into the start of that day.
    public static func parseDay(_ text: String?, calendar: Calendar = .current) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    /// Entries matching the filters, most recent first, as compact one-line rows.
    public static func findRows(
        in snapshots: [MigraineSnapshot],
        from: String? = nil,
        to: String? = nil,
        minimumPain: Int? = nil,
        trigger: String? = nil,
        medication: String? = nil,
        limit: Int? = nil,
        calendar: Calendar = .current
    ) -> String {
        let start = parseDay(from, calendar: calendar)
        let end = parseDay(to, calendar: calendar).flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
        let trigger = trigger?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let medication = medication?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matches = snapshots
            .filter { snapshot in
                if let start, snapshot.startDate < start { return false }
                if let end, snapshot.startDate >= end { return false }
                if let minimumPain, snapshot.painLevel < minimumPain { return false }
                if let trigger, !trigger.isEmpty, !snapshot.triggerNames.contains(where: { $0.lowercased().contains(trigger) }) { return false }
                if let medication, !medication.isEmpty, !snapshot.medications.contains(where: { $0.lowercased().contains(medication) }) { return false }
                return true
            }
            .sorted { $0.startDate > $1.startDate }

        guard !matches.isEmpty else { return "No matching entries." }
        let cap = min(max(limit ?? maximumRows, 1), maximumRows)
        var lines = matches.prefix(cap).map { row(for: $0, calendar: calendar) }
        if matches.count > cap {
            lines.append("(\(matches.count - cap) more matching entries not shown; narrow the dates to see them.)")
        }
        return "\(matches.count) matching entries, most recent first:\n" + lines.joined(separator: "\n")
    }

    /// One entry as a single line: date, pain, stress, duration, triggers, doses, note.
    public static func row(for snapshot: MigraineSnapshot, calendar: Calendar = .current) -> String {
        var formatter = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        formatter.timeZone = calendar.timeZone
        var parts = [
            snapshot.startDate.formatted(formatter),
            "pain \(snapshot.painLevel)/10",
            "stress \(snapshot.stressLevel)/10",
            snapshot.durationHours.map { MigraineDates.durationPhrase(hours: $0) } ?? "ongoing",
        ]
        if !snapshot.triggerNames.isEmpty { parts.append("triggers: " + snapshot.triggerNames.joined(separator: ", ")) }
        if !snapshot.medications.isEmpty { parts.append("doses: " + snapshot.medications.joined(separator: ", ")) }
        if let note = snapshot.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            parts.append("note: " + String(note.prefix(80)))
        }
        return "- " + parts.joined(separator: "; ")
    }

    /// Counts and averages for a period, as short labelled lines.
    public static func summaryText(
        of snapshots: [MigraineSnapshot],
        period: MigrainePeriod,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let inPeriod = period.filter(snapshots, now: now, calendar: calendar)
        let summary = PeriodSummary(inPeriod, calendar: calendar)
        var lines = ["Period: \(label(for: period))", "Migraines: \(summary.count)"]
        guard summary.count > 0 else {
            lines.append("No entries in this period.")
            return lines.joined(separator: "\n")
        }
        lines.append("Days with a migraine: \(summary.migraineDays)")
        if let pain = summary.averagePain { lines.append(String(format: "Average pain: %.1f/10", pain)) }
        if let highest = summary.highestPain { lines.append("Highest pain: \(highest)/10") }
        if let hours = summary.averageDurationHours { lines.append("Average duration of finished entries: \(MigraineDates.durationPhrase(hours: hours))") }
        if !summary.topTriggers.isEmpty {
            lines.append("Most logged triggers: " + summary.topTriggers.map { "\($0.name) (\($0.count))" }.joined(separator: ", "))
        }
        lines.append("Doses recorded: \(summary.medicationDoseCount)")
        if let last = inPeriod.map(\.startDate).max() {
            lines.append("Days since the latest entry: \(MigraineDates.daysSince(last, now: now, calendar: calendar))")
        }
        return lines.joined(separator: "\n")
    }

    public static func label(for period: MigrainePeriod) -> String {
        switch period {
        case .last7Days: "last 7 days"
        case .last30Days: "last 30 days"
        case .last90Days: "last 90 days"
        case .thisMonth: "this calendar month"
        case .thisYear: "this calendar year"
        case .allTime: "all logged history"
        }
    }
}

#if canImport(FoundationModels)

/// The period a summary covers, as the model sees it.
@available(iOS 26.0, macOS 26.0, *)
@Generable
nonisolated enum SummaryPeriodArgument: String {
    case last7Days
    case last30Days
    case last90Days
    case thisMonth
    case thisYear
    case allTime

    var period: MigrainePeriod { MigrainePeriod(rawValue: rawValue) ?? .last30Days }
}

/// Looks up logged entries by date, pain level, trigger, or medication name.
@available(iOS 26.0, macOS 26.0, *)
nonisolated struct FindMigrainesTool: Tool {
    let snapshots: [MigraineSnapshot]

    let name = "findMigraines"
    let description = "Looks up the user's own logged migraine entries. All filters are optional. Use it whenever the user asks about specific entries, dates, triggers, or doses."

    @Generable
    struct Arguments {
        @Guide(description: "First day to include, formatted yyyy-MM-dd.")
        var from: String?
        @Guide(description: "Last day to include, formatted yyyy-MM-dd.")
        var to: String?
        @Guide(description: "Only entries with at least this pain level, 0 to 10.", .range(0...10))
        var minimumPain: Int?
        @Guide(description: "Part of a trigger name, such as stress or sleep.")
        var trigger: String?
        @Guide(description: "Part of a medication name that was recorded.")
        var medication: String?
    }

    func call(arguments: Arguments) async throws -> String {
        IntelligenceToolbox.findRows(
            in: snapshots,
            from: arguments.from,
            to: arguments.to,
            minimumPain: arguments.minimumPain,
            trigger: arguments.trigger,
            medication: arguments.medication
        )
    }
}

/// Counts and averages for a period.
@available(iOS 26.0, macOS 26.0, *)
nonisolated struct MigraineSummaryTool: Tool {
    let snapshots: [MigraineSnapshot]

    let name = "summarizePeriod"
    let description = "Returns counts and averages from the user's own log for a period: number of migraines, days affected, average and highest pain, most logged triggers, and doses recorded. Use it for any how-many or how-often question."

    @Generable
    struct Arguments {
        @Guide(description: "The period to summarize.")
        var period: SummaryPeriodArgument
    }

    func call(arguments: Arguments) async throws -> String {
        IntelligenceToolbox.summaryText(of: snapshots, period: arguments.period.period)
    }
}
#endif
