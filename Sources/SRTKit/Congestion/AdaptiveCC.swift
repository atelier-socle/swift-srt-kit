// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Adaptive congestion controller that blends live and file behaviors.
///
/// Detects the content pattern (real-time vs bulk transfer) and
/// adjusts its strategy:
/// - Real-time detected: behaves like LiveCC (pacing-based)
/// - Bulk transfer detected: behaves like FileCC (window-based)
/// - Mixed: hybrid approach with weighted parameters
///
/// Detection is based on packet arrival patterns and send rate stability.
public struct AdaptiveCC: CongestionControllerPlugin, Sendable {
    /// Detection mode.
    public enum DetectedMode: String, Sendable, Equatable {
        /// Real-time content (consistent pacing, low jitter).
        case realTime
        /// Bulk transfer (bursty, filling window).
        case bulkTransfer
        /// Mixed or unknown.
        case mixed
    }

    /// Configuration for the adaptive CC.
    public struct Configuration: Sendable, Equatable {
        /// Number of samples before initial detection (default: 10).
        public let detectionSamples: Int

        /// Send rate variance threshold for real-time detection (default: 0.2 = 20%).
        public let realtimeVarianceThreshold: Double

        /// Window growth factor in bulk mode (default: 1.5).
        public let windowGrowthFactor: Double

        /// Minimum congestion window (default: 16 packets).
        public let minimumWindow: Int

        /// Maximum congestion window (default: 8192 packets).
        public let maximumWindow: Int

        /// Pacing floor in microseconds (default: 1 = 1 microsecond minimum).
        public let pacingFloorMicroseconds: UInt64

        /// Create an adaptive CC configuration.
        ///
        /// - Parameters:
        ///   - detectionSamples: Samples before detection.
        ///   - realtimeVarianceThreshold: CV threshold for real-time.
        ///   - windowGrowthFactor: Window growth factor in bulk mode.
        ///   - minimumWindow: Minimum congestion window.
        ///   - maximumWindow: Maximum congestion window.
        ///   - pacingFloorMicroseconds: Minimum pacing interval.
        public init(
            detectionSamples: Int = 10,
            realtimeVarianceThreshold: Double = 0.2,
            windowGrowthFactor: Double = 1.5,
            minimumWindow: Int = 16,
            maximumWindow: Int = 8192,
            pacingFloorMicroseconds: UInt64 = 1
        ) {
            self.detectionSamples = detectionSamples
            self.realtimeVarianceThreshold = realtimeVarianceThreshold
            self.windowGrowthFactor = windowGrowthFactor
            self.minimumWindow = minimumWindow
            self.maximumWindow = maximumWindow
            self.pacingFloorMicroseconds = pacingFloorMicroseconds
        }

        /// Default configuration.
        public static let `default` = Configuration()
    }

    /// The adaptive CC configuration.
    public let configuration: Configuration

    private var _congestionWindow: Int
    private var _sendingPeriodMicroseconds: UInt64 = 0
    private var _detectedMode: DetectedMode = .mixed
    private var _modeSwitchCount: Int = 0
    private var _samplesCollected: Int = 0
    private var sendRateSamples: [Double] = []

