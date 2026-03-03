// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Testing

@testable import SRTKitCommands

// MARK: - ReceiveCommand Parsing Coverage

@Suite("ReceiveCommand Parsing Coverage")
struct ReceiveCommandParsingCoverageTests {

    @Test("ReceiveCommand command name is 'receive'")
    func commandName() {
        #expect(ReceiveCommand.configuration.commandName == "receive")
    }

    @Test("ReceiveCommand abstract is set")
    func abstract() {
        #expect(
            ReceiveCommand.configuration.abstract
                == "Receive data from an SRT caller")
    }

    @Test("ReceiveCommand default port is 4200")
    func defaultPort() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.port == 4200)
    }

    @Test("ReceiveCommand default bind is 0.0.0.0")
    func defaultBind() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.bind == "0.0.0.0")
    }

    @Test("ReceiveCommand default output is nil")
    func defaultOutput() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.output == nil)
    }

    @Test("ReceiveCommand default passphrase is nil")
    func defaultPassphrase() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.passphrase == nil)
    }

    @Test("ReceiveCommand default latency is nil")
    func defaultLatency() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.latency == nil)
    }

    @Test("ReceiveCommand default duration is 0")
    func defaultDuration() throws {
        let cmd = try ReceiveCommand.parse([])
        #expect(cmd.duration == 0)
    }

    @Test("ReceiveCommand --port sets port")
    func parsePort() throws {
        let cmd = try ReceiveCommand.parse(["--port", "8080"])
        #expect(cmd.port == 8080)
    }

    @Test("ReceiveCommand --bind sets bind address")
    func parseBind() throws {
        let cmd = try ReceiveCommand.parse(["--bind", "192.168.1.1"])
        #expect(cmd.bind == "192.168.1.1")
    }

    @Test("ReceiveCommand --output sets output path")
    func parseOutput() throws {
        let cmd = try ReceiveCommand.parse(["--output", "/tmp/received.ts"])
        #expect(cmd.output == "/tmp/received.ts")
    }

    @Test("ReceiveCommand --passphrase sets passphrase")
    func parsePassphrase() throws {
        let cmd = try ReceiveCommand.parse(["--passphrase", "receiver-secret"])
        #expect(cmd.passphrase == "receiver-secret")
    }

    @Test("ReceiveCommand --latency sets latency")
    func parseLatency() throws {
        let cmd = try ReceiveCommand.parse(["--latency", "500"])
        #expect(cmd.latency == 500)
    }

    @Test("ReceiveCommand --duration sets duration")
    func parseDuration() throws {
        let cmd = try ReceiveCommand.parse(["--duration", "120"])
        #expect(cmd.duration == 120)
    }

    @Test("ReceiveCommand parses all options together")
    func allOptions() throws {
        let cmd = try ReceiveCommand.parse([
            "--port", "5500", "--bind", "10.0.0.1",
            "--output", "capture.ts", "--passphrase", "my-pass",
            "--latency", "250", "--duration", "60"
        ])
        #expect(cmd.port == 5500)
        #expect(cmd.bind == "10.0.0.1")
        #expect(cmd.output == "capture.ts")
        #expect(cmd.passphrase == "my-pass")
        #expect(cmd.latency == 250)
        #expect(cmd.duration == 60)
    }

    @Test("ReceiveCommand parses port and output only")
    func portAndOutput() throws {
        let cmd = try ReceiveCommand.parse(["--port", "3333", "--output", "stream.ts"])
        #expect(cmd.port == 3333)
        #expect(cmd.output == "stream.ts")
        #expect(cmd.bind == "0.0.0.0")
    }

    @Test("ReceiveCommand parses bind and passphrase")
    func bindAndPassphrase() throws {
        let cmd = try ReceiveCommand.parse(["--bind", "::1", "--passphrase", "ipv6-secret"])
        #expect(cmd.bind == "::1")
        #expect(cmd.passphrase == "ipv6-secret")
    }

    @Test("ReceiveCommand rejects non-integer port")
    func rejectNonIntPort() {
        #expect(throws: (any Error).self) { try ReceiveCommand.parse(["--port", "abc"]) }
    }

    @Test("ReceiveCommand rejects non-integer latency")
    func rejectNonIntLatency() {
        #expect(throws: (any Error).self) { try ReceiveCommand.parse(["--latency", "medium"]) }
    }

    @Test("ReceiveCommand rejects non-integer duration")
    func rejectNonIntDuration() {
        #expect(throws: (any Error).self) { try ReceiveCommand.parse(["--duration", "forever"]) }
    }

    @Test("ReceiveCommand rejects unknown option")
    func rejectUnknownOption() {
        #expect(throws: (any Error).self) { try ReceiveCommand.parse(["--host", "localhost"]) }
    }

    @Test("ReceiveCommand rejects positional arguments")
    func rejectPositionalArgs() {
        #expect(throws: (any Error).self) { try ReceiveCommand.parse(["unexpected"]) }
    }
}

