import XCTest
@testable import SideScreen

class StreamingServerTests: XCTestCase {

    func testCreateDisplaySizeData() {
        // Arrange
        let server = StreamingServer(port: 1234)

        let expectedWidth = 1920
        let expectedHeight = 1080
        let expectedRotation = 90

        server.setDisplaySize(width: expectedWidth, height: expectedHeight, rotation: expectedRotation)

        // Act
        let data = server.createDisplaySizeData()

        // Assert
        // 1 byte type + 4 bytes width + 4 bytes height + 4 bytes rotation = 13 bytes
        XCTAssertEqual(data.count, 13, "Data payload should be exactly 13 bytes")

        // Check message type (first byte)
        XCTAssertEqual(data[0], 1, "Message type should be 1 for display size config")

        // Extract and check width (bytes 1-4)
        let widthBytes = data.subdata(in: 1..<5)
        let decodedWidth = Int(widthBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedWidth, expectedWidth, "Width should be correctly encoded in big-endian")

        // Extract and check height (bytes 5-8)
        let heightBytes = data.subdata(in: 5..<9)
        let decodedHeight = Int(heightBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedHeight, expectedHeight, "Height should be correctly encoded in big-endian")

        // Extract and check rotation (bytes 9-12)
        let rotationBytes = data.subdata(in: 9..<13)
        let decodedRotation = Int(rotationBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedRotation, expectedRotation, "Rotation should be correctly encoded in big-endian")
    }

    func testCreateDisplaySizeData_WithNegativeValues() {
        // Arrange
        let server = StreamingServer(port: 1234)

        let expectedWidth = -1920
        let expectedHeight = -1080
        let expectedRotation = -90

        server.setDisplaySize(width: expectedWidth, height: expectedHeight, rotation: expectedRotation)

        // Act
        let data = server.createDisplaySizeData()

        // Assert
        XCTAssertEqual(data.count, 13, "Data payload should be exactly 13 bytes")
        XCTAssertEqual(data[0], 1, "Message type should be 1")

        let widthBytes = data.subdata(in: 1..<5)
        let decodedWidth = Int(widthBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedWidth, expectedWidth)

        let heightBytes = data.subdata(in: 5..<9)
        let decodedHeight = Int(heightBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedHeight, expectedHeight)

        let rotationBytes = data.subdata(in: 9..<13)
        let decodedRotation = Int(rotationBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedRotation, expectedRotation)
    }

    func testCreateDisplaySizeData_WithZeroValues() {
        // Arrange
        let server = StreamingServer(port: 1234)

        let expectedWidth = 0
        let expectedHeight = 0
        let expectedRotation = 0

        server.setDisplaySize(width: expectedWidth, height: expectedHeight, rotation: expectedRotation)

        // Act
        let data = server.createDisplaySizeData()

        // Assert
        XCTAssertEqual(data.count, 13, "Data payload should be exactly 13 bytes")
        XCTAssertEqual(data[0], 1, "Message type should be 1")

        let widthBytes = data.subdata(in: 1..<5)
        let decodedWidth = Int(widthBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedWidth, expectedWidth)

        let heightBytes = data.subdata(in: 5..<9)
        let decodedHeight = Int(heightBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedHeight, expectedHeight)

        let rotationBytes = data.subdata(in: 9..<13)
        let decodedRotation = Int(rotationBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
        XCTAssertEqual(decodedRotation, expectedRotation)
    }
}
