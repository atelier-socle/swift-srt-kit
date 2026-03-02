// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages connection lifecycle, keepalive, and shutdown detection.
///
/// Pure logic component — computes what actions to take based on
/// time and events. Does NOT schedule timers or send packets directly.
public struct ConnectionManager: Sendable {
    /// Action the connection actor should take.
    public enum Action: Sendable, Equatable {
        /// Send a keepalive packet.
        case sendKeepalive
        /// Connection timed out (no response from peer).
        case timeout
        /// Initiate graceful shutdown.
        case initiateShutdown
        /// Shutdown complete.
        case shutdownComplete
        /// No action needed.
        case none
    }

    /// Configuration for connection management.
    public struct Configuration: Sendable {
        /// Keepalive interval in microseconds (default: 1 second).
        public let keepaliveInterval: UInt64
        /// Keepalive timeout in microseconds (default: 5 seconds).
        /// If no response for this duration, connection is broken.
        public let keepaliveTimeout: UInt64
        /// Shutdown timeout in microseconds (default: 3 seconds).
        public let shutdownTimeout: UInt64

        /// Creates a connection manager configuration.
        ///
        /// - Parameters:
        ///   - keepaliveInterval: Interval between keepalive sends in microseconds.
        ///   - keepaliveTimeout: Timeout before connection is considered broken.
        ///   - shutdownTimeout: Timeout for graceful shutdown to complete.
        public init(
            keepaliveInterval: UInt64 = 1_000_000,
            keepaliveTimeout: UInt64 = 5_000_000,
            shutdownTimeout: UInt64 = 3_000_000
        ) {
            self.keepaliveInterval = keepaliveInterval
            self.keepaliveTimeout = keepaliveTimeout
            self.shutdownTimeout = shutdownTimeout
        }
    }

    /// The connection manager configuration.
    public let configuration: Configuration

    /// Time of last response from peer in microseconds.
    private var lastPeerResponseTime: UInt64?

    /// Time of last keepalive sent in microseconds.
    private var lastKeepaliveSentTime: UInt64?

    /// Time shutdown was initiated in microseconds.
    private var shutdownStartTime: UInt64?

    /// Whether shutdown has been initiated.
    private var shuttingDown: Bool = false

    /// Creates a connection manager.
    ///
    /// - Parameter configuration: The connection manager configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    /// Record that a packet was received from the peer.
    ///
    /// - Parameter time: Current time in microseconds.
    public mutating func peerResponseReceived(at time: UInt64) {
        lastPeerResponseTime = time
    }

    /// Record that a keepalive was sent.
    ///
    /// - Parameter time: Current time in microseconds.
    public mutating func keepaliveSent(at time: UInt64) {
        lastKeepaliveSentTime = time
    }

    /// Check what action is needed based on current time.
    ///
    /// - Parameter currentTime: Current time in microseconds.
    /// - Returns: Action to take.
    public func check(at currentTime: UInt64) -> Action {
        if shuttingDown {
            if let start = shutdownStartTime,
                currentTime >= start + configuration.shutdownTimeout
            {
                return .shutdownComplete
            }
            return .initiateShutdown
        }

        guard let lastResponse = lastPeerResponseTime else {
            return .none
        }

        if currentTime >= lastResponse + configuration.keepaliveTimeout {
            return .timeout
        }

        let lastSent = lastKeepaliveSentTime ?? 0
        if currentTime >= lastSent + configuration.keepaliveInterval {
            return .sendKeepalive
        }

        return .none
    }

    /// Initiate graceful shutdown.
    ///
    /// - Parameter time: Current time in microseconds.
    public mutating func beginShutdown(at time: UInt64) {
        shuttingDown = true
        shutdownStartTime = time
    }

    /// Whether shutdown has been initiated.
    public var isShuttingDown: Bool { shuttingDown }

    /// Time of last peer response in microseconds.
    public var lastPeerResponse: UInt64? { lastPeerResponseTime }

    /// Time since last peer response.
    ///
    /// - Parameter currentTime: Current time in microseconds.
    /// - Returns: Duration since last response, or nil if no response recorded.
    public func timeSinceLastResponse(at currentTime: UInt64) -> UInt64? {
        guard let last = lastPeerResponseTime else { return nil }
        return currentTime - last
    }
}
