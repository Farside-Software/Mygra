# Mygra 3.0 App Store screenshots

The set uploaded to App Store Connect for Mygra 3.0.0 (2026-11-18). Images are in Git LFS and are not fetched by default (`git lfs pull --include "Marketing/**" --exclude ""` fetches them).

## Files

- `Mygra 3.0 Artboards.af`: the layered Affinity document. Every artboard has three layers: Background (image), Device (framed capture) and Headline (live text, SF Pro Rounded Heavy, first line ink `#1E1A2E`, second line Mygra purple `#6E60FF`).
- `final/`: the exports as uploaded (PNG, no alpha).
- `backgrounds/`: the canvas backgrounds (pale lilac gradient, soft glow, faint eight-segment halo from the app icon), rendered by `source/bg.swift`.
- `source/`: shot lists (`shots*.json`) and the scripts that build the artboards.

## The sets

| Set | Size | Shots |
|---|---|---|
| iPhone (`APP_IPHONE_67`) | 1320x2868 | 8 |
| iPad (`APP_IPAD_PRO_3GEN_129`) | 2064x2752 | 8 |
| iPhone Duo (`APP_IPHONE_DUO`) | 1398x2034 folded, 2853x2007 unfolded | 5 + 4 |
| Apple Watch (`APP_WATCH_SERIES_10`) | 416x496 | 2 |
| Product page header | 3840x1646 | 1 |
| Search results | 3840x2560 | 1 |

Captions, in order: Your migraines, at a glance. / Log an attack in seconds. / See the pattern take shape. / Every attack, in detail. / Weather and cycle, side by side. / Track it from your Lock Screen. / Ask about your history. / A clear report for your doctor.

## Rebuilding

1. Capture on simulators with `-MygraDebugScenario store -MygraDebugHealth connected -isOnboardingComplete YES` (add `-MygraDebugOngoing YES` for the ongoing-attack shots, `-Plus.grandfathered YES` only for Plus screens other than the dashboard). Status bar: `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100`. Watch clocks are redrawn with `source/watchclock.swift`.
2. Frame with the Framous CLI: iPhone 17 Pro Max silver, iPad Pro 13-inch (M5) silver, `iPhoneDuoOuterClosed` / `iPhoneDuoInnerOpen` star-white, `appleWatch11-46`.
3. Affinity's scripting can only read the Desktop, so the working copy lives in `~/Desktop/Mygra 3.0 Store (Claude)/` with the framed images in its `images/` folder.
4. `source/affinity/make_jobs.py <shots.json> <jobs.json>` lays out each artboard (`make_assets.py` for the header and search images), and `source/affinity/run.sh build.js <jobs.json>` builds or refreshes them in Affinity and exports them.
