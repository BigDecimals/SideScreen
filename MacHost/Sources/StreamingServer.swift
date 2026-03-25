import Foundation
import Network

class AdaptiveBitrateController {
    private var currentBitrateMbps: Int = 30
    private var state: State = .steady
    private var baselineRttMs: Double = 0
    private var consecutiveIncreases = 0

    enum State { case probingUp, steady, backingOff }

    var onBitrateChanged: ((Int) -> Void)?

    init(initialBitrate: Int) {
        self.currentBitrateMbps = initialBitrate
    }

    func onNetworkReport(rttMs: Double, bandwidthMbps: Double, wifiBand: UInt8) {
        let limits = bitrateLimits(for: wifiBand)

        switch state {
        case .steady:
            if rttMs < 12.0 && wifiBand == 0x02 {
                state = .probingUp
                baselineRttMs = rttMs
            } else if rttMs > 25.0 {
                backOff(limits: limits)
            }

        case .probingUp:
            if rttMs > baselineRttMs + 5.0 {
                // RTT degraded — this bitrate is too high
                currentBitrateMbps = Int(Double(currentBitrateMbps) * 0.9)
                consecutiveIncreases = 0
                state = .steady
            } else {
                currentBitrateMbps = min(Int(Double(currentBitrateMbps) * 1.1), limits.max)
                consecutiveIncreases += 1
                if consecutiveIncreases >= 3 { state = .steady }
            }

        case .backingOff:
            break // timer-driven, not RTT-driven
        }

        onBitrateChanged?(currentBitrateMbps)
    }

    private func backOff(limits: (min: Int, max: Int)) {
        currentBitrateMbps = max(Int(Double(currentBitrateMbps) * 0.75), limits.min)
        state = .backingOff
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.state = .steady
        }
        onBitrateChanged?(currentBitrateMbps)
    }

    private func bitrateLimits(for wifiBand: UInt8) -> (min: Int, max: Int) {
        switch wifiBand {
        case 0x01: // 2.4GHz
            return (8, 25)
        case 0x02: // 5GHz
            return (15, 60)
        case 0x03: // 6GHz
            return (20, 80)
        default:
            return (15, 30) // Unknown
        }
    }
}

class StreamingServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connection: NWConnection?
    var onClientConnected: (() -> Void)?
    var onClientDisconnected: (() -> Void)?
    // Touch callback: (x1, y1, action, pointerCount, x2, y2)
    var onTouchEvent: ((Float, Float, Int, Int, Float, Float) -> Void)?
    var onStats: ((Double, Double) -> Void)?
    var onNetworkReport: ((Double, Double, UInt8) -> Void)?

    private let frameQueue = DispatchQueue(label: "frameQueue", qos: .userInteractive)
    private let receiveQueue = DispatchQueue(label: "receiveQueue", qos: .userInteractive)
    private let networkQueue = DispatchQueue(label: "networkQueue", qos: .userInteractive)
    private var bytesSent: UInt64 = 0
    private var frameCount: UInt64 = 0
    private var droppedFrames: UInt64 = 0
    private var lastStatsTime = DispatchTime.now()
    private var displayWidth = 1920
    private var displayHeight = 1080
    private var rotation = 0
    private var isReceiving = false
    private var isStopped = false
    private var connectionReady = false

    var connectionMode: String = "usb"
    var frameRate: Int = 60

    init(port: UInt16) {
        self.port = port
    }

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    func start() {
        isStopped = false
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            // Optimize TCP for low-latency streaming
            if let tcpOptions = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                tcpOptions.noDelay = true  // Disable Nagle's algorithm
                tcpOptions.enableFastOpen = true
            }

            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))

            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.handleConnection(newConnection)
            }

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    debugLog("TCP Server listening on port \(self.port)")
                case .failed(let error):
                    debugLog("Server failed: \(error)")
                default:
                    break
                }
            }

            if connectionMode == "wifi" {
                var txtRecord = NWTXTRecord()
                txtRecord.setEntry(forKey: "v", value: "1")
                txtRecord.setEntry(forKey: "model", value: getMacModel())
                txtRecord.setEntry(forKey: "display", value: "\(displayWidth)x\(displayHeight)")
                txtRecord.setEntry(forKey: "fps", value: "\(frameRate)")

                listener?.service = NWListener.Service(
                    name: nil,
                    type: "_sidescreen._tcp.",
                    domain: nil,
                    txtRecord: txtRecord
                )
            }

            listener?.start(queue: networkQueue)
        } catch {
            debugLog("Failed to start server: \(error)")
        }
    }

    private func handleConnection(_ newConnection: NWConnection) {
        debugLog("New connection incoming...")

        // Clean up old connection properly
        if let oldConnection = connection {
            isReceiving = false
            oldConnection.cancel()
        }

        connectionReady = false
        connection = newConnection
        droppedFrames = 0

        connection?.stateUpdateHandler = { [weak self] state in
            debugLog("Connection state: \(state)")
            switch state {
            case .ready:
                debugLog("Client connected - sending display config first")
                self?.sendDisplaySize()
                self?.connectionReady = true
                debugLog("Connection ready for frames")
                self?.onClientConnected?()
                self?.startReceivingTouch()
            case .failed(let error):
                debugLog("Connection failed: \(error)")
                self?.onClientDisconnected?()
            case .cancelled:
                debugLog("Connection cancelled")
                self?.onClientDisconnected?()
            default:
                break
            }
        }

        connection?.start(queue: networkQueue)
    }

    func setDisplaySize(width: Int, height: Int, rotation: Int = 0) {
        displayWidth = width
        displayHeight = height
        self.rotation = rotation
    }

    /// Update rotation and send to connected client
    func updateRotation(_ rotation: Int) {
        self.rotation = rotation
        sendDisplaySize() // Re-send display config with new rotation
    }

    func sendDisplaySize() {
        guard let connection = connection else { return }

        var data = Data()
        data.append(1) // Type: Display size + rotation
        data.append(contentsOf: withUnsafeBytes(of: Int32(displayWidth).bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(displayHeight).bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(rotation).bigEndian) { Data($0) })

        connection.send(content: data, completion: .contentProcessed { _ in })
        debugLog("Sent display config: \(displayWidth)x\(displayHeight) @ \(rotation)°")
    }

    func sendBitrateUpdate(_ newBitrateMbps: Int) {
        guard let connection = connection else { return }

        var data = Data()
        data.append(7) // Type: Bitrate update
        data.append(UInt8(min(max(newBitrateMbps, 0), 255)))

        connection.send(content: data, completion: .contentProcessed { _ in })
        debugLog("Sent bitrate update: \(newBitrateMbps)Mbps")
    }

    private func startReceivingTouch() {
        guard !isReceiving else {
            debugLog("Already receiving touch events")
            return
        }
        isReceiving = true
        debugLog("Starting touch receive loop...")

        // Use loop-based pattern instead of recursion to prevent stack overflow
        receiveQueue.async { [weak self] in
            self?.touchReceiveLoop()
        }
    }

    private func touchReceiveLoop() {
        guard let connection = connection, isReceiving, !isStopped else {
            isReceiving = false
            return
        }

        // New format: 1 type + 1 pointerCount + N*(4x+4y) + 4 action
        // 1 finger: 14 bytes, 2 fingers: 22 bytes
        connection.receive(minimumIncompleteLength: 2, maximumLength: 22) { [weak self] data, _, isComplete, error in
            guard let self = self, self.isReceiving, !self.isStopped else { return }

            if error != nil || isComplete {
                self.isReceiving = false
                return
            }

            if let data = data, data.count >= 1 {
                let msgType = data[0]

                if msgType == 2 && data.count >= 2 {
                    // Touch event
                    let pointerCount = Int(data[1])
                    let expectedSize = 2 + pointerCount * 8 + 4

                    if data.count >= expectedSize {
                        let x1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 2, as: Float.self) }
                        let y1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 6, as: Float.self) }

                        var x2: Float = 0
                        var y2: Float = 0
                        if pointerCount >= 2 {
                            x2 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 10, as: Float.self) }
                            y2 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 14, as: Float.self) }
                        }

                        let actionOffset = 2 + pointerCount * 8
                        let action = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: actionOffset, as: Int32.self) }

                        DispatchQueue.main.async {
                            self.onTouchEvent?(x1, y1, Int(action), pointerCount, x2, y2)
                        }
                    }
                } else if msgType == 4 && data.count >= 9 {
                    // Ping from client — echo back as pong (type=5) with client's timestamp
                    let clientTimestamp = data.subdata(in: 1..<9)
                    var pong = Data(capacity: 9)
                    pong.append(5) // Type: Pong
                    pong.append(clientTimestamp)
                    connection.send(content: pong, completion: .contentProcessed { _ in })
                } else if msgType == 6 && data.count >= 3 {
                    // Client Info (mode, device model)
                    let modeLength = Int(data[1])
                    if data.count >= 3 + modeLength {
                        let modeData = data.subdata(in: 2..<(2 + modeLength))
                        let modelLengthIdx = 2 + modeLength
                        if data.count >= modelLengthIdx + 1 {
                            let modelLength = Int(data[modelLengthIdx])
                            if data.count >= modelLengthIdx + 1 + modelLength {
                                let modelData = data.subdata(in: (modelLengthIdx + 1)..<(modelLengthIdx + 1 + modelLength))
                                let modeString = String(data: modeData, encoding: .utf8) ?? "unknown"
                                let modelString = String(data: modelData, encoding: .utf8) ?? "unknown"
                                debugLog("Client Info: Mode=\(modeString), Model=\(modelString)")
                            }
                        }
                    }
                } else if msgType == 8 && data.count >= 10 {
                    // Network Quality Report
                    let rttMs = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 1, as: Float.self) }
                    let bandwidthMbps = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 5, as: Float.self) }
                    let wifiBand = data[9]

                    // Note: Endianness is big endian from kotlin
                    let rttMsDouble = Double(Float(bitPattern: UInt32(bigEndian: rttMs.bitPattern)))
                    let bandwidthMbpsDouble = Double(Float(bitPattern: UInt32(bigEndian: bandwidthMbps.bitPattern)))

                    DispatchQueue.main.async {
                        self.onNetworkReport?(rttMsDouble, bandwidthMbpsDouble, wifiBand)
                    }
                }
            }

            self.receiveQueue.async {
                self.touchReceiveLoop()
            }
        }
    }

    func sendFrame(_ data: Data, timestamp: UInt64, isKeyframe: Bool = false) {
        guard let connection = connection, !isStopped, connectionReady else { return }

        // With all-intra encoding, every frame is independently decodable.
        // No frame-age dropping or backpressure — send everything immediately.
        // The encode queue depth limit (2 pending) in ScreenCapture handles flow control.
        frameQueue.async { [weak self] in
            guard let self = self else { return }

            var packet = Data(capacity: data.count + 5)
            packet.append(0) // Type: Video frame
            var frameSize = Int32(data.count).bigEndian
            withUnsafeBytes(of: &frameSize) { packet.append(contentsOf: $0) }
            packet.append(data)

            connection.send(content: packet, completion: .contentProcessed { error in
                if error != nil {
                    self.droppedFrames += 1
                }
            })

            // Track frame age at send time for pipeline profiling
            let sendAge = DispatchTime.now().uptimeNanoseconds - timestamp
            self.updateStats(bytes: data.count, frameAgeNs: sendAge)
        }
    }

    // Pipeline profiling: track frame age at send time
    private var totalFrameAgeNs: UInt64 = 0
    private var profiledFrameCount: UInt64 = 0

    private func updateStats(bytes: Int, frameAgeNs: UInt64 = 0) {
        bytesSent += UInt64(bytes)
        frameCount += 1
        if frameAgeNs > 0 {
            totalFrameAgeNs += frameAgeNs
            profiledFrameCount += 1
        }

        let now = DispatchTime.now()
        let elapsed = Double(now.uptimeNanoseconds - lastStatsTime.uptimeNanoseconds) / 1_000_000_000

        if elapsed >= 1.0 {
            let mbps = Double(bytesSent * 8) / elapsed / 1_000_000
            let fps = Double(frameCount) / elapsed
            onStats?(fps, mbps)

            // Log pipeline latency profile
            if profiledFrameCount > 0 {
                let avgAgeMs = Double(totalFrameAgeNs) / Double(profiledFrameCount) / 1_000_000.0
                debugLog("Pipeline: \(String(format: "%.1f", fps))fps, \(String(format: "%.1f", mbps))Mbps, avg frame age: \(String(format: "%.1f", avgAgeMs))ms, dropped: \(droppedFrames)")
            }

            bytesSent = 0
            frameCount = 0
            droppedFrames = 0
            totalFrameAgeNs = 0
            profiledFrameCount = 0
            lastStatsTime = now
        }
    }

    func stop() {
        isStopped = true
        isReceiving = false

        // Wait for pending operations before cancelling
        frameQueue.sync {}
        receiveQueue.sync {}

        connection?.cancel()
        listener?.cancel()
        connection = nil
        listener = nil
    }
}
