//
//  IntelligenceService.swift
//  MygraServices
//
//  Apple Intelligence (Foundation Models, iOS 26+) behind the Core `MigraineIntelligence`
//  seam: single-migraine analysis, Quick Bit explanations (guided generation), and the
//  multi-turn analyst chat, which streams its replies and looks entries up through
//  read-only tools over the user's own records. Everything runs on device. Every model
//  call is availability-gated so the module compiles for the iOS 18 floor; prompts are
//  built by pure helpers that are host-tested.
//

import Foundation
import Observation
import MygraCore
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated public enum IntelligenceError: LocalizedError {
    case unavailable
    case chatInactive
    case declined

    public var errorDescription: String? {
        switch self {
        case .unavailable: return String(localized: "Apple Intelligence is not available on this device.")
        case .chatInactive: return String(localized: "Chat session is not active. Please start a new analysis chat.")
        case .declined: return String(localized: "I can't help with that one. Try asking about the entries in your log.")
        }
    }
}

#if canImport(FoundationModels)
/// The explanation the model fills in directly (guided generation), replacing JSON parsing.
@available(iOS 26.0, macOS 26.0, *)
@Generable
nonisolated struct GeneratedExplanation {
    @Guide(description: "One or two plain sentences describing what the insight shows in the user's own log. Descriptive only, no advice.")
    var summary: String
    @Guide(description: "One short, non-medical thing the user could look at in their own log next, phrased as a suggestion to look, not as treatment or advice.")
    var nextLook: String
}
#endif

@MainActor
@Observable
public final class IntelligenceService: MigraineIntelligence {

    public private(set) var conversation: [ChatMessage] = []
    public private(set) var isChatActive: Bool = false

    /// Holds a `LanguageModelSession` on supported OS versions.
    @ObservationIgnored private var chatSession: AnyObject?
    /// What the chat was started with, so a session can be rebuilt after a context overflow.
    @ObservationIgnored private var chatContext: ChatContext?

    private struct ChatContext {
        let snapshots: [MigraineSnapshot]
        let userSummary: String
        let historySummary: String
    }

    public init() {}

    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Single-migraine analysis

    public func analyze(migraine: Migraine, user: User?) async throws -> String? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: IntelligencePrompts.analysisInstructions)
            let response = try await session.respond(
                to: IntelligencePrompts.analysisPrompt(migraine: migraine, user: user),
                options: GenerationOptions(temperature: 0.4)
            )
            return response.content
        }
        #endif
        return nil
    }

    // MARK: - Quick Bit explanation

    public func explain(insight: Insight, user: User?) async throws -> QuickBitExplanation? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: IntelligencePrompts.explanationInstructions)
            let prompt = IntelligencePrompts.explanationPrompt(insight: insight, user: user)
            do {
                let generated = try await session.respond(to: prompt, generating: GeneratedExplanation.self, options: GenerationOptions(temperature: 0.3)).content
                return QuickBitExplanation(description: generated.summary, recommendation: generated.nextLook)
            } catch let error as LanguageModelSession.GenerationError {
                // Guided generation can fail on an oddly shaped insight; fall back to plain text.
                Log.intelligence.error("Guided explanation failed, falling back to text: \(error.localizedDescription)")
                let fallback = LanguageModelSession(instructions: IntelligencePrompts.explanationFallbackInstructions)
                let response = try await fallback.respond(to: prompt)
                return IntelligencePrompts.parseExplanation(response.content, fallbackDescription: insight.message)
            }
        }
        #endif
        return nil
    }

    // MARK: - Analyst chat

    public func startChat(migraines: [Migraine], user: User?) async {
        guard isAvailable else { return }
        conversation.removeAll()

        let snapshots = migraines.map(MigraineSnapshot.init)
        let context = ChatContext(
            snapshots: snapshots,
            userSummary: IntelligencePrompts.summarize(user: user),
            historySummary: IntelligencePrompts.summarize(migraines: migraines, limit: 50)
        )
        chatContext = context
        conversation.append(.assistant(IntelligencePrompts.chatGreeting(entryCount: min(migraines.count, 60))))

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = makeChatSession(context)
            session.prewarm()
            chatSession = session
            isChatActive = true
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func makeChatSession(_ context: ChatContext) -> LanguageModelSession {
        LanguageModelSession(
            tools: [FindMigrainesTool(snapshots: context.snapshots), MigraineSummaryTool(snapshots: context.snapshots)],
            instructions: IntelligencePrompts.chatInstructions(userSummary: context.userSummary, historySummary: context.historySummary)
        )
    }
    #endif

    /// Sends a message and streams the reply into `conversation` as it is written. Returns
    /// the finished reply.
    public func send(message: String) async throws -> String {
        guard isAvailable else { throw IntelligenceError.unavailable }
        guard isChatActive else { throw IntelligenceError.chatInactive }
        conversation.append(.user(message))
        conversation.append(.assistant(""))
        let replyIndex = conversation.count - 1

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), var session = chatSession as? LanguageModelSession {
            var retriedAfterOverflow = false
            while true {
                do {
                    var latest = ""
                    for try await snapshot in session.streamResponse(to: message, options: GenerationOptions(temperature: 0.3)) {
                        latest = snapshot.content
                        conversation[replyIndex] = .assistant(latest)
                    }
                    chatSession = session
                    return latest
                } catch LanguageModelSession.GenerationError.exceededContextWindowSize where !retriedAfterOverflow {
                    // The conversation outgrew the on-device window: start a fresh session
                    // with the same instructions and tools, then ask again.
                    retriedAfterOverflow = true
                    guard let context = chatContext else { break }
                    session = makeChatSession(context)
                    conversation[replyIndex] = .assistant("")
                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    conversation[replyIndex] = .assistant(IntelligenceError.declined.errorDescription ?? "")
                    throw IntelligenceError.declined
                } catch {
                    conversation[replyIndex] = .assistant(IntelligencePrompts.chatFailureReply)
                    throw error
                }
            }
        }
        #endif
        conversation[replyIndex] = .assistant(IntelligencePrompts.chatFailureReply)
        throw IntelligenceError.chatInactive
    }

    public func resetChat() {
        chatSession = nil
        chatContext = nil
        conversation.removeAll()
        isChatActive = false
    }
}

