// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTAccessControl Tests")
struct SRTAccessControlTests {
    // MARK: - Parsing

    @Test("Parse structured: r, m, u")
    func parseResourceModeUser() {
        let ac = SRTAccessControl.parse("#!::r=live/stream1,m=publish,u=broadcaster")
        #expect(ac.resource == "live/stream1")
        #expect(ac.mode == .publish)
        #expect(ac.userName == "broadcaster")
        #expect(ac.sessionID == nil)
        #expect(ac.contentType == nil)
    }

    @Test("Parse structured: r, m, t")
    func parseResourceModeType() {
        let ac = SRTAccessControl.parse("#!::r=vod/movie.ts,m=request,t=file")
        #expect(ac.resource == "vod/movie.ts")
        #expect(ac.mode == .request)
        #expect(ac.contentType == .file)
    }

    @Test("Parse structured: all fields")
    func parseAllFields() {
        let ac = SRTAccessControl.parse(
            "#!::r=cam,m=bidirectional,s=sess123,u=admin,t=stream"
        )
        #expect(ac.resource == "cam")
        #expect(ac.mode == .bidirectional)
        #expect(ac.sessionID == "sess123")
        #expect(ac.userName == "admin")
        #expect(ac.contentType == .stream)
    }

    @Test("Parse plain string -> resource only")
    func parsePlainString() {
        let ac = SRTAccessControl.parse("live/mystream")
        #expect(ac.resource == "live/mystream")
        #expect(ac.mode == nil)
        #expect(ac.sessionID == nil)
    }

    @Test("Parse empty string -> all nil")
    func parseEmptyString() {
        let ac = SRTAccessControl.parse("")
        #expect(ac.resource == nil)
        #expect(ac.mode == nil)
    }

    @Test("Parse #!:: with no keys -> all nil")
    func parseEmptyStructured() {
        let ac = SRTAccessControl.parse("#!::")
        #expect(ac.resource == nil)
        #expect(ac.mode == nil)
    }

    @Test("Parse with custom keys")
    func parseCustomKeys() {
        let ac = SRTAccessControl.parse("#!::r=test,x=custom1,y=custom2")
        #expect(ac.resource == "test")
        #expect(ac.customKeys.count == 2)
        #expect(ac.customKeys[0].key == "x")
        #expect(ac.customKeys[0].value == "custom1")
        #expect(ac.customKeys[1].key == "y")
        #expect(ac.customKeys[1].value == "custom2")
    }

    @Test("Parse with value containing =")
    func parseValueWithEquals() {
        let ac = SRTAccessControl.parse("#!::r=path/with=equals")
        #expect(ac.resource == "path/with=equals")
    }

    @Test("Parse with unknown mode -> mode nil")
    func parseUnknownMode() {
        let ac = SRTAccessControl.parse("#!::m=unknown")
        #expect(ac.mode == nil)
    }

    @Test("Parse single key -> mode set, resource nil")
    func parseSingleKey() {
        let ac = SRTAccessControl.parse("#!::m=publish")
        #expect(ac.mode == .publish)
        #expect(ac.resource == nil)
    }

    // MARK: - Generation

    @Test("Generate from resource only -> plain string")
    func generateResourceOnly() {
        let ac = SRTAccessControl(resource: "live/stream1")
        #expect(ac.generate() == "live/stream1")
    }

    @Test("Generate from resource + mode -> structured")
    func generateResourceAndMode() {
        let ac = SRTAccessControl(resource: "live/test", mode: .publish)
        #expect(ac.generate() == "#!::r=live/test,m=publish")
    }

    @Test("Generate from all fields")
    func generateAllFields() {
        let ac = SRTAccessControl(
            resource: "cam",
            mode: .bidirectional,
            sessionID: "sess1",
            userName: "admin",
            contentType: .stream
        )
        let result = ac.generate()
        #expect(result == "#!::r=cam,m=bidirectional,s=sess1,u=admin,t=stream")
    }

    @Test("Generate with custom keys")
    func generateCustomKeys() {
        let ac = SRTAccessControl(
            resource: "test",
            customKeys: [("x", "val1"), ("y", "val2")]
        )
        let result = ac.generate()
        #expect(result == "#!::r=test,x=val1,y=val2")
    }

    @Test("Generate with nil fields -> omitted")
    func generateNilFieldsOmitted() {
        let ac = SRTAccessControl(mode: .request)
        let result = ac.generate()
        #expect(result == "#!::m=request")
    }

    // MARK: - Roundtrip

    @Test("Parse then generate roundtrip")
    func parseThenGenerate() {
        let original = "#!::r=live/stream1,m=publish,u=broadcaster"
        let ac = SRTAccessControl.parse(original)
        let generated = ac.generate()
        #expect(generated == original)
    }

    @Test("Generate then parse roundtrip")
    func generateThenParse() {
        let ac = SRTAccessControl(
            resource: "test/stream",
            mode: .request,
            contentType: .file
        )
        let generated = ac.generate()
        let parsed = SRTAccessControl.parse(generated)
        #expect(parsed.resource == "test/stream")
        #expect(parsed.mode == .request)
        #expect(parsed.contentType == .file)
    }
}
