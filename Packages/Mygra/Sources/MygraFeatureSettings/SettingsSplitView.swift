//
//  SettingsSplitView.swift
//  MygraFeatureSettings
//
//  Settings as a split view for the unfolded iPhone Duo: the existing Settings list in a
//  leading pane and the selected page to the right of the hinge. The list and the pages are
//  the same views the pushed layout uses; only the rows' behavior changes (they select
//  instead of pushing) through the `settingsSelection` environment value.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

private struct SettingsSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<SettingsDestination?>? = nil
}

extension EnvironmentValues {
    /// Set by `SettingsSplitView`; when present, Settings rows select a page instead of pushing it.
    var settingsSelection: Binding<SettingsDestination?>? {
        get { self[SettingsSelectionKey.self] }
        set { self[SettingsSelectionKey.self] = newValue }
    }
}

/// A trailing disclosure chevron in the system indicator's size, weight and tertiary color.
struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

/// A Settings row that pushes its page, or selects it in the split view's detail pane.
struct SettingsRowLink<Label: View>: View {
    let destination: SettingsDestination
    let label: Label
    @Environment(\.settingsSelection) private var selection

    init(_ destination: SettingsDestination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    var body: some View {
        if let selection {
            let isSelected = selection.wrappedValue == destination
            Button {
                Haptics.lightImpact()
                selection.wrappedValue = destination
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    label
                    Spacer(minLength: 0)
                    DisclosureChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.18) : nil)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(value: destination) { label }
        }
    }
}

/// The page a `SettingsDestination` opens, used by the pushed stack and the split detail.
public struct SettingsDestinationView: View {
    let destination: SettingsDestination

    public init(destination: SettingsDestination) {
        self.destination = destination
    }

    public var body: some View {
        switch destination {
        case .tags: TagManagementView()
        case .dashboardStats: DashboardStatsSettingsView()
        case .profile: ProfileSettingsPage()
        }
    }
}

/// The profile editor as a page (the pushed layouts open it as a sheet). Edits a scratch
/// copy and saves on request, like the sheet.
struct ProfileSettingsPage: View {
    @Environment(UserDataModel.self) private var userData
    @State private var draft: User?

    var body: some View {
        Group {
            if let draft {
                Form {
                    UserEditView(user: draft)
                }
                .formStyle(.grouped)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") {
                            userData.apply(draft)
                            Haptics.success()
                        }
                        .tint(.mygraBlue)
                    }
                }
            } else {
                Color.clear
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard draft == nil else { return }
            let copy = User()
            copy.apply(userData.currentUser ?? User())
            draft = copy
        }
    }
}

public struct SettingsSplitView: View {
    @Binding private var selection: SettingsDestination?

    public init(selection: Binding<SettingsDestination?>) {
        _selection = selection
    }

    public var body: some View {
        NavigationSplitView {
            SettingsView()
                .navigationTitle("Settings")
                .environment(\.settingsSelection, $selection)
                .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 400)
        } detail: {
            NavigationStack {
                if let selection {
                    SettingsDestinationView(destination: selection)
                        .id(selection)
                } else {
                    ContentUnavailableView("Choose a Setting", systemImage: "gearshape", description: Text("Pick a page on the left."))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
#endif
