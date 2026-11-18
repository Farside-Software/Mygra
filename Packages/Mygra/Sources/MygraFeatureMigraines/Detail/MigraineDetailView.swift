//
//  MigraineDetailView.swift
//  MygraFeatureMigraines
//
//  One migraine: timing and levels, the intensity chart, the AI insight, note,
//  triggers, weather, and health — with end / modify / delete / pin actions.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared
import os

public struct MigraineDetailView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(InsightModel.self) private var insights
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(HealthManager.self) private var healthManager
    @Environment(AttackModeModel.self) private var attackMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    let migraine: Migraine
    /// Regular-width hosts supply a close action for the leading toolbar button.
    var onClose: (() -> Void)?

    @State private var showingEndSheet = false
    @State private var endError: String?
    @State private var showDeleteConfirm = false
    @State private var showingModifySheet = false
    @State private var showingIntensitySheet = false
    @State private var showingMedicationSheet = false
    @State private var showPastWeatherAlert = false
    @State private var layout = LayoutProbe()

    public init(migraine: Migraine, onClose: (() -> Void)? = nil) {
        self.migraine = migraine
        self.onClose = onClose
    }

    private var isWide: Bool {
        MigraineLayout.isWide(layout, isRegularWidth: horizontalSizeClass == .regular)
    }

    public var body: some View {
        ScrollView {
            Group {
                if isWide {
                    wideContent
                } else {
                    stackedContent
                }
            }
            .frame(maxWidth: isWide ? MigraineLayout.wideMaxWidth : MigraineLayout.singleColumnMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: LayoutProbe.self) { LayoutProbe($0) } action: { layout = $0 }
        .softScrollEdgesIfAvailable()
        .migraineTopEdgeEffectHidden(layout.hasVerticalBar)
        .navigationTitle(migraine.isOngoing ? Text("Ongoing Migraine") : Text("Migraine"))
        .navigationSubtitleIfAvailable(DateFormatting.date(migraine.startDate, useDMY: useDayMonthYearDates))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            // A calm moment to ask for a rating (the policy requires the migraine ended 24h+ ago).
            migraineData.noteSummaryViewed(migraine)
        }
        // The deferred "finish logging" prompt lands here and opens Modify, pre-filled.
        .onChange(of: attackMode.finishRequestID, initial: true) { _, requested in
            guard requested == migraine.id, !migraine.isOngoing else { return }
            attackMode.finishRequestID = nil
            showingModifySheet = true
        }
        .sheet(isPresented: $showingIntensitySheet) {
            IntensityUpdateSheet(migraine: migraine) { pain, stress, note in
                migraineData.addIntensitySample(to: migraine, painLevel: pain, stressLevel: stress, note: note)
            }
            .presentationDetents([.large])
            .presentationSizing(.form)
        }
        .sheet(isPresented: $showingMedicationSheet) {
            MedicationQuickAddSheet(migraine: migraine) { name, medicationClass, dose, takenAt in
                migraineData.logMedication(for: migraine, name: name, medicationClass: medicationClass, dose: dose, takenAt: takenAt)
            }
            .presentationDetents([.large])
            .presentationSizing(.form)
        }
        .sheet(isPresented: $showingEndSheet) {
            EndMigraineSheet(startDate: migraine.startDate, initialEndDate: defaultEndDate) { selected in
                endError = nil
                guard selected >= migraine.startDate else {
                    endError = String(localized: "End time must be after the start time.")
                    return
                }
                migraineData.update(migraine) { $0.endDate = selected }
                showingEndSheet = false
                close()
            }
            .presentationDetents([.medium])
            .presentationSizing(.form)
        }
        .sheet(isPresented: $showingModifySheet) {
            ModifyMigraineSheetView(
                migraine: migraine,
                onCancel: { showingModifySheet = false },
                onSave: { edits in
                    apply(edits)
                    showingModifySheet = false
                }
            )
            .presentationSizing(.page)
        }
        .confirmationDialog("Delete this migraine?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Migraine", role: .destructive) {
                Haptics.error()
                migraineData.delete(migraine)
                close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Weather", isPresented: $showPastWeatherAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Weather isn't attached for past start dates.")
        }
    }

    // MARK: - Content

    private var header: some View {
        MigraineDetailHeaderView(
            migraine: migraine,
            startText: DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates),
            endText: migraine.endDate.map { DateFormatting.dateTime($0, useDMY: useDayMonthYearDates) } ?? String(localized: "Ongoing"),
            durationText: MigraineDates.durationString((migraine.endDate ?? Date()).timeIntervalSince(migraine.startDate)),
            endError: endError,
            onEndTap: { showingEndSheet = true }
        )
    }

    private var chart: some View {
        IntensityChartView(
            samples: migraine.intensitySamples ?? [],
            onUpdateIntensity: migraine.isOngoing ? { showingIntensitySheet = true } : nil
        )
    }

    private var medication: some View {
        MedicationSectionView(migraine: migraine) { showingMedicationSheet = true }
    }

    @ViewBuilder
    private var contextCards: some View {
        if let note = migraine.note, !note.isEmpty {
            NoteDetailView(note: note)
        }
        if !migraine.triggers.isEmpty || !migraine.customTriggers.isEmpty {
            TriggersDetailView(triggers: migraine.triggers, customTriggers: migraine.customTriggers)
        }
        if let health = migraine.health {
            HealthDetailView(health: health, useMetricUnits: useMetricUnits)
        }
        if let weather = migraine.weather {
            WeatherDetailView(weather: weather, useMetricUnits: useMetricUnits)
        }
    }

    /// Phone, folded Duo, narrow windows: one calm column. On the Duo the nav bar is the
    /// trailing strip and the title already sits above, so no extra gap at the top.
    private var stackedContent: some View {
        VStack(spacing: Brand.Space.lg) {
            header
            chart
            medication
            InsightSectionView(migraine: migraine)
            contextCards
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.top, LayoutProbe.detailTopInset(hasVerticalBar: layout.hasVerticalBar, hasTitleRow: true))
        .padding(.bottom, Brand.Space.xxl)
    }

    /// Unfolded Duo and iPad: two equal columns with a fixed assignment, so no card jumps
    /// sides. The timeline, chart, medication and insight sit on one side, what the record
    /// captured around it (notes, triggers, Health, weather) on the other.
    /// While a fold is active the gap widens so the hinge sits between the columns.
    private var wideContent: some View {
        MigraineTwoColumns(spacing: MigraineLayout.columnGap(layout)) {
            VStack(spacing: Brand.Space.lg) {
                header
                chart
                medication
                InsightSectionView(migraine: migraine)
            }
            VStack(spacing: Brand.Space.lg) {
                contextCards
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.top, LayoutProbe.detailTopInset(hasVerticalBar: layout.hasVerticalBar, hasTitleRow: true))
        .padding(.bottom, Brand.Space.xxl)
    }

    // MARK: - Toolbar

    /// One menu holds every secondary action (pin, Attack Mode while ongoing, modify, delete),
    /// so the bar stays one button wide on the iPhone Duo's vertical strip and destructive
    /// actions aren't a stray tap away. The page's one primary action is End Migraine.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    Haptics.lightImpact()
                    migraineData.togglePinned(migraine)
                } label: {
                    Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
                }
                .accessibilityIdentifier("pinMigraineButton")
                if migraine.isOngoing {
                    Button {
                        Haptics.lightImpact()
                        attackMode.present()
                    } label: {
                        Label("Attack Mode", systemImage: "moon.fill")
                    }
                    .accessibilityIdentifier("openAttackModeButton")
                } else {
                    Button {
                        showingModifySheet = true
                    } label: {
                        Label("Modify", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("modifyMigraineButton")
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Migraine", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteMigraineButton")
                }
            } label: {
                Label("More", systemImage: migraine.isPinned ? "pin.circle.fill" : "ellipsis")
            }
            .accessibilityIdentifier("migraineMoreMenu")
        }
    }

    // MARK: - Actions

    private var defaultEndDate: Date {
        max(Date(), migraine.startDate.addingTimeInterval(60))
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// Persists the edits, writes staged intake to Health, regenerates the insight, and
    /// refreshes the health/weather snapshots for the edited window.
    private func apply(_ edits: MigraineEdits) {
        migraineData.update(migraine) { m in
            m.startDate = edits.startDate
            m.endDate = edits.endDate
            m.painLevel = edits.painLevel
            m.stressLevel = edits.stressLevel
            m.triggers = Array(edits.triggers)
            let trimmedNote = edits.note.trimmingCharacters(in: .whitespacesAndNewlines)
            m.note = trimmedNote.isEmpty ? nil : trimmedNote
        }

        Task {
            if !edits.additions.isEmpty {
                do {
                    try await healthManager.save(edits.additions, on: edits.startDate)
                } catch {
                    Log.app.error("Failed to save staged HealthKit intake: \(error.localizedDescription)")
                }
            }

            do {
                let health = try await healthManager.fetchSnapshot(forMigraineStart: edits.startDate)
                migraineData.update(migraine) { $0.health = health }
            } catch {
                Log.app.error("Failed to fetch Health snapshot for edited migraine: \(error.localizedDescription)")
            }

            if Calendar.current.isDateInToday(edits.startDate) {
                await weatherManager.refresh()
                if let weather = weatherManager.makeWeatherData(createdAt: edits.startDate) {
                    migraineData.update(migraine) { $0.weather = weather }
                }
            } else if migraine.weather != nil {
                migraineData.update(migraine) { $0.weather = nil }
                showPastWeatherAlert = true
            }

            await insights.regenerateInsight(for: migraine)
        }
    }
}

#if DEBUG
#Preview("Migraine Detail") {
    let env = PreviewEnvironment()
    return NavigationStack {
        MigraineDetailView(migraine: env.migraineData.migraines.first!)
    }
    .previewEnvironment(env)
}
#endif
#endif
