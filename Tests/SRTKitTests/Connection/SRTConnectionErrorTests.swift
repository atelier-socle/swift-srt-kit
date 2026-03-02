// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConnectionError Tests")
struct SRTConnectionErrorTests {
    @Test("Each error has a meaningful description")
    func errorDescriptions() {
        let errors: [SRTConnectionError] = [
            .connectionTimeout,
            .handshakeRejected(reason: "bad cookie"),
            .connectionBroken,
            .invalidState(current: .idle, required: "connected"),
            .bufferFull,
            .alreadyListening,
            .bindFailed("port in use"),
            .encryptionMismatch,
            .encryptionRequired
        ]
        for err in errors {
            #expect(!err.description.isEmpty)
        }
    }

    @Test("Equatable works for simple cases")
    func equatable() {
        #expect(SRTConnectionError.connectionTimeout == .connectionTimeout)
        #expect(SRTConnectionError.connectionBroken == .connectionBroken)
        #expect(SRTConnectionError.bufferFull == .bufferFull)
        #expect(SRTConnectionError.connectionTimeout != .connectionBroken)
    }

    @Test("Equatable works for associated values")
    func equatableWithValues() {
        #expect(
            SRTConnectionError.handshakeRejected(reason: "x")
                == .handshakeRejected(reason: "x"))
        #expect(
            SRTConnectionError.handshakeRejected(reason: "x")
                != .handshakeRejected(reason: "y"))
        #expect(
            SRTConnectionError.invalidState(current: .idle, required: "active")
                == .invalidState(current: .idle, required: "active"))
        #expect(
            SRTConnectionError.invalidState(current: .idle, required: "active")
                != .invalidState(current: .closed, required: "active"))
    }

    @Test("invalidState includes current and required state")
    func invalidStateDescription() {
        let err = SRTConnectionError.invalidState(
            current: .idle, required: "connected")
        #expect(err.description.contains("idle"))
        #expect(err.description.contains("connected"))
    }

    @Test("handshakeRejected includes reason")
    func handshakeRejectedDescription() {
        let err = SRTConnectionError.handshakeRejected(reason: "bad cookie")
        #expect(err.description.contains("bad cookie"))
    }

    @Test("bindFailed includes reason")
    func bindFailedDescription() {
        let err = SRTConnectionError.bindFailed("port 4200 in use")
        #expect(err.description.contains("port 4200 in use"))
    }
}
