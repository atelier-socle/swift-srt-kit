// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Testing

@testable import SRTKitCommands

@Suite("Command Parsing Tests")
struct CommandParsingTests {
    // MARK: - SendCommand

    @Test("SendCommand defaults: host 127.0.0.1, port 4200")
    func sendDefaults() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.host == "127.0.0.1")
        #expect(cmd.port == 4200)
    }

    @Test("SendCommand: --host and --port set")
    func sendHostPort() throws {
        let cmd = try SendCommand.parse([
            "--host", "10.0.0.1", "--port", "5000"
        ])
        #expect(cmd.host == "10.0.0.1")
        #expect(cmd.port == 5000)
    }

    @Test("SendCommand: --file sets file")
    func sendFile() throws {
        let cmd = try SendCommand.parse(["--file", "test.ts"])
        #expect(cmd.file == "test.ts")
    }

    @Test("SendCommand: --preset sets preset")
    func sendPreset() throws {
        let cmd = try SendCommand.parse(["--preset", "lowLatency"])
        #expect(cmd.preset == "lowLatency")
    }

    @Test("SendCommand: --passphrase sets passphrase")
    func sendPassphrase() throws {
        let cmd = try SendCommand.parse(["--passphrase", "secret123"])
        #expect(cmd.passphrase == "secret123")
    }

    @Test("SendCommand: --stream-id sets streamID")
    func sendStreamID() throws {
        let cmd = try SendCommand.parse(["--stream-id", "#!::r=live"])
        #expect(cmd.streamID == "#!::r=live")
    }

    // MARK: - ReceiveCommand

    @Test("ReceiveCommand defaults: port 4200, bind 0.0.0.0")
    func receiveDefaults() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.port == 4200)
        #expect(cmd.bind == "0.0.0.0")
    }

    @Test("ReceiveCommand: --output and --duration set")
    func receiveOutputDuration() throws {
        let cmd = try ReceiveCommand.parse([
            "--output", "out.ts", "--duration", "30"
        ])
        #expect(cmd.output == "out.ts")
        #expect(cmd.duration == 30)
    }

    // MARK: - StatsCommand

    @Test("StatsCommand: --interval and --quality set")
    func statsIntervalQuality() throws {
        let cmd = try StatsCommand.parse([
            "--interval", "5", "--quality"
        ])
        #expect(cmd.interval == 5)
        #expect(cmd.quality == true)
    }

    // MARK: - TestCommand

    @Test("TestCommand defaults: duration 5, bitrate 5000")
    func testDefaults() throws {
        let cmd = try TestCommand.parse([])
        #expect(cmd.duration == 5)
        #expect(cmd.bitrate == 5000)
    }

    @Test("TestCommand: --duration and --bitrate set")
    func testDurationBitrate() throws {
        let cmd = try TestCommand.parse([
            "--duration", "10", "--bitrate", "10000"
        ])
        #expect(cmd.duration == 10)
        #expect(cmd.bitrate == 10000)
    }

    // MARK: - ProbeCommand

    @Test("ProbeCommand defaults: mode standard, target balanced")
    func probeDefaults() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(cmd.mode == "standard")
        #expect(cmd.target == "balanced")
    }

    @Test("ProbeCommand: --mode and --target set")
    func probeModeTarget() throws {
        let cmd = try ProbeCommand.parse([
            "--mode", "quick", "--target", "lowLatency"
        ])
        #expect(cmd.mode == "quick")
        #expect(cmd.target == "lowLatency")
    }

    // MARK: - InfoCommand

    @Test("InfoCommand: --verbose sets flag")
    func infoVerbose() throws {
        let cmd = try InfoCommand.parse(["--verbose"])
        #expect(cmd.verbose == true)
    }
}
