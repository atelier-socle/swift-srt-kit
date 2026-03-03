// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// High-level SRT connection configuration.
///
/// Combines socket options, access control, and connection metadata
/// into a single configuration object. Can be created from presets
/// or built manually.
public struct SRTConfiguration: Sendable {
    /// Connection mode.
    public enum ConnectionMode: String, Sendable, CaseIterable {
        /// Initiates connection to a remote listener.
        case caller
        /// Accepts incoming connections.
        case listener
        /// Both sides initiate simultaneously.
        case rendezvous
    }

    /// Remote host (for caller/rendezvous).
    public var host: String

    /// Port number.
    public var port: Int

    /// Connection mode.
    public var mode: ConnectionMode

    /// Socket options.
    public var options: SRTSocketOptions

    /// Access control / StreamID (nil = no StreamID).
    public var accessControl: SRTAccessControl?

    /// Create a configuration with defaults.
    ///
    /// - Parameters:
    ///   - host: Remote host (default: "0.0.0.0").
    ///   - port: Port number (default: 4200).
    ///   - mode: Connection mode (default: .caller).
    ///   - options: Socket options (default: .default).
    ///   - accessControl: Access control / StreamID (default: nil).
    public init(
        host: String = "0.0.0.0",
        port: Int = 4200,
        mode: ConnectionMode = .caller,
        options: SRTSocketOptions = .default,
        accessControl: SRTAccessControl? = nil
    ) {
        self.host = host
        self.port = port
        self.mode = mode
        self.options = options
        self.accessControl = accessControl
    }

    /// Validate the configuration.
    ///
    /// - Throws: ``SRTConfigurationError`` on validation failure.
    public func validate() throws {
        // Port range
        guard (1...65535).contains(port) else {
            throw SRTConfigurationError.portOutOfRange(got: port)
        }

        // Caller requires non-empty host
        if mode == .caller && host.isEmpty {
            throw SRTConfigurationError.callerRequiresHost
        }

        // Validate socket options
        let errors = SRTOptionValidation.validate(options)
        if !errors.isEmpty {
            throw SRTConfigurationError.validationFailed(errors: errors)
        }
    }

    /// Create a `SRTCaller.Configuration` from this configuration.
    ///
    /// - Returns: A caller configuration with mapped fields.
    public func callerConfiguration() -> SRTCaller.Configuration {
        SRTCaller.Configuration(
            host: host,
            port: port,
            connectTimeout: options.connectTimeout,
            streamID: accessControl?.generate(),
            passphrase: options.passphrase,
            keySize: options.keySize,
            cipherMode: options.cipherMode,
            latency: options.latency,
            congestionControl: options.congestionControl,
            fecConfiguration: options.fecConfiguration
        )
    }

    /// Create a `SRTListener.Configuration` from this configuration.
    ///
    /// - Returns: A listener configuration with mapped fields.
    public func listenerConfiguration() -> SRTListener.Configuration {
        SRTListener.Configuration(
            host: host,
            port: port,
            passphrase: options.passphrase,
            keySize: options.keySize,
            cipherMode: options.cipherMode,
            latency: options.latency
        )
    }
}
