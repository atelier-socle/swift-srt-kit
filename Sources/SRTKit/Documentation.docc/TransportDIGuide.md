# Transport Dependency Injection Guide

Bridge SRTKit with other streaming frameworks.

## Overview

SRTKit's architecture separates transport concerns from protocol logic, enabling integration with other streaming frameworks. The Transport module is the only layer that touches NIO directly, while all other modules (Packet, Handshake, Reliability, Encryption) are testable in isolation.

### Architecture Layers

```
Connection/     — Integration layer (SRTCaller, SRTListener, SRTSocket)
  ↓
Handshake/      — State machines (CallerHandshake, ListenerHandshake)
Reliability/    — Retransmission (SendBuffer, ReceiveBuffer, LossDetector)
Encryption/     — AES-CTR/GCM (SRTEncryptor, SRTDecryptor, KeyDerivation)
Congestion/     — Bandwidth control (LiveCC, FileCC, AdaptiveCC)
Timing/         — TSBPD, drift correction
  ↓
Packet/         — Data structures (no I/O, no NIO imports except PacketCodec)
  ↓
Transport/      — UDP I/O (only NIO user)
```

### Design Principles

- **Transport/** is the only module that imports NIO directly
- **Packet/** is pure data structures with no I/O
- **Handshake/** depends on Packet/ but not Transport/ — state machines are testable without network
- **Reliability/** depends on Packet/ and Timing/ — retransmission logic is testable without network
- **Encryption/** depends on swift-crypto only — testable with known test vectors
- **Statistics/** aggregates from internal state — never from network probing

### Bridge Pattern

To integrate SRTKit with another framework (like an HLS pipeline), use the extension-based bridge pattern:

```swift
// Your framework provides a transport protocol
protocol MediaTransport: Sendable {
    func send(_ data: [UInt8]) async throws
}

// Bridge SRTCaller to your transport
extension SRTCaller {
    func bridgeTo(transport: some MediaTransport) async throws {
        try await connect()
        // Use SRTCaller's send/receive with your transport
    }
}
```

This keeps SRTKit free of hard dependencies on any specific framework.

### Testing Without Network

The layered architecture enables testing without a real network. Handshake state machines, encryption, reliability, and congestion control can all be unit tested with direct method calls:

```swift
// Test handshake logic without network
var caller = CallerHandshake(
    configuration: HandshakeConfiguration(localSocketID: 0xABCD))
let actions = caller.start()
// Verify actions without sending actual UDP packets

// Test encryption with known vectors
let encryptor = try SRTEncryptor(
    sek: knownKey, salt: knownSalt,
    cipherMode: .ctr, keySize: .aes128)
let encrypted = try encryptor.encrypt(
    payload: knownPlaintext,
    sequenceNumber: SequenceNumber(42),
    header: knownHeader)
// Verify against expected ciphertext
```

## Next Steps

- <doc:TestingGuide> — Testing strategies and showcase tests
- <doc:InteroperabilityGuide> — Interop with libsrt
