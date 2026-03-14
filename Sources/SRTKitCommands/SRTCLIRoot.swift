// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the srt-cli tool.
public struct SRTCLIRoot: AsyncParsableCommand {
    /// Configuration for the CLI command.
    public static let configuration = CommandConfiguration(
        commandName: "srt-cli",
        abstract: "SRT streaming toolkit — pure Swift implementation",
        version: "0.3.0",
        subcommands: [
            SendCommand.self,
            ReceiveCommand.self,
            StatsCommand.self,
            TestCommand.self,
            ProbeCommand.self,
            InfoCommand.self
        ]
    )

    /// Creates a new instance of the root command.
    public init() {}
}
