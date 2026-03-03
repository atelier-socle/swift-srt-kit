// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

// MARK: - SRTError missing description coverage

@Suite("SRTError Coverage Tests")
struct SRTErrorCoverageTests {
    @Test("invalidOption description")
    func invalidOptionDescription() {
        let error = SRTError.invalidOption("latency")
        #expect(error.description == "Invalid option: latency")
    }

    @Test("optionNotApplicable description")
    func optionNotApplicableDescription() {
        let error = SRTError.optionNotApplicable("fec")
        #expect(error.description == "Option not applicable: fec")
    }

    @Test("groupFailed description")
    func groupFailedDescription() {
        let error = SRTError.groupFailed("no members")
        #expect(error.description == "Group failed: no members")
    }

    @Test("allLinksDown description")
    func allLinksDownDescription() {
        let error = SRTError.allLinksDown
        #expect(error.description == "All links down")
    }

    @Test("memberNotFound description")
    func memberNotFoundDescription() {
        let error = SRTError.memberNotFound("member-42")
        #expect(error.description == "Member not found: member-42")
    }

    @Test("socketCreationFailed description")
    func socketCreationFailedDescription() {
        let error = SRTError.socketCreationFailed("bind error")
        #expect(error.description == "Socket creation failed: bind error")
    }

    @Test("internalError description")
    func internalErrorDescription() {
        let error = SRTError.internalError("unexpected state")
        #expect(error.description == "Internal error: unexpected state")
    }
}

// MARK: - StreamIDValidator.ValidationError description coverage

@Suite("StreamIDValidator Error Description Tests")
struct StreamIDValidatorErrorDescriptionTests {
    @Test("tooLong description")
    func tooLongDescription() {
        let error = StreamIDValidator.ValidationError.tooLong(length: 600, maxLength: 512)
        #expect(error.description == "StreamID too long: 600 bytes (max 512)")
    }

    @Test("invalidFormat description")
    func invalidFormatDescription() {
        let error = StreamIDValidator.ValidationError.invalidFormat(reason: "bad syntax")
        #expect(error.description == "Invalid StreamID format: bad syntax")
    }

    @Test("emptyResource description")
    func emptyResourceDescription() {
        let error = StreamIDValidator.ValidationError.emptyResource
        #expect(error.description == "Empty resource in StreamID")
    }

    @Test("invalidMode description")
    func invalidModeDescription() {
        let error = StreamIDValidator.ValidationError.invalidMode("unknown")
        #expect(error.description == "Invalid mode: unknown")
    }

    @Test("invalidContentType description")
    func invalidContentTypeDescription() {
        let error = StreamIDValidator.ValidationError.invalidContentType("bad")
        #expect(error.description == "Invalid content type: bad")
    }

    @Test("Missing equals in structured pair")
    func missingEqualsInPair() {
        let error = StreamIDValidator.validate("#!::r=live,badpair,m=publish")
        if case .invalidFormat(let reason) = error {
            #expect(reason.contains("Missing '='"))
        } else {
            #expect(Bool(false), "Expected invalidFormat error")
        }
    }

    @Test("Invalid mode in structured StreamID")
    func invalidModeInStructured() {
        let error = StreamIDValidator.validate("#!::r=live,m=badmode")
        if case .invalidMode(let mode) = error {
            #expect(mode == "badmode")
        } else {
            #expect(Bool(false), "Expected invalidMode error")
        }
    }

    @Test("Invalid content type in structured StreamID")
    func invalidContentTypeInStructured() {
        let error = StreamIDValidator.validate("#!::r=live,t=badtype")
        if case .invalidContentType(let ct) = error {
            #expect(ct == "badtype")
        } else {
            #expect(Bool(false), "Expected invalidContentType error")
        }
    }
}

// MARK: - SRTAccessControl Equatable coverage

@Suite("SRTAccessControl Equatable Tests")
struct SRTAccessControlEquatableTests {
    @Test("Equal instances compare as equal")
    func equalInstances() {
        let a = SRTAccessControl(
            resource: "live", mode: .publish, sessionID: "s1",
            userName: "user", contentType: .stream,
            customKeys: [("x", "1")], rawStreamID: "#!::r=live"
        )
        let b = SRTAccessControl(
            resource: "live", mode: .publish, sessionID: "s1",
            userName: "user", contentType: .stream,
            customKeys: [("x", "1")], rawStreamID: "#!::r=live"
        )
        #expect(a == b)
    }

    @Test("Different resource compares as not equal")
    func differentResource() {
        let a = SRTAccessControl(resource: "live1")
        let b = SRTAccessControl(resource: "live2")
        #expect(a != b)
    }

    @Test("Different custom keys count compares as not equal")
    func differentCustomKeysCount() {
        let a = SRTAccessControl(customKeys: [("x", "1")])
        let b = SRTAccessControl(customKeys: [("x", "1"), ("y", "2")])
        #expect(a != b)
    }

    @Test("Different custom key values compares as not equal")
    func differentCustomKeyValues() {
        let a = SRTAccessControl(customKeys: [("x", "1")])
        let b = SRTAccessControl(customKeys: [("x", "2")])
        #expect(a != b)
    }
}

// MARK: - CallerHandshake edge case coverage

@Suite("CallerHandshake Edge Case Coverage Tests")
struct CallerHandshakeEdgeCaseCoverageTests {
    private func makeConfig(
        passphrase: String? = nil,
        cipherType: UInt16 = 0
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: 0x1234,
            senderTSBPDDelay: 120,
            receiverTSBPDDelay: 120,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    @Test("receive in idle state returns error")
    func receiveInIdleState() {
        var hs = CallerHandshake(configuration: makeConfig())
        let actions = hs.receive(
            handshake: HandshakePacket(
                version: 5,
                handshakeType: .induction,
                srtSocketID: 0xABCD
            ),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("timeout in idle state returns error")
    func timeoutInIdleState() {
        var hs = CallerHandshake(configuration: makeConfig())
        let action = hs.timeout()
        if case .error = action {
            // expected
        } else {
            #expect(Bool(false), "Expected error action on timeout in idle state")
        }
    }
}
