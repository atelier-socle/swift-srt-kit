// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Connection group actor for bonded SRT links.
///
/// Manages multiple SRT connections as a group, providing
/// broadcast, main/backup, or balancing bonding modes.
public actor SRTConnectionGroup {
    /// Group event.
    public enum GroupEvent: Sendable {
        /// Member status changed.
        case memberStatusChanged(
            memberID: UInt32, from: LinkStatus, to: LinkStatus)
        /// Failover occurred (main/backup mode).
        case failover(BackupStrategy.FailoverEvent)
        /// All links down.
        case allLinksDown
        /// Member added.
        case memberAdded(UInt32)
        /// Member removed.
        case memberRemoved(UInt32)
    }

    /// The group configuration.
    public let configuration: GroupConfiguration

    /// All group members.
    private var memberList: [GroupMember] = []

    /// Broadcast strategy (when mode is .broadcast).
    private var broadcastStrategy: BroadcastStrategy

    /// Backup strategy (when mode is .mainBackup).
    private var backupStrategy: BackupStrategy

    /// Balancing strategy (when mode is .balancing).
    private var balancingStrategy: BalancingStrategy

    /// Event stream continuation.
    private let eventContinuation: AsyncStream<GroupEvent>.Continuation

    /// Event stream backing storage.
    private let eventStream: AsyncStream<GroupEvent>

    /// Creates a connection group.
    ///
    /// - Parameter configuration: The group configuration.
    public init(configuration: GroupConfiguration) {
        self.configuration = configuration
        self.broadcastStrategy = BroadcastStrategy()
        self.backupStrategy = BackupStrategy()
        self.balancingStrategy = BalancingStrategy()

        let (stream, continuation) = AsyncStream.makeStream(
            of: GroupEvent.self)
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Add a member to the group.
    ///
    /// - Parameter member: The member to add.
    /// - Throws: ``BondingError/groupFull(maxMembers:)`` or ``BondingError/duplicateMember(id:)``.
    public func addMember(_ member: GroupMember) throws {
        guard memberList.count < configuration.maxMembers else {
            throw BondingError.groupFull(
                maxMembers: configuration.maxMembers)
        }
        guard !memberList.contains(where: { $0.id == member.id }) else {
            throw BondingError.duplicateMember(id: member.id)
        }
        memberList.append(member)
        eventContinuation.yield(.memberAdded(member.id))
    }

    /// Remove a member from the group.
    ///
    /// - Parameter id: The member ID to remove.
    public func removeMember(id: UInt32) {
        memberList.removeAll { $0.id == id }
        eventContinuation.yield(.memberRemoved(id))
    }

    /// Get all members.
    public var members: [GroupMember] {
        memberList
    }

    /// Get members filtered by status.
    ///
    /// - Parameter status: The status to filter by.
    /// - Returns: Members with the given status.
    public func members(withStatus status: LinkStatus) -> [GroupMember] {
        memberList.filter { $0.status == status }
    }

    /// Update a member's status.
    ///
    /// - Parameters:
    ///   - id: The member ID.
    ///   - status: The new status.
    /// - Throws: ``BondingError/memberNotFound(id:)`` or ``BondingError/invalidStatusTransition(from:to:)``.
    public func updateMemberStatus(
        id: UInt32, to status: LinkStatus
    ) throws {
        guard let index = memberList.firstIndex(where: { $0.id == id })
        else {
            throw BondingError.memberNotFound(id: id)
        }
        let current = memberList[index].status
        guard current.validTransitions.contains(status) else {
            throw BondingError.invalidStatusTransition(
                from: current, to: status)
        }
        memberList[index].status = status
        eventContinuation.yield(
            .memberStatusChanged(memberID: id, from: current, to: status))
    }

    /// Update a member's performance metrics.
    ///
    /// - Parameters:
    ///   - id: The member ID.
    ///   - lastResponseTime: Last peer response time.
    ///   - estimatedBandwidth: Estimated bandwidth.
    ///   - currentLoad: Current load.
    public func updateMemberMetrics(
        id: UInt32,
        lastResponseTime: UInt64?,
        estimatedBandwidth: UInt64?,
        currentLoad: Int?
    ) {
        guard let index = memberList.firstIndex(where: { $0.id == id })
        else { return }
        if let t = lastResponseTime {
            memberList[index].lastResponseTime = t
        }
        if let bw = estimatedBandwidth {
            memberList[index].estimatedBandwidth = bw
        }
        if let load = currentLoad {
            memberList[index].currentLoad = load
        }
    }

    /// Run a stability check (main/backup mode).
    ///
    /// - Parameter currentTime: Current time in microseconds.
    /// - Returns: Stability check result.
    public func checkStability(
        currentTime: UInt64
    ) -> BackupStrategy.StabilityCheckResult {
        let result = backupStrategy.checkStability(
            members: memberList,
            currentTime: currentTime,
            stabilityTimeout: configuration.effectiveStabilityTimeout
        )
        if case .failover(let event) = result {
            eventContinuation.yield(.failover(event))
        } else if case .allLinksDown = result {
            eventContinuation.yield(.allLinksDown)
        }
        return result
    }

    /// Prepare to send a packet.
    ///
    /// - Returns: Member IDs to send on and assigned sequence numbers.
    public func prepareSend() -> [(
        memberID: UInt32, sequenceNumber: SequenceNumber
    )] {
        switch configuration.mode {
        case .broadcast:
            let active = memberList.filter { $0.status.isActive }
                .map(\.id)
            let result = broadcastStrategy.prepareSend(
                activeMembers: active)
            return result.targets.map {
                (memberID: $0, sequenceNumber: result.sequenceNumber)
            }
        case .mainBackup:
            if let result = backupStrategy.prepareSend() {
                return [
                    (
                        memberID: result.memberID,
                        sequenceNumber: result.sequenceNumber
                    )
                ]
            }
            return []
        case .balancing:
            let active = memberList.filter { $0.status.isActive }
            if let selection = balancingStrategy.selectLink(
                from: active)
            {
                return [
                    (
                        memberID: selection.memberID,
                        sequenceNumber: SequenceNumber(selection.messageNumber)
                    )
                ]
            }
            return []
        }
    }

    /// Process a received packet.
    ///
    /// - Parameters:
    ///   - sequenceNumber: The packet's sequence number.
    ///   - payload: The packet payload.
    ///   - fromMember: Source member ID.
    ///   - messageNumber: Message number (for balancing mode).
    /// - Returns: Payloads ready for delivery.
    public func processReceive(
        sequenceNumber: SequenceNumber,
        payload: [UInt8],
        fromMember: UInt32,
        messageNumber: UInt32?
    ) -> [[UInt8]] {
        switch configuration.mode {
        case .broadcast:
            let result = broadcastStrategy.processReceive(
                sequenceNumber: sequenceNumber,
                payload: payload,
                fromMember: fromMember
            )
            if case .newPacket(let data, _) = result {
                return [data]
            }
            return []
        case .mainBackup:
            return [payload]
        case .balancing:
            if let msgNum = messageNumber {
                return balancingStrategy.processReceive(
                    messageNumber: msgNum,
                    payload: payload,
                    fromMember: fromMember
                )
            }
            return [payload]
        }
    }

    /// Event stream.
    public var events: AsyncStream<GroupEvent> {
        eventStream
    }

    /// Number of active members.
    public var activeMemberCount: Int {
        memberList.filter { $0.status.isActive }.count
    }

    /// Group mode.
    public var mode: GroupMode {
        configuration.mode
    }
}
