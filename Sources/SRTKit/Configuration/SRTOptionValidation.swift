// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validates SRT socket options.
public enum SRTOptionValidation: Sendable {
    /// Validation error.
    public enum ValidationError: Error, Sendable, Equatable, CustomStringConvertible {
        /// Passphrase is shorter than minimum length.
        case passphraseTooShort(length: Int, minimum: Int)
        /// Passphrase is longer than maximum length.
        case passphraseTooLong(length: Int, maximum: Int)
        /// Payload size is outside the valid range.
        case payloadSizeOutOfRange(got: Int, range: ClosedRange<Int>)
        /// Overhead percent is outside the valid range.
        case overheadPercentOutOfRange(got: Int, range: ClosedRange<Int>)
        /// Buffer size is too small.
        case bufferSizeTooSmall(name: String, got: Int, minimum: Int)
        /// Latency is negative (should not happen with UInt64 but validates peerLatency logic).
        case latencyNegative
        /// IP TTL is outside the valid range.
        case ipTTLOutOfRange(got: Int, range: ClosedRange<Int>)
        /// IP TOS is outside the valid range.
        case ipTOSOutOfRange(got: Int, range: ClosedRange<Int>)
        /// Key pre-announce interval exceeds refresh rate.
        case kmPreAnnounceExceedsRefreshRate(preAnnounce: UInt64, refreshRate: UInt64)

        /// A human-readable description of the validation error.
        public var description: String {
            switch self {
            case .passphraseTooShort(let length, let minimum):
                "Passphrase too short: \(length) characters, minimum \(minimum)"
            case .passphraseTooLong(let length, let maximum):
                "Passphrase too long: \(length) characters, maximum \(maximum)"
            case .payloadSizeOutOfRange(let got, let range):
                "Payload size \(got) out of range \(range)"
            case .overheadPercentOutOfRange(let got, let range):
                "Overhead percent \(got) out of range \(range)"
            case .bufferSizeTooSmall(let name, let got, let minimum):
                "Buffer '\(name)' size \(got) below minimum \(minimum)"
            case .latencyNegative:
                "Latency must not be negative"
            case .ipTTLOutOfRange(let got, let range):
                "IP TTL \(got) out of range \(range)"
            case .ipTOSOutOfRange(let got, let range):
                "IP TOS \(got) out of range \(range)"
            case .kmPreAnnounceExceedsRefreshRate(let preAnnounce, let refreshRate):
                "Key pre-announce \(preAnnounce) exceeds refresh rate \(refreshRate)"
            }
        }
    }

    /// Valid range for payload size.
    public static let payloadSizeRange: ClosedRange<Int> = 72...1500

    /// Valid range for overhead percent.
    public static let overheadPercentRange: ClosedRange<Int> = 5...100

    /// Valid range for IP TTL.
    public static let ipTTLRange: ClosedRange<Int> = 1...255

    /// Valid range for IP TOS.
    public static let ipTOSRange: ClosedRange<Int> = 0...255

    /// Minimum passphrase length.
    public static let minPassphraseLength: Int = 10

    /// Maximum passphrase length.
    public static let maxPassphraseLength: Int = 79

    /// Minimum buffer size.
    public static let minBufferSize: Int = 1

    /// Validate a complete set of socket options.
    ///
    /// - Parameter options: The options to validate.
    /// - Returns: Array of validation errors (empty = valid).
    public static func validate(_ options: SRTSocketOptions) -> [ValidationError] {
        var errors: [ValidationError] = []
        validateEncryptionAndSizes(options, into: &errors)
        validateNetworkAndKeyRotation(options, into: &errors)
        return errors
    }

    /// Validate passphrase, payload, overhead, and buffer sizes.
    private static func validateEncryptionAndSizes(
        _ options: SRTSocketOptions,
        into errors: inout [ValidationError]
    ) {
        if let passphrase = options.passphrase {
            if passphrase.count < minPassphraseLength {
                errors.append(
                    .passphraseTooShort(
                        length: passphrase.count, minimum: minPassphraseLength))
            }
            if passphrase.count > maxPassphraseLength {
                errors.append(
                    .passphraseTooLong(
                        length: passphrase.count, maximum: maxPassphraseLength))
            }
        }

        if !payloadSizeRange.contains(options.maxPayloadSize) {
            errors.append(
                .payloadSizeOutOfRange(
                    got: options.maxPayloadSize, range: payloadSizeRange))
        }

        if !overheadPercentRange.contains(options.overheadPercent) {
            errors.append(
                .overheadPercentOutOfRange(
                    got: options.overheadPercent, range: overheadPercentRange))
        }

        validateBufferSize("sendBuffer", options.sendBufferSize, into: &errors)
        validateBufferSize("receiveBuffer", options.receiveBufferSize, into: &errors)
        validateBufferSize("flowWindow", options.flowWindowSize, into: &errors)
    }

    /// Validate a single buffer size.
    private static func validateBufferSize(
        _ name: String, _ size: Int,
        into errors: inout [ValidationError]
    ) {
        if size < minBufferSize {
            errors.append(
                .bufferSizeTooSmall(
                    name: name, got: size, minimum: minBufferSize))
        }
    }

    /// Validate IP and key rotation parameters.
    private static func validateNetworkAndKeyRotation(
        _ options: SRTSocketOptions,
        into errors: inout [ValidationError]
    ) {
        if !ipTTLRange.contains(options.ipTTL) {
            errors.append(
                .ipTTLOutOfRange(got: options.ipTTL, range: ipTTLRange))
        }

        if !ipTOSRange.contains(options.ipTOS) {
            errors.append(
                .ipTOSOutOfRange(got: options.ipTOS, range: ipTOSRange))
        }

        if options.kmPreAnnounce > options.kmRefreshRate {
            errors.append(
                .kmPreAnnounceExceedsRefreshRate(
                    preAnnounce: options.kmPreAnnounce,
                    refreshRate: options.kmRefreshRate))
        }
    }

    /// Validate and throw on first error.
    ///
    /// - Parameter options: The options to validate.
    /// - Throws: The first ``ValidationError`` found.
    public static func validateOrThrow(_ options: SRTSocketOptions) throws {
        let errors = validate(options)
        if let first = errors.first {
            throw first
        }
    }
}
