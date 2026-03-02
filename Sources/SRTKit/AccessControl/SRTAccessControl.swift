// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Parsed SRT access control StreamID.
///
/// Supports both the structured `#!::` format and plain string format.
/// The `#!::` format uses key-value pairs separated by commas:
/// `#!::r=live/stream1,m=publish,u=broadcaster`
///
/// Standard keys: `r` (resource), `m` (mode), `s` (session ID),
/// `u` (user name), `t` (content type).
public struct SRTAccessControl: Sendable, Equatable {
    /// Stream access mode.
    public enum Mode: String, Sendable, CaseIterable {
        /// Receive mode (viewer).
        case request
        /// Send mode (broadcaster).
        case publish
        /// Both directions.
        case bidirectional
    }

    /// Content type.
    public enum ContentType: String, Sendable, CaseIterable {
        /// Live or recorded stream content.
        case stream
        /// File transfer content.
        case file
        /// Authentication-only content.
        case auth
    }

    /// Resource name (e.g., "live/stream1").
    public let resource: String?
    /// Stream access mode.
    public let mode: Mode?
    /// Session identifier.
    public let sessionID: String?
    /// Username for authentication.
    public let userName: String?
    /// Content type.
    public let contentType: ContentType?
    /// Additional custom key-value pairs not covered by standard keys.
    public let customKeys: [(key: String, value: String)]
    /// The original raw StreamID string.
    public let rawStreamID: String

    /// Creates a new access control instance.
    ///
    /// - Parameters:
    ///   - resource: Resource name.
    ///   - mode: Stream access mode.
    ///   - sessionID: Session identifier.
    ///   - userName: Username for authentication.
    ///   - contentType: Content type.
    ///   - customKeys: Additional custom key-value pairs.
    ///   - rawStreamID: The original raw StreamID string.
    public init(
        resource: String? = nil,
        mode: Mode? = nil,
        sessionID: String? = nil,
        userName: String? = nil,
        contentType: ContentType? = nil,
        customKeys: [(key: String, value: String)] = [],
        rawStreamID: String? = nil
    ) {
        self.resource = resource
        self.mode = mode
        self.sessionID = sessionID
        self.userName = userName
        self.contentType = contentType
        self.customKeys = customKeys
        self.rawStreamID = rawStreamID ?? ""
    }

    /// Parse a StreamID string into structured access control data.
    ///
    /// Supports both `#!::key=value,key=value` format and plain strings.
    /// Plain strings are treated as resource names.
    /// - Parameter streamID: The raw StreamID string.
    /// - Returns: The parsed access control data.
    public static func parse(_ streamID: String) -> SRTAccessControl {
        guard !streamID.isEmpty else {
            return SRTAccessControl(rawStreamID: streamID)
        }

        guard streamID.hasPrefix("#!::") else {
            return SRTAccessControl(resource: streamID, rawStreamID: streamID)
        }

        let payload = String(streamID.dropFirst(4))
        guard !payload.isEmpty else {
            return SRTAccessControl(rawStreamID: streamID)
        }

        return parseStructured(payload, rawStreamID: streamID)
    }

    /// Generate a StreamID string from structured data.
    ///
    /// Produces `#!::` format if structured keys are present,
    /// or plain resource name if only resource is set.
    /// - Returns: The generated StreamID string.
    public func generate() -> String {
        let hasStructuredFields =
            mode != nil || sessionID != nil
            || userName != nil || contentType != nil || !customKeys.isEmpty

        if !hasStructuredFields {
            return resource ?? ""
        }

        var pairs: [String] = []
        if let resource { pairs.append("r=\(resource)") }
        if let mode { pairs.append("m=\(mode.rawValue)") }
        if let sessionID { pairs.append("s=\(sessionID)") }
        if let userName { pairs.append("u=\(userName)") }
        if let contentType { pairs.append("t=\(contentType.rawValue)") }
        for custom in customKeys {
            pairs.append("\(custom.key)=\(custom.value)")
        }

        return "#!::\(pairs.joined(separator: ","))"
    }

    // MARK: - Equatable

    /// Compares two access control instances for equality.
    public static func == (lhs: SRTAccessControl, rhs: SRTAccessControl) -> Bool {
        lhs.resource == rhs.resource
            && lhs.mode == rhs.mode
            && lhs.sessionID == rhs.sessionID
            && lhs.userName == rhs.userName
            && lhs.contentType == rhs.contentType
            && lhs.customKeys.count == rhs.customKeys.count
            && zip(lhs.customKeys, rhs.customKeys).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }

    // MARK: - Private

    /// Parses the structured `key=value,key=value` payload.
    private static func parseStructured(
        _ payload: String,
        rawStreamID: String
    ) -> SRTAccessControl {
        var resource: String?
        var mode: Mode?
        var sessionID: String?
        var userName: String?
        var contentType: ContentType?
        var customKeys: [(key: String, value: String)] = []

        let pairs = payload.split(separator: ",", omittingEmptySubsequences: true)
        for pair in pairs {
            guard let eqIndex = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[pair.startIndex..<eqIndex])
            let value = String(pair[pair.index(after: eqIndex)...])

            switch key {
            case "r": resource = value
            case "m": mode = Mode(rawValue: value)
            case "s": sessionID = value
            case "u": userName = value
            case "t": contentType = ContentType(rawValue: value)
            default: customKeys.append((key: key, value: value))
            }
        }

        return SRTAccessControl(
            resource: resource,
            mode: mode,
            sessionID: sessionID,
            userName: userName,
            contentType: contentType,
            customKeys: customKeys,
            rawStreamID: rawStreamID
        )
    }
}
