// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builder pattern for SRTConfiguration.
///
/// Provides a fluent API for constructing configurations
/// with optional chaining. Each method returns a new builder
/// instance (immutable builder pattern).
public struct SRTConfigurationBuilder: Sendable {
    /// The configuration being built.
    private var configuration: SRTConfiguration

    /// Start building a configuration.
    ///
    /// - Parameters:
    ///   - host: Remote host.
    ///   - port: Remote port (default: 4200).
    public init(host: String, port: Int = 4200) {
        self.configuration = SRTConfiguration(host: host, port: port)
    }

    /// Set connection mode.
    ///
    /// - Parameter mode: The connection mode.
    /// - Returns: A new builder with the mode set.
    public func mode(
        _ mode: SRTConfiguration.ConnectionMode
    ) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.mode = mode
        return builder
    }

    /// Apply a preset.
    ///
    /// - Parameter preset: The preset to apply.
    /// - Returns: A new builder with preset options applied.
    public func preset(_ preset: SRTPreset) -> SRTConfigurationBuilder {
        var builder = self
        preset.apply(to: &builder.configuration.options)
        return builder
    }

    /// Apply a server preset.
    ///
    /// - Parameters:
    ///   - preset: The server preset to apply.
    ///   - resource: Resource name for StreamID (if applicable).
    /// - Returns: A new builder with server preset options applied.
    public func serverPreset(
        _ preset: SRTServerPreset,
        resource: String? = nil
    ) -> SRTConfigurationBuilder {
        var builder = self
        preset.apply(to: &builder.configuration.options)
        if preset.usesStreamID, let resource = resource {
            builder.configuration.accessControl = SRTAccessControl(
                resource: resource, mode: .publish)
        }
        return builder
    }

    /// Set latency.
    ///
    /// - Parameter microseconds: Latency in microseconds.
    /// - Returns: A new builder with the latency set.
    public func latency(microseconds: UInt64) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.options.latency = microseconds
        return builder
    }

    /// Set encryption.
    ///
    /// - Parameters:
    ///   - passphrase: Encryption passphrase.
    ///   - keySize: AES key size (default: .aes128).
    ///   - cipherMode: Cipher mode (default: .ctr).
    /// - Returns: A new builder with encryption configured.
    public func encryption(
        passphrase: String,
        keySize: KeySize = .aes128,
        cipherMode: CipherMode = .ctr
    ) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.options.passphrase = passphrase
        builder.configuration.options.keySize = keySize
        builder.configuration.options.cipherMode = cipherMode
        return builder
    }

    /// Set FEC.
    ///
    /// - Parameter fecConfiguration: FEC configuration.
    /// - Returns: A new builder with FEC configured.
    public func fec(_ fecConfiguration: FECConfiguration) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.options.fecConfiguration = fecConfiguration
        return builder
    }

    /// Set StreamID / access control.
    ///
    /// - Parameter accessControl: The access control configuration.
    /// - Returns: A new builder with access control set.
    public func streamID(
        _ accessControl: SRTAccessControl
    ) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.accessControl = accessControl
        return builder
    }

    /// Set max bandwidth.
    ///
    /// - Parameter bitsPerSecond: Maximum bandwidth in bits/second.
    /// - Returns: A new builder with max bandwidth set.
    public func maxBandwidth(
        _ bitsPerSecond: UInt64
    ) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.options.maxBandwidth = bitsPerSecond
        return builder
    }

    /// Set congestion control.
    ///
    /// - Parameter name: Congestion control algorithm name.
    /// - Returns: A new builder with congestion control set.
    public func congestionControl(
        _ name: String
    ) -> SRTConfigurationBuilder {
        var builder = self
        builder.configuration.options.congestionControl = name
        return builder
    }

    /// Build and validate the configuration.
    ///
    /// - Returns: A validated ``SRTConfiguration``.
    /// - Throws: ``SRTConfigurationError`` on validation failure.
    public func build() throws -> SRTConfiguration {
        let config = configuration
        try config.validate()
        return config
    }

    /// Build without validation.
    ///
    /// - Returns: The ``SRTConfiguration`` without validation.
    public func buildUnchecked() -> SRTConfiguration {
        configuration
    }
}
