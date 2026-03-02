// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PacketPacer Tests")
struct PacketPacerTests {
    // MARK: - Timing

    @Test("First packet returns sendNow")
    func firstPacketSendNow() {
        let pacer = PacketPacer()
        #expect(pacer.canSend(currentTime: 1_000_000, sendingPeriod: 1000) == .sendNow)
    }

    @Test("Immediately after send returns wait")
    func immediatelyAfterWait() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        let decision = pacer.canSend(currentTime: 1_000_000, sendingPeriod: 1000)
        #expect(decision == .waitMicroseconds(1000))
    }

    @Test("After full period elapsed returns sendNow")
    func afterPeriodSendNow() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        let decision = pacer.canSend(currentTime: 1_001_000, sendingPeriod: 1000)
        #expect(decision == .sendNow)
    }

    @Test("Partial period returns remaining wait time")
    func partialPeriod() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        let decision = pacer.canSend(currentTime: 1_000_600, sendingPeriod: 1000)
        #expect(decision == .waitMicroseconds(400))
    }

    @Test("Zero sending period returns sendNow")
    func zeroPeriodSendNow() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        let decision = pacer.canSend(currentTime: 1_000_000, sendingPeriod: 0)
        #expect(decision == .sendNow)
    }

    @Test("Past period by more than one interval returns sendNow")
    func pastMultipleIntervals() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        let decision = pacer.canSend(currentTime: 1_010_000, sendingPeriod: 1000)
        #expect(decision == .sendNow)
    }

    // MARK: - Probe detection

    @Test("Packet 0 is probe first")
    func probeFirst() {
        let pacer = PacketPacer()
        #expect(pacer.isProbePacket(probeInterval: 16))
        #expect(!pacer.isProbeSecond(probeInterval: 16))
    }

    @Test("Packet 1 is probe second")
    func probeSecond() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 0)
        #expect(pacer.isProbePacket(probeInterval: 16))
        #expect(pacer.isProbeSecond(probeInterval: 16))
    }

    @Test("Packets 2-15 are not probes")
    func notProbe() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 0)  // 0
        pacer.packetSent(at: 0)  // 1
        for _ in 2..<16 {
            #expect(!pacer.isProbePacket(probeInterval: 16))
            pacer.packetSent(at: 0)
        }
    }

    @Test("Packet 16 is probe first again")
    func probeWraps() {
        var pacer = PacketPacer()
        for _ in 0..<16 {
            pacer.packetSent(at: 0)
        }
        #expect(pacer.isProbePacket(probeInterval: 16))
        #expect(!pacer.isProbeSecond(probeInterval: 16))
    }

    // MARK: - State

    @Test("lastSendTime tracks correctly")
    func lastSendTime() {
        var pacer = PacketPacer()
        #expect(pacer.lastSendTime == nil)
        pacer.packetSent(at: 5_000_000)
        #expect(pacer.lastSendTime == 5_000_000)
        pacer.packetSent(at: 6_000_000)
        #expect(pacer.lastSendTime == 6_000_000)
    }

    @Test("packetsSent increments")
    func packetsSentIncrements() {
        var pacer = PacketPacer()
        #expect(pacer.packetsSent == 0)
        pacer.packetSent(at: 0)
        #expect(pacer.packetsSent == 1)
        pacer.packetSent(at: 0)
        #expect(pacer.packetsSent == 2)
    }

    @Test("reset clears state")
    func reset() {
        var pacer = PacketPacer()
        pacer.packetSent(at: 1_000_000)
        pacer.packetSent(at: 2_000_000)
        pacer.reset()
        #expect(pacer.lastSendTime == nil)
        #expect(pacer.packetsSent == 0)
        #expect(pacer.canSend(currentTime: 0, sendingPeriod: 1000) == .sendNow)
    }
}
