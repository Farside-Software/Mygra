#if os(iOS)
import Testing
import CoreGraphics
@testable import MygraFeatureMigraines

@MainActor
struct MigraineLayoutTests {
    @Test func duoSplitsFromWidthAlone() {
        #expect(!MigraineLayout.isWide(width: 400, isDuo: true, isRegularWidth: false, wasWide: false))
        #expect(MigraineLayout.isWide(width: 951, isDuo: true, isRegularWidth: false, wasWide: false))
    }

    @Test func hysteresisKeepsLayoutNearThreshold() {
        #expect(!MigraineLayout.isWide(width: 590, isDuo: true, isRegularWidth: false, wasWide: false))
        #expect(MigraineLayout.isWide(width: 590, isDuo: true, isRegularWidth: false, wasWide: true))
        #expect(!MigraineLayout.isWide(width: 540, isDuo: true, isRegularWidth: false, wasWide: true))
    }

    @Test func phoneNeverSplits() {
        #expect(!MigraineLayout.isWide(width: 900, isDuo: false, isRegularWidth: false, wasWide: false))
        #expect(MigraineLayout.isWide(width: 820, isDuo: false, isRegularWidth: true, wasWide: false))
    }
}
#endif
