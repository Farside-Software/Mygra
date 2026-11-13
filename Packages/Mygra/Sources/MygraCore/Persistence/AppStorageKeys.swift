//
//  AppStorageKeys.swift
//  MygraCore
//

import Foundation

nonisolated public enum AppStorageKeys {
    // MARK: - Global Settings
    public static let useMetricUnits = "useMetricUnits"
    public static let useDayMonthYearDates = "useDayMonthYearDates"
    public static let bgWeatherTaskScheduled = "bgWeatherTaskScheduled"
    public static let isOnboardingComplete = "isOnboardingComplete"
    /// Legacy Bool flags, read only to migrate into `lastPromptedVersion`.
    public static let hasPromptedForFifthReview = "MigraineManager.hasPromptedForFifthReview"
    public static let hasPromptedForExportReview = "Review.hasPromptedAfterFirstExport"
    /// App version (CFBundleShortVersionString) the rating prompt last appeared on.
    public static let lastPromptedVersion = "Review.lastPromptedVersion"
    /// Seconds since 1970 of the first launch that recorded it.
    public static let firstLaunchDate = "Review.firstLaunchDate"

    // MARK: - Mygra Plus
    /// Cached grandfather verdict (absent = never checked).
    public static let plusGrandfathered = "Plus.grandfathered"
    public static let plusEarlySupporterThanksShown = "Plus.earlySupporterThanksShown"

    // MARK: - Clinical
    /// JSON `[String: Int]` of the overuse level already notified per class.
    public static let medicationAlertLevels = "Medication.alertLevels"
    /// JSON `ClinicalAssessment` (latest MIDAS / HIT-6 answers).
    public static let clinicalAssessment = "Clinical.assessment"
    public static let reportWindowMonths = "Clinical.reportWindowMonths"
    public static let reportIncludeName = "Clinical.reportIncludeName"
    public static let reportIncludeBirthday = "Clinical.reportIncludeBirthday"
    public static let reportIncludeHealthProfile = "Clinical.reportIncludeHealthProfile"

    // MARK: - Cycle insights and pressure
    /// Whether the user opted in to the menstrual-cycle correlation (reads Health flow data).
    public static let cycleInsightsEnabled = "Cycle.insightsEnabled"
    public static let pressureDropThresholdHpa = "Pressure.dropThresholdHpa"
    public static let pressureDropWindowHours = "Pressure.dropWindowHours"

    // MARK: - Attack Mode
    /// Whether ending an attack schedules the gentle finish-logging prompt (default on).
    public static let attackFinishPromptEnabled = "AttackMode.finishPromptEnabled"
    /// Minutes after End Attack before the prompt (default 120).
    public static let attackFinishPromptDelayMinutes = "AttackMode.finishPromptDelayMinutes"
    /// JSON `[FinishItem]` of ended attacks still waiting to be finished.
    public static let attackPendingFinishItems = "AttackMode.pendingFinishItems"

    // MARK: - Dashboard Stat Visibility
    public static let showWaterStat = "showWaterStat"
    public static let showSleepStat = "showSleepStat"
    public static let showFoodStat = "showFoodStat"
    public static let showCaffeineStat = "showCaffeineStat"
    public static let showStepsStat = "showStepsStat"
    public static let showHeartRateStat = "showHeartRateStat"
    public static let showOxygenStat = "showOxygenStat"
    public static let showGlucoseStat = "showGlucoseStat"
    public static let showTriggersStat = "showTriggersStat"

    // MARK: - Dashboard Stat Order
    /// JSON-encoded `[DashboardStat]` giving the user's tile order on the Today card.
    public static let dashboardStatOrder = "dashboardStatOrder"
}