// MARK: - Prompts (pure)

public enum IntelligencePrompts {

    /// The disclaimer every generated explanation ends with.
    public static let analysisDisclaimer = "This describes your own log and is not medical advice."

    public static let analysisInstructions = """
    You summarize one entry from a person's own migraine log.
    Describe only what the entry records: pain and stress levels, how long it lasted, the triggers the person selected, and any intake, sleep, or weather figures logged around it.
    You may point out which logged figures stood out, for example short sleep or a low pressure reading, as things that were recorded at the same time. Never say they caused the migraine.
    Do not diagnose, do not predict future migraines, and do not suggest medication, doses, or treatment. Do not give advice.
    Write 2 to 4 plain sentences. End with: "\(analysisDisclaimer)"
    """

    public static let explanationInstructions = """
    You explain one pattern shown in a person's own migraine log, in everyday words.
    Stay descriptive: say what the log shows, not what it means medically. Never diagnose, predict, or suggest medication or treatment.
    The second part is only something the person could look at in their own log next, for example comparing sleep on migraine days. It is not advice.
    """

    /// Used when guided generation fails and the model is asked for plain text instead.
    public static let explanationFallbackInstructions = """
    \(explanationInstructions)
    Reply with two short lines. Line one: what the log shows. Line two: one thing the person could look at in their own log next.
    """

    public static let chatFailureReply = String(localized: "Sorry, I ran into a problem.")

    /// Questions the assistant offers before the first message, each answerable from the log.
    public static var starterQuestions: [String] {
        [
            String(localized: "How many migraines did I have this month?"),
            String(localized: "Which triggers do I log most often?"),
            String(localized: "When was my last severe migraine?"),
            String(localized: "What did I take for my last migraine?"),
        ]
    }

