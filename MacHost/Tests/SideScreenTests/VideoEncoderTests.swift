import XCTest
@testable import SideScreen
import VideoToolbox
import CoreMedia

final class VideoEncoderTests: XCTestCase {

    // Helper method to extract properties from VTCompressionSession
    private func getProperty(_ session: VTCompressionSession, key: CFString) -> Any? {
        var valueOut: CFTypeRef?
        let status = VTSessionCopyProperty(session, key: key, allocator: kCFAllocatorDefault, valueOut: &valueOut)
        guard status == noErr else { return nil }
        return valueOut
    }

    func testInitialization_StaticProperties() {
        let encoder = VideoEncoder(width: 1920, height: 1080, bitrateMbps: 20, quality: "medium", gamingBoost: false, frameRate: 60)

        guard let session = encoder.compressionSession else {
            XCTFail("Compression session was not created")
            return
        }

        // Verify basic properties
        XCTAssertEqual(getProperty(session, key: kVTCompressionPropertyKey_RealTime) as? Bool, true)
        XCTAssertEqual(getProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering) as? Bool, false)

        // Verify delay count
        if let maxFrameDelayCount = getProperty(session, key: kVTCompressionPropertyKey_MaxFrameDelayCount) as? NSNumber {
            XCTAssertEqual(maxFrameDelayCount.intValue, 0)
        } else {
            XCTFail("MaxFrameDelayCount property missing")
        }

        // Verify key frame interval
        if let maxKeyFrameInterval = getProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval) as? NSNumber {
            XCTAssertEqual(maxKeyFrameInterval.intValue, 1)
        } else {
            XCTFail("MaxKeyFrameInterval property missing")
        }

        // Verify expected frame rate
        if let expectedFrameRate = getProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate) as? NSNumber {
            XCTAssertEqual(expectedFrameRate.intValue, 60)
        } else {
            XCTFail("ExpectedFrameRate property missing")
        }
    }

    func testUpdateSettings_NormalMode() {
        let encoder = VideoEncoder(width: 1920, height: 1080, bitrateMbps: 20, quality: "low", gamingBoost: false, frameRate: 60)

        // From VideoEncoder.swift: let effectiveBitrate = gamingBoost ? bitrateMbps : max(bitrateMbps, 60)
        // Should use max(20, 60) = 60 Mbps for normal mode
        let initialBitrate = 60 * 1_000_000

        guard let session1 = encoder.compressionSession else {
            XCTFail("Compression session was not created")
            return
        }

        if let avgBitRate = getProperty(session1, key: kVTCompressionPropertyKey_AverageBitRate) as? NSNumber {
            XCTAssertEqual(avgBitRate.intValue, initialBitrate)
        } else {
            XCTFail("AverageBitRate property missing")
        }

        // Quality "low" maps to 0.65
        if let quality = getProperty(session1, key: kVTCompressionPropertyKey_Quality) as? NSNumber {
            XCTAssertEqual(quality.floatValue, 0.65, accuracy: 0.01)
        } else {
            XCTFail("Quality property missing")
        }

        // Update settings
        encoder.updateSettings(bitrateMbps: 80, quality: "high", gamingBoost: false)

        guard let session2 = encoder.compressionSession else {
            XCTFail("Updated compression session was not created")
            return
        }

        // Should use max(80, 60) = 80 Mbps for normal mode
        let updatedBitrate = 80 * 1_000_000
        if let avgBitRate2 = getProperty(session2, key: kVTCompressionPropertyKey_AverageBitRate) as? NSNumber {
            XCTAssertEqual(avgBitRate2.intValue, updatedBitrate)
        } else {
            XCTFail("AverageBitRate property missing on updated session")
        }

        // Quality "high" maps to 0.9
        if let quality2 = getProperty(session2, key: kVTCompressionPropertyKey_Quality) as? NSNumber {
            XCTAssertEqual(quality2.floatValue, 0.9, accuracy: 0.01)
        } else {
            XCTFail("Quality property missing on updated session")
        }
    }

    func testUpdateSettings_GamingBoost() {
        let encoder = VideoEncoder(width: 1920, height: 1080, bitrateMbps: 20, quality: "medium", gamingBoost: false, frameRate: 60)

        // Enable gaming boost
        encoder.updateSettings(bitrateMbps: 100, quality: "high", gamingBoost: true)

        guard let session = encoder.compressionSession else {
            XCTFail("Compression session was not created")
            return
        }

        // Gaming boost overrides bitrate to 50 Mbps despite passing 100
        // Wait, from code:
        // updateSettings: self.bitrateMbps = gamingBoost ? 50 : bitrateMbps
        // setupCompressionSession: let effectiveBitrate = gamingBoost ? bitrateMbps : max(bitrateMbps, 60)
        // So effectiveBitrate = gamingBoost (true) ? 50 : ... -> 50 Mbps
        let expectedBitrate = 50 * 1_000_000
        if let avgBitRate = getProperty(session, key: kVTCompressionPropertyKey_AverageBitRate) as? NSNumber {
            XCTAssertEqual(avgBitRate.intValue, expectedBitrate)
        } else {
            XCTFail("AverageBitRate property missing")
        }

        // Gaming boost overrides quality to 0.3
        // updateSettings: self.quality = gamingBoost ? "ultralow" : quality
        // setupCompressionSession: if gamingBoost { qualityValue = 0.3 }
        if let quality = getProperty(session, key: kVTCompressionPropertyKey_Quality) as? NSNumber {
            XCTAssertEqual(quality.floatValue, 0.3, accuracy: 0.01)
        } else {
            XCTFail("Quality property missing")
        }
    }
}
