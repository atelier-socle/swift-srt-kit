# FEC Guide

Protect streams with Forward Error Correction.

## Overview

SRTKit implements XOR-based Forward Error Correction (FEC) that can recover lost packets without retransmission. FEC operates on a matrix of source packets, generating row and column parity packets that enable recovery when packets are lost in transit.

### Configuration

``FECConfiguration`` defines the FEC matrix dimensions and behavior:

```swift
let config = try FECConfiguration(
    columns: 10, rows: 5,
    layout: .staircase, arqMode: .always)

config.matrixSize        // 50 (columns x rows)
config.rowFECCount       // 5
config.columnFECCount    // 10
config.totalFECPackets   // 15
config.overheadRatio     // > 0
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `columns` | `Int` | Packets per row (1–256) |
| `rows` | `Int` | Packets per column (1–256) |
| `layout` | ``FECConfiguration/Layout`` | `.even` or `.staircase` |
| `arqMode` | ``FECConfiguration/ARQMode`` | `.always`, `.onreq`, or `.never` |

Invalid dimensions are rejected:

```swift
// Zero columns — throws FECError
try FECConfiguration(columns: 0, rows: 5)

// Zero rows — throws FECError
try FECConfiguration(columns: 5, rows: 0)
```

### Filter String Format

FEC configuration can be serialized to and parsed from the SRT `SRTO_PACKETFILTER` format:

```swift
let config = try FECConfiguration(columns: 5, rows: 3)
let filterString = config.toFilterString()
let parsed = FECConfiguration.parse(filterString)
// parsed?.columns == 5
// parsed?.rows == 3
```

### FEC Encoder

``FECEncoder`` accumulates source packets and generates FEC parity packets:

```swift
let config = try FECConfiguration(
    columns: 4, rows: 1,
    layout: .even, arqMode: .always)
var encoder = FECEncoder(configuration: config)

// Submit source packets
for i in 0..<4 {
    let source = FECEncoder.SourcePacket(
        sequenceNumber: SequenceNumber(UInt32(i)),
        payload: Array(repeating: UInt8(i), count: 188),
        timestamp: UInt32(i) * 10_000)
    let result = encoder.submitPacket(source)
    // First 3 packets: .pending (accumulating)
    // 4th packet: generates FEC
}
// encoder.packetsProcessed == 4
```

### FEC Decoder

``FECDecoder`` tracks received packets and attempts recovery when losses are detected:

```swift
let config = try FECConfiguration(columns: 4, rows: 1)
var decoder = FECDecoder(configuration: config)

// Feed source packets
for i in 0..<4 {
    decoder.receiveSourcePacket(
        sequenceNumber: SequenceNumber(UInt32(i)),
        payload: Array(repeating: UInt8(i), count: 188),
        timestamp: UInt32(i) * 10_000)
}

let result = decoder.attemptRecovery()
// .noLoss when all packets received
```

### ARQ Modes

| Mode | Description |
|------|-------------|
| `.always` | Always request retransmission via NAK, FEC supplements |
| `.onreq` | Only use FEC recovery, no NAK retransmission |
| `.never` | Disable both FEC recovery and ARQ |

## Next Steps

- <doc:ConfigurationGuide> — FEC as part of socket options
- <doc:CongestionGuide> — How congestion control interacts with FEC
