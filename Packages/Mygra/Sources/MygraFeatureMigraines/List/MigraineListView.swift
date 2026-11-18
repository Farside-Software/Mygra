//
//  MigraineListView.swift
//  MygraFeatureMigraines
//
//  The searchable, filterable migraine history: pinned entries first, then one section
//  per month. Swipe to pin or delete, long-press for the same actions, and a filter
//  sheet for everything else.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineListView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var layout = LayoutProbe()
    /// The migraine shown in the trailing pane while the list is wide.
    @State private var selectedID: UUID?

    public init() {}

    private var filter: MigraineFilter { migraineData.filter }

    /// The search field is kept out of the persisted filter so clearing it never
    /// disturbs the user's pin/trigger choices.
    private var searchFilter: MigraineFilter {
        var combined = filter
        combined.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }

    private var visible: [Migraine] {
        migraineData.migraines.filter { searchFilter.matches($0) }
    }

    private var pinned: [Migraine] { visible.filter(\.isPinned) }
    private var unpinned: [Migraine] { visible.filter { !$0.isPinned } }

    private var monthGroups: [MigraineMonthGroup] {
        MigraineStatistics.monthGroups(unpinned)
    }

    private var migrainesByID: [UUID: Migraine] {
        Dictionary(unpinned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Wide windows (the unfolded Duo, iPad) split into the list and the selected migraine.
    private var isWide: Bool {
        MigraineLayout.isWide(layout, isRegularWidth: horizontalSizeClass == .regular)
    }

    /// The Duo (folded or not) and wide windows keep search as a field at the top of the list
    /// itself: always visible, never minimized into the toolbar, and clear of the hinge.
    private var usesInlineSearch: Bool { PhoneDuo.isDuo || isWide }

    public var body: some View {
        Group {
            if isWide {
                splitContent
            } else {
                listColumn
            }
        }
        .onGeometryChange(for: LayoutProbe.self) { LayoutProbe($0) } action: { layout = $0 }
        .onChange(of: isWide, initial: true) { _, wide in
            if wide, selectedID == nil { selectedID = visible.first?.id }
        }
        .onChange(of: visible.map(\.id)) { _, ids in
            guard isWide else { return }
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
        .navigationSubtitleIfAvailable(subtitle)
        .toolbar {
            // Wide windows put filtering next to the search field, so the page has one menu
            // (the detail pane's) instead of two ellipses side by side.
            if !isWide {
                ToolbarItem(placement: .secondaryAction) {
                    filterButton
                }
                ToolbarItem(placement: .secondaryAction) {
                    pinnedOnlyToggle
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                MigraineFilterSheet(
                    initialFilter: filter,
                    apply: { newFilter in
                        migraineData.filter = newFilter
                        showingFilterSheet = false
                    },
                    cancel: { showingFilterSheet = false }
                )
            }
            .presentationDetents([.large])
            .presentationSizing(.page)
            .interactiveDismissDisabled()
        }
        .refreshable {
            migraineData.refresh()
            Haptics.success()
        }
    }

    private var subtitle: String {
        let count = visible.count
        if searchFilter.isActive {
            return String(localized: "\(count) matching")
        }
        return count == 1 ? String(localized: "1 migraine") : String(localized: "\(count) migraines")
    }

    private var pinnedOnlyBinding: Binding<Bool> {
        Binding(
            get: { filter.pinnedOnly },
            set: { newValue in
                Haptics.lightImpact()
                migraineData.filter.pinnedOnly = newValue
            }
        )
    }

    // MARK: - Columns

    private var listColumn: some View {
        VStack(spacing: 0) {
            if usesInlineSearch {
                inlineSearchField
            }
            Group {
                if visible.isEmpty {
                    if searchFilter.isActive {
                        filteredEmptyState
                    } else {
                        emptyState
                    }
                } else {
                    list
                }
            }
        }
        .modifier(SystemSearchModifier(isEnabled: !usesInlineSearch, text: $searchText))
    }

    private var inlineSearchField: some View {
        HStack(spacing: Brand.Space.sm) {
            HStack(spacing: Brand.Space.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                SearchField("Search notes, triggers, and insights", text: $searchText)
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm + 2)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            .accessibilityIdentifier("migraineSearchField")

            if isWide {
                Menu {
                    filterButton
                    pinnedOnlyToggle
                } label: {
                    Label("Filter", systemImage: filter.hasCriteria ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityIdentifier("filterMenu")
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.bottom, Brand.Space.sm)
    }

    private var filterButton: some View {
        Button {
            Haptics.lightImpact()
            showingFilterSheet = true
        } label: {
            Label("Filter", systemImage: filter.hasCriteria ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .symbolRenderingMode(filter.hasCriteria ? .multicolor : .monochrome)
        }
        .accessibilityIdentifier("filterButton")
        .accessibilityValue(filter.hasCriteria ? Text("Active") : Text("Off"))
    }

    private var pinnedOnlyToggle: some View {
        Toggle(isOn: pinnedOnlyBinding) {
            Label("Pinned Only", systemImage: filter.pinnedOnly ? "pin.fill" : "pin")
        }
        .accessibilityIdentifier("pinnedOnlyToggle")
    }

    /// List and detail side by side. With a hardware fold the list takes everything left of
    /// the hinge and the detail everything right of it; the gap between them is the hinge.
    private var splitContent: some View {
        let gap = MigraineLayout.columnGap(layout)
        let listWidth: CGFloat = layout.foldCenterX.map { max($0 - gap / 2, 0) } ?? min(max(layout.width * 0.42, 340), 440)
        return HStack(spacing: 0) {
            listColumn
                .frame(width: listWidth)
            if layout.hasFold {
                Color.clear.frame(width: gap)
            } else {
                Divider()
            }
            detailPane
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedID, let migraine = migraineData.migraine(withID: selectedID) {
            NavigationStack {
                MigraineDetailView(migraine: migraine, onClose: { self.selectedID = visible.first(where: { $0.id != selectedID })?.id })
            }
            .id(selectedID)
        } else {
            ContentUnavailableView {
                Label("Select a Migraine", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Choose a migraine on the left to see its details.")
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { migraine in
                        row(migraine)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .foregroundStyle(.yellow)
                }
            }

            let lookup = migrainesByID
            ForEach(monthGroups) { group in
                Section {
                    ForEach(group.migraineIDs.compactMap { lookup[$0] }) { migraine in
                        row(migraine)
                    }
                } header: {
                    Text(group.monthStart, format: .dateTime.month(.wide).year())
                }
            }

            if filter.isActive {
                Section {
                    EmptyView()
                } footer: {
                    activeFilterFooter
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: visible.map(\.id))
    }

    @ViewBuilder
    private func rowLink(_ migraine: Migraine) -> some View {
        if isWide {
            Button {
                Haptics.lightImpact()
                selectedID = migraine.id
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    MigraineRowView(migraine: migraine)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedID == migraine.id ? Color.mygraBlue.opacity(0.16) : nil)
            .accessibilityAddTraits(selectedID == migraine.id ? .isSelected : [])
        } else {
            NavigationLink(value: migraine.id) {
                MigraineRowView(migraine: migraine)
            }
        }
    }

    private func row(_ migraine: Migraine) -> some View {
        rowLink(migraine)
        .hoverHighlight()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Haptics.lightImpact()
                migraineData.togglePinned(migraine)
            } label: {
                Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Haptics.error()
                migraineData.delete(migraine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                Haptics.lightImpact()
                migraineData.togglePinned(migraine)
            } label: {
                Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
            }
            if migraine.isOngoing {
                Button {
                    Haptics.success()
                    migraineData.endOngoing()
                } label: {
                    Label("End Migraine", systemImage: "stop.circle")
                }
            }
            Divider()
            Button(role: .destructive) {
                Haptics.error()
                migraineData.delete(migraine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            MigraineRowView(migraine: migraine)
                .padding()
                .frame(width: 340)
        }
    }

    private var activeFilterFooter: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Label("Filters are applied", systemImage: "line.3.horizontal.decrease.circle")
                .font(.footnote.weight(.semibold))
            if !filter.requiredTriggers.isEmpty {
                Text(filter.requiredTriggerSummary)
                    .font(.caption)
                    .accessibilityIdentifier("footerTriggerSummary")
            }
            HStack(spacing: Brand.Space.sm) {
                if filter.pinnedOnly {
                    showAllButton
                        .controlSize(.small)
                        .accessibilityIdentifier("footerShowAllButton")
                }
                clearFiltersButton
                    .controlSize(.small)
                    .accessibilityIdentifier("footerClearFiltersButton")
                adjustFiltersButton(title: "Adjust")
                    .controlSize(.small)
                    .accessibilityIdentifier("footerAdjustFiltersButton")
            }
        }
        .padding(.top, Brand.Space.xs)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Migraines Yet", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Your logged migraines will appear here. Tap New Migraine to add your first.")
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
        } description: {
            VStack(spacing: Brand.Space.sm) {
                if !searchText.isEmpty {
                    Text("Nothing matches “\(searchText)”.")
                } else if filter.pinnedOnly && filter.hasCriteria {
                    Text("Pinned-only and other filters are applied. Try clearing them to see more migraines.")
                } else if filter.pinnedOnly {
                    Text("Showing pinned only. Turn it off to see all migraines.")
                } else {
                    Text("Filters are applied. Try clearing them to see more migraines.")
                }
                if !filter.requiredTriggers.isEmpty {
                    Text(filter.requiredTriggerSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } actions: {
            HStack(spacing: Brand.Space.md) {
                if filter.pinnedOnly {
                    showAllButton
                        .accessibilityIdentifier("emptyShowAllButton")
                }
                if filter.hasCriteria {
                    clearFiltersButton
                        .accessibilityIdentifier("emptyClearFiltersButton")
                }
                adjustFiltersButton(title: "Adjust Filters")
            }
        }
    }

    // MARK: - Buttons

    private var showAllButton: some View {
        Button {
            Haptics.lightImpact()
            migraineData.filter.pinnedOnly = false
        } label: {
            Label("Show All", systemImage: "pin.slash")
        }
        .glassActionButton(prominent: false)
    }

    private var clearFiltersButton: some View {
        Button {
            Haptics.success()
            migraineData.filter = MigraineFilter()
            searchText = ""
        } label: {
            Label("Clear Filters", systemImage: "xmark.circle")
        }
        .glassActionButton()
    }

    private func adjustFiltersButton(title: LocalizedStringKey) -> some View {
        Button {
            Haptics.lightImpact()
            showingFilterSheet = true
        } label: {
            Label(title, systemImage: "slider.horizontal.3")
        }
        .glassActionButton(prominent: false)
    }
}

/// The system search field (minimizing into the toolbar on iOS 26) for the phone and iPad
/// layouts that have no fold to work around.
private struct SystemSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(text: $text, prompt: Text("Search notes, triggers, and insights"))
                .minimizingSearchIfAvailable()
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MigraineListView()
            .navigationTitle("Migraines")
    }
    .previewEnvironment()
}
#endif
#endif
