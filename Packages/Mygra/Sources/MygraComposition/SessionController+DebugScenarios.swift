//
//  SessionController+DebugScenarios.swift
//  MygraComposition
//
//  DEBUG-only: drives Attack Mode through its real model and use-cases from a launch
//  argument (`-MygraDebugScenario attackActive|attackEnded`), so the screens can be
//  captured on a simulator without tapping. Not compiled into release builds.
//
//  Launch flags (all DEBUG only, read from UserDefaults, so they are plain launch arguments):
//  - `-MygraDebugScenario attackActive|attackEnded`  an attack replayed through Attack Mode.
//  - `-MygraDebugScenario cyclePressure`             cycle and pressure screens (pair with `-Plus.grandfathered YES`).
//  - `-MygraDebugScenario dashRecent|dashDays|dashQuiet|dashActive`  header wording states.
//  - `-MygraDebugScenario store`                     a rich three-month history for store captures:
//        about 22 migraines (6 to 9 a month, 2 to 30 hours, varied pain), intensity curves,
//        triggers, tags, medication, weather and Health snapshots on the recent ones, a pressure
//        series with drops, canned period days, one pinned migraine, and Health connected. The
//        newest migraine ended about two days ago. Pair with `-Plus.grandfathered YES`.
//  - `-MygraDebugHealth connected`                   canned Health stats and a connected state, with ANY scenario.
//  - `-MygraDebugOngoing YES`                        adds an ongoing migraine started 1 h 20 min ago with three
//        readings (Attack Mode and Live Activity captures), unless one is already ongoing.
//  - `-MygraDebugTab`, `-MygraDebugPresent`, `-isOnboardingComplete YES` are handled by the app and MainView.
//

#if DEBUG
import Foundation
import MygraCore
import MygraServices

extension SessionController {
    /// Seeds a little medication history, then replays an attack the way a user would:
    /// start, pick an intensity step, take a usual medication, and (for `attackEnded`) end it.
    public func runDebugAttackScenario(_ scenario: String) {
        guard scenario == "attackActive" || scenario == "attackEnded" else { return }

        migraineData.deleteAll()
        let now = Date()
        for (daysAgo, doses) in [(20.0, [("Sumatriptan", MedicationClass.triptan, "50 mg")]),
                                 (9.0, [("Sumatriptan", .triptan, "50 mg"), ("Ibuprofen", .simpleAnalgesic, "400 mg")]),
                                 (3.0, [("Ibuprofen", .simpleAnalgesic, "400 mg")])] {
            let start = now.addingTimeInterval(-daysAgo * 86_400)
            let past = Migraine(startDate: start, endDate: start.addingTimeInterval(4 * 3600), painLevel: 6, stressLevel: 4)
            migraineData.log(past)
            for (name, cls, dose) in doses {
                migraineData.logMedication(for: past, name: name, medicationClass: cls, dose: dose, takenAt: start.addingTimeInterval(600))
            }
        }

        attackMode.startAttack()
        attackMode.setIntensity(8)
        if let medication = attackMode.quickMedications.first {
            attackMode.logMedication(medication)
        }
        if scenario == "attackEnded" {
            attackMode.endAttack()
        }
    }
}

// MARK: - Cycle and pressure

