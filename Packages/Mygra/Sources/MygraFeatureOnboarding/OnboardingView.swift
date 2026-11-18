//
//  OnboardingView.swift
//  MygraFeatureOnboarding
//
//  The paged first-run flow after the splash: privacy, location, health, notifications,
//  about you, done. One page per `OnboardingStep`, slid horizontally, with the primary button
//  pinned below the page and Back as a toolbar item. Every permission page is skippable
//  ("Not now"; the HIG asks apps never to gate on a permission), and the profile drafted on
//  the About You page is saved when the flow finishes.
//
//  On an iPhone Duo the toolbar is the vertical strip on the trailing edge; unfolded, the
//  page header and body take the two halves either side of the hinge.
//

#if os(iOS)
import SwiftUI
import UIKit
import MygraCore
import MygraDesignSystem
import MygraFeatureShared
import MygraServices

public struct OnboardingView: View {
    @Environment(UserDataModel.self) private var userData
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(HealthManager.self) private var healthManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var viewModel = ViewModel()
    @State private var probe = LayoutProbe()

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    private var steps: [OnboardingStep] { OnboardingStep.allCases }
    private var step: OnboardingStep { viewModel.currentStep }
    private var currentIndex: Int { steps.firstIndex(of: step) ?? 0 }
    private var isLastStep: Bool { step.next == nil }

    private var permissions: PermissionInfo {
        PermissionInfo(weather: weatherManager, health: healthManager, notifications: notificationManager)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                groupedBackground
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    progress
                        .padding(.top, Brand.Space.xs)
                        .padding(.bottom, Brand.Space.sm)
                    pages
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .containerLayoutProbe { probe = $0 }
        .onChange(of: step) { _, _ in
            // Resign the keyboard when the page changes.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            AccessibilityNotification.Announcement(step.title).post()
        }
    }

    // MARK: Toolbar

