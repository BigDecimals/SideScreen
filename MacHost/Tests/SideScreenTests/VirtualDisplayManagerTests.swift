import XCTest
@testable import SideScreen
import CGVirtualDisplayBridge

@available(macOS 14.0, *)
class MockVirtualDisplay: VirtualDisplayProtocol {
    var displayID: UInt32 = 12345
    var shouldApplySucceed = true

    func applySettings(_ settings: CGVirtualDisplaySettings) -> Bool {
        return shouldApplySucceed
    }
}

@available(macOS 14.0, *)
final class VirtualDisplayManagerTests: XCTestCase {

    var manager: VirtualDisplayManager!

    override func setUp() {
        super.setUp()
        manager = VirtualDisplayManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testCreateDisplaySuccess_Standard() throws {
        // Arrange
        let mockDisplay = MockVirtualDisplay()
        manager.displayFactory = { _ in return mockDisplay }

        // Act
        try manager.createDisplay(width: 1920, height: 1080, refreshRate: 60, hiDPI: false, name: "Test Standard")

        // Assert
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.displayID, 12345)

        // Validate descriptor
        let descriptor = try XCTUnwrap(manager.displayDescriptor)
        XCTAssertEqual(descriptor.name, "Test Standard")
        XCTAssertEqual(descriptor.maxPixelsWide, 1920)
        XCTAssertEqual(descriptor.maxPixelsHigh, 1080)

        // Validate settings
        let settings = try XCTUnwrap(manager.displaySettings)
        XCTAssertEqual(settings.hiDPI, 0)
        XCTAssertEqual(settings.modes.count, 1)

        let mode = settings.modes[0]
        XCTAssertEqual(mode.width, 1920)
        XCTAssertEqual(mode.height, 1080)
        XCTAssertEqual(mode.refreshRate, 60.0)
    }

    func testCreateDisplaySuccess_HiDPI() throws {
        // Arrange
        let mockDisplay = MockVirtualDisplay()
        manager.displayFactory = { _ in return mockDisplay }

        // Act
        try manager.createDisplay(width: 1920, height: 1080, refreshRate: 120, hiDPI: true, name: "Test HiDPI")

        // Assert
        XCTAssertTrue(manager.isActive)

        // Validate descriptor
        let descriptor = try XCTUnwrap(manager.displayDescriptor)
        XCTAssertEqual(descriptor.name, "Test HiDPI")
        XCTAssertEqual(descriptor.maxPixelsWide, 1920 * 2) // Physical pixels = 2x logical
        XCTAssertEqual(descriptor.maxPixelsHigh, 1080 * 2)

        // Validate settings
        let settings = try XCTUnwrap(manager.displaySettings)
        XCTAssertEqual(settings.hiDPI, 1)
        XCTAssertEqual(settings.modes.count, 2) // Should have physical anchor mode + logical mode

        // Physical anchor mode
        let physicalMode = settings.modes[0]
        XCTAssertEqual(physicalMode.width, 1920 * 2)
        XCTAssertEqual(physicalMode.height, 1080 * 2)
        XCTAssertEqual(physicalMode.refreshRate, 120.0)

        // Logical mode
        let logicalMode = settings.modes[1]
        XCTAssertEqual(logicalMode.width, 1920)
        XCTAssertEqual(logicalMode.height, 1080)
        XCTAssertEqual(logicalMode.refreshRate, 120.0)
    }

    func testCreateDisplayFailure_Creation() {
        // Arrange
        manager.displayFactory = { _ in return nil } // Simulate failure to create CGVirtualDisplay

        // Act & Assert
        XCTAssertThrowsError(try manager.createDisplay(width: 1920, height: 1080)) { error in
            guard let virtualError = error as? VirtualDisplayError else {
                XCTFail("Expected VirtualDisplayError but got \(error)")
                return
            }

            if case .creationFailed = virtualError {
                // Success
            } else {
                XCTFail("Expected .creationFailed but got \(virtualError)")
            }
        }

        XCTAssertFalse(manager.isActive)
    }

    func testCreateDisplayFailure_ApplySettings() {
        // Arrange
        let mockDisplay = MockVirtualDisplay()
        mockDisplay.shouldApplySucceed = false // Simulate apply failure
        manager.displayFactory = { _ in return mockDisplay }

        // Act & Assert
        XCTAssertThrowsError(try manager.createDisplay(width: 1920, height: 1080)) { error in
            guard let virtualError = error as? VirtualDisplayError else {
                XCTFail("Expected VirtualDisplayError but got \(error)")
                return
            }

            if case .settingsApplyFailed = virtualError {
                // Success
            } else {
                XCTFail("Expected .settingsApplyFailed but got \(virtualError)")
            }
        }

        XCTAssertFalse(manager.isActive) // Display should be cleaned up
        XCTAssertNil(manager.displayDescriptor)
        XCTAssertNil(manager.displaySettings)
    }
}
