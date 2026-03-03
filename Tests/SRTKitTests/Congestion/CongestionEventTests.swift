// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CongestionEvent Tests")
struct CongestionEventTests {
    @Test("packetSent carries size and sequence")
    func packetSentFields() {
        let event = CongestionEvent.packetSent(
            size: 1316, sequenceNumber: 42, timestamp: 1000)
        if case .packetSent(let size, let seq, let ts) = event {
            #expect(size == 1316)
            #expect(seq == 42)
            #expect(ts == 1000)
        } else {
            Issue.record("Expected packetSent")
        }
    }

    @Test("ackReceived carries all 4 fields")
    func ackReceivedFields() {
        let event = CongestionEvent.ackReceived(
            ackSequence: 100,
            rttMicroseconds: 25_000,
            rttVarianceMicroseconds: 3_000,
            estimatedBandwidthBps: 5_000_000)
        if case .ackReceived(let seq, let rtt, let rttVar, let bw) = event {
            #expect(seq == 100)
            #expect(rtt == 25_000)
            #expect(rttVar == 3_000)
            #expect(bw == 5_000_000)
        } else {
            Issue.record("Expected ackReceived")
        }
    }

    @Test("nakReceived carries loss list")
    func nakReceivedFields() {
        let event = CongestionEvent.nakReceived(
            lossSequences: [10, 11, 15])
        if case .nakReceived(let losses) = event {
            #expect(losses == [10, 11, 15])
        } else {
            Issue.record("Expected nakReceived")
        }
    }

    @Test("Equatable: same events are equal")
    func equatableSame() {
        let a = CongestionEvent.tick(currentTime: 500)
        let b = CongestionEvent.tick(currentTime: 500)
        #expect(a == b)
    }

    @Test("Equatable: different events are not equal")
    func equatableDifferent() {
        let a = CongestionEvent.connectionEstablished(
            initialRTTMicroseconds: 1000)
        let b = CongestionEvent.connectionClosing
        #expect(a != b)
    }

    @Test("timeout carries lastACKSequence")
    func timeoutFields() {
        let event = CongestionEvent.timeout(lastACKSequence: 99)
        if case .timeout(let seq) = event {
            #expect(seq == 99)
        } else {
            Issue.record("Expected timeout")
        }
    }
}
