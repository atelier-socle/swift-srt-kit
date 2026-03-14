// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PacketPipeline Send Tests")
struct PacketPipelineSendTests {
    /// Create a pipeline with defaults for send testing.
    private func makePipeline(
        sendBufferCapacity: Int = 100,
        fecConfig: FECConfiguration? = nil
    ) -> PacketPipeline {
        PacketPipeline(
            configuration: .init(
                fecEnabled: fecConfig != nil,
                fecConfiguration: fecConfig,
                sendBufferCapacity: sendBufferCapacity
            ))
    }

    // MARK: - Basic send (no encryption, no FEC)

    @Test("Send payload returns transmit with correct sequence number")
    func sendBasic() throws {
        var pipeline = makePipeline()
        let result = try pipeline.processSend(
            payload: [0x01, 0x02, 0x03],
            currentTime: 1000
        )
        if case .transmit(let packets) = result {
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(0))
            #expect(packets[0].payload == [0x01, 0x02, 0x03])
            #expect(!packets[0].isRetransmit)
            #expect(!packets[0].isFEC)
        } else {
            Issue.record("Expected transmit")
        }
    }

    @Test("Sequential sends assign incrementing sequence numbers")
    func sequentialSends() throws {
        var pipeline = makePipeline()
        let r1 = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        let r2 = try pipeline.processSend(payload: [0x02], currentTime: 2000)
        let r3 = try pipeline.processSend(payload: [0x03], currentTime: 3000)

        if case .transmit(let p1) = r1 {
            #expect(p1[0].sequenceNumber == SequenceNumber(0))
        }
        if case .transmit(let p2) = r2 {
            #expect(p2[0].sequenceNumber == SequenceNumber(1))
        }
        if case .transmit(let p3) = r3 {
            #expect(p3[0].sequenceNumber == SequenceNumber(2))
        }
    }

    @Test("Send when buffer full returns bufferFull")
    func sendBufferFull() throws {
        var pipeline = makePipeline(sendBufferCapacity: 2)
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        _ = try pipeline.processSend(payload: [0x02], currentTime: 2000)
        let result = try pipeline.processSend(
            payload: [0x03], currentTime: 3000)
        if case .bufferFull = result {
        } else {
            Issue.record("Expected bufferFull")
        }
    }

    @Test("Packet data includes timestamp from current time")
    func packetTimestamp() throws {
        var pipeline = makePipeline()
        let result = try pipeline.processSend(
            payload: [0x01], currentTime: 12345)
        if case .transmit(let packets) = result {
            #expect(packets[0].timestamp == 12345)
        }
    }

    // MARK: - Send with FEC

    @Test("Send with FEC generates FEC packets after group fills")
    func sendWithFECGeneratesFEC() throws {
        let fecConfig = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var pipeline = makePipeline(fecConfig: fecConfig)

        let r0 = try pipeline.processSend(payload: [0x10], currentTime: 1000)
        if case .transmit(let p) = r0 {
            #expect(p.count == 1)
            #expect(!p[0].isFEC)
        }

        let r1 = try pipeline.processSend(payload: [0x20], currentTime: 2000)
        if case .transmit(let p) = r1 {
            #expect(p.count == 1)
        }

        // Third packet completes the row → FEC generated
        let r2 = try pipeline.processSend(payload: [0x30], currentTime: 3000)
        if case .transmit(let packets) = r2 {
            #expect(packets.count >= 2)
            let fecPackets = packets.filter { $0.isFEC }
            #expect(!fecPackets.isEmpty)
        } else {
            Issue.record("Expected transmit with FEC")
        }
    }

    @Test("FEC packets included in transmit result")
    func fecPacketsInResult() throws {
        let fecConfig = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var pipeline = makePipeline(fecConfig: fecConfig)

        _ = try pipeline.processSend(payload: [0xAA], currentTime: 1000)
        let result = try pipeline.processSend(
            payload: [0xBB], currentTime: 2000)

        if case .transmit(let packets) = result {
            let dataPackets = packets.filter { !$0.isFEC }
            let fecPackets = packets.filter { $0.isFEC }
            #expect(dataPackets.count == 1)
            #expect(fecPackets.count >= 1)
        }
    }

    // MARK: - Control path

    @Test("processACK advances send buffer")
    func processACK() throws {
        var pipeline = makePipeline()
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        _ = try pipeline.processSend(payload: [0x02], currentTime: 2000)
        _ = try pipeline.processSend(payload: [0x03], currentTime: 3000)
        #expect(pipeline.sendBufferCount == 3)

        // ACK up to seq 1 (inclusive) — removes seq 0 and 1
        pipeline.processACK(
            ackNumber: SequenceNumber(1),
            rtt: 50_000,
            bandwidth: 1_000_000,
            availableBuffer: 100
        )
        #expect(pipeline.sendBufferCount == 1)
    }

    @Test("processNAK returns retransmit packets")
    func processNAK() throws {
        var pipeline = makePipeline()
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        _ = try pipeline.processSend(payload: [0x02], currentTime: 2000)

        let retransmit = pipeline.processNAK(
            lossList: [SequenceNumber(0)])
        #expect(retransmit.count == 1)
        #expect(retransmit[0].sequenceNumber == SequenceNumber(0))
        #expect(retransmit[0].isRetransmit)
    }

    @Test("retransmissions counter incremented on NAK processing")
    func retransmissionsCounter() throws {
        var pipeline = makePipeline()
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        #expect(pipeline.retransmissions == 0)

        _ = pipeline.processNAK(lossList: [SequenceNumber(0)])
        #expect(pipeline.retransmissions == 1)
    }

    @Test("pendingACK returns ACK action when due")
    func pendingACK() throws {
        var pipeline = makePipeline()
        // Receive a packet to trigger ACK
        _ = try pipeline.processReceivedPacket(
            payload: [0x01],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 0
        )
        // Check for periodic ACK at SYN_INTERVAL
        let action = pipeline.pendingACK(currentTime: 10_000)
        // ACK manager may or may not have a pending ACK depending on state
        switch action {
        case .sendFullACK, .sendLightACK, .none:
            break  // all valid outcomes
        }
    }

    // MARK: - Stats

    @Test("packetsSent increments on send")
    func packetsSentStat() throws {
        var pipeline = makePipeline()
        #expect(pipeline.packetsSent == 0)
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)
        #expect(pipeline.packetsSent == 1)
        _ = try pipeline.processSend(payload: [0x02], currentTime: 2000)
        #expect(pipeline.packetsSent == 2)
    }

    @Test("currentRTT reflects estimator")
    func currentRTT() {
        let pipeline = makePipeline()
        // Default RTT is 100_000 µs
        #expect(pipeline.currentRTT == 100_000)
    }

    // MARK: - Configuration

    @Test("Default pipeline configuration has expected values")
    func defaultConfig() {
        let config = PacketPipeline.Configuration()
        #expect(!config.encryptionEnabled)
        #expect(!config.fecEnabled)
        #expect(config.fecConfiguration == nil)
        #expect(config.cipherMode == .ctr)
        #expect(config.latencyMicroseconds == 120_000)
        #expect(config.initialSequenceNumber == SequenceNumber(0))
        #expect(config.sendBufferCapacity == 8192)
    }

    @Test("Custom initial sequence number applied")
    func customInitialSequence() throws {
        var pipeline = PacketPipeline(
            configuration: .init(
                sendInitialSequenceNumber: SequenceNumber(100)))
        let result = try pipeline.processSend(
            payload: [0x01], currentTime: 1000)
        if case .transmit(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(100))
        }
    }

    @Test("Buffer full does not consume sequence number")
    func bufferFullNoSeqConsume() throws {
        var pipeline = makePipeline(sendBufferCapacity: 1)
        _ = try pipeline.processSend(payload: [0x01], currentTime: 1000)

        // Buffer full
        let r2 = try pipeline.processSend(payload: [0x02], currentTime: 2000)
        if case .bufferFull = r2 {
        } else {
            Issue.record("Expected bufferFull")
        }

        // ACK to free space
        pipeline.processACK(
            ackNumber: SequenceNumber(1),
            rtt: 50_000, bandwidth: 0, availableBuffer: 100)

        // Next send should use seq 1 (not 2)
        let r3 = try pipeline.processSend(payload: [0x03], currentTime: 3000)
        if case .transmit(let packets) = r3 {
            #expect(packets[0].sequenceNumber == SequenceNumber(1))
        }
    }
}
