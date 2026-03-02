// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTSocketOptions Tests")
struct SRTSocketOptionsTests {
    // MARK: - Defaults

    @Test("Default latency is 120_000")
    func defaultLatency() {
        let options = SRTSocketOptions()
        #expect(options.latency == 120_000)
    }

    @Test("Default sendBufferSize is 8192")
    func defaultSendBufferSize() {
        let options = SRTSocketOptions()
        #expect(options.sendBufferSize == 8192)
    }

    @Test("Default maxPayloadSize is 1316")
    func defaultMaxPayloadSize() {
        let options = SRTSocketOptions()
        #expect(options.maxPayloadSize == 1316)
    }

    @Test("Default congestionControl is live")
    func defaultCongestionControl() {
        let options = SRTSocketOptions()
        #expect(options.congestionControl == "live")
    }

    @Test("Default passphrase is nil")
    func defaultPassphrase() {
        let options = SRTSocketOptions()
        #expect(options.passphrase == nil)
    }

    @Test("Default keySize is .aes128")
    func defaultKeySize() {
        let options = SRTSocketOptions()
        #expect(options.keySize == .aes128)
    }

    @Test("Default transmissionType is .live")
    func defaultTransmissionType() {
        let options = SRTSocketOptions()
        #expect(options.transmissionType == .live)
    }

    @Test("Default tlpktdrop is true")
    func defaultTlpktdrop() {
        let options = SRTSocketOptions()
        #expect(options.tlpktdrop)
    }

    @Test("Default tsbpd is true")
    func defaultTsbpd() {
        let options = SRTSocketOptions()
        #expect(options.tsbpd)
    }

    @Test("Default peerLatency is 0")
    func defaultPeerLatency() {
        let options = SRTSocketOptions()
        #expect(options.peerLatency == 0)
    }

    @Test("Default flowWindowSize is 25600")
    func defaultFlowWindowSize() {
        let options = SRTSocketOptions()
        #expect(options.flowWindowSize == 25_600)
    }

    @Test("Default kmRefreshRate is 2^24")
    func defaultKmRefreshRate() {
        let options = SRTSocketOptions()
        #expect(options.kmRefreshRate == 1 << 24)
    }

    // MARK: - TransmissionType

    @Test("TransmissionType.live raw value is live")
    func liveRawValue() {
        #expect(SRTSocketOptions.TransmissionType.live.rawValue == "live")
    }

    @Test("TransmissionType.file raw value is file")
    func fileRawValue() {
        #expect(SRTSocketOptions.TransmissionType.file.rawValue == "file")
    }

    @Test("TransmissionType CaseIterable lists both")
    func transmissionTypeCaseIterable() {
        let cases = SRTSocketOptions.TransmissionType.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.live))
        #expect(cases.contains(.file))
    }

    // MARK: - Equatable

    @Test("Same defaults are equal")
    func sameDefaultsEqual() {
        let a = SRTSocketOptions()
        let b = SRTSocketOptions()
        #expect(a == b)
    }

    @Test("Changed latency makes not equal")
    func changedLatencyNotEqual() {
        var a = SRTSocketOptions()
        let b = SRTSocketOptions()
        a.latency = 50_000
        #expect(a != b)
    }

    @Test("Changed passphrase makes not equal")
    func changedPassphraseNotEqual() {
        var a = SRTSocketOptions()
        let b = SRTSocketOptions()
        a.passphrase = "testpassphrase"
        #expect(a != b)
    }

    // MARK: - Static default

    @Test("Static default equals fresh init")
    func staticDefaultEqualsFreshInit() {
        #expect(SRTSocketOptions.default == SRTSocketOptions())
    }
}
