//
//  SettingsDestination.swift
//  MygraFeatureSettings
//
//  Screens pushed inside the Settings tab. The composition root registers the
//  `navigationDestination` so deep links (`mygra://tags`) can land here too.
//

import Foundation

nonisolated public enum SettingsDestination: Hashable, Sendable {
    case tags
    case dashboardStats
    /// The profile editor as a page (the unfolded iPhone Duo's split view); elsewhere it is a sheet.
    case profile
}
