import ReviewCore
import Testing

@Suite
struct ZoomLevelTests {
    @Test("Zooming in then out returns to actual size")
    func roundTrip() throws {
        let larger = try #require(ZoomLevel.actualSize.zoomedIn)
        #expect(larger.scale > 1)
        #expect(larger.zoomedOut == .actualSize)
        #expect(larger.zoomedOut?.isActualSize == true)
    }

    @Test("The ladder stops at both ends")
    func ends() {
        #expect(ZoomLevel(scale: 2).zoomedIn == nil)
        #expect(ZoomLevel(scale: 0.75).zoomedOut == nil)
    }

    @Test("Out-of-range and non-finite scales are clamped")
    func clamping() {
        #expect(ZoomLevel(scale: 10).scale == 2)
        #expect(ZoomLevel(scale: 0.1).scale == 0.75)
        #expect(ZoomLevel(scale: .nan).scale == 1)
    }

    @Test("A scale between steps snaps to the neighbouring step")
    func snapping() {
        let between = ZoomLevel(scale: 1.2)
        #expect(between.zoomedIn?.scale == 1.3)
        #expect(between.zoomedOut?.scale == 1.15)
    }

    @Test("A stored value a hair off a step still moves a whole step")
    func tolerance() {
        #expect(ZoomLevel(scale: 1.1500001).zoomedIn?.scale == 1.3)
        #expect(ZoomLevel(scale: 1.1499999).zoomedOut?.scale == 1)
    }
}
