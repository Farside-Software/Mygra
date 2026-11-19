# Mygra 3.0 App Preview

The App Store app preview and its web version. Images and video are in Git LFS.

- `Mygra 3.0 App Preview (iPhone 6.9).mp4`: the upload to App Store Connect (886x1920, H.264, 30 fps, 30 s, with audio). Poster frame 00:00:02:21 (the opening card).
- `Mygra 3.0 App Preview (iPad 13).mp4`: the iPad 13" preview (1200x1600 portrait, 30 s), uploaded to the `IPAD_PRO_3GEN_129` set.
- `Mygra 3.0 App Preview (iPhone Duo unfolded).mp4` (1920x886 landscape, the open inner display) and `... (iPhone Duo folded).mp4` (886x1920 portrait, the outer display with the vertical tab strip): the two iPhone Duo previews, uploaded to the `IPHONE_DUO` set.
- `Mygra 3.0 App Preview web.mp4` and `... web poster.webp`: the web encode (720 px wide, CRF 26, faststart) used on farsidesoftware.com/mygra.
- `... poster (title card, 2.7s).png`: the opening card at full size.
- `Mygra score B soft mallets.py` / `.wav`: the original score (Python, numpy/scipy).

Recorded with Matte on an iPhone 18 Pro, iPad Pro 13-inch (M5) and iPhone Duo simulator, using `-MygraDebugScenario store -MygraDebugHealth connected -isOnboardingComplete YES -MygraDebugLocalStore YES -Plus.grandfathered YES -Plus.earlySupporterThanksShown YES` (plus `-MygraDebugStoreNoCycle YES -MygraDebugStoreNoPressure YES` for the iPad and Duo takes) (see `Packages/Mygra/Sources/MygraComposition/SessionController+DebugScenarios.swift`). The Matte project packages stay outside the repo.
