// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Pure logic engine for bandwidth probing.
///
/// Fed statistics snapshots at each probe step, determines
/// saturation point and generates recommendations.
/// Does NOT perform any network I/O.
public struct ProbeEngine: Sendable {
    /// State of the probe.
    public enum State: String, Sendable, Equatable {
        /// Not started.
        case idle
        /// Actively probing at a step.
        case probing
        /// Probe complete.
        case complete
        /// Probe failed.
        case failed
    }

    /// Action the caller should take.
    public enum Action: Sendable, Equatable {
        /// Start sending at the given bitrate.
        case sendAtBitrate(bitsPerSecond: UInt64, stepIndex: Int)
        /// Probe is complete, here's the result.
        case complete(ProbeResult)
        /// Probe failed.
        case failed(reason: String)
    }

    /// The probe configuration.
    public let configuration: ProbeConfiguration

    private var _state: State = .idle
    private var _currentStepIndex: Int = 0
    private var _stepMeasurements: [StepMeasurement] = []
    private var _probeStartTime: UInt64 = 0
    private var _baselineRTT: UInt64 = 0
    private var _saturationStepIndex: Int?

    /// Create a probe engine.
    ///
    /// - Parameter configuration: Probe configuration.
    public init(configuration: ProbeConfiguration = .standard) {
        self.configuration = configuration
    }

    /// Current state.
    public var state: State { _state }

    /// Current step index.
    public var currentStepIndex: Int { _currentStepIndex }

    /// Per-step measurements collected so far.
    public var stepMeasurements: [StepMeasurement] { _stepMeasurements }

    /// Start the probe. Returns the first action.
    ///
    /// - Returns: Action to send at the first step's bitrate, or failed.
    public mutating func start() -> Action {
        guard _state == .idle else {
            return .failed(reason: "Probe already in progress")
        }
        guard !configuration.steps.isEmpty else {
            return .failed(reason: "No steps configured")
        }

        _state = .probing
        _currentStepIndex = 0
        _stepMeasurements = []
        _saturationStepIndex = nil
        _baselineRTT = 0

        return .sendAtBitrate(
            bitsPerSecond: configuration.steps[0],
            stepIndex: 0
        )
    }

    /// Feed statistics for the current step.
    ///
    /// Call this after each step's duration has elapsed.
    ///
    /// - Parameters:
    ///   - statistics: Statistics snapshot for this step.
    ///   - stepStartTime: When this step started (microseconds).
    ///   - currentTime: Current time (microseconds).
    /// - Returns: Next action (advance, complete, or failed).
    public mutating func feedStepResult(
        statistics: SRTStatistics,
        stepStartTime: UInt64,
        currentTime: UInt64
    ) -> Action {
        guard _state == .probing else {
            return .failed(reason: "Probe not started")
        }

        if _probeStartTime == 0 {
            _probeStartTime = stepStartTime
        }

        if _baselineRTT == 0 {
            _baselineRTT = statistics.rttMicroseconds
        }

        let saturated = detectSaturation(statistics: statistics)

        let measurement = StepMeasurement(
            targetBitrate: configuration.steps[_currentStepIndex],
            achievedSendRate: statistics.sendRateBitsPerSecond,
            rttMicroseconds: statistics.rttMicroseconds,
            rttVarianceMicroseconds: statistics.rttVarianceMicroseconds,
            lossRate: statistics.lossRate,
            bufferUtilization: statistics.sendBufferUtilization,
            saturated: saturated,
            stepIndex: _currentStepIndex
        )
        _stepMeasurements.append(measurement)

        // Check if saturated and past minimum steps
        if saturated && _currentStepIndex >= configuration.minimumSteps {
            _saturationStepIndex = _currentStepIndex
            return completeProbe(at: currentTime)
        }

        // Advance to next step
        _currentStepIndex += 1
        if _currentStepIndex >= configuration.steps.count {
            return completeProbe(at: currentTime)
        }

        return .sendAtBitrate(
            bitsPerSecond: configuration.steps[_currentStepIndex],
            stepIndex: _currentStepIndex
        )
    }

    /// Generate a ProbeResult from completed probe data.
    ///
    /// - Parameter targetQuality: Quality target for recommendations.
    /// - Returns: Probe result, or nil if probe not complete.
    public func generateResult(
        targetQuality: TargetQuality = .balanced
    ) -> ProbeResult? {
        guard _state == .complete, !_stepMeasurements.isEmpty else {
            return nil
        }
        return buildResult(targetQuality: targetQuality)
    }

