# Getting Started with SRTKit

Set up your first SRT connection in minutes.

## Overview

SRTKit provides everything you need for reliable, low-latency media transport over UDP. This guide walks you through installation, basic configuration, and your first streaming session using ``SRTCaller`` and ``SRTListener``.

### Installation

Add SRTKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-srt-kit.git", from: "0.3.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SRTKit"]
)
```

### Import

```swift
import SRTKit
```

### Quick Start — Caller

The caller initiates a connection to a remote listener:

```swift
// 1. Configure the caller
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com", port: 4200
))

// 2. Connect (performs full SRT handshake)
try await caller.connect()

// 3. Send data
let bytesSent = try await caller.send(tsPacketData)

// 4. Check statistics
let stats = await caller.statistics()

// 5. Disconnect
await caller.disconnect()
```

### Quick Start — Listener

The listener accepts incoming connections on a local port:

```swift
// 1. Configure the listener
let listener = SRTListener(configuration: .init(port: 4200))

// 2. Start listening
try await listener.start()

// 3. Accept connections
for await socket in listener.incomingConnections {
    let data = await socket.receive()
    // Process received data
}

// 4. Stop
await listener.stop()
```

### Configuration Defaults

``SRTCaller/Configuration`` and ``SRTListener/Configuration`` provide sensible defaults:

| Property | Caller Default | Listener Default |
|----------|---------------|-----------------|
| Port | (required) | (required) |
| Host | (required) | `"0.0.0.0"` |
| Passphrase | `nil` (no encryption) | `nil` (no encryption) |
| Key Size | `.aes128` | `.aes128` |
| Cipher Mode | `.ctr` | `.ctr` |
| Backlog | — | `5` |

### Adding Encryption

Enable AES encryption by setting a passphrase (10–79 characters):

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com",
    port: 4200,
    passphrase: "my-secret-key-phrase",
    keySize: .aes256,
    cipherMode: .ctr
))
```

Both sides must use the same passphrase. Key derivation, key wrapping, and key exchange happen automatically during the handshake.

### Connection States

Every SRT connection follows the same state machine:

```
idle → connecting → handshaking → connected → transferring → closing → closed
                                                                ↗
                                                         broken
```

Only `connected` and `transferring` are active states. `closed` and `broken` are terminal.

## Next Steps

- <doc:CallerGuide> — Complete caller walkthrough with encryption and events
- <doc:ListenerGuide> — Listener setup with access control
- <doc:EncryptionGuide> — AES-CTR, AES-GCM, key derivation, and rotation
