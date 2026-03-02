// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("LatencyNegotiator Tests")
struct LatencyNegotiatorTests {
    @Test("Caller higher sender delay wins")
    func callerHigherSenderDelay() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 500, localReceiverDelay: 100,
            remoteSenderDelay: 100, remoteReceiverDelay: 100
        )
        #expect(result.senderDelay == 500)
    }

    @Test("Listener higher receiver delay wins")
    func listenerHigherReceiverDelay() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 100, localReceiverDelay: 100,
            remoteSenderDelay: 100, remoteReceiverDelay: 500
        )
        #expect(result.senderDelay == 500)
    }

    @Test("Equal values produce same value")
    func equalValues() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 120, localReceiverDelay: 120,
            remoteSenderDelay: 120, remoteReceiverDelay: 120
        )
        #expect(result.senderDelay == 120)
        #expect(result.receiverDelay == 120)
    }

    @Test("Zero values produce zero (no TSBPD)")
    func zeroValues() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 0, localReceiverDelay: 0,
            remoteSenderDelay: 0, remoteReceiverDelay: 0
        )
        #expect(result.senderDelay == 0)
        #expect(result.receiverDelay == 0)
    }

    @Test("Asymmetric delays: different sender/receiver")
    func asymmetricDelays() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 100, localReceiverDelay: 200,
            remoteSenderDelay: 300, remoteReceiverDelay: 50
        )
        // senderDelay = max(local_sender=100, remote_receiver=50) = 100
        #expect(result.senderDelay == 100)
        // receiverDelay = max(local_receiver=200, remote_sender=300) = 300
        #expect(result.receiverDelay == 300)
    }

    @Test("Large values preserved")
    func largeValues() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: UInt16.max, localReceiverDelay: 100,
            remoteSenderDelay: 100, remoteReceiverDelay: 100
        )
        #expect(result.senderDelay == UInt16.max)
    }

    @Test("Cross-negotiation: local sender vs remote receiver")
    func crossNegotiation() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 100, localReceiverDelay: 200,
            remoteSenderDelay: 150, remoteReceiverDelay: 250
        )
        // senderDelay = max(100, 250) = 250
        #expect(result.senderDelay == 250)
        // receiverDelay = max(200, 150) = 200
        #expect(result.receiverDelay == 200)
    }

    @Test("One side zero, other non-zero")
    func oneSideZero() {
        let result = LatencyNegotiator.negotiate(
            localSenderDelay: 0, localReceiverDelay: 0,
            remoteSenderDelay: 120, remoteReceiverDelay: 120
        )
        #expect(result.senderDelay == 120)
        #expect(result.receiverDelay == 120)
    }
}