extension SessionController {
    /// Seeds a month-by-month history that clusters around period starts, canned period
    /// days from "Health", and a pressure series with three drops (one forecast), so the
    /// cycle and pressure screens can be captured on a simulator without Health or
    /// WeatherKit (`-MygraDebugScenario cyclePressure`). Pair with `-Plus.grandfathered YES`.
    public func runDebugCyclePressureScenario() {
        migraineData.deleteAll()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, hour: Int = 9) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        }

        // Periods start every 28 days; the latest began 5 days ago. Flow lasts 5 days.
        let periodStartOffsets = [-145, -117, -89, -61, -33, -5]
        var flowDays: [Date] = []
        for offset in periodStartOffsets {
            for extra in 0..<5 { flowDays.append(day(offset + extra, hour: 0)) }
        }
        cycleData.installDebugFlowDays(flowDays)

        // Attacks: most start in the window around a period start, a few elsewhere.
        let attackOffsets = [-144, -118, -90, -88, -62, -60, -34, -32, -130, -75, -45, -20]
        for offset in attackOffsets {
            let start = day(offset)
            migraineData.log(Migraine(startDate: start, endDate: start.addingTimeInterval(5 * 3600), painLevel: 6, stressLevel: 4))
        }
        // Recent attacks for the pressure graph.
        for hoursAgo in [20.0, 70.0, 108.0] {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            migraineData.log(Migraine(startDate: start, endDate: start.addingTimeInterval(4 * 3600), painLevel: 7, stressLevel: 5))
        }

        // Hourly pressure: a gentle swell with falls at -118 h, -30 h, and +4 h (forecast).
        func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        func hpa(_ hour: Double) -> Double {
            var p = 1016 + 1.5 * sin(hour / 22)
            p -= 7 * smooth((hour + 126) / 9) - 7 * smooth((hour + 100) / 14)
            p -= 7.5 * smooth((hour + 34) / 9) - 7.5 * smooth((hour + 12) / 16)
            p -= 6.5 * smooth((hour - 2) / 10)
            return p
        }
        let series = (-168...48).map { PressureSample(date: now.addingTimeInterval(Double($0) * 3600), hpa: hpa(Double($0))) }
        weatherManager.installDebugWeather(
            reading: WeatherReading(
                temperature: Measurement(value: 64, unit: .fahrenheit),
                pressure: Measurement(value: hpa(0), unit: .hectopascals),
                humidity: 0.58,
                condition: .cloudy,
                fetchedAt: now
            ),
            pressureSeries: series
        )
    }

    #if canImport(UIKit)
    /// Writes the clinical report (with the cycle section) to Documents/debug-report.pdf.
    public func writeDebugClinicalReport() {
        let blocks = ClinicalReport.blocks(
            user: userData.currentUser,
            migraines: migraineData.migraines,
            options: ClinicalReportOptions(months: 6),
            useMetricUnits: false,
            useDMY: false,
            perimenstrual: cycleData.result(for: migraineData.migraines)
        )
        let data = PDFReportRenderer.render(blocks)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: documents.appendingPathComponent("debug-report.pdf"))
        }
    }
    #endif
}

// MARK: - Dashboard states

extension SessionController {
    /// Seeds a history whose last attack ended `hoursAgo` hours ago (`-MygraDebugScenario
    /// dashRecent` = 16 h, `dashDays` = 3 days, `dashQuiet` = 12 days, `dashActive` = ongoing), so the header
    /// wording can be captured. `-MygraDebugHealth connected` (any scenario) adds canned Health stats.
    public func runDebugDashboardScenario(_ scenario: String) {
        let hours: [String: Double] = ["dashRecent": 16, "dashDays": 3 * 24, "dashQuiet": 12 * 24, "dashActive": 40]
        guard let endedHoursAgo = hours[scenario] else { return }
        migraineData.deleteAll()
        let now = Date()
        // 15 attacks in total, the newest ending `endedHoursAgo` ago.
        for index in 0..<15 {
            let end = now.addingTimeInterval(-(endedHoursAgo + Double(index) * 52) * 3600)
            migraineData.log(Migraine(startDate: end.addingTimeInterval(-4 * 3600), endDate: end, painLevel: 3 + index % 5, stressLevel: 4))
        }
        if scenario == "dashActive" {
            // An ongoing attack, started 40 minutes ago, without opening Attack Mode.
            migraineData.log(Migraine(startDate: now.addingTimeInterval(-40 * 60), endDate: nil, painLevel: 7, stressLevel: 4))
        }
    }
}

// MARK: - Store showcase and shared debug flags

extension SessionController {
    /// Applies the flags that work with any scenario: `-MygraDebugHealth connected` (canned,
    /// connected Health) and `-MygraDebugOngoing YES` (an ongoing migraine, 1 h 20 min old).
    public func applyDebugFlags() {
        let defaults = UserDefaults.standard
        #if canImport(HealthKit) && !os(macOS)
        if defaults.string(forKey: "MygraDebugHealth") == "connected" {
            healthManager.installDebugHealth(HealthData(
                waterLiters: 1.4, sleepHours: 7.1, energyKilocalories: 1650, caffeineMg: 95,
                stepCount: 6420, restingHeartRate: 58
            ))
        }
        #endif
        if defaults.bool(forKey: "MygraDebugOngoing"), migraineData.ongoingMigraine == nil {
            let start = Date().addingTimeInterval(-80 * 60)
            let migraine = Migraine(startDate: start, endDate: nil, painLevel: 4, stressLevel: 5)
            let readings = [(25.0, 6, 5), (50.0, 7, 5), (75.0, 7, 4)]
            let samples = readings.map {
                IntensitySample(timestamp: start.addingTimeInterval($0.0 * 60), painLevel: $0.1, stressLevel: $0.2)
            }
            migraine.intensitySamples = samples
            for sample in samples { sample.parentMigraine = migraine }
            migraineData.log(migraine)
            migraineData.update(migraine) { $0.painLevel = 7; $0.stressLevel = 4 }
        }
    }

