// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the SRT CLI tool.
public struct SRTCLIRoot: ParsableCommand {
    /// Configuration for the CLI command.
    public static let configuration = CommandConfiguration(
        commandName: "srt-cli",
        abstract: "Pure Swift SRT protocol tool",
        version: "0.1.0"
    )

    /// Creates a new instance of the root command.
    public init() {}

    /// Runs the root command.
    public func run() throws {
        print("srt-cli — Pure Swift SRT protocol tool")
        print("Use --help for available commands.")
    }
}
