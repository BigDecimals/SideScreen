import XCTest
import CoreGraphics
@testable import SideScreen

class MockDisplayInfoProvider: DisplayInfoProviding {
    var mockMainDisplayID: CGDirectDisplayID?
    var mockWidth: Int = 1920
    var mockHeight: Int = 1080
    var mockRefreshRate: Int? = 60

    func mainDisplayID() -> CGDirectDisplayID? {
        return mockMainDisplayID
    }

    func displayPixelsWide(_ display: CGDirectDisplayID) -> Int {
        return mockWidth
    }

    func displayPixelsHigh(_ display: CGDirectDisplayID) -> Int {
        return mockHeight
    }

    func displayRefreshRate(_ display: CGDirectDisplayID) -> Int? {
        return mockRefreshRate
    }
}

@available(macOS 14.0, *)
class VirtualDisplayManagerTests: XCTestCase {

    var manager: VirtualDisplayManager!
    var mockProvider: MockDisplayInfoProvider!

    override func setUp() {
        super.setUp()
        mockProvider = MockDisplayInfoProvider()
        manager = VirtualDisplayManager(displayInfoProvider: mockProvider)
    }

    override func tearDown() {
        manager = nil
        mockProvider = nil
        super.tearDown()
    }

    func testCloneMainDisplay_WhenMainDisplayNotFound_ThrowsError() {
        // Arrange
        mockProvider.mockMainDisplayID = nil

        // Act & Assert
        XCTAssertThrowsError(try manager.cloneMainDisplay()) { error in
            guard let virtualDisplayError = error as? VirtualDisplayError else {
                XCTFail("Expected VirtualDisplayError but got \(error)")
                return
            }

            switch virtualDisplayError {
            case .mainDisplayNotFound:
                // Success
                break
            default:
                XCTFail("Expected .mainDisplayNotFound but got \(virtualDisplayError)")
            }
        }
    }

    // We can also test the properties and other logic if desired
}
