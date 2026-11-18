# Mygra

A calm journal for your migraines, for iPhone and Apple Watch, published by Farside Software LLC.

Mygra logs each migraine with its intensity over time, attaches the Apple Health and weather context around it, and shows your history back to you through simple, rule-based Quick Bits and an on-device assistant. Everything syncs privately through your own iCloud. Mygra is a journal, not a medical device, and gives no medical advice.

- App page: https://farsidesoftware.com/mygra
- Support: https://farsidesoftware.com/support
- Privacy policy: https://farsidesoftware.com/privacy

## Features

- **Migraine journal**: start an ongoing migraine (with a Live Activity and Dynamic Island timer) or log a finished one; pin, filter and search your history.
- **Intensity tracking**: record pain and stress as an attack evolves and see the curve on each migraine.
- **Health and weather context**: sleep, hydration, caffeine, energy, steps and heart rate from Apple Health, and conditions and pressure from WeatherKit, attached when you log.
- **Dashboard and Quick Bits**: this month against last, a 30-day strip, common triggers and medications, and when attacks tend to start.
- **Migraine Assistant**: on-device Apple Intelligence explanations and chat over your own entries.
- **Tags, calendar, reports**: your own tags, a month calendar, and PDF and CSV export.
- **Siri, Shortcuts, widgets**: ask when your last migraine was, log a medication or trigger by voice, and use the days-since widget and Live Activity.
- **Apple Watch**: see days since your last migraine, start one, or end it from your wrist.
- **iPhone Duo**: two-column detail pages, calendar and list side by side, and a Settings split view when unfolded.

## Platforms

iOS 18 and watchOS 10 or later (Apple Intelligence features need a supported device and OS). HealthKit, WeatherKit and Apple Intelligence need a real device.

## Building

Open `Mygra.xcworkspace` (it resolves the local package in `Packages/Mygra`; there are no external dependencies). Xcode 27, Swift 6 language mode.

```sh
xcodebuild -workspace Mygra.xcworkspace -scheme Mygra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run the package tests, which need no simulator:

```sh
cd Packages/Mygra && swift test
```

## Project structure

```
Mygra/
├── Mygra/                  App target: @main, App Intents, Spotlight, background tasks, menu commands
├── MygraWidgets/           Days-since widget and ongoing-migraine Live Activity
├── Mygra Wrist Watch App/  Watch companion
├── Mygra Wrist Widgets/    Watch complication
├── Packages/Mygra/         The app itself, an SPM umbrella package of layered modules
├── AppStore/3.0.0/         App Store copy for this release
├── Icons/                  App icon source
└── Scripts/                Localization tooling
```

`CLAUDE.md` has the module-by-module tour.

## Privacy

Your migraine data stays on your device and in your private iCloud. Health data is read and written only with your permission. Insights and the assistant run on-device. No analytics or tracking.

## License

MIT, see [LICENSE](LICENSE).
