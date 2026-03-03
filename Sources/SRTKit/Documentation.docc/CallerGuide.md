# Caller Guide

Initiate SRT connections with ``SRTCaller``.

## Overview

``SRTCaller`` is an actor that initiates connections to remote SRT listeners. It handles the complete handshake negotiation, optional encryption setup, and provides `send`/`receive` methods for bidirectional data transfer. This guide covers configuration, connection lifecycle, event monitoring, and statistics.

### Configuration

``SRTCaller/Configuration`` controls all aspects of the caller connection:

```swift
let config = SRTCaller.Configuration(
    host: "srt.example.com",
    port: 4200
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `host` | `String` | (required) | Remote host address |
| `port` | `Int` | (required) | Remote port |
| `streamID` | `String?` | `nil` | Access control stream ID |
| `passphrase` | `String?` | `nil` | Encryption passphrase (10–79 chars) |
| `keySize` | ``KeySize`` | `.aes128` | AES key size |
| `cipherMode` | ``CipherMode`` | `.ctr` | AES-CTR or AES-GCM |

### Connect and Send

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com", port: 4200
))

// Connect — performs the full SRT handshake
try await caller.connect()

// Send data — returns the number of bytes sent
let payload: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
let byteCount = try await caller.send(payload)

// Disconnect gracefully
await caller.disconnect()
```

### Receive Data

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com", port: 4200
))
try await caller.connect()

// Receive returns nil when no data is available
let data = await caller.receive()
```

### Event Monitoring

Subscribe to the ``SRTCaller/events`` `AsyncStream` to observe state changes and handshake completion:

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com", port: 4200
))
let events = await caller.events

Task {
    for await event in events {
        switch event {
        case .stateChanged(_, let to) where to == .connected:
            print("Connected")
        case .handshakeComplete(let peerID, let latency):
            print("Peer: \(peerID), latency: \(latency)µs")
        default:
            break
        }
    }
}

try await caller.connect()
```

### Statistics

Access real-time metrics at any point:

```swift
let stats = await caller.statistics()
print("Sent: \(stats.packetsSent) packets")
print("Received: \(stats.packetsReceived) packets")
print("Retransmitted: \(stats.packetsRetransmitted) packets")
```

### Encrypted Connection

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com",
    port: 4200,
    passphrase: "my-secret-key-phrase",
    keySize: .aes256,
    cipherMode: .ctr
))
try await caller.connect()
// Encryption is negotiated automatically during the handshake
```

### Disconnect

``SRTCaller/disconnect()`` is safe to call from any state and is idempotent:

```swift
await caller.disconnect()
let state = await caller.state
// state == .closed
```

## Next Steps

- <doc:ListenerGuide> — Accept incoming SRT connections
- <doc:EncryptionGuide> — Encryption details and key rotation
- <doc:StatisticsGuide> — Metrics, quality scoring, and export
