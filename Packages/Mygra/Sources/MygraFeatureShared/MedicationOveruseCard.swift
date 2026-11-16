//
//  MedicationOveruseCard.swift
//  MygraFeatureShared
//
//  The in-app medication-overuse warning: one row per class at 8+ days (approaching) or
//  at its 10/15-day threshold in the last 30 days. Free for everyone. Informational,
//  with a link to the American Migraine Foundation's guidance.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct MedicationOveruseCard: View {
    @Environment(MigraineDataModel.self) private var migraineData

    public init() {}

    public var body: some View {
        if let summary = migraineData.overuseSummary() {
            let tint: Color = summary.status == .threshold ? .red : .orange
            InsightCard(title: String(localized: "Medication Use"), systemImage: "pills.fill", accent: tint) {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                        Text(summary.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    VStack(spacing: Brand.Space.sm) {
                        ForEach(summary.rows) { row in
                            let rowTint: Color = row.status == .threshold ? .red : .orange
                            HStack(spacing: Brand.Space.sm) {
                                Image(systemName: row.status == .threshold ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(rowTint)
                                    .font(.footnote)
                                    .frame(width: 20)
                                    .accessibilityHidden(true)
                                Text(row.name)
                                    .font(.subheadline)
                                Spacer(minLength: Brand.Space.sm)
                                Text(row.countText)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(rowTint)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.accessibilityLabel)
                        }
                    }

                    Text("Taking these on this many days a month is linked to medication-overuse headache. This is general information, not medical advice. Please talk with your clinician.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: MedicationOveruse.guidanceURL) {
                        Label("American Migraine Foundation: medication-overuse headache", systemImage: "arrow.up.right.square")
                            .font(.footnote.weight(.semibold))
                    }
                    .accessibilityHint("Opens in your browser")
                }
            }
        }
    }
}
#endif
