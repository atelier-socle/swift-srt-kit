# Listener Guide

Accept incoming SRT connections with ``SRTListener``.

## Overview

``SRTListener`` is an actor that binds to a local port and accepts incoming SRT connections. Each accepted connection is delivered as an ``SRTSocket`` through an `AsyncStream`, enabling concurrent handling of multiple peers.

### Configuration

``SRTListener/Configuration`` controls the listener behavior:

```swift
let config = SRTListener.Configuration(port: 4200)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `host` | `String` | `"0.0.0.0"` | Bind address |
| `port` | `Int` | (required) | Listen port |
| `backlog` | `Int` | `5` | Max pending connections |
| `passphrase` | `String?` | `nil` | Encryption passphrase |
| `keySize` | ``KeySize`` | `.aes128` | AES key size |
| `cipherMode` | ``CipherMode`` | `.ctr` | AES-CTR or AES-GCM |

### Start and Accept Connections

```swift
let listener = SRTListener(configuration: .init(port: 4200))

// Start listening — binds the UDP port
try await listener.start()

// Accept incoming connections via AsyncStream
for await socket in listener.incomingConnections {
    Task {
        let data = await socket.receive()
        // Process data from this peer
    }
}
```

### Encrypted Listener

Require all connecting callers to provide a matching passphrase:

```swift
let listener = SRTListener(configuration: .init(
    port: 4200,
    passphrase: "shared-secret-phrase",
    keySize: .aes256
))
try await listener.start()
```

Callers that connect without a passphrase or with the wrong passphrase are rejected during the handshake.

### Stop

``SRTListener/stop()`` closes the listener and all active connections:

```swift
await listener.stop()
```

## Next Steps

- <doc:CallerGuide> — Initiate connections to a listener
- <doc:AccessControlGuide> — StreamID-based routing and filtering
- <doc:EncryptionGuide> — Encryption details
