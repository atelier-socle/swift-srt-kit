// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Decision output from a congestion controller.
///
/// Returned after processing an event, tells the connection
/// layer how to adjust sending behavior.
public struct CongestionDecision: Sendable, Equatable {
    /// Congestion window size in packets (nil = no change).
    public let congestionWindow: Int?

    /// Sending period / pacing interval in microseconds (nil = no change).
    public let sendingPeriodMicroseconds: UInt64?

    /// Whether to drop current packet (too-late, buffer full).
    public let shouldDrop: Bool

    /// Recommended max send rate in bits/second (nil = no change).
    public let maxSendRateBps: UInt64?

    /// Create a congestion decision.
    ///
    /// - Parameters:
    ///   - congestionWindow: Congestion window size (nil = no change).
    ///   - sendingPeriodMicroseconds: Pacing interval (nil = no change).
    ///   - shouldDrop: Whether to drop the packet.
    ///   - maxSendRateBps: Recommended max send rate (nil = no change).
    public init(
        congestionWindow: Int? = nil,
        sendingPeriodMicroseconds: UInt64? = nil,
        shouldDrop: Bool = false,
        maxSendRateBps: UInt64? = nil
    ) {
        self.congestionWindow = congestionWindow
        self.sendingPeriodMicroseconds = sendingPeriodMicroseconds
        self.shouldDrop = shouldDrop
        self.maxSendRateBps = maxSendRateBps
    }

    /// No changes needed.
    public static let noChange = CongestionDecision()

    /// Drop the current packet.
    public static let drop = CongestionDecision(shouldDrop: true)
}
