// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Convenience presets for common SRT use cases.
///
/// Each preset configures appropriate socket options for its
/// target use case. Apply a preset then customize further.
public enum SRTPreset: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Ultra-low latency for real-time communication.
    /// Latency=20ms, TLPKTDROP=true, LiveCC, auto BW.
    case lowLatency

    /// General-purpose live streaming (default).
    /// Latency=120ms, TLPKTDROP=true, LiveCC, auto BW.
    case balanced

    /// Reliable delivery for critical content.
    /// Latency=500ms, TLPKTDROP=false, LiveCC, auto BW.
    case reliable

    /// High bandwidth for 4K/8K content.
    /// Latency=120ms, TLPKTDROP=true, LiveCC, unlimited BW.
    case highBandwidth

    /// Broadcast contribution with overhead budget.
    /// Latency=120ms, TLPKTDROP=true, LiveCC, 25% overhead.
    case broadcast

    /// Bulk file transfer.
    /// No TSBPD, TLPKTDROP=false, FileCC, unlimited BW.
    case fileTransfer

    /// A human-readable description of this preset.
    public var description: String {
        switch self {
        case .lowLatency:
            "Low latency (20ms, real-time)"
        case .balanced:
            "Balanced (120ms, general live)"
        case .reliable:
            "Reliable (500ms, no drops)"
        case .highBandwidth:
            "High bandwidth (4K/8K, unlimited)"
        case .broadcast:
            "Broadcast (120ms, 25% overhead)"
        case .fileTransfer:
            "File transfer (no TSBPD, file CC)"
        }
    }

    /// Apply this preset's options to existing options.
    ///
    /// - Parameter options: The options to modify in place.
    public func apply(to options: inout SRTSocketOptions) {
        switch self {
        case .lowLatency:
            options.latency = 20_000
            options.peerLatency = 20_000
            options.tlpktdrop = true
            options.tsbpd = true
            options.congestionControl = "live"
            options.transmissionType = .live

        case .balanced:
            options.latency = 120_000
            options.peerLatency = 0
            options.tlpktdrop = true
            options.tsbpd = true
            options.congestionControl = "live"
            options.transmissionType = .live

        case .reliable:
            options.latency = 500_000
            options.peerLatency = 0
            options.tlpktdrop = false
            options.tsbpd = true
            options.congestionControl = "live"
            options.transmissionType = .live

        case .highBandwidth:
            options.latency = 120_000
            options.tlpktdrop = true
            options.tsbpd = true
            options.congestionControl = "live"
            options.maxBandwidth = 0
            options.sendBufferSize = 16_384
            options.receiveBufferSize = 16_384
            options.transmissionType = .live

        case .broadcast:
            options.latency = 120_000
            options.tlpktdrop = true
            options.tsbpd = true
            options.congestionControl = "live"
            options.overheadPercent = 25
            options.transmissionType = .live

        case .fileTransfer:
            options.latency = 0
            options.peerLatency = 0
            options.tlpktdrop = false
            options.tsbpd = false
            options.congestionControl = "file"
            options.maxBandwidth = 0
            options.transmissionType = .file
        }
    }

    /// Generate socket options for this preset.
    ///
    /// - Returns: A new ``SRTSocketOptions`` configured for this preset.
    public func socketOptions() -> SRTSocketOptions {
        var options = SRTSocketOptions()
        apply(to: &options)
        return options
    }

    /// Generate a full configuration for this preset.
    ///
    /// - Parameters:
    ///   - host: Remote host.
    ///   - port: Remote port (default: 4200).
    ///   - mode: Connection mode (default: .caller).
    /// - Returns: A fully configured ``SRTConfiguration``.
    public func configuration(
        host: String,
        port: Int = 4200,
        mode: SRTConfiguration.ConnectionMode = .caller
    ) -> SRTConfiguration {
        SRTConfiguration(
            host: host,
            port: port,
            mode: mode,
            options: socketOptions()
        )
    }
}
