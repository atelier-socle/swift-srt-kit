// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import SRTKit

/// Parses CLI preset strings to SRTKit types.
public struct PresetParser: Sendable {
    /// Parse a preset name string to SRTPreset.
    ///
    /// - Parameter name: Preset name (case-insensitive).
    /// - Returns: The matching SRTPreset.
    /// - Throws: CLIError.invalidPreset if no match.
    public static func parsePreset(_ name: String) throws -> SRTPreset {
        switch name.lowercased() {
        case "lowlatency":
            return .lowLatency
        case "balanced":
            return .balanced
        case "reliable":
            return .reliable
        case "highbandwidth":
            return .highBandwidth
        case "broadcast":
            return .broadcast
        case "filetransfer":
            return .fileTransfer
        default:
            throw CLIError.invalidPreset(name: name)
        }
    }

    /// Parse a server preset name string.
    ///
    /// - Parameter name: Server preset name (case-insensitive).
    /// - Returns: The matching SRTServerPreset.
    /// - Throws: CLIError.invalidPreset if no match.
    public static func parseServerPreset(
        _ name: String
    ) throws -> SRTServerPreset {
        switch name.lowercased() {
        case "awsmediaconnect":
            return .awsMediaConnect
        case "nimblestreamer":
            return .nimbleStreamer
        case "haivisionhub":
            return .haivisionHub
        case "vmix":
            return .vmix
        case "obsstudio":
            return .obsStudio
        case "srsserver":
            return .srsServer
        case "wowzastreaming":
            return .wowzaStreaming
        default:
            throw CLIError.invalidPreset(name: name)
        }
    }

    /// Parse a probe configuration name.
    ///
    /// - Parameter name: Probe mode name (case-insensitive).
    /// - Returns: The matching ProbeConfiguration.
    /// - Throws: CLIError.invalidProbeMode if no match.
    public static func parseProbeConfiguration(
        _ name: String
    ) throws -> ProbeConfiguration {
        switch name.lowercased() {
        case "quick":
            return .quick
        case "standard":
            return .standard
        case "thorough":
            return .thorough
        default:
            throw CLIError.invalidProbeMode(name: name)
        }
    }

    /// Parse a target quality name.
    ///
    /// - Parameter name: Target quality name (case-insensitive).
    /// - Returns: The matching TargetQuality.
    /// - Throws: CLIError.invalidTargetQuality if no match.
    public static func parseTargetQuality(
        _ name: String
    ) throws -> TargetQuality {
        switch name.lowercased() {
        case "quality":
            return .quality
        case "balanced":
            return .balanced
        case "lowlatency":
            return .lowLatency
        default:
            throw CLIError.invalidTargetQuality(name: name)
        }
    }
}
