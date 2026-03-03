# Probing Guide

Measure available bandwidth with ``ProbeEngine``.

## Overview

SRTKit includes a bandwidth probing system that sends data at increasing bitrates to determine the available bandwidth, then generates configuration recommendations. The ``ProbeEngine`` executes stepped probes and produces a ``ProbeResult`` with measurements and auto-configuration suggestions.

### Probe Configurations

``ProbeConfiguration`` provides three presets with ascending step counts:

```swift
let quick = ProbeConfiguration.quick
let standard = ProbeConfiguration.standard
let thorough = ProbeConfiguration.thorough

// quick.steps.count < standard.steps.count < thorough.steps.count
```

Steps are always ascending — each step tests a higher bitrate than the previous one.

### Running a Probe

```swift
var engine = ProbeEngine(configuration: .standard)

// Start — returns the first action
let action = engine.start()
// .sendAtBitrate(bitsPerSecond: ..., stepIndex: 0)

// Feed statistics after each step
for i in 0..<3 {
    var stats = SRTStatistics()
    stats.sendRateBitsPerSecond = UInt64(i + 1) * 2_000_000
    stats.rttMicroseconds = 20_000 + UInt64(i) * 2_000
    stats.packetsSent = UInt64(i + 1) * 100

    let next = engine.feedStepResult(
        statistics: stats,
        stepStartTime: UInt64(i) * 1_000_000,
        currentTime: UInt64(i + 1) * 1_000_000)
    // .sendAtBitrate for next step, or .complete when done
}
```

### Probe Results

``ProbeResult`` summarizes the probe measurements:

| Property | Description |
|----------|-------------|
| `achievedBandwidth` | Maximum achieved bandwidth (bps) |
| `averageRTTMicroseconds` | Average round-trip time |
| `rttVarianceMicroseconds` | RTT variance |
| `packetLossRate` | Observed loss rate (0.0–1.0) |
| `stabilityScore` | Network stability (0–100) |
| `recommendedBitrate` | Suggested operating bitrate |
| `recommendedLatency` | Suggested latency setting |

### Auto-Configuration

Generate a full ``SRTCaller/Configuration`` from probe results:

```swift
let result = ProbeResult(
    achievedBandwidth: 10_000_000,
    averageRTTMicroseconds: 25_000,
    rttVarianceMicroseconds: 5_000,
    packetLossRate: 0.01,
    stabilityScore: 85,
    recommendedBitrate: 7_000_000,
    recommendedLatency: 100_000,
    stepsCompleted: 5,
    totalDurationMicroseconds: 5_000_000,
    saturationStepIndex: 4)

let config = ProbeEngine.autoConfiguration(
    from: result,
    host: "srt.example.com",
    port: 4200,
    targetQuality: .balanced)
```

### Target Quality

``TargetQuality`` presets control how aggressively the probe recommends bandwidth usage:

```swift
TargetQuality.quality.bandwidthFactor     // 0.6 (conservative)
TargetQuality.balanced.bandwidthFactor    // 0.7 (moderate)
TargetQuality.lowLatency.bandwidthFactor  // 0.8 (aggressive)
```

### Bitrate Monitor

``BitrateMonitor`` provides ongoing bitrate recommendations with hysteresis to prevent oscillation:

```swift
var monitor = BitrateMonitor(configuration: .conservative)

var stats = SRTStatistics()
stats.packetsSent = 1000
stats.rttMicroseconds = 20_000
stats.sendBufferPackets = 10
stats.sendBufferCapacity = 8192
stats.bandwidthBitsPerSecond = 10_000_000
stats.sendRateBitsPerSecond = 8_000_000

let recommendation = monitor.evaluate(
    statistics: stats, currentBitrate: 8_000_000)
// .maintain or .increase under stable conditions
```

## Next Steps

- <doc:CongestionGuide> — Congestion control algorithms
- <doc:CLIReference> — The `probe` CLI command
- <doc:ConfigurationGuide> — Applying probe results
