import XCTest
import CoreGraphics
@testable import SideScreen

final class ScreenCaptureTests: XCTestCase {

    class MockDisplayModeProvider: DisplayModeProvider {
        var mockPhysicalSize: (width: Int, height: Int)?
        var mockPixelsWide: Int = 1920
        var mockPixelsHigh: Int = 1080

        func copyDisplayModePhysicalSize(for displayID: CGDirectDisplayID) -> (width: Int, height: Int)? {
            return mockPhysicalSize
        }
        func pixelsWide(for displayID: CGDirectDisplayID) -> Int {
            return mockPixelsWide
        }
        func pixelsHigh(for displayID: CGDirectDisplayID) -> Int {
            return mockPixelsHigh
        }
    }

    func testPhysicalSizeWithValidMode() {
        let provider = MockDisplayModeProvider()
        provider.mockPhysicalSize = (width: 3840, height: 2160)
        // Set fallback values to something different to ensure we didn't hit fallback
        provider.mockPixelsWide = 1920
        provider.mockPixelsHigh = 1080

        let size = ScreenCapture.physicalSize(for: 12345, provider: provider)

        XCTAssertEqual(size.width, 3840)
        XCTAssertEqual(size.height, 2160)
    }

    func testPhysicalSizeFallback() {
        let provider = MockDisplayModeProvider()
        provider.mockPhysicalSize = nil // trigger fallback
        provider.mockPixelsWide = 2560
        provider.mockPixelsHigh = 1440

        let size = ScreenCapture.physicalSize(for: 12345, provider: provider)

        XCTAssertEqual(size.width, 2560)
        XCTAssertEqual(size.height, 1440)
    }
}
