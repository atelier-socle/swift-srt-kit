// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Main/Backup bonding logic.
///
/// Manages active/standby link selection, instability detection,
/// and seamless failover with sequence number synchronization.
public struct BackupStrategy: Sendable {
    /// Failover event.
    public struct FailoverEvent: Sendable, Equatable {
        /// Member that became unstable.
        public let fromMember: UInt32
        /// Member activated as replacement.
        public let toMember: UInt32
        /// Sequence number at failover point.
        public let atSequence: SequenceNumber
    }

    /// Result of a stability check.
    public enum StabilityCheckResult: Sendable {
        /// All stable, no action needed.
        case stable
        /// Failover triggered.
        case failover(FailoverEvent)
        /// Active link recovered from unstable.
        case recovered(memberID: UInt32)
        /// All links down, no backup available.
        case allLinksDown
    }

    /// The currently active member ID.
    public private(set) var activeMember: UInt32?

    /// Group sequence number.
    public var groupSequence: SequenceNumber

    /// History of failover events.
    private var failoverEvents: [FailoverEvent] = []

    /// Creates a backup strategy.
    ///
    /// - Parameter initialSequence: Initial group sequence number.
    public init(initialSequence: SequenceNumber = SequenceNumber(0)) {
        self.groupSequence = initialSequence
    }

    /// Activate the highest-weight idle member.
    ///
    /// - Parameter members: All group members (sorted by weight internally).
    /// - Returns: Activated member ID, or nil if none available.
    public mutating func activateHighestWeight(
        from members: [GroupMember]
    ) -> UInt32? {
        let idle =
            members
            .filter { $0.status == .idle }
            .sorted { $0.weight > $1.weight }
        guard let best = idle.first else { return nil }
        activeMember = best.id
        return best.id
    }

    /// Check link stability and trigger failover if needed.
    ///
    /// - Parameters:
    ///   - members: All group members.
    ///   - currentTime: Current time in microseconds.
    ///   - stabilityTimeout: Effective stability timeout.
    /// - Returns: Stability check result.
    public mutating func checkStability(
        members: [GroupMember],
        currentTime: UInt64,
        stabilityTimeout: UInt64
    ) -> StabilityCheckResult {
        guard let activeID = activeMember else {
            return .allLinksDown
        }

        guard let active = members.first(where: { $0.id == activeID }) else {
            return .allLinksDown
        }

        // Check if active link is unstable
        if active.status == .unstable || isTimedOut(active, at: currentTime, timeout: stabilityTimeout) {
            return attemptFailover(
                from: activeID, members: members)
        }

        // Check if previously unstable member recovered
        if active.status == .stable {
            return .stable
        }

        return .stable
    }

    /// Synchronize a member's sequence to the group sequence.
    ///
    /// - Parameter memberID: Member to synchronize.
    /// - Returns: Sequence number to set on the member.
    public func synchronizeSequence(for memberID: UInt32) -> SequenceNumber {
        groupSequence
    }

    /// Prepare a send — returns the active member ID.
    ///
    /// - Returns: Member ID to send on and sequence number, or nil if no active member.
    public mutating func prepareSend() -> (memberID: UInt32, sequenceNumber: SequenceNumber)? {
        guard let activeID = activeMember else { return nil }
        let seq = groupSequence
        groupSequence += 1
        return (memberID: activeID, sequenceNumber: seq)
    }

    /// Failover history.
    public var failoverHistory: [FailoverEvent] {
        failoverEvents
    }

    /// Total number of failovers.
    public var failoverCount: Int {
        failoverEvents.count
    }

    // MARK: - Private

    /// Check if a member has timed out.
    private func isTimedOut(
        _ member: GroupMember,
        at currentTime: UInt64,
        timeout: UInt64
    ) -> Bool {
        guard let lastResponse = member.lastResponseTime else {
            return false
        }
        return currentTime > lastResponse && (currentTime - lastResponse) > timeout
    }

    /// Attempt failover from the current active member.
    private mutating func attemptFailover(
        from activeID: UInt32,
        members: [GroupMember]
    ) -> StabilityCheckResult {
        let idle =
            members
            .filter { $0.status == .idle }
            .sorted { $0.weight > $1.weight }

        guard let backup = idle.first else {
            activeMember = nil
            return .allLinksDown
        }

        let event = FailoverEvent(
            fromMember: activeID,
            toMember: backup.id,
            atSequence: groupSequence
        )
        failoverEvents.append(event)
        activeMember = backup.id
        return .failover(event)
    }
}