// MARK: - StatsCommand Parsing Coverage

@Suite("StatsCommand Parsing Coverage")
struct StatsCommandParsingCoverageTests {

    @Test("StatsCommand command name is 'stats'")
    func commandName() {
        #expect(StatsCommand.configuration.commandName == "stats")
    }

    @Test("StatsCommand abstract is set")
    func abstract() {
        #expect(
            StatsCommand.configuration.abstract
                == "Display real-time connection statistics")
    }

    @Test("StatsCommand default host is 127.0.0.1")
    func defaultHost() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.host == "127.0.0.1")
    }

    @Test("StatsCommand default port is 4200")
    func defaultPort() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.port == 4200)
    }

    @Test("StatsCommand default interval is 2")
    func defaultInterval() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.interval == 2)
    }

    @Test("StatsCommand default streamID is nil")
    func defaultStreamID() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.streamID == nil)
    }

    @Test("StatsCommand default passphrase is nil")
    func defaultPassphrase() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.passphrase == nil)
    }

    @Test("StatsCommand default quality is false")
    func defaultQuality() throws {
        let cmd = try StatsCommand.parse([])
        #expect(cmd.quality == false)
    }

    @Test("StatsCommand --host sets host")
    func parseHost() throws {
        let cmd = try StatsCommand.parse(["--host", "media-server.local"])
        #expect(cmd.host == "media-server.local")
    }

    @Test("StatsCommand --port sets port")
    func parsePort() throws {
        let cmd = try StatsCommand.parse(["--port", "9876"])
        #expect(cmd.port == 9876)
    }

    @Test("StatsCommand --interval sets interval")
    func parseInterval() throws {
        let cmd = try StatsCommand.parse(["--interval", "10"])
        #expect(cmd.interval == 10)
    }

    @Test("StatsCommand --stream-id sets streamID")
    func parseStreamID() throws {
        let cmd = try StatsCommand.parse(["--stream-id", "monitor/feed1"])
        #expect(cmd.streamID == "monitor/feed1")
    }

    @Test("StatsCommand --passphrase sets passphrase")
    func parsePassphrase() throws {
        let cmd = try StatsCommand.parse(["--passphrase", "stats-key"])
        #expect(cmd.passphrase == "stats-key")
    }

    @Test("StatsCommand --quality enables quality flag")
    func parseQuality() throws {
        let cmd = try StatsCommand.parse(["--quality"])
        #expect(cmd.quality == true)
    }

    @Test("StatsCommand parses all options together")
    func allOptions() throws {
        let cmd = try StatsCommand.parse([
            "--host", "10.0.0.50", "--port", "4500", "--interval", "5",
            "--stream-id", "stats-stream", "--passphrase", "encrypted", "--quality"
        ])
        #expect(cmd.host == "10.0.0.50")
        #expect(cmd.port == 4500)
        #expect(cmd.interval == 5)
        #expect(cmd.streamID == "stats-stream")
        #expect(cmd.passphrase == "encrypted")
        #expect(cmd.quality == true)
    }

    @Test("StatsCommand rejects non-integer port")
    func rejectNonIntPort() {
        #expect(throws: (any Error).self) { try StatsCommand.parse(["--port", "xyz"]) }
    }

    @Test("StatsCommand rejects non-integer interval")
    func rejectNonIntInterval() {
        #expect(throws: (any Error).self) { try StatsCommand.parse(["--interval", "fast"]) }
    }

    @Test("StatsCommand rejects unknown option")
    func rejectUnknownOption() {
        #expect(throws: (any Error).self) { try StatsCommand.parse(["--duration", "10"]) }
    }

    @Test("StatsCommand rejects --quality with a value")
    func rejectQualityWithValue() {
        #expect(throws: (any Error).self) { try StatsCommand.parse(["--quality", "true"]) }
    }
}