    /// Generate an auto-configured SRTConfiguration from probe results.
    ///
    /// - Parameters:
    ///   - result: Probe result.
    ///   - host: Target host.
    ///   - port: Target port.
    ///   - targetQuality: Quality target.
    /// - Returns: Configured SRTConfiguration.
    public static func autoConfiguration(
        from result: ProbeResult,
        host: String,
        port: Int,
        targetQuality: TargetQuality = .balanced
    ) -> SRTConfiguration {
        let bitrate = UInt64(
            Double(result.achievedBandwidth) * targetQuality.bandwidthFactor)
        let latency = computeLatency(
            averageRTT: result.averageRTTMicroseconds,
            multiplier: targetQuality.latencyMultiplier
        )

        var options = SRTSocketOptions()
        options.maxBandwidth = bitrate
        options.latency = latency

        return SRTConfiguration(
            host: host,
            port: port,
            mode: .caller,
            options: options
        )
    }

    // MARK: - Private

    private func detectSaturation(statistics: SRTStatistics) -> Bool {
        // Loss exceeds threshold
        if statistics.lossRate > configuration.lossThreshold {
            return true
        }
        // RTT increased beyond threshold relative to baseline
        if _baselineRTT > 0 {
            let rttRatio =
                Double(statistics.rttMicroseconds) / Double(_baselineRTT)
            if rttRatio > configuration.rttIncreaseThreshold {
                return true
            }
        }
        return false
    }

    private mutating func completeProbe(at currentTime: UInt64) -> Action {
        _state = .complete
        let result = buildResult(targetQuality: .balanced)
        return .complete(result)
    }

    private func buildResult(targetQuality: TargetQuality) -> ProbeResult {
        let count = _stepMeasurements.count
        let achievedBandwidth = computeAchievedBandwidth()
        let avgRTT = computeAverageRTT()
        let maxVariance = computeMaxVariance()
        let avgLoss = computeAverageLoss()
        let stability = computeStabilityScore(
            avgRTT: avgRTT, maxVariance: maxVariance)
        let recommended = UInt64(
            Double(achievedBandwidth) * targetQuality.bandwidthFactor)
        let latency = Self.computeLatency(
            averageRTT: avgRTT, multiplier: targetQuality.latencyMultiplier)
        let totalDuration =
            count > 0
            ? UInt64(count) * configuration.stepDurationMicroseconds : 0

        return ProbeResult(
            achievedBandwidth: achievedBandwidth,
            averageRTTMicroseconds: avgRTT,
            rttVarianceMicroseconds: maxVariance,
            packetLossRate: avgLoss,
            stabilityScore: stability,
            recommendedBitrate: recommended,
            recommendedLatency: latency,
            stepsCompleted: count,
            totalDurationMicroseconds: totalDuration,
            saturationStepIndex: _saturationStepIndex
        )
    }

    private func computeAchievedBandwidth() -> UInt64 {
        // Last non-saturated step's target bitrate
        for m in _stepMeasurements.reversed() where !m.saturated {
            return m.targetBitrate
        }
        // All saturated — use first step
        return _stepMeasurements.first?.targetBitrate ?? 0
    }

    private func computeAverageRTT() -> UInt64 {
        guard !_stepMeasurements.isEmpty else { return 0 }
        let total = _stepMeasurements.reduce(UInt64(0)) {
            $0 + $1.rttMicroseconds
        }
        return total / UInt64(_stepMeasurements.count)
    }

    private func computeMaxVariance() -> UInt64 {
        _stepMeasurements.map(\.rttVarianceMicroseconds).max() ?? 0
    }

    private func computeAverageLoss() -> Double {
        guard !_stepMeasurements.isEmpty else { return 0 }
        let total = _stepMeasurements.reduce(0.0) { $0 + $1.lossRate }
        return total / Double(_stepMeasurements.count)
    }

    private func computeStabilityScore(
        avgRTT: UInt64, maxVariance: UInt64
    ) -> Int {
        let ratio = avgRTT > 0 ? Double(maxVariance) / Double(avgRTT) : 0
        return max(0, min(100, Int(100.0 * (1.0 - ratio))))
    }

    private static func computeLatency(
        averageRTT: UInt64, multiplier: Double
    ) -> UInt64 {
        let base = UInt64(Double(averageRTT) * multiplier)
        return max(20_000, min(base, 2_000_000))
    }
}
