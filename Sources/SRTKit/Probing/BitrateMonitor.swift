// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Monitors network conditions and produces bitrate recommendations.
///
/// Pure logic component — fed statistics snapshots, outputs
/// BitrateRecommendation when conditions warrant a change.
/// Implements hysteresis to avoid oscillation.
public struct BitrateMonitor: Sendable {
    /// The monitor configuration.
    public let configuration: BitrateMonitorConfiguration

    private var _consecutiveSignals: Int = 0
    private var _pendingDirection: BitrateRecommendation.Direction?
    private var _pendingReason: BitrateRecommendation.Reason = .stable
    private var _recommendationCount: Int = 0
    private var _baselineRTT: UInt64?

    /// Create a bitrate monitor.
    ///
    /// - Parameter configuration: Monitor configuration.
    public init(
        configuration: BitrateMonitorConfiguration = .init()
    ) {
        self.configuration = configuration
    }

    /// Current consecutive signal count in the pending direction.
    public var consecutiveSignals: Int { _consecutiveSignals }

    /// Pending direction (before hysteresis threshold met).
    public var pendingDirection: BitrateRecommendation.Direction? {
        _pendingDirection
    }

    /// Number of recommendations emitted.
    public var recommendationCount: Int { _recommendationCount }

    /// Baseline RTT (from first evaluation, for comparison).
    public var baselineRTT: UInt64? { _baselineRTT }

    /// Feed a statistics snapshot.
    ///
    /// Call this periodically (e.g., every 2 seconds).
    ///
    /// - Parameters:
    ///   - statistics: Current statistics.
    ///   - currentBitrate: Current send bitrate in bits/second.
    /// - Returns: Recommendation if hysteresis threshold met, nil otherwise.
    public mutating func evaluate(
        statistics: SRTStatistics,
        currentBitrate: UInt64
    ) -> BitrateRecommendation? {
        // Establish baseline RTT on first evaluation
        if _baselineRTT == nil {
            _baselineRTT = statistics.rttMicroseconds
        }

        let signals = computeSignals(statistics: statistics)
        let result = aggregate(signals: signals)
        let direction = result.direction

        // Hysteresis tracking
        if direction == _pendingDirection {
            _consecutiveSignals += 1
        } else {
            _pendingDirection = direction
            _pendingReason = result.reason
            _consecutiveSignals = 1
        }

        // Check if hysteresis threshold met
        guard _consecutiveSignals >= configuration.hysteresisCount else {
            return nil
        }

        // Emit recommendation
        let recommended = computeBitrate(
            current: currentBitrate, direction: direction)

        let recommendation = BitrateRecommendation(
            recommendedBitrate: recommended,
            currentBitrate: currentBitrate,
            direction: direction,
            reason: _pendingReason,
            confidence: result.confidence
        )

        _recommendationCount += 1
        _consecutiveSignals = 0
        _pendingDirection = nil

        return recommendation
    }

    /// Reset the monitor state (e.g., after a reconnection).
    public mutating func reset() {
        _consecutiveSignals = 0
        _pendingDirection = nil
        _pendingReason = .stable
        _baselineRTT = nil
    }

    // MARK: - Private

    private enum Signal {
        case decrease
        case increase
        case neutral
    }

    private struct SignalSet {
        var loss: Signal
        var rtt: Signal
        var buffer: Signal
        var headroom: Signal

        var all: [Signal] { [loss, rtt, buffer, headroom] }
    }

    private struct AggregateResult {
        var direction: BitrateRecommendation.Direction
        var reason: BitrateRecommendation.Reason
        var confidence: Double
    }

    private func computeSignals(
        statistics: SRTStatistics
    ) -> SignalSet {
        // Loss signal
        let lossSignal: Signal =
            statistics.lossRate > configuration.lossThreshold
            ? .decrease : .neutral

        // RTT signal
        let rttSignal: Signal
        if let baseline = _baselineRTT, baseline > 0 {
            let rttRatio =
                Double(statistics.rttMicroseconds) / Double(baseline)
            rttSignal =
                rttRatio > configuration.rttIncreaseRatio
                ? .decrease : .neutral
        } else {
            rttSignal = .neutral
        }

        // Buffer signal
        let bufferSignal: Signal =
            statistics.sendBufferUtilization > configuration.bufferThreshold
            ? .decrease : .neutral

        // Headroom signal
        let headroomSignal: Signal
        if statistics.maxBandwidthBitsPerSecond > 0 {
            let utilization =
                Double(statistics.sendRateBitsPerSecond)
                / Double(statistics.maxBandwidthBitsPerSecond)
            headroomSignal =
                utilization < configuration.headroomRatio
                ? .increase : .neutral
        } else {
            headroomSignal = .neutral
        }

        return SignalSet(
            loss: lossSignal, rtt: rttSignal,
            buffer: bufferSignal, headroom: headroomSignal)
    }

    private func aggregate(signals: SignalSet) -> AggregateResult {
        let allSignals = signals.all

        let hasDecrease = allSignals.contains { isDecrease($0) }
        let hasIncrease = allSignals.contains { isIncrease($0) }

        let direction: BitrateRecommendation.Direction
        let reason: BitrateRecommendation.Reason

        if hasDecrease {
            direction = .decrease
            reason = primaryDecreaseReason(signals: signals)
        } else if hasIncrease {
            direction = .increase
            reason = .bandwidthAvailable
        } else {
            direction = .maintain
            reason = .stable
        }

        // Confidence = agreeing signals / total
        let agreeCount: Int
        switch direction {
        case .decrease:
            agreeCount = allSignals.filter { isDecrease($0) }.count
        case .increase:
            agreeCount = allSignals.filter { isIncrease($0) }.count
        case .maintain:
            agreeCount = allSignals.filter { isNeutral($0) }.count
        }
        let confidence = Double(agreeCount) / Double(allSignals.count)

        return AggregateResult(
            direction: direction, reason: reason, confidence: confidence)
    }

    private func primaryDecreaseReason(
        signals: SignalSet
    ) -> BitrateRecommendation.Reason {
        if isDecrease(signals.loss) { return .packetLoss }
        if isDecrease(signals.buffer) { return .congestion }
        if isDecrease(signals.rtt) { return .rttIncrease }
        return .packetLoss
    }

    private func computeBitrate(
        current: UInt64,
        direction: BitrateRecommendation.Direction
    ) -> UInt64 {
        switch direction {
        case .decrease:
            let reduced = UInt64(
                Double(current) * configuration.stepDownFactor)
            return max(reduced, configuration.minimumBitrate)
        case .increase:
            let increased = UInt64(
                Double(current) * configuration.stepUpFactor)
            if configuration.maximumBitrate > 0 {
                return min(increased, configuration.maximumBitrate)
            }
            return increased
        case .maintain:
            return current
        }
    }

    private func isDecrease(_ signal: Signal) -> Bool {
        if case .decrease = signal { return true }
        return false
    }

    private func isIncrease(_ signal: Signal) -> Bool {
        if case .increase = signal { return true }
        return false
    }

    private func isNeutral(_ signal: Signal) -> Bool {
        if case .neutral = signal { return true }
        return false
    }
}
