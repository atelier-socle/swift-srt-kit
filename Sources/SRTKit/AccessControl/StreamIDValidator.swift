// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validates StreamID strings and access control rules.
///
/// Checks length limits, format correctness, and access control completeness
/// according to the SRT specification.
public enum StreamIDValidator: Sendable {
    /// Maximum StreamID length in bytes (SRT spec limit).
    public static let maxLength: Int = 512

    /// Validation error for StreamID.
    public enum ValidationError: Error, Sendable, CustomStringConvertible {
        /// The StreamID exceeds the maximum allowed length.
        case tooLong(length: Int, maxLength: Int)
        /// The StreamID has an invalid format.
        case invalidFormat(reason: String)
        /// The resource field is empty in a structured StreamID.
        case emptyResource
        /// The mode string is not a valid access mode.
        case invalidMode(String)
        /// The content type string is not a valid content type.
        case invalidContentType(String)

        /// A human-readable description of the validation error.
        public var description: String {
            switch self {
            case .tooLong(let length, let maxLen):
                "StreamID too long: \(length) bytes (max \(maxLen))"
            case .invalidFormat(let reason):
                "Invalid StreamID format: \(reason)"
            case .emptyResource:
                "Empty resource in StreamID"
            case .invalidMode(let mode):
                "Invalid mode: \(mode)"
            case .invalidContentType(let ct):
                "Invalid content type: \(ct)"
            }
        }
    }

    /// Validate a StreamID string.
    ///
    /// Checks length limits and, for structured format, validates key-value pairs.
    /// - Parameter streamID: The StreamID string to validate.
    /// - Returns: nil if valid, or a ``ValidationError`` describing the issue.
    public static func validate(_ streamID: String) -> ValidationError? {
        let byteCount = streamID.utf8.count
        if byteCount > maxLength {
            return .tooLong(length: byteCount, maxLength: maxLength)
        }

        guard streamID.hasPrefix("#!::") else { return nil }

        let payload = String(streamID.dropFirst(4))
        guard !payload.isEmpty else { return nil }

        return validateStructuredPayload(payload)
    }

    /// Validate a parsed ``SRTAccessControl`` for completeness.
    ///
    /// Checks that required fields are present based on mode.
    /// For publish or bidirectional modes, a resource is required.
    /// - Parameter ac: The parsed access control to validate.
    /// - Returns: nil if valid, or a ``ValidationError`` describing the issue.
    public static func validateAccessControl(
        _ ac: SRTAccessControl
    ) -> ValidationError? {
        if let mode = ac.mode {
            switch mode {
            case .publish, .bidirectional:
                if ac.resource == nil || ac.resource?.isEmpty == true {
                    return .emptyResource
                }
            case .request:
                break
            }
        }
        return nil
    }

    // MARK: - Private

    /// Validates the key-value pairs in a structured StreamID payload.
    private static func validateStructuredPayload(
        _ payload: String
    ) -> ValidationError? {
        let pairs = payload.split(separator: ",", omittingEmptySubsequences: true)
        for pair in pairs {
            guard let eqIndex = pair.firstIndex(of: "=") else {
                return .invalidFormat(reason: "Missing '=' in pair: \(pair)")
            }
            let key = String(pair[pair.startIndex..<eqIndex])
            let value = String(pair[pair.index(after: eqIndex)...])

            switch key {
            case "r":
                if value.isEmpty { return .emptyResource }
            case "m":
                if SRTAccessControl.Mode(rawValue: value) == nil {
                    return .invalidMode(value)
                }
            case "t":
                if SRTAccessControl.ContentType(rawValue: value) == nil {
                    return .invalidContentType(value)
                }
            default:
                break
            }
        }
        return nil
    }
}