    public static func chatInstructions(userSummary: String, historySummary: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        var instructions = """
        You are the assistant inside Mygra, a migraine journal. You answer questions about the person's own logged entries, and nothing else.
        Everything you know comes from two tools: findMigraines (look up entries by date, pain level, trigger, or medication) and summarizePeriod (counts and averages). Call a tool before you state any date, count, average, or trigger. If a tool returns nothing, say there are no matching entries. Never guess or invent entries.
        Describe patterns in the log in neutral language. Say "your log shows" rather than claiming a cause. Never diagnose, never predict whether a migraine will happen, and never recommend, name, or dose a medication or treatment. If asked for medical advice, say you can only describe the log and suggest asking a clinician.
        Keep answers short: a few sentences. Reply in the language the person writes in.
        Today is \(dayString(now, calendar: calendar)).
        """
        if !userSummary.isEmpty { instructions += "\nProfile: \(userSummary)" }
        if !historySummary.isEmpty { instructions += "\nHistory overview: \(historySummary)" }
        return instructions
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        var style = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    public static func chatGreeting(entryCount: Int) -> String {
        String(localized: "I’ve loaded your migraine history and profile, including your last \(entryCount) entries. I can analyze patterns and trends in your logs. What would you like to explore?")
    }

    public static func analysisPrompt(migraine: Migraine, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Summarize what this single migraine entry records, including any logged figures that stood out. Describe only; do not state causes, give advice, or suggest treatment.")
        lines.append("2–4 sentences max.")
        if let name = user?.name, !name.isEmpty {
            lines.append("User: \(name)")
        }
        lines.append("Pain: \(migraine.painLevel)/10, Stress: \(migraine.stressLevel)/10")
        if let end = migraine.endDate {
            let hours = max(0, end.timeIntervalSince(migraine.startDate)) / 3600.0
            lines.append(String(format: "Duration: %.1f hours", hours))
        } else {
            lines.append("Duration: ongoing")
        }
        let triggers = migraine.allTriggerNames
        if !triggers.isEmpty {
            lines.append("Selected triggers: \(triggers.joined(separator: ", "))")
        }
        if !migraine.foodsEaten.isEmpty {
            lines.append("Foods: \(migraine.foodsEaten.joined(separator: ", "))")
        }
        if let health = migraine.health {
            var bits: [String] = []
            if let water = health.waterLiters { bits.append(String(format: "water=%.1fL", water)) }
            if let sleep = health.sleepHours { bits.append(String(format: "sleep=%.1fh", sleep)) }
            if let kcal = health.energyKilocalories { bits.append(String(format: "calories=%.0f kcal", kcal)) }
            if let caffeine = health.caffeineMg { bits.append(String(format: "caffeine=%.0f mg", caffeine)) }
            if !bits.isEmpty { lines.append("Health: " + bits.joined(separator: ", ")) }
        }
        if let weather = migraine.weather {
            lines.append(String(format: "Weather: %.0f hPa, %.0f%% humidity, %.0f°C, condition=%@",
                                weather.barometricPressureHpa, weather.humidityPercent, weather.temperatureCelsius, weather.condition.rawValue))
        }
        if let note = migraine.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Note: \(note)")
        }
        lines.append("Output: A short descriptive summary of the entry. End with: \(analysisDisclaimer)")
        return lines.joined(separator: "\n")
    }

    public static func explanationPrompt(insight: Insight, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Explain what this insight shows in everyday terms, then name one thing the person could look at in their own log next. Describe only; no advice or treatment.")
        if let name = user?.name, !name.isEmpty {
            lines.append("User: \(name)")
        }
        lines.append("Insight category: \(insight.category.rawValue)")
        lines.append("Title: \(insight.title)")
        if !insight.message.isEmpty {
            lines.append("Message: \(insight.message)")
        }
        if !insight.tags.isEmpty {
            let tags = insight.tags.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
            lines.append("Tags: \(tags)")
        }
        lines.append("Priority: \(insight.priority.rawValue)")
        return lines.joined(separator: "\n")
    }

    /// Decodes the model's JSON (tolerating code fences and surrounding prose), falling
    /// back to a heuristic split of plain text.
    public static func parseExplanation(_ raw: String, fallbackDescription: String) -> QuickBitExplanation {
        let cleaned = extractJSON(from: raw) ?? raw
        if let decoded = try? JSONDecoder().decode(QuickBitExplanation.self, from: Data(cleaned.utf8)) {
            return decoded
        }
        let parts = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let description = parts.first ?? fallbackDescription
        let recommendation = parts.dropFirst().joined(separator: " ")
        return QuickBitExplanation(
            description: description,
            recommendation: recommendation.isEmpty
                ? String(localized: "Consider small, everyday adjustments like hydration, sleep regularity, and balanced meals.")
                : recommendation
        )
    }

