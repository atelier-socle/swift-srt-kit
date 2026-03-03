# Statistics Guide

Monitor connections with real-time metrics and quality scoring.

## Overview

SRTKit provides comprehensive connection statistics through ``SRTStatistics``, quality scoring via ``SRTConnectionQuality``, and metric export to Prometheus and StatsD. Statistics are collected internally from socket state and never from network probing.

### SRTStatistics

``SRTStatistics`` tracks packet counts, byte counts, timing, bandwidth, buffer state, congestion, encryption, and FEC metrics:

```swift
var stats = SRTStatistics()
stats.packetsSent = 10_000
stats.packetsReceived = 9_800
stats.packetsSentLost = 50
stats.bytesReceived = 12_888_800
stats.rttMicroseconds = 25_000
stats.bandwidthBitsPerSecond = 10_000_000
stats.sendBufferPackets = 32
stats.sendBufferCapacity = 8192
```

Key computed properties:

```swift
// Loss rate (0.0–1.0)
stats.lossRate

// Buffer utilization (0.0–1.0)
stats.sendBufferUtilization
```

### Quality Scoring

``SRTConnectionQuality`` computes an overall quality score from five weighted metrics:

```swift
let stats = SRTStatistics()
let quality = SRTConnectionQuality.from(statistics: stats)

quality.score  // 0.0–1.0
quality.grade  // .excellent, .good, .fair, .poor, or .critical
```

| Grade | Score Range |
|-------|------------|
| `.excellent` | > 0.9 |
| `.good` | > 0.7 |
| `.fair` | > 0.5 |
| `.poor` | > 0.3 |
| `.critical` | <= 0.3 |

The five scoring weights:

```swift
SRTConnectionQuality.rttWeight        // 0.30
SRTConnectionQuality.lossWeight       // 0.25
SRTConnectionQuality.bufferWeight     // 0.20
SRTConnectionQuality.bitrateWeight    // 0.15
SRTConnectionQuality.stabilityWeight  // 0.10
// Total: 1.0
```

### Prometheus Export

``PrometheusExporter`` renders statistics in the Prometheus text exposition format:

```swift
var stats = SRTStatistics()
stats.packetsSent = 5000
stats.packetsReceived = 4900
stats.rttMicroseconds = 15_000

let exporter = PrometheusExporter(prefix: "srt")
let rendered = exporter.render(stats, labels: ["stream": "main"])
// Contains "# HELP", "# TYPE", and "srt_" prefixed metrics
```

### StatsD Export

``StatsDExporter`` renders statistics in the StatsD datagram format:

```swift
var stats = SRTStatistics()
stats.packetsSent = 1000
stats.rttMicroseconds = 20_000

let exporter = StatsDExporter(prefix: "srt")
let rendered = exporter.render(stats, labels: ["env": "test"])
// StatsD format: metric:value|type (|g for gauges, |c for counters)
```

### Accessing Statistics

From a caller:

```swift
let stats = await caller.statistics()
```

From a socket:

```swift
let stats = await socket.statistics()
```

## Next Steps

- <doc:CallerGuide> — Caller statistics
- <doc:ProbingGuide> — Using statistics for probing
- <doc:ConfigurationGuide> — Tuning based on statistics
