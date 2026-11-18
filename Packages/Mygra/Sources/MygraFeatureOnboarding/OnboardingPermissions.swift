//
//  OnboardingPermissions.swift
//  MygraFeatureOnboarding
//
//  What each permission step shows for the current authorization state, and how the primary
//  button behaves: "Allow …" until the system has been asked, "Continue" afterwards. Nothing
//  here requests anything by itself; the explicit button does, per the HIG.
//

#if os(iOS)
import SwiftUI
import CoreLocation
import UserNotifications
import MygraCore
import MygraDesignSystem
import MygraServices

/// The authorization state of a system permission as presented on an onboarding page.
enum PermissionState: Equatable {
    case notRequested
    case granted
    case denied
}

/// The symbol, tint and copy of one step in one state.
struct PermissionPresentation {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
}

/// Reads the three managers once per render and answers state and presentation questions.
struct PermissionInfo {
    let locationStatus: CLAuthorizationStatus?
    let hasLocationManager: Bool
    let isHealthAuthorized: Bool
    let healthFailed: Bool
    let notificationStatus: UNAuthorizationStatus

    @MainActor
    init(weather: WeatherManager, health: HealthManager, notifications: NotificationManager) {
        locationStatus = weather.locationManager?.authorizationStatus
        hasLocationManager = weather.locationManager != nil
        isHealthAuthorized = health.isAuthorized
        healthFailed = health.lastError != nil
        notificationStatus = notifications.authorizationStatus
    }

    func state(for step: OnboardingStep) -> PermissionState {
        switch step {
        case .location:
            switch locationStatus {
            case .authorizedAlways, .authorizedWhenInUse: return .granted
            case .denied, .restricted: return .denied
            default: return hasLocationManager ? .notRequested : .denied
            }
        case .health:
            if isHealthAuthorized { return .granted }
            return healthFailed ? .denied : .notRequested
        case .notification:
            switch notificationStatus {
            case .authorized, .provisional, .ephemeral: return .granted
            case .denied: return .denied
            default: return .notRequested
            }
        default:
            return .granted
        }
    }

    func presentation(for step: OnboardingStep) -> PermissionPresentation {
        let state = state(for: step)
        switch step {
        case .location:
            if !hasLocationManager {
                return .init(icon: "location.slash.fill", tint: .secondary, title: "Location unavailable", subtitle: "Location isn't available right now. You can turn it on later in Settings.")
            }
            switch state {
            case .granted: return .init(icon: "checkmark.circle.fill", tint: .green, title: "Location is on", subtitle: "Mygra will show the weather where you are.")
            case .denied: return .init(icon: "location.slash.fill", tint: .orange, title: "Location is off", subtitle: "You can turn it on in Settings whenever you like.")
            case .notRequested: return .init(icon: "location.fill", tint: .mygraBlue, title: "Local weather", subtitle: "Mygra can show the weather where you are.")
            }
        case .health:
            switch state {
            case .granted: return .init(icon: "checkmark.circle.fill", tint: .green, title: "Health is connected", subtitle: "Health details will appear with each entry.")
            case .denied: return .init(icon: "heart.slash.fill", tint: .orange, title: "Health is off", subtitle: "You can turn it on in Settings whenever you like.")
            case .notRequested: return .init(icon: "heart.fill", tint: .pink, title: "Connect Health", subtitle: "Mygra can add details from Health to each entry.")
            }
        case .notification:
            switch state {
            case .granted: return .init(icon: "checkmark.circle.fill", tint: .green, title: "Notifications are on", subtitle: "Mygra can now send weather alerts and reminders.")
            case .denied: return .init(icon: "bell.slash.fill", tint: .orange, title: "Notifications are off", subtitle: "You can turn them on in Settings whenever you like.")
            case .notRequested: return .init(icon: "bell.badge.fill", tint: .mygraBlue, title: "Notifications", subtitle: "Weather alerts and reminders, if you want them.")
            }
        case .privacy:
            return .init(icon: "lock.shield.fill", tint: .mygraPurple, title: "Your data stays yours", subtitle: "Mygra keeps your journal private.")
        case .user:
            return .init(icon: "person.crop.circle.fill", tint: .mygraBlue, title: "About you", subtitle: "Everything here is optional. It stays on your device and in your iCloud.")
        case .complete:
            return .init(icon: "checkmark.circle.fill", tint: .green, title: "You're all set", subtitle: "Here is what Mygra does.")
        }
    }

    /// The primary button's title and symbol for a permission step that has not been asked yet.
    static func requestLabel(for step: OnboardingStep) -> (title: LocalizedStringKey, icon: String) {
        switch step {
        case .location: return ("Allow Location", "location.fill")
        case .health: return ("Allow Health Access", "heart.fill")
        default: return ("Allow Notifications", "bell.fill")
        }
    }
}
#endif
