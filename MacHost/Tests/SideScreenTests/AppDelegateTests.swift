import XCTest
import ApplicationServices
@testable import SideScreen

@available(macOS 14.0, *)
final class AppDelegateTests: XCTestCase {

    var appDelegate: AppDelegate!
    var postedEvents: [CGEvent]!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        appDelegate.bypassAccessibilityCheckForTesting = true
        appDelegate.settings.touchEnabled = true
        postedEvents = []

        // Mock eventPoster to capture events instead of posting them
        appDelegate.eventPoster = { [weak self] event in
            self?.postedEvents.append(event)
        }
    }

    override func tearDown() {
        appDelegate = nil
        postedEvents = nil
        super.tearDown()
    }

    func testSingleFingerTap() {
        // Touch down
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 0, pointerCount: 1)

        // Touch up immediately (simulating a tap)
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 2, pointerCount: 1)

        // Should have posted move (from down), down, and up events
        XCTAssertEqual(postedEvents.count, 3)
        XCTAssertEqual(postedEvents[0].type, .mouseMoved)
        XCTAssertEqual(postedEvents[1].type, .leftMouseDown)
        XCTAssertEqual(postedEvents[2].type, .leftMouseUp)

        XCTAssertEqual(postedEvents[1].getIntegerValueField(.mouseEventClickState), 1)
        XCTAssertEqual(postedEvents[2].getIntegerValueField(.mouseEventClickState), 1)

        // Verify coordinates (1920/2, 1080/2)
        XCTAssertEqual(postedEvents[1].location.x, 960.0)
        XCTAssertEqual(postedEvents[1].location.y, 540.0)
    }

    func testDoubleTap() {
        // First tap
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 0, pointerCount: 1)
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 2, pointerCount: 1)

        // Wait a short time to simulate realistic time between taps (though currently not using wall clock except for down->up check)
        // Note: AppDelegate uses DispatchTime.now().uptimeNanoseconds internally.
        // It's a bit tricky to mock uptimeNanoseconds without refactoring, but a quick successive call works because time elapsed is ~0

        // Second tap
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 0, pointerCount: 1)
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 2, pointerCount: 1)

        // Total events: move, down, up, move, down, up
        XCTAssertEqual(postedEvents.count, 6)

        // Second down/up should have click state 2
        XCTAssertEqual(postedEvents[4].type, .leftMouseDown)
        XCTAssertEqual(postedEvents[5].type, .leftMouseUp)
        XCTAssertEqual(postedEvents[4].getIntegerValueField(.mouseEventClickState), 2)
        XCTAssertEqual(postedEvents[5].getIntegerValueField(.mouseEventClickState), 2)
    }

    func testOneFingerDrag() {
        // Touch down
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 0, pointerCount: 1)

        // Move significantly to trigger scroll state (tapMaxDistance is 15, so 100 pixels is enough)
        appDelegate.handleTouch(x: 0.5, y: 0.6, action: 1, pointerCount: 1) // 10% of 1080 = 108px > 15

        // Expect move (from down) and then scroll (from move)
        // Wait, 1 finger drag actually triggers scroll by default unless long pressed!
        XCTAssertEqual(postedEvents.count, 2)
        XCTAssertEqual(postedEvents[0].type, .mouseMoved)
        XCTAssertEqual(postedEvents[1].type, .scrollWheel)

        let scrollEvent = postedEvents[1]
        // dy = 0.6 - 0.5 = 0.1 * 1080 = 108
        // scroll sensitivity = 1.2
        // wheel1 is deltaY, expected 108 * 1.2 = 129
        let expectedDeltaY = Int32(108.0 * 1.2)
        XCTAssertEqual(scrollEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1), Int64(expectedDeltaY))
    }

    func testTwoFingerScroll() {
        // Touch down (2 fingers)
        appDelegate.handleTouch(x: 0.5, y: 0.5, action: 0, pointerCount: 2, x2: 0.55, y2: 0.55)

        // Move both fingers down
        appDelegate.handleTouch(x: 0.5, y: 0.6, action: 1, pointerCount: 2, x2: 0.55, y2: 0.65)

        // Wait, for move, distance between fingers is unchanged. Midpoint changed from (0.525, 0.525) to (0.525, 0.625)
        // The midpoint changed by 0.1 in Y, which is 108 pixels. This triggers 2-finger scroll

        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents[0].type, .scrollWheel)

        let scrollEvent = postedEvents[0]
        let expectedDeltaY = Int32(108.0 * 1.2)
        XCTAssertEqual(scrollEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1), Int64(expectedDeltaY))
    }

    func testPinchZoom() {
        // Touch down (2 fingers)
        appDelegate.handleTouch(x: 0.4, y: 0.5, action: 0, pointerCount: 2, x2: 0.6, y2: 0.5)

        // Pinch inward (decrease distance)
        // Original distance: 0.2 * 1920 = 384 pixels
        // New distance: 0.1 * 1920 = 192 pixels (distance change = 192, > 20, triggers pinch)
        appDelegate.handleTouch(x: 0.45, y: 0.5, action: 1, pointerCount: 2, x2: 0.55, y2: 0.5)

        XCTAssertEqual(postedEvents.count, 1)
        let zoomEvent = postedEvents[0]
        XCTAssertEqual(zoomEvent.type, .scrollWheel)

        // Check for Cmd flag for zoom
        XCTAssertTrue(zoomEvent.flags.contains(.maskCommand))

        // Expected scale delta: 192 - 384 = -192
        // Zoom amount = -192 * 0.5 = -96
        XCTAssertEqual(zoomEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1), -96)
    }

}