    /// Back is a bar item with a symbol and a title, so it sits in the navigation bar on
    /// iPhone and iPad and moves into the vertical strip on iPhone Duo.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if step.previous != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    goBack()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityHint("Returns to the previous page")
                .accessibilityIdentifier("backButton")
            }
        } else if #available(iOS 26.0, *) {
            // The first page keeps an invisible Back so the bar, and with it the progress
            // dots, sit exactly where they do on every other page.
            ToolbarItem(placement: .topBarLeading) {
                Button {} label: { Label("Back", systemImage: "chevron.backward") }
                    .hidden()
                    .accessibilityHidden(true)
                    .disabled(true)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    // MARK: Progress

    private var progress: some View {
        HStack(spacing: Brand.Space.xs + 2) {
            ForEach(steps, id: \.self) { item in
                Capsule(style: .continuous)
                    .fill(item == step ? AnyShapeStyle(Color.mygraPurple) : AnyShapeStyle(.tertiary))
                    .frame(width: item == step ? 24 : 8, height: 8)
                    .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
            }
        }
        .frame(maxWidth: OnboardingSplit(probe) != nil ? .infinity : nil)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentIndex + 1) of \(steps.count)")
        .accessibilityValue(Text(step.title))
    }

    // MARK: Pages

    private var pages: some View {
        let info = permissions
        let presentation = info.presentation(for: step)
        return ZStack {
            Group {
                if step == .user {
                    OnboardingUserPage(user: viewModel.draftUser, presentation: presentation, probe: probe)
                } else {
                    OnboardingFeaturePage(step: step, presentation: presentation, probe: probe)
                }
            }
            .id(step)
            .transition(pageTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .simultaneousGesture(swipeGesture)
        .onChange(of: info.state(for: step)) { _, newValue in
            if newValue == .granted, step.isPermissionStep { Haptics.success() }
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = viewModel.direction == .forward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width > 80 {
                    goBack()
                }
            }
    }

    // MARK: Bottom bar

    /// The primary button, and under it one quiet text button: "Not now" while a permission is
    /// still undecided, "Open Settings" once it was refused, "Skip" on About You. The row keeps
    /// its height on every page so the primary button never jumps.
    private var bottomBar: some View {
        let info = permissions
        let state = info.state(for: step)
        let asksPermission = step.isPermissionStep && state == .notRequested
        let request = PermissionInfo.requestLabel(for: step)
        let canOpenSettings = step.isPermissionStep && state == .denied && (step != .location || info.hasLocationManager)

        return VStack(spacing: Brand.Space.sm) {
            Button {
                Haptics.mediumImpact()
                if asksPermission {
                    requestPermission()
                } else {
                    advance()
                }
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    if asksPermission {
                        Image(systemName: request.icon)
                            .accessibilityHidden(true)
                        Text(request.title)
                    } else {
                        Text(isLastStep ? "Enter Mygra" : "Continue")
                        if !isLastStep {
                            Image(systemName: "arrow.right")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .primaryActionButton()
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("continueButton")
            .accessibilityHint(asksPermission ? "Shows the system permission prompt" : (isLastStep ? "Finishes the introduction" : "Goes to the next page"))

            ZStack {
                if asksPermission || step == .user {
                    Button {
                        Haptics.lightImpact()
                        skip()
                    } label: {
                        Text(step.isPermissionStep ? "Not now" : "Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                    .accessibilityHint("Skips this step. You can change this later in Settings.")
                    .accessibilityIdentifier("skipButton")
                } else if canOpenSettings {
                    Button {
                        openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.mygraPurple)
                    .hoverHighlight()
                    .accessibilityHint("Opens the Settings app where you can grant access")
                }
            }
            .frame(minHeight: 44)
        }
        .frame(maxWidth: Brand.readableWidth)
        .padding(.horizontal, Brand.Space.xl)
        .padding(.top, Brand.Space.md)
        .padding(.bottom, Brand.Space.sm)
        .frame(maxWidth: .infinity, alignment: OnboardingSplit(probe) != nil ? .trailing : .center)
        .padding(.leading, OnboardingSplit(probe).map { $0.trailingOffset - Brand.Space.xl } ?? 0)
    }

    // MARK: Actions

    /// Asks the system for the step's permission. Everything runs on the main actor (this view
    /// and the `Task`s it starts inherit it), so no UI state is touched from a callback queue.
    private func requestPermission() {
        switch step {
        case .location:
            weatherManager.locationManager?.requestAuthorization()
        case .health:
            Task { await healthManager.requestAuthorization() }
        case .notification:
            Task { try? await notificationManager.requestAuthorization() }
        default:
            break
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func advance() {
        if isLastStep {
            userData.save(viewModel.draftUser)
            onFinished()
        } else {
            move(.forward) { viewModel.advance() }
        }
    }

    private func skip() {
        guard step.isSkippable else { return }
        advance()
    }

    private func goBack() {
        guard step.previous != nil else { return }
        move(.backward) { viewModel.goBack() }
    }

    /// Commits the direction before the step changes so the outgoing page slides the right
    /// way, then animates the page change on the next main-actor turn.
    private func move(_ direction: ViewModel.Direction, _ change: @escaping () -> Void) {
        viewModel.direction = direction
        Task { @MainActor in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)) {
                change()
            }
        }
    }
}

extension OnboardingView {
    @MainActor
    @Observable
    final class ViewModel {
        enum Direction { case forward, backward }

        var currentStep: OnboardingStep = ViewModel.initialStep
        var direction: Direction = .forward
        /// The profile drafted on the About You page.
        let draftUser = User()

        private static var initialStep: OnboardingStep {
            #if DEBUG
            // Simulator verification: `-MygraOnboardingStep N` (0-based) opens that page.
            if UserDefaults.standard.object(forKey: "MygraOnboardingStep") != nil {
                let page = UserDefaults.standard.integer(forKey: "MygraOnboardingStep")
                if OnboardingStep.allCases.indices.contains(page) { return OnboardingStep.allCases[page] }
            }
            #endif
            return .privacy
        }

        func advance() {
            guard let next = currentStep.next else { return }
            currentStep = next
        }

        func goBack() {
            guard let previous = currentStep.previous else { return }
            currentStep = previous
        }

        func skip() {
            guard currentStep.isSkippable else { return }
            advance()
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView(onFinished: {})
        .previewEnvironment()
}
#endif
#endif