    /// Seeds about three months of believable history for marketing captures
    /// (`-MygraDebugScenario store`). Deterministic: the same data on every launch.
    public func runDebugStoreScenario() {
        migraineData.deleteAll()
        var rng = DebugRandom(seed: 2027)
        let calendar = Calendar.current
        let now = Date()

        // Tags.
        let tagDefinitions: [(String, String)] = [
            ("Work Stress", "#EF4444"), ("Weather Related", "#3B82F6"), ("Hormonal", "#EC4899"),
            ("Food Trigger", "#F97316"), ("Sleep Issues", "#8B5CF6"), ("Exercise", "#10B981"),
        ]
        let tags: [MigraineTag] = tagDefinitions.compactMap { name, hex in
            tagData.tags.first { $0.name == name } ?? tagData.create(name: name, colorHex: hex)
        }
        func tag(_ index: Int) -> MigraineTag? { index < tags.count ? tags[index] : nil }

        // Trigger sets, each with the tag that goes with it.
        let triggerSets: [(triggers: [MigraineTrigger], custom: [String], tag: Int?)] = [
            ([.stress, .lackOfSleep], [], 0),
            ([.skippedMeals, .dehydration], [], 3),
            ([.barometricPressureChange], [], 1),
            ([.hormonalFluctuation], [], 2),
            ([.stress, .screenTimeFlicker, .caffeineExcess], [], 0),
            ([.lackOfSleep, .caffeineWithdrawal], ["Long flight"], 4),
            ([.stormsWind, .highHumidity, .barometricPressureChange], [], 1),
            ([.alcoholRedWine, .agedCheese], [], 3),
            ([.intenseExercise, .dehydration], [], 5),
            ([.brightLightGlare, .eyeStrainBlueLight], ["Skipped lunch at the office"], nil),
            ([.hormonalFluctuation, .stress], [], 2),
            ([.oversleeping], [], 4),
        ]
        let medicines: [(String, MedicationClass, String)] = [
            ("Sumatriptan", .triptan, "50 mg"), ("Ibuprofen", .simpleAnalgesic, "400 mg"),
            ("Rizatriptan", .triptan, "10 mg"), ("Naproxen", .simpleAnalgesic, "500 mg"),
        ]
        let conditions: [SkyCondition] = [.cloudy, .partlyCloudy, .rain, .clear, .mostlyCloudy, .drizzle]
        let places = ["Seattle, WA", "Portland, OR"]
        let durations: [Double] = [2.5, 3, 4, 5, 6, 8, 10, 12, 15, 18, 22, 26, 30]
        let notes: [String?] = [nil, nil, "Started behind the left eye.", nil, "Better after resting in the dark.", nil, nil, "Woke with it."]

        // Start times: the newest began 62 h ago (ended 48 h ago); the rest are spread over three months.
        var starts: [Date] = [now.addingTimeInterval(-62 * 3600)]
        let perMonth = [6, 8, 7]
        for (month, count) in perMonth.enumerated() {
            let first = month == 0 ? 1 : 0
            for index in first..<count {
                let daysAgo = 3.4 + Double(month) * 30 + (Double(index) + 0.15 + rng.next(in: 0...0.7)) * 30 / Double(count)
                let day = calendar.startOfDay(for: now.addingTimeInterval(-daysAgo * 86_400))
                let hour = Double(rng.nextInt(in: 5...21)) + rng.next(in: 0...0.9)
                starts.append(day.addingTimeInterval(hour * 3600))
            }
        }
        starts.sort(by: >)

        for (position, start) in starts.enumerated() {
            let isNewest = position == 0
            let hours = isNewest ? 14 : durations[rng.nextInt(in: 0...(durations.count - 1))]
            let end = start.addingTimeInterval(hours * 3600)
            let peak = isNewest ? 7 : rng.nextInt(in: 4...9)
            let stress = rng.nextInt(in: 2...8)
            let set = triggerSets[(position * 5 + rng.nextInt(in: 0...3)) % triggerSets.count]
            let hasTriggers = rng.nextInt(in: 0...9) < 8

            // Intensity readings: 4 to 8, rising to a peak about a third of the way in, then easing.
            let readings = min(8, max(4, 3 + Int(hours / 4)))
            let startPain = max(2, peak - 3)
            var samples: [IntensitySample] = []
            for index in 1..<readings {
                let t = Double(index) / Double(readings - 1)
                let shape = t < 0.35 ? (0.55 + 0.45 * t / 0.35) : (1 - 0.8 * (t - 0.35) / 0.65)
                let pain = max(1, min(10, Int((Double(peak) * shape + rng.next(in: -0.4...0.4)).rounded())))
                let note: String? = (t >= 0.3 && t < 0.45 && samples.isEmpty == false && index == readings / 3) ? "Worst point" : nil
                samples.append(IntensitySample(timestamp: start.addingTimeInterval(hours * 3600 * t), painLevel: index == readings - 1 ? 1 : pain, stressLevel: max(1, stress - Int(t * 3)), note: note))
            }

            let migraine = Migraine(
                startDate: start,
                endDate: end,
                painLevel: startPain,
                stressLevel: stress,
                note: notes[rng.nextInt(in: 0...(notes.count - 1))],
                triggers: hasTriggers ? set.triggers : [],
                customTriggers: hasTriggers ? set.custom : []
            )
            migraine.intensitySamples = samples
            for sample in samples { sample.parentMigraine = migraine }
            if hasTriggers, let index = set.tag, let t = tag(index) { migraine.tags = [t] }

            // Medication on about half.
            if rng.nextInt(in: 0...9) < 6 {
                var doses = [medicines[rng.nextInt(in: 0...3)]]
                if rng.nextInt(in: 0...2) == 0, let second = medicines.last(where: { $0.1 != doses[0].1 }) { doses.append(second) }
                migraine.medications = doses.enumerated().map { index, item in
                    MedicationDose(name: item.0, medicationClass: item.1, dose: item.2, takenAt: start.addingTimeInterval(Double(1500 + index * 1500)))
                }
                for dose in migraine.medications ?? [] { dose.migraine = migraine }
            }

            // Weather and Health snapshots on the recent ones (the last 45 days).
            if now.timeIntervalSince(start) < 45 * 86_400 {
                migraine.weather = WeatherData(
                    barometricPressureHpa: 1003 + rng.next(in: 0...14),
                    temperatureCelsius: 7 + rng.next(in: 0...13),
                    humidityPercent: 55 + rng.next(in: 0...35),
                    condition: conditions[rng.nextInt(in: 0...(conditions.count - 1))],
                    locationDescription: places[position % places.count]
                )
                migraine.health = HealthData(
                    waterLiters: 0.9 + rng.next(in: 0...1.3),
                    sleepHours: 5.2 + rng.next(in: 0...2.6),
                    energyKilocalories: 1300 + rng.next(in: 0...900),
                    caffeineMg: 40 + rng.next(in: 0...220),
                    stepCount: 2500 + rng.nextInt(in: 0...6500),
                    restingHeartRate: 56 + rng.nextInt(in: 0...9)
                )
            }
            if position == 9 { migraine.pinned = true }

            migraineData.log(migraine)
            // The headline levels are the peak, not the first reading the repository recorded.
            migraineData.update(migraine) { $0.painLevel = peak; $0.stressLevel = stress }
        }

        // Cycle: periods every 28 days, the latest 5 days ago.
        func day(_ offset: Int) -> Date {
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        var flowDays: [Date] = []
        for offset in [-117, -89, -61, -33, -5] {
            for extra in 0..<5 { flowDays.append(day(offset + extra)) }
        }
        cycleData.installDebugFlowDays(flowDays)

        // Pressure: drops ahead of the newest attack and one a week earlier, one forecast.
        func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        func hpa(_ hour: Double) -> Double {
            var p = 1016 + 1.5 * sin(hour / 22)
            p -= 7.5 * smooth((hour + 76) / 9) - 7.5 * smooth((hour + 62) / 16)
            p -= 7 * smooth((hour + 196) / 9) - 7 * smooth((hour + 180) / 14)
            p -= 6.5 * smooth((hour - 3) / 10)
            return p
        }
        let series = (-168...48).map { PressureSample(date: now.addingTimeInterval(Double($0) * 3600), hpa: hpa(Double($0))) }
        weatherManager.installDebugWeather(
            reading: WeatherReading(
                temperature: Measurement(value: 57, unit: .fahrenheit),
                pressure: Measurement(value: hpa(0), unit: .hectopascals),
                humidity: 0.64,
                condition: .partlyCloudy,
                fetchedAt: now
            ),
            pressureSeries: series
        )
    }
}

/// A small seeded generator (SplitMix64), so the store scenario is identical on every launch.
private struct DebugRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func nextBits() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(nextBits() % 1_000_000) / 1_000_000 * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(nextBits() % UInt64(range.count))
    }
}
#endif
