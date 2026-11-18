//
//  Toast.swift
//  MygraDesignSystem
//
//  Quiet, inline status feedback, as in Opalite 2.0. `ToastManager` (the name predates the
//  design) routes success and info items to `currentToast`, which the screen's navigation
//  subtitle shows for a few seconds (iOS 26+; before that a slim row under the navigation
//  bar), and errors to `currentAlert`, which is presented as a standard system alert over
//  whatever is on screen, sheets included. Nothing floats over content, and no error is
//  ever silent.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Style

public enum ToastStyle: Sendable, Equatable {
    case error
    case success
    case info

    public var iconName: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}

// MARK: - Item

public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let style: ToastStyle
    public let icon: String?
    public let duration: TimeInterval

    public init(message: String, style: ToastStyle = .info, icon: String? = nil, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.icon = icon
        self.duration = duration
    }

    public var symbol: String { icon ?? style.iconName }

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Manager

@MainActor
@Observable
public final class ToastManager {
    /// The status shown in the navigation subtitle (or the iOS 18 row): success and info only.
    public private(set) var currentToast: ToastItem?
    /// The latest error, kept until acknowledged in the system alert.
    public private(set) var currentAlert: ToastItem?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    public init() {}

    /// Errors become an alert; everything else a transient status line.
    public func show(_ toast: ToastItem) {
        if toast.style == .error {
            currentAlert = toast
            presentAlert(toast)
            return
        }
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { currentToast = toast }
        // A subtitle change is not announced on its own.
        AccessibilityNotification.Announcement(toast.message).post()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.duration))
            if !Task.isCancelled { self?.dismiss() }
        }
    }

    public func show(message: String, style: ToastStyle = .info, icon: String? = nil) {
        show(ToastItem(message: message, style: style, icon: icon))
    }

    public func showSuccess(_ message: String) {
        show(ToastItem(message: message, style: .success))
    }

    public func show(error: any Error) {
        let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        show(ToastItem(message: message, style: .error))
    }

    /// Clears the status (not a pending alert).
    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { currentToast = nil }
    }

    public func dismissAlert() {
        currentAlert = nil
    }

    // MARK: System alert

    #if os(iOS)
    @ObservationIgnored private weak var presentedAlert: UIAlertController?

    /// Presents a standard alert on the top-most view controller, so it shows over sheets
    /// and full-screen covers too. A second error replaces the one on screen.
    private func presentAlert(_ item: ToastItem) {
        guard let top = Self.topViewController() else { return }
        if let presentedAlert, presentedAlert.presentingViewController != nil {
            presentedAlert.title = item.message
            return
        }
        let alert = UIAlertController(title: item.message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel) { [weak self] _ in
            self?.dismissAlert()
        })
        presentedAlert = alert
        top.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
    #else
    private func presentAlert(_ item: ToastItem) {}
    #endif
}

#if os(iOS)

// MARK: - Status row (before iOS 26)

private struct StatusRowContent: View {
    let toast: ToastItem

    var body: some View {
        Text("\(Image(systemName: toast.symbol)) \(toast.message)")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.xs)
            .background(.thinMaterial)
            .transition(.opacity)
    }
}

private struct StatusRowModifier: ViewModifier {
    @Environment(ToastManager.self) private var status: ToastManager?

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if let toast = status?.currentToast {
                StatusRowContent(toast: toast)
            }
        }
    }
}

// MARK: - Subtitle

private struct StatusSubtitleModifier: ViewModifier {
    let subtitle: String
    @Environment(ToastManager.self) private var status: ToastManager?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(Text(verbatim: status?.currentToast?.message ?? subtitle))
        } else {
            content.modifier(StatusRowModifier())
        }
    }
}

extension View {
    /// The current status in this screen's navigation subtitle (iOS 26+), else a slim row
    /// under the bar; `subtitle` shows when there is no status.
    func statusSubtitle(replacing subtitle: String) -> some View {
        modifier(StatusSubtitleModifier(subtitle: subtitle))
    }

    /// For navigation screens with no subtitle of their own.
    public func statusSubtitle() -> some View {
        modifier(StatusSubtitleModifier(subtitle: ""))
    }
}

#if DEBUG
#Preview("Status") {
    struct PreviewContainer: View {
        @State private var toastManager = ToastManager()

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Button("Show Success") { toastManager.showSuccess("Migraine saved") }
                    Button("Show Info") { toastManager.show(message: "Syncing with iCloud…", style: .info, icon: "icloud.fill") }
                    Button("Show Error") { toastManager.show(message: "Something went wrong", style: .error) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Status")
                .statusSubtitle()
            }
            .environment(toastManager)
        }
    }
    return PreviewContainer()
}
#endif
#endif