// MARK: - InfoCommand Parsing Coverage

@Suite("InfoCommand Parsing Coverage")
struct InfoCommandParsingCoverageTests {

    @Test("InfoCommand command name is 'info'")
    func commandName() {
        #expect(InfoCommand.configuration.commandName == "info")
    }

    @Test("InfoCommand default verbose is false")
    func defaultVerbose() throws {
        let cmd = try InfoCommand.parse([])
        #expect(cmd.verbose == false)
    }

    @Test("InfoCommand --verbose enables verbose")
    func parseVerbose() throws {
        let cmd = try InfoCommand.parse(["--verbose"])
        #expect(cmd.verbose == true)
    }

    @Test("InfoCommand rejects unknown option")
    func rejectUnknownOption() {
        #expect(throws: (any Error).self) { try InfoCommand.parse(["--host", "localhost"]) }
    }

    @Test("InfoCommand rejects positional arguments")
    func rejectPositionalArgs() {
        #expect(throws: (any Error).self) { try InfoCommand.parse(["extra"]) }
    }
}

// MARK: - Cross-Command Parsing Coverage

@Suite("Cross-Command Parsing Coverage")
struct CrossCommandParsingCoverageTests {

    @Test("All six commands parse with no arguments")
    func allParseEmpty() throws {
        _ = try TestCommand.parse([])
        _ = try ProbeCommand.parse([])
        _ = try SendCommand.parse([])
        _ = try ReceiveCommand.parse([])
        _ = try StatsCommand.parse([])
        _ = try InfoCommand.parse([])
    }

    @Test("TestCommand and ProbeCommand have different default ports")
    func differentDefaultPorts() throws {
        let test = try TestCommand.parse([])
        let probe = try ProbeCommand.parse([])
        #expect(test.port == 9999)
        #expect(probe.port == 4200)
    }

    @Test("SendCommand and ReceiveCommand share default port 4200")
    func sendReceiveSharePort() throws {
        let send = try SendCommand.parse([])
        let receive = try ReceiveCommand.parse([])
        #expect(send.port == receive.port)
    }

    @Test("Command names are all distinct")
    func distinctCommandNames() {
        let names = [
            TestCommand.configuration.commandName,
            ProbeCommand.configuration.commandName,
            SendCommand.configuration.commandName,
            ReceiveCommand.configuration.commandName,
            StatsCommand.configuration.commandName,
            InfoCommand.configuration.commandName
        ]
        #expect(Set(names).count == names.count)
    }

    @Test("All command abstracts are non-empty")
    func allAbstractsNonEmpty() {
        #expect(!TestCommand.configuration.abstract.isEmpty)
        #expect(!ProbeCommand.configuration.abstract.isEmpty)
        #expect(!SendCommand.configuration.abstract.isEmpty)
        #expect(!ReceiveCommand.configuration.abstract.isEmpty)
        #expect(!StatsCommand.configuration.abstract.isEmpty)
        #expect(!InfoCommand.configuration.abstract.isEmpty)
    }
}
