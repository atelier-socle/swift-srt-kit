// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import SRTKit

/// Builds SRTCaller and SRTListener configurations from CLI arguments.
public struct ConfigurationFactory: Sendable {

    /// Optional caller connection parameters.
    public struct CallerOptions: Sendable {
        /// Optional StreamID for access control.
        public let streamID: String?
        /// Optional encryption passphrase.
        public let passphrase: String?
        /// Optional preset name (e.g., "lowLatency").
        public let preset: String?
        /// Optional latency override in milliseconds.
        public let latency: Int?

        /// Creates caller options.
        public init(
            streamID: String? = nil,
            passphrase: String? = nil,
            preset: String? = nil,
            latency: Int? = nil
        ) {
            self.streamID = streamID
            self.passphrase = passphrase
            self.preset = preset
            self.latency = latency
        }
    }

    /// Build a caller configuration from CLI arguments.
    ///
    /// - Parameters:
    ///   - host: Remote host.
    ///   - port: Remote port.
    ///   - options: Optional caller parameters.
    /// - Returns: A configured `SRTCaller.Configuration`.
    /// - Throws: ``CLIError`` if preset name is invalid.
    public static func callerConfiguration(
        host: String,
        port: Int,
        options: CallerOptions = CallerOptions()
    ) throws -> SRTCaller.Configuration {
        var latencyUs: UInt64 = 120_000
        var keySize: KeySize = .aes128
        var cipherMode: CipherMode = .ctr

        if let presetName = options.preset {
            let srtPreset = try PresetParser.parsePreset(presetName)
            let opts = srtPreset.socketOptions()
            latencyUs = opts.latency
            keySize = opts.keySize
            cipherMode = opts.cipherMode
        }

        if let ms = options.latency {
            latencyUs = UInt64(ms) * 1000
        }

        if let passphrase = options.passphrase {
            return SRTCaller.Configuration(
                host: host,
                port: port,
                streamID: options.streamID,
                passphrase: passphrase,
                keySize: keySize,
                cipherMode: cipherMode,
                latency: latencyUs
            )
        }

        return SRTCaller.Configuration(
            host: host,
            port: port,
            streamID: options.streamID,
            latency: latencyUs
        )
    }

    /// Build a listener configuration from CLI arguments.
    ///
    /// - Parameters:
    ///   - bind: Bind address.
    ///   - port: Listen port.
    ///   - passphrase: Optional encryption passphrase.
    ///   - latency: Optional latency override in milliseconds.
    /// - Returns: A configured `SRTListener.Configuration`.
    public static func listenerConfiguration(
        bind: String,
        port: Int,
        passphrase: String?,
        latency: Int?
    ) -> SRTListener.Configuration {
        let latencyUs: UInt64 =
            latency.map { UInt64($0) * 1000 } ?? 120_000

        if let passphrase {
            return SRTListener.Configuration(
                host: bind,
                port: port,
                passphrase: passphrase,
                latency: latencyUs
            )
        }

        return SRTListener.Configuration(
            host: bind,
            port: port,
            latency: latencyUs
        )
    }
}