    static func extractJSON(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let newline = s.range(of: "\n") {
                s.removeSubrange(s.startIndex..<newline.upperBound)
            }
            if let fence = s.range(of: "```", options: .backwards) {
                s.removeSubrange(fence.lowerBound..<s.endIndex)
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}"), first <= last {
            return String(s[first...last])
        }
        return nil
    }

    /// A compact Markdown table and JSON array of recent migraines (most recent first).
    public static func historyDataset(migraines: [Migraine], limit: Int) -> (table: String, json: String) {
        let slice = migraines.sorted { $0.startDate > $1.startDate }.prefix(limit)
        var tableLines: [String] = [
            "| date | pain | stress | triggers | duration_h | sleep_h | caffeine_mg | pressure_hPa | humidity_% | temp_C |",
            "|------|------|--------|----------|------------|---------|-------------|--------------|------------|--------|",
        ]
        var jsonItems: [String] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        for migraine in slice {
            let date = formatter.string(from: migraine.startDate)
            let triggers = migraine.allTriggerNames.joined(separator: "; ")
            let durationHours: Double = migraine.endDate.map { max(0, $0.timeIntervalSince(migraine.startDate)) / 3600.0 } ?? 0
            let sleep = migraine.health?.sleepHours.map { String(format: "%.1f", $0) } ?? ""
            let caffeine = migraine.health?.caffeineMg.map { String(format: "%.0f", $0) } ?? ""
            let pressure = migraine.weather.map { String(format: "%.0f", $0.barometricPressureHpa) } ?? ""
            let humidity = migraine.weather.map { String(format: "%.0f", $0.humidityPercent) } ?? ""
            let temperature = migraine.weather.map { String(format: "%.0f", $0.temperatureCelsius) } ?? ""

            tableLines.append("|\(date)|\(migraine.painLevel)|\(migraine.stressLevel)|\(triggers)|\(String(format: "%.1f", durationHours))|\(sleep)|\(caffeine)|\(pressure)|\(humidity)|\(temperature)|")
            jsonItems.append(
                "{\"date\":\"\(date)\",\"pain\":\(migraine.painLevel),\"stress\":\(migraine.stressLevel),\"triggers\":\"\(triggers)\",\"duration_h\":\(String(format: "%.1f", durationHours)),\"sleep_h\":\(sleep.isEmpty ? "null" : sleep),\"caffeine_mg\":\(caffeine.isEmpty ? "null" : caffeine),\"pressure_hPa\":\(pressure.isEmpty ? "null" : pressure),\"humidity_pct\":\(humidity.isEmpty ? "null" : humidity),\"temp_C\":\(temperature.isEmpty ? "null" : temperature)}"
            )
        }
        return (tableLines.joined(separator: "\n"), "[\n" + jsonItems.joined(separator: ",\n") + "\n]")
    }

    public static func summarize(user: User?) -> String {
        guard let user else { return "" }
        var parts: [String] = []
        if !user.name.isEmpty { parts.append("name=\(user.name)") }
        parts.append(String(format: "avgSleep=%.1fh", user.averageSleepHours))
        parts.append("avgCaffeine=\(Int(user.averageCaffeineMg))mg")
        if !user.chronicConditions.isEmpty { parts.append("conditions=\(user.chronicConditions.joined(separator: ", "))") }
        if !user.dietaryRestrictions.isEmpty { parts.append("dietary=\(user.dietaryRestrictions.joined(separator: ", "))") }
        return parts.joined(separator: "; ")
    }

    public static func summarize(migraines: [Migraine], limit: Int) -> String {
        guard !migraines.isEmpty else { return "" }
        let top = migraines.prefix(limit)
        let avgPain = Double(top.reduce(0) { $0 + $1.painLevel }) / Double(top.count)
        let triggers = Array(Set(top.flatMap { $0.triggers.map(\.displayName) })).sorted().prefix(10)
        return "count=\(migraines.count); recentAvgPain=\(String(format: "%.1f", avgPain)); commonTriggers=\(triggers.joined(separator: ", "))"
    }
}
