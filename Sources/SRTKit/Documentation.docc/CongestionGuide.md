# Congestion Control Guide

Manage bandwidth with LiveCC, FileCC, and AdaptiveCC.

## Overview

SRTKit provides three congestion control algorithms and a pluggable architecture for custom implementations. ``LiveCC`` handles live streaming with packet pacing, ``FileCC`` implements AIMD (Additive Increase Multiplicative Decrease) for file transfers, and ``AdaptiveCC`` auto-detects traffic patterns and switches algorithms at runtime.

### LiveCC — Live Streaming

``LiveCC`` paces packets based on estimated bandwidth to maintain steady delivery:

```swift
let config = LiveCC.Configuration(
    mode: .direct(bitsPerSecond: 10_000_000),
    initialPayloadSize: 1316)
var liveCC = LiveCC(configuration: config)

// Sending period = payloadSize * 8 / bandwidth
let period = liveCC.sendingPeriod()
// period > 0

// Track sent packets
liveCC.onPacketSent(payloadSize: 1316, timestamp: 0)

// Update bandwidth from ACK feedback
liveCC.onACK(
    acknowledgedPackets: 10,
    rtt: 20_000,
    bandwidth: 8_000_000,
    availableBuffer: 100)
liveCC.updateEstimatedBandwidth(8_000_000)
```

### FileCC — File Transfer

``FileCC`` uses AIMD with slow start and congestion avoidance phases:

```swift
var fileCC = FileCC(
    configuration: .init(initialCWND: 16, minimumCWND: 2))

// Starts in slow start
fileCC.phase  // .slowStart
fileCC.cwnd   // 16

// ACKs grow window exponentially during slow start
fileCC.onACK(
    acknowledgedPackets: 16,
    rtt: 20_000,
    bandwidth: 10_000_000,
    availableBuffer: 100)
// fileCC.cwnd > 16

// Loss triggers multiplicative decrease
fileCC.onNAK(lossCount: 5)
fileCC.phase  // .congestionAvoidance
```

### AdaptiveCC — Auto-Detection

``AdaptiveCC`` monitors traffic patterns and switches between live and file congestion control:

```swift
var adaptive = AdaptiveCC()

// Feed network events — AdaptiveCC detects the pattern
// Real-time traffic → switches to LiveCC behavior
// Bulk transfer → switches to FileCC behavior
```

### Bandwidth Estimation

``BandwidthEstimator`` estimates available bandwidth from probe packet pairs:

```swift
var estimator = BandwidthEstimator()

for i: UInt64 in 0..<20 {
    estimator.recordProbePacket(
        packetSize: 1316,
        receiveTime: i * 1000,
        isSecondOfPair: i % 2 == 1)
}
// estimator.estimateCount > 0
```

### Packet Pacing

``PacketPacer`` enforces minimum intervals between packets:

```swift
var pacer = PacketPacer()
let sendingPeriod: UInt64 = 1000  // 1ms

// First packet can always be sent
pacer.canSend(currentTime: 0, sendingPeriod: sendingPeriod)
// .sendNow
pacer.packetSent(at: 0)

// Too soon — must wait
pacer.canSend(currentTime: 500, sendingPeriod: sendingPeriod)
// .waitMicroseconds(500)

// After full period
pacer.canSend(currentTime: 1000, sendingPeriod: sendingPeriod)
// .sendNow
```

### Plugin Architecture

Implement ``CongestionControllerPlugin`` to create custom congestion control:

```swift
struct MyCC: CongestionControllerPlugin {
    var name: String { "custom" }
    var congestionWindow: Int { 64 }
    var sendingPeriodMicroseconds: UInt64 { 1000 }

    mutating func processEvent(
        _ event: CongestionEvent,
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        // Custom logic
        return .maintain
    }

    mutating func reset() { }
}
```

## Next Steps

- <doc:ProbingGuide> — Bandwidth probing to tune congestion settings
- <doc:ConfigurationGuide> — Setting congestion control mode
- <doc:StatisticsGuide> — Congestion metrics in statistics
