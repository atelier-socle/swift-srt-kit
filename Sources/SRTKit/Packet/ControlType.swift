// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The type of an SRT control packet.
///
/// Control types are encoded in bits 1-15 of word 0 of a control packet header.
public enum ControlType: UInt16, Sendable, CaseIterable, Hashable, CustomStringConvertible {
    /// Handshake control packet.
    case handshake = 0x0000
    /// Keep-alive control packet.
    case keepalive = 0x0001
    /// Acknowledgement control packet.
    case ack = 0x0002
    /// Negative acknowledgement (loss report) control packet.
    case nak = 0x0003
    /// Congestion warning control packet.
    case congestion = 0x0004
    /// Shutdown control packet.
    case shutdown = 0x0005
    /// Acknowledgement of acknowledgement control packet.
    case ackack = 0x0006
    /// Drop request control packet.
    case dropreq = 0x0007
    /// Peer error control packet.
    case peererror = 0x0008
    /// User-defined control packet type.
    case userDefined = 0x7FFF

    /// A human-readable description of the control type.
    public var description: String {
        switch self {
        case .handshake: "handshake"
        case .keepalive: "keepalive"
        case .ack: "ack"
        case .nak: "nak"
        case .congestion: "congestion"
        case .shutdown: "shutdown"
        case .ackack: "ackack"
        case .dropreq: "dropreq"
        case .peererror: "peererror"
        case .userDefined: "userDefined"
        }
    }
}
