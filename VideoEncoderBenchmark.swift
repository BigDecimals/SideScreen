import Foundation
import VideoToolbox
import CoreMedia

@testable import MacHost

func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let options: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]

    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        options as CFDictionary,
        &pixelBuffer
    )

    if status == kCVReturnSuccess {
        return pixelBuffer
    }
    return nil
}

func runBenchmark() {
    let encoder = VideoEncoder(width: 1920, height: 1080)
    guard let pixelBuffer = createPixelBuffer(width: 1920, height: 1080) else {
        print("Failed to create pixel buffer")
        return
    }

    let iterations = 100_000

    let startTime = CFAbsoluteTimeGetCurrent()

    for i in 0..<iterations {
        let time = CMTime(value: CMTimeValue(i), timescale: 60)
        encoder.encode(pixelBuffer: pixelBuffer, presentationTimeStamp: time)
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let duration = endTime - startTime
    print("Time taken for \(iterations) encodes: \(duration) seconds")
    print("Time per encode: \(duration / Double(iterations) * 1_000_000) microseconds")
}

runBenchmark()
