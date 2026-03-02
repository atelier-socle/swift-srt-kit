// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StreamRecorder Tests")
struct StreamRecorderTests {
    // MARK: - Basic recording

    @Test("Initial isRecording is false")
    func initialNotRecording() {
        let recorder = StreamRecorder()
        #expect(!recorder.isRecording)
    }

    @Test("start sets isRecording to true")
    func startRecording() {
        var recorder = StreamRecorder()
        recorder.start(at: 0)
        #expect(recorder.isRecording)
    }

    @Test("stop sets isRecording to false and returns buffer")
    func stopRecording() {
        var recorder = StreamRecorder()
        recorder.start(at: 0)
        _ = recorder.write([0x01, 0x02], at: 100)
        let remaining = recorder.stop()
        #expect(!recorder.isRecording)
        #expect(remaining == [0x01, 0x02])
    }

    @Test("write returns .none when no flush needed")
    func writeNoFlush() {
        var recorder = StreamRecorder()
        recorder.start(at: 0)
        let action = recorder.write([0x01], at: 100)
        #expect(action == .none)
    }

    @Test("write accumulates bytes in buffer")
    func writeAccumulates() {
        var recorder = StreamRecorder()
        recorder.start(at: 0)
        _ = recorder.write([0x01, 0x02], at: 100)
        _ = recorder.write([0x03], at: 200)
        let remaining = recorder.stop()
        #expect(remaining == [0x01, 0x02, 0x03])
    }

    // MARK: - Flush

    @Test("checkFlush before interval returns .none")
    func checkFlushBeforeInterval() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                flushIntervalMicroseconds: 1_000_000))
        recorder.start(at: 0)
        _ = recorder.write([0x01], at: 100)
        let action = recorder.checkFlush(at: 500_000)
        #expect(action == .none)
    }

    @Test("checkFlush after interval returns .flush")
    func checkFlushAfterInterval() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                flushIntervalMicroseconds: 1_000_000))
        recorder.start(at: 0)
        _ = recorder.write([0x01, 0x02], at: 100)
        let action = recorder.checkFlush(at: 1_500_000)
        if case .flush(let data) = action {
            #expect(data == [0x01, 0x02])
        } else {
            Issue.record("Expected flush")
        }
    }

    @Test("After flush, buffer is empty")
    func afterFlushBufferEmpty() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                flushIntervalMicroseconds: 1_000_000))
        recorder.start(at: 0)
        _ = recorder.write([0x01], at: 100)
        _ = recorder.checkFlush(at: 1_500_000)
        let remaining = recorder.stop()
        #expect(remaining.isEmpty)
    }

    @Test("flushCount increments")
    func flushCountIncrements() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                flushIntervalMicroseconds: 1_000_000))
        recorder.start(at: 0)
        _ = recorder.write([0x01], at: 100)
        _ = recorder.checkFlush(at: 1_500_000)
        #expect(recorder.statistics.flushCount == 1)
    }

    // MARK: - Rotation by size

    @Test("write exceeds maxFileSize triggers rotation")
    func rotationBySize() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                maxFileSizeBytes: 10))
        recorder.start(at: 0)
        _ = recorder.write([UInt8](repeating: 0xAA, count: 5), at: 100)
        let action = recorder.write(
            [UInt8](repeating: 0xBB, count: 6), at: 200)
        if case .rotate(_, let reason) = action {
            #expect(reason == .maxSize)
        } else {
            Issue.record("Expected rotate with maxSize")
        }
    }

    @Test("After rotation, fileRotations increments")
    func rotationIncrementsCount() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                maxFileSizeBytes: 5))
        recorder.start(at: 0)
        _ = recorder.write([UInt8](repeating: 0xAA, count: 6), at: 100)
        #expect(recorder.statistics.fileRotations == 1)
    }

    @Test("currentFileBytesWritten resets after rotation")
    func currentBytesResetAfterRotation() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                maxFileSizeBytes: 5))
        recorder.start(at: 0)
        _ = recorder.write([UInt8](repeating: 0xAA, count: 6), at: 100)
        #expect(recorder.statistics.currentFileBytesWritten == 0)
    }

    // MARK: - Rotation by duration

    @Test("write after maxDuration triggers rotation")
    func rotationByDuration() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                maxDurationMicroseconds: 5_000_000))
        recorder.start(at: 0)
        _ = recorder.write([0x01], at: 1_000_000)
        let action = recorder.write([0x02], at: 6_000_000)
        if case .rotate(_, let reason) = action {
            #expect(reason == .maxDuration)
        } else {
            Issue.record("Expected rotate with maxDuration")
        }
    }

    // MARK: - Manual rotation

    @Test("requestRotation returns .rotate with manual reason")
    func manualRotation() {
        var recorder = StreamRecorder()
        recorder.start(at: 0)
        _ = recorder.write([0x01, 0x02], at: 100)
        let action = recorder.requestRotation()
        if case .rotate(let data, let reason) = action {
            #expect(data == [0x01, 0x02])
            #expect(reason == .manual)
        } else {
            Issue.record("Expected rotate with manual")
        }
    }

    // MARK: - Statistics

    @Test("totalBytesWritten accumulates across rotations")
    func totalBytesAccumulate() {
        var recorder = StreamRecorder(
            configuration: RecordingConfiguration(
                maxFileSizeBytes: 5))
        recorder.start(at: 0)
        _ = recorder.write([UInt8](repeating: 0xAA, count: 6), at: 100)
        _ = recorder.write([UInt8](repeating: 0xBB, count: 3), at: 200)
        #expect(recorder.statistics.totalBytesWritten == 9)
    }

    @Test("durationMicroseconds from start time")
    func durationFromStart() {
        var recorder = StreamRecorder()
        recorder.start(at: 1000)
        _ = recorder.write([0x01], at: 5000)
        #expect(recorder.statistics.durationMicroseconds == 4000)
    }
}
