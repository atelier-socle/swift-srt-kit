// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Presets for interoperability with popular SRT products.
///
/// Each preset configures socket options, latency, encryption,
/// and StreamID format for optimal compatibility with the target
/// product.
public enum SRTServerPreset: String, Sendable, CaseIterable, CustomStringConvertible {
    /// AWS Elemental MediaConnect SRT input.
    case awsMediaConnect
    /// Softvelum Nimble Streamer.
    case nimbleStreamer
    /// Haivision SRT Hub / Media Gateway.
    case haivisionHub
    /// vMix SRT caller/listener.
    case vmix
    /// OBS Studio SRT output/listener.
    case obsStudio
    /// SRS (Simple Realtime Server) SRT.
    case srsServer
    /// Wowza Streaming Engine SRT.
    case wowzaStreaming

    /// A human-readable description of this server preset.
    public var description: String {
        switch self {
        case .awsMediaConnect:
            "AWS Elemental MediaConnect"
        case .nimbleStreamer:
            "Softvelum Nimble Streamer"
        case .haivisionHub:
            "Haivision SRT Hub / Media Gateway"
        case .vmix:
            "vMix"
        case .obsStudio:
            "OBS Studio"
        case .srsServer:
            "SRS (Simple Realtime Server)"
        case .wowzaStreaming:
            "Wowza Streaming Engine"
        }
    }

    /// Default port for this server product.
    public var defaultPort: Int {
        switch self {
        case .awsMediaConnect: 4200
        case .nimbleStreamer: 4200
        case .haivisionHub: 4200
        case .vmix: 4200
        case .obsStudio: 4200
        case .srsServer: 10080
        case .wowzaStreaming: 9710
        }
    }

    /// Whether this server typically requires encryption.
    public var requiresEncryption: Bool {
        switch self {
        case .awsMediaConnect: true
        case .nimbleStreamer: false
        case .haivisionHub: true
        case .vmix: false
        case .obsStudio: false
        case .srsServer: false
        case .wowzaStreaming: true
        }
    }

    /// Whether this server uses StreamID.
    public var usesStreamID: Bool {
        switch self {
        case .awsMediaConnect: true
        case .nimbleStreamer: true
        case .haivisionHub: true
        case .vmix: false
        case .obsStudio: false
        case .srsServer: true
        case .wowzaStreaming: true
        }
    }

    /// StreamID format hint for documentation.
    public var streamIDFormat: String? {
        switch self {
        case .awsMediaConnect: "#!::r=<id>,m=publish"
        case .nimbleStreamer: "#!::r=<path>"
        case .haivisionHub: "#!::r=<feed>,u=<user>"
        case .vmix: nil
        case .obsStudio: nil
        case .srsServer: "#!::r=<app>/<stream>"
        case .wowzaStreaming: "#!::r=<app>/<stream>"
        }
    }

    /// Apply this server preset to existing options.
    ///
    /// - Parameter options: The options to modify in place.
    public func apply(to options: inout SRTSocketOptions) {
        switch self {
        case .awsMediaConnect:
            options.latency = 1_000_000
            options.sendBufferSize = 16_384
            options.receiveBufferSize = 16_384
            options.keySize = .aes128
            options.cipherMode = .ctr

        case .nimbleStreamer:
            options.latency = 500_000
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192

        case .haivisionHub:
            options.latency = 120_000
            options.keySize = .aes256
            options.cipherMode = .ctr
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192

        case .vmix:
            options.latency = 120_000
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192

        case .obsStudio:
            options.latency = 120_000
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192

        case .srsServer:
            options.latency = 120_000
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192

        case .wowzaStreaming:
            options.latency = 500_000
            options.keySize = .aes128
            options.cipherMode = .ctr
            options.sendBufferSize = 8192
            options.receiveBufferSize = 8192
        }
    }

    /// Generate socket options for this server.
    ///
    /// - Returns: A new ``SRTSocketOptions`` configured for this server.
    public func socketOptions() -> SRTSocketOptions {
        var options = SRTSocketOptions()
        apply(to: &options)
        return options
    }

    /// Generate a full configuration for this server.
    ///
    /// - Parameters:
    ///   - host: Server host.
    ///   - port: Server port (nil = use default port for this server).
    ///   - resource: Resource name for StreamID (if applicable).
    ///   - user: User name for StreamID (if applicable).
    /// - Returns: A fully configured ``SRTConfiguration``.
    public func configuration(
        host: String,
        port: Int? = nil,
        resource: String? = nil,
        user: String? = nil
    ) -> SRTConfiguration {
        let effectivePort = port ?? defaultPort
        let options = socketOptions()

        var accessControl: SRTAccessControl?
        if usesStreamID, let resource = resource {
            accessControl = SRTAccessControl(
                resource: resource,
                mode: .publish,
                userName: user
            )
        }

        return SRTConfiguration(
            host: host,
            port: effectivePort,
            mode: .caller,
            options: options,
            accessControl: accessControl
        )
    }
}
