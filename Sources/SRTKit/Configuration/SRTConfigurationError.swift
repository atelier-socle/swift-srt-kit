// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from configuration operations.
public enum SRTConfigurationError: Error, Sendable, Equatable, CustomStringConvertible {
    /// One or more validation errors.
    case validationFailed(errors: [SRTOptionValidation.ValidationError])
    /// Host is empty.
    case emptyHost
    /// Port out of range (1-65535).
    case portOutOfRange(got: Int)
    /// Caller mode requires a host.
    case callerRequiresHost
    /// Listener mode requires a port.
    case listenerRequiresPort

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .validationFailed(let errors):
            "Validation failed: \(errors.map(\.description).joined(separator: ", "))"
        case .emptyHost:
            "Host must not be empty"
        case .portOutOfRange(let got):
            "Port \(got) out of valid range 1-65535"
        case .callerRequiresHost:
            "Caller mode requires a non-empty host"
        case .listenerRequiresPort:
            "Listener mode requires a valid port"
        }
    }
}
