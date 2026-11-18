//
//  MigraineLiveActivityIntents.swift
//  MygraServices
//
//  The buttons on the ongoing-migraine Live Activity. They are `LiveActivityIntent`s, so
//  the system runs `perform()` in the app's process (waking it in the background) while
//  the widget extension only renders the buttons. The app registers a
//  `MigraineLiveActivityActions` dependency that does the actual work.
//

#if canImport(ActivityKit) && os(iOS)
import AppIntents
import Foundation

/// The work behind the Live Activity buttons, supplied by the app at launch.
@MainActor
public final class MigraineLiveActivityActions {
    private let changePain: @MainActor (Int) -> Void
    private let endMigraine: @MainActor () -> Void

    /// - Parameters:
    ///   - changePain: Moves the ongoing migraine's pain level by the given amount (clamped to 0-10).
    ///   - endMigraine: Ends the ongoing migraine.
    public init(changePain: @escaping @MainActor (Int) -> Void, endMigraine: @escaping @MainActor () -> Void) {
        self.changePain = changePain
        self.endMigraine = endMigraine
    }

    func adjustPain(by delta: Int) { changePain(delta) }
    func end() { endMigraine() }
}

/// Lets the app target and the widget extension both see the intents above.
public struct MygraServicesIntentsPackage: AppIntentsPackage {}

/// Nudges the ongoing migraine's pain level up or down by one.
public struct AdjustMigrainePainIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Adjust Pain Level"
    public static let description = IntentDescription("Moves the pain level of your ongoing migraine up or down by one.")
    public static let isDiscoverable = false
    /// Usable from the Lock Screen without unlocking: someone mid-migraine should not
    /// have to face a screen and Face ID to nudge a number or end the attack.
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Change")
    public var delta: Int

    @Dependency private var actions: MigraineLiveActivityActions

    public init() {}

    public init(delta: Int) {
        self.delta = delta
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        actions.adjustPain(by: delta)
        return .result()
    }
}

/// Ends the ongoing migraine from the Lock Screen or Dynamic Island.
public struct EndMigraineFromActivityIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End Migraine"
    public static let description = IntentDescription("Marks your ongoing migraine as ended.")
    public static let isDiscoverable = false
    /// Usable from the Lock Screen without unlocking: someone mid-migraine should not
    /// have to face a screen and Face ID to nudge a number or end the attack.
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Dependency private var actions: MigraineLiveActivityActions

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        actions.end()
        return .result()
    }
}
#endif
