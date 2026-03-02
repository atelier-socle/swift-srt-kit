// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Records SRT stream data with rotation and flush support.
///
/// Pure logic recorder — accumulates data in an internal buffer
/// and signals when flushes and rotations should occur.
/// The actual file I/O is handled by the caller.
public struct StreamRecorder: Sendable {
    /// Action the caller should take.
    public enum Action: Sendable, Equatable {
        /// Flush buffered data to storage.
        case flush(data: [UInt8])
        /// Rotate: flush current data and start a new file.
        case rotate(data: [UInt8], reason: RotationReason)
        /// No action needed.
        case none
    }

    /// Reason for file rotation.
    public enum RotationReason: String, Sendable, Equatable {
        /// Maximum file size reached.
        case maxSize
        /// Maximum duration reached.
        case maxDuration
        /// Manual rotation requested.
        case manual
    }

    /// The recording configuration.
    public let configuration: RecordingConfiguration

    /// Whether recording is active.
    public private(set) var isRecording: Bool = false

    private var buffer: [UInt8] = []
    private var startTime: UInt64 = 0
    private var lastFlushTime: UInt64 = 0
    private var stats = RecordingStatistics()

    /// Create a stream recorder.
    ///
    /// - Parameter configuration: Recording configuration.
    public init(configuration: RecordingConfiguration = .default) {
        self.configuration = configuration
    }

    /// Start recording.
    ///
    /// - Parameter time: Start time in microseconds.
    public mutating func start(at time: UInt64) {
        isRecording = true
        startTime = time
        lastFlushTime = time
        buffer = []
        stats = RecordingStatistics()
    }

    /// Stop recording and flush remaining data.
    ///
    /// - Returns: Any remaining buffered data.
    public mutating func stop() -> [UInt8] {
        isRecording = false
        let remaining = buffer
        buffer = []
        return remaining
    }

    /// Write data to the recorder.
    ///
    /// - Parameters:
    ///   - payload: Data bytes to record.
    ///   - time: Current time in microseconds.
    /// - Returns: Action if flush/rotation needed.
    public mutating func write(_ payload: [UInt8], at time: UInt64) -> Action {
        guard isRecording else { return .none }

        buffer.append(contentsOf: payload)
        let payloadSize = UInt64(payload.count)
        stats.totalBytesWritten += payloadSize
        stats.currentFileBytesWritten += payloadSize
        stats.durationMicroseconds = time - startTime

        // Check size-based rotation
        if let maxSize = configuration.maxFileSizeBytes,
            stats.currentFileBytesWritten >= maxSize
        {
            return performRotation(reason: .maxSize)
        }

        // Check duration-based rotation
        if let maxDuration = configuration.maxDurationMicroseconds,
            stats.durationMicroseconds >= maxDuration
        {
            return performRotation(reason: .maxDuration)
        }

        return .none
    }

    /// Check if a timed flush is due.
    ///
    /// - Parameter time: Current time in microseconds.
    /// - Returns: `.flush` if interval elapsed, `.none` otherwise.
    public mutating func checkFlush(at time: UInt64) -> Action {
        guard isRecording else { return .none }
        guard !buffer.isEmpty else { return .none }

        if time - lastFlushTime >= configuration.flushIntervalMicroseconds {
            return performFlush(at: time)
        }

        return .none
    }

    /// Request manual rotation.
    ///
    /// - Returns: `.rotate` with current buffer.
    public mutating func requestRotation() -> Action {
        guard isRecording else { return .none }
        return performRotation(reason: .manual)
    }

    /// Current recording statistics.
    public var statistics: RecordingStatistics {
        stats
    }

    // MARK: - Private

    private mutating func performFlush(at time: UInt64) -> Action {
        let data = buffer
        buffer = []
        lastFlushTime = time
        stats.flushCount += 1
        return .flush(data: data)
    }

    private mutating func performRotation(reason: RotationReason) -> Action {
        let data = buffer
        buffer = []
        stats.fileRotations += 1
        stats.currentFileBytesWritten = 0
        stats.flushCount += 1
        return .rotate(data: data, reason: reason)
    }
}
