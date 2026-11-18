//
//  OnboardingPages.swift
//  MygraFeatureOnboarding
//
//  The page bodies: a feature page (hero header and feature rows, used by privacy, the three
//  permission steps and the finish page) and the About You form. Both sit at the readable
//  width; a feature page tightens its spacing on short windows (the folded iPhone Duo) and
//  scrolls only when even that cannot fit.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureSettings

// MARK: - Feature page

struct OnboardingFeaturePage: View {
    let step: OnboardingStep
    let presentation: PermissionPresentation
    let probe: LayoutProbe

    var body: some View {
        // The roomiest layout that fits without clipping, then a tighter one, and only as a
        // last resort the tight layout scrolling. The folded Duo (466 x 678) fits the tight one.
        ViewThatFits(in: .vertical) {
            content(compact: false)
            content(compact: true)
            ScrollView {
                content(compact: true)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func content(compact: Bool) -> some View {
        OnboardingColumns(probe: probe) {
            OnboardingHeader(
                systemImage: presentation.icon,
                tint: presentation.tint,
                title: presentation.title,
                subtitle: presentation.subtitle,
                compact: compact
            )
        } trail: {
            rows(compact: compact)
        }
        .padding(.horizontal, compact ? Brand.Space.lg : Brand.Space.xl)
        .padding(.vertical, compact ? Brand.Space.sm : Brand.Space.xl)
        .frame(maxWidth: probe.hasFold ? .infinity : Brand.readableWidth)
        .frame(maxWidth: .infinity)
    }

    @ContentBuilder
    private func rows(compact: Bool) -> some View {
        switch step {
        case .privacy:
            OnboardingFeatureCard {
                OnboardingFeatureRow(icon: "iphone", tint: .mygraBlue, title: "On your device", detail: "Entries are stored here and in your own iCloud.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "person.fill.checkmark", tint: .mygraPurple, title: "Only you", detail: "Nobody else can open your journal.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "server.rack", tint: .mygraBlue, title: "No outside servers", detail: "Mygra doesn't send your health data to third parties.", compact: compact)
            }
        case .location:
            OnboardingFeatureCard {
                OnboardingFeatureRow(icon: "sun.max.fill", tint: .orange, title: "Local weather", detail: "Current conditions on your dashboard.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "barometer", tint: .teal, title: "Pressure changes", detail: "See barometric pressure alongside each entry.", compact: compact)
            }
        case .health:
            OnboardingFeatureCard {
                OnboardingFeatureRow(icon: "drop.fill", tint: .blue, title: "Hydration and caffeine", detail: "Shown with each migraine, and logged with Quick Add.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "bed.double.fill", tint: .indigo, title: "Sleep", detail: "Shown with each migraine.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "brain.head.profile", tint: .pink, title: "Headache records", detail: "Finished migraines are saved to Health.", compact: compact)
            }
        case .notification:
            OnboardingFeatureCard {
                OnboardingFeatureRow(icon: "cloud.sun.fill", tint: .orange, title: "Weather alerts", detail: "A notice when conditions change.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "waveform.path.ecg", tint: .mygraPurple, title: "Live Activity", detail: "An ongoing migraine shows on your Lock Screen.", compact: compact)
            }
        case .complete:
            OnboardingFeatureCard {
                OnboardingFeatureRow(icon: "brain.head.profile.fill", tint: .pink, title: "Log migraines", detail: "Start, rate and end an attack in seconds.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis", tint: .green, title: "Review your history", detail: "Calendar, charts and notes from your own entries.", compact: compact)
                OnboardingRowDivider()
                OnboardingFeatureRow(icon: "icloud.fill", tint: .mygraBlue, title: "Sync with iCloud", detail: "Your journal follows you across your devices.", compact: compact)
            }
        case .user:
            EmptyView()
        }
    }
}

// MARK: - About You page

/// The one page that collects input: a grouped form with the profile fields.
struct OnboardingUserPage: View {
    let user: User
    let presentation: PermissionPresentation
    let probe: LayoutProbe

    var body: some View {
        if OnboardingSplit(probe) != nil {
            OnboardingColumns(probe: probe) {
                header
            } trail: {
                form
            }
        } else {
            form
                .frame(maxWidth: Brand.readableWidth + 2 * Brand.Space.xl)
                .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        OnboardingHeader(
            systemImage: presentation.icon,
            tint: presentation.tint,
            title: presentation.title,
            subtitle: presentation.subtitle
        )
    }

    private var form: some View {
        Form {
            if OnboardingSplit(probe) == nil {
                Section {
                    // Horizontal padding: the row has zero insets, so without it the wrapped
                    // subtitle ran into the window's edges on the folded iPhone Duo.
                    header
                        .padding(.top, Brand.Space.lg)
                        .padding(.horizontal, Brand.Space.lg)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            UserEditView(user: user)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}
#endif