    /// Create an adaptive congestion controller.
    ///
    /// - Parameter configuration: Adaptive CC configuration.
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self._congestionWindow = configuration.minimumWindow
    }

    // MARK: - CongestionControllerPlugin

    /// Plugin name.
    public var name: String { "adaptive" }

    /// Process a congestion event and return a decision.
    ///
    /// - Parameters:
    ///   - event: The congestion event.
    ///   - snapshot: Current network state.
    /// - Returns: Decision for the connection layer.
    public mutating func processEvent(
        _ event: CongestionEvent,
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        switch event {
        case .packetSent(let size, _, _):
            collectSample(sendRate: Double(snapshot.sendRateBps))
            _ = size
            return .noChange

        case .ackReceived:
            return handleACK(snapshot: snapshot)

        case .nakReceived(let lossSequences):
            return handleNAK(
                lossCount: lossSequences.count, snapshot: snapshot)

        case .timeout:
            return handleTimeout(snapshot: snapshot)

        case .tick:
            return .noChange

        case .connectionEstablished:
            _congestionWindow = configuration.minimumWindow
            _sendingPeriodMicroseconds = 0
            return CongestionDecision(
                congestionWindow: _congestionWindow)

        case .connectionClosing:
            return .noChange
        }
    }

    /// Current congestion window size in packets.
    public var congestionWindow: Int { _congestionWindow }

    /// Current sending period in microseconds.
    public var sendingPeriodMicroseconds: UInt64 {
        _sendingPeriodMicroseconds
    }

    /// Reset the controller state.
    public mutating func reset() {
        _congestionWindow = configuration.minimumWindow
        _sendingPeriodMicroseconds = 0
        _detectedMode = .mixed
        _modeSwitchCount = 0
        _samplesCollected = 0
        sendRateSamples = []
    }

    // MARK: - Adaptive-specific

    /// Current detected content mode.
    public var detectedMode: DetectedMode { _detectedMode }

    /// Number of mode switches so far.
    public var modeSwitchCount: Int { _modeSwitchCount }

    /// Samples collected for detection.
    public var samplesCollected: Int { _samplesCollected }

    // MARK: - Private

    private mutating func collectSample(sendRate: Double) {
        sendRateSamples.append(sendRate)
        _samplesCollected += 1

        if sendRateSamples.count >= configuration.detectionSamples {
            detectMode()
            sendRateSamples = []
        }
    }

    private mutating func detectMode() {
        let cv = coefficientOfVariation(sendRateSamples)
        let oldMode = _detectedMode

        if cv < configuration.realtimeVarianceThreshold {
            _detectedMode = .realTime
        } else if cv > 2.0 * configuration.realtimeVarianceThreshold {
            _detectedMode = .bulkTransfer
        } else {
            _detectedMode = .mixed
        }

        if _detectedMode != oldMode {
            _modeSwitchCount += 1
        }
    }

    private func coefficientOfVariation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        guard mean > 0 else { return 0 }
        let variance =
            values.map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / count
        let stddev = variance.squareRoot()
        return stddev / mean
    }

    private mutating func handleACK(
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        switch _detectedMode {
        case .realTime:
            return handleRealtimeACK(snapshot: snapshot)
        case .bulkTransfer:
            return handleBulkACK(snapshot: snapshot)
        case .mixed:
            return handleMixedACK(snapshot: snapshot)
        }
    }

    private mutating func handleRealtimeACK(
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        // Pacing-based: sendingPeriod = packetSize * 8 / bw
        if snapshot.estimatedBandwidthBps > 0 {
            let period =
                1316 * 8 * 1_000_000
                / snapshot.estimatedBandwidthBps
            _sendingPeriodMicroseconds = max(
                period, configuration.pacingFloorMicroseconds)
        }
        // Window = max(packetsInFlight + 16, minimumWindow)
        _congestionWindow = clampWindow(
            max(snapshot.packetsInFlight + 16, configuration.minimumWindow))

        return CongestionDecision(
            congestionWindow: _congestionWindow,
            sendingPeriodMicroseconds: _sendingPeriodMicroseconds)
    }

    private mutating func handleBulkACK(
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        // Window-based: grow window by factor
        let grown = Int(
            Double(_congestionWindow) * configuration.windowGrowthFactor)
        _congestionWindow = clampWindow(grown)
        _sendingPeriodMicroseconds = 0

        return CongestionDecision(congestionWindow: _congestionWindow)
    }

    private mutating func handleMixedACK(
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        // Blend: moderate window growth + some pacing
        let grown = _congestionWindow + 1
        _congestionWindow = clampWindow(grown)

        if snapshot.estimatedBandwidthBps > 0 {
            let period =
                1316 * 8 * 1_000_000
                / snapshot.estimatedBandwidthBps
            _sendingPeriodMicroseconds = max(
                period / 2, configuration.pacingFloorMicroseconds)
        }

        return CongestionDecision(
            congestionWindow: _congestionWindow,
            sendingPeriodMicroseconds: _sendingPeriodMicroseconds)
    }

    private mutating func handleNAK(
        lossCount: Int, snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        switch _detectedMode {
        case .realTime:
            // Gentle: reduce by 12.5%
            _congestionWindow = clampWindow(
                _congestionWindow * 7 / 8)
        case .bulkTransfer:
            // Aggressive: halve window
            _congestionWindow = clampWindow(_congestionWindow / 2)
        case .mixed:
            // Moderate: reduce by 25%
            _congestionWindow = clampWindow(
                _congestionWindow * 3 / 4)
        }
        return CongestionDecision(congestionWindow: _congestionWindow)
    }

    private mutating func handleTimeout(
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        switch _detectedMode {
        case .realTime:
            _congestionWindow = clampWindow(
                _congestionWindow * 3 / 4)
        case .bulkTransfer:
            _congestionWindow = clampWindow(
                _congestionWindow / 2)
        case .mixed:
            _congestionWindow = clampWindow(
                _congestionWindow * 5 / 8)
        }
        return CongestionDecision(congestionWindow: _congestionWindow)
    }

    private func clampWindow(_ value: Int) -> Int {
        max(
            configuration.minimumWindow,
            min(value, configuration.maximumWindow))
    }
}
