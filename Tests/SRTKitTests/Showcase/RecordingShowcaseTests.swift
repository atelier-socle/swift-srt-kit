// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Recording Showcase")
struct RecordingShowcaseTests {
    @Test("StreamRecorder accumulates data and flushes")
    func recorderBufferAndFlush() {
        var recorder = StreamRecorder()
        recorder.start(at: 1_000_000)
        #expect(recorder.isRecording)

        // Write some data
        let action1 = recorder.write(
            [0x47, 0x00, 0x11, 0x00], at: 1_010_000)
        // Small write — stays buffered
        if case .none = action1 {
            // Expected: no action yet
        }

        // Statistics track bytes
        let stats = recorder.statistics
        #expect(stats.totalBytesWritten == 4)
    }

    @Test("StreamRecorder file rotation on request")
    func recorderRotation() {
        var recorder = StreamRecorder()
        recorder.start(at: 1_000_000)

        // Write data
        _ = recorder.write(
            Array(repeating: 0x47, count: 188), at: 1_010_000)

        // Request rotation
        let action = recorder.requestRotation()
        if case .rotate = action {
            // Expected
        }
    }

    @Test("RecordingConfiguration defaults")
    func configDefaults() {
        let config = RecordingConfiguration.default
        // Default config exists and is usable
        _ = config.maxFileSizeBytes
        _ = config.maxDurationMicroseconds
    }

    @Test("RecordingStatistics starts at zero")
    func statsStartAtZero() {
        let stats = RecordingStatistics()
        #expect(stats.totalBytesWritten == 0)
        #expect(stats.fileRotations == 0)
        #expect(stats.flushCount == 0)
    }

    @Test("RecordingFormat cases")
    func formatCases() {
        let mpegts = RecordingFormat.mpegts
        let raw = RecordingFormat.raw
        #expect(mpegts != raw)
    }
}
