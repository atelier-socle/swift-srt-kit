// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StreamIDValidator Tests")
struct StreamIDValidatorTests {
    @Test("Valid StreamID passes")
    func validStreamIDPasses() {
        let error = StreamIDValidator.validate("#!::r=live/stream1,m=publish")
        #expect(error == nil)
    }

    @Test("Too long StreamID (>512 bytes)")
    func tooLongStreamID() {
        let longString = String(repeating: "a", count: 513)
        let error = StreamIDValidator.validate(longString)
        if case .tooLong(let length, let maxLen) = error {
            #expect(length == 513)
            #expect(maxLen == 512)
        } else {
            #expect(Bool(false), "Expected tooLong error")
        }
    }

    @Test("Exactly 512 bytes is valid")
    func exactly512Bytes() {
        let exactString = String(repeating: "a", count: 512)
        let error = StreamIDValidator.validate(exactString)
        #expect(error == nil)
    }

    @Test("Empty resource in structured format")
    func emptyResource() {
        let error = StreamIDValidator.validate("#!::r=")
        if case .emptyResource = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected emptyResource error")
        }
    }

    @Test("Invalid mode string")
    func invalidMode() {
        let error = StreamIDValidator.validate("#!::m=invalid")
        if case .invalidMode(let mode) = error {
            #expect(mode == "invalid")
        } else {
            #expect(Bool(false), "Expected invalidMode error")
        }
    }

    @Test("Invalid content type")
    func invalidContentType() {
        let error = StreamIDValidator.validate("#!::t=video")
        if case .invalidContentType(let ct) = error {
            #expect(ct == "video")
        } else {
            #expect(Bool(false), "Expected invalidContentType error")
        }
    }

    @Test("Plain string within length is valid")
    func plainStringValid() {
        let error = StreamIDValidator.validate("live/mystream")
        #expect(error == nil)
    }

    @Test("Empty string is valid")
    func emptyStringValid() {
        let error = StreamIDValidator.validate("")
        #expect(error == nil)
    }

    @Test("Validate access control: publish with resource is valid")
    func publishWithResourceValid() {
        let ac = SRTAccessControl(resource: "live/test", mode: .publish)
        let error = StreamIDValidator.validateAccessControl(ac)
        #expect(error == nil)
    }

    @Test("Validate access control: publish without resource is error")
    func publishWithoutResourceError() {
        let ac = SRTAccessControl(mode: .publish)
        let error = StreamIDValidator.validateAccessControl(ac)
        if case .emptyResource = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected emptyResource error")
        }
    }

    @Test("Validate access control: request without resource is valid")
    func requestWithoutResourceValid() {
        let ac = SRTAccessControl(mode: .request)
        let error = StreamIDValidator.validateAccessControl(ac)
        #expect(error == nil)
    }

    @Test("Validate access control: bidirectional without resource is error")
    func bidirectionalWithoutResourceError() {
        let ac = SRTAccessControl(mode: .bidirectional)
        let error = StreamIDValidator.validateAccessControl(ac)
        if case .emptyResource = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected emptyResource error")
        }
    }
}
