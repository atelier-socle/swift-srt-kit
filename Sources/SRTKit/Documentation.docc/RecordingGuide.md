# Recording Guide

Record SRT streams with ``StreamRecorder``.

## Overview

SRTKit includes a buffered stream recording system that writes received data to files with optional size-based or duration-based rotation. ``StreamRecorder`` accumulates data in memory and flushes it in configurable intervals, supporting MPEG-TS and raw recording formats.

### Basic Recording

```swift
var recorder = StreamRecorder()
recorder.start(at: 1_000_000)
// recorder.isRecording == true

// Write data — stays buffered until flush threshold
let action = recorder.write(
    [0x47, 0x00, 0x11, 0x00], at: 1_010_000)
// .none (no flush needed yet)

// Check statistics
let stats = recorder.statistics
// stats.totalBytesWritten == 4
```

### File Rotation

Request a file rotation to start a new recording segment:

```swift
var recorder = StreamRecorder()
recorder.start(at: 1_000_000)

_ = recorder.write(
    Array(repeating: 0x47, count: 188), at: 1_010_000)

let action = recorder.requestRotation()
// .rotate(data: [...], reason: .manual)
```

### Configuration

``RecordingConfiguration`` controls buffer sizes and rotation thresholds:

```swift
let config = RecordingConfiguration.default
_ = config.maxFileSizeBytes
_ = config.maxDurationMicroseconds
```

### Recording Formats

| Format | Description |
|--------|-------------|
| `.mpegts` | MPEG Transport Stream |
| `.raw` | Raw byte stream |

### Statistics

``RecordingStatistics`` tracks recording progress:

```swift
let stats = RecordingStatistics()
stats.totalBytesWritten  // 0
stats.fileRotations      // 0
stats.flushCount         // 0
```

## Next Steps

- <doc:ListenerGuide> — Recording received streams
- <doc:StatisticsGuide> — Recording metrics
