# Bonding Guide

Aggregate multiple links with ``SRTConnectionGroup``.

## Overview

Connection bonding allows multiple SRT links to operate as a single logical connection. SRTKit supports three bonding modes: broadcast (send on all links), main/backup (automatic failover), and balancing (aggregate bandwidth). All bonding operations are managed through the ``SRTConnectionGroup`` actor.

### Group Modes

``GroupMode`` defines the bonding strategy:

```swift
GroupMode.broadcast.description   // "Broadcast (all links)"
GroupMode.mainBackup.description  // "Main/Backup (failover)"
GroupMode.balancing.description   // "Balancing (aggregate)"
```

| Mode | Description | Use Case |
|------|-------------|----------|
| `.broadcast` | Send on all active links simultaneously | Maximum reliability |
| `.mainBackup` | Use primary link, fail over to backup | Zero-interruption failover |
| `.balancing` | Distribute across links by weight | Maximum aggregate bandwidth |

### Group Configuration

```swift
let config = GroupConfiguration(
    mode: .mainBackup,
    stabilityTimeout: 40_000,   // 40ms
    peerLatency: 120_000)       // 120ms

// effectiveStabilityTimeout = max(peerLatency, stabilityTimeout)
config.effectiveStabilityTimeout  // 120_000
```

### Group Members

``GroupMember`` represents a single link in the group:

```swift
let member = GroupMember(
    id: 1, host: "cdn1.example.com",
    port: 4200, weight: 10)
member.status   // .pending (initial)
```

### Link Status

``LinkStatus`` tracks the lifecycle of each link:

```swift
// Active states
LinkStatus.freshActivated.isActive  // true
LinkStatus.stable.isActive          // true
LinkStatus.unstable.isActive        // false

// Terminal state
LinkStatus.broken.isTerminal        // true
```

### Broadcast Strategy

``BroadcastStrategy`` sends data to all active members and deduplicates received packets:

```swift
var strategy = BroadcastStrategy(initialSequence: SequenceNumber(0))

// Send to all active members
let result = strategy.prepareSend(activeMembers: [1, 2, 3])
// result.targets == [1, 2, 3]

// Deduplicate received packets
let r1 = strategy.processReceive(
    sequenceNumber: SequenceNumber(10),
    payload: payload, fromMember: 1)
// .newPacket

let r2 = strategy.processReceive(
    sequenceNumber: SequenceNumber(10),
    payload: payload, fromMember: 2)
// .duplicate
```

### Backup Strategy

``BackupStrategy`` activates the highest-weight idle member when the primary link fails:

```swift
var strategy = BackupStrategy(initialSequence: SequenceNumber(0))

var m1 = GroupMember(id: 1, host: "a.com", port: 4200, weight: 5)
m1.status = .idle
var m2 = GroupMember(id: 2, host: "b.com", port: 4200, weight: 10)
m2.status = .idle

let activated = strategy.activateHighestWeight(from: [m1, m2])
// activated == 2 (higher weight)
```

### Balancing Strategy

``BalancingStrategy`` distributes packets across links based on weight and estimated bandwidth:

```swift
var strategy = BalancingStrategy(initialMessageNumber: 0)

var m1 = GroupMember(id: 1, host: "a.com", port: 4200, weight: 1)
m1.status = .stable
m1.estimatedBandwidth = 10_000_000
var m2 = GroupMember(id: 2, host: "b.com", port: 4200, weight: 1)
m2.status = .stable
m2.estimatedBandwidth = 10_000_000

for _ in 0..<10 {
    if let selection = strategy.selectLink(from: [m1, m2]) {
        strategy.recordDelivery(memberID: selection.memberID)
    }
}
let stats = strategy.distributionStats
// Both members should have some deliveries
```

### Packet Deduplication

``PacketDeduplicator`` detects duplicate packets within a sliding window:

```swift
var dedup = PacketDeduplicator(windowSize: 100)

dedup.isNew(SequenceNumber(1))  // true
dedup.isNew(SequenceNumber(1))  // false (duplicate)
dedup.duplicatesDetected        // 1

dedup.reset()
dedup.isNew(SequenceNumber(1))  // true (window cleared)
```

## Next Steps

- <doc:ConfigurationGuide> — Group configuration options
- <doc:StatisticsGuide> — Per-link and group statistics
