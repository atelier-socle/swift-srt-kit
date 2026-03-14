# ``SRTKit``

@Metadata {
    @DisplayName("SRTKit")
}

Pure Swift implementation of the Secure Reliable Transport (SRT) protocol.

## Overview

SRTKit provides a complete, pure Swift implementation of the SRT protocol for reliable, low-latency media transport over UDP. The library handles the full SRT lifecycle — handshake negotiation, AES encryption, packet reliability, congestion control, forward error correction, connection bonding, and real-time statistics — all built with Swift 6.2 strict concurrency and no C dependencies.

```swift
import SRTKit

let caller = SRTCaller(configuration: .init(
    host: "srt.example.com", port: 4200
))
try await caller.connect()

try await caller.send(tsPacketData)
let stats = await caller.statistics()
await caller.disconnect()
```

### Key Features

- **Caller/Listener/Rendezvous** — Three connection modes for any SRT topology
- **AES-CTR + AES-GCM** — End-to-end encryption with PBKDF2 key derivation, key wrap, and automatic rotation
- **Forward Error Correction** — Row, column, and matrix FEC with configurable layouts and ARQ modes
- **Connection Bonding** — Broadcast (all links), main/backup (failover), and balancing (aggregate) groups
- **Congestion Control** — LiveCC (pacing), FileCC (AIMD), AdaptiveCC (pattern detection), pluggable architecture
- **Bandwidth Probing** — Stepped probe engine with auto-configuration recommendations
- **TSBPD Timing** — Time-Based Sender/Buffer/Delivery with clock drift correction and too-late drop
- **Real-time Statistics** — Comprehensive metrics with quality scoring, Prometheus and StatsD export
- **Stream Recording** — Buffered recording with size/duration rotation in MPEG-TS or raw format
- **Access Control** — StreamID-based access control with `#!::` format parsing and generation
- **Auto-reconnect** — Exponential backoff with configurable jitter and four presets
- **Multi-stream** — Route multiple streams over a single listener with socket ID multiplexing
- **Server Presets** — One-line configuration for AWS MediaConnect, Nimble, Haivision, OBS, and more
- **Cross-platform** — macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+, Linux
- **CLI tool** — `srt-cli` for sending, receiving, probing, statistics, and diagnostics
- **Swift 6.2 strict concurrency** — Actors for stateful types, `Sendable` everywhere, zero `@unchecked Sendable`

### Standards

| Standard | Reference |
|----------|-----------|
| SRT Protocol | [SRT Alliance Technical Overview](https://github.com/Haivision/srt/blob/master/docs/API/API-functions.md) |
| SRT Handshake | [SRT Handshake Specification](https://datatracker.ietf.org/doc/html/draft-sharabayko-srt) |
| AES Key Wrap | [RFC 3394](https://datatracker.ietf.org/doc/html/rfc3394) |
| PBKDF2 | [RFC 2898](https://datatracker.ietf.org/doc/html/rfc2898) |
| AES-CTR / AES-GCM | [NIST SP 800-38A](https://csrc.nist.gov/publications/detail/sp/800-38a/final) / [NIST SP 800-38D](https://csrc.nist.gov/publications/detail/sp/800-38d/final) |

## Topics

### Essentials

- <doc:WhatsNew030>
- <doc:GettingStarted>
- <doc:CallerGuide>
- <doc:ListenerGuide>

### Security

- <doc:EncryptionGuide>
- <doc:AccessControlGuide>

### Reliability

- <doc:FECGuide>
- <doc:CongestionGuide>

### Advanced Features

- <doc:BondingGuide>
- <doc:ProbingGuide>
- <doc:RecordingGuide>

### Configuration

- <doc:ConfigurationGuide>
- <doc:ServerPresetsGuide>
- <doc:StatisticsGuide>

### Integration

- <doc:TransportDIGuide>
- <doc:InteroperabilityGuide>

### Tools

- <doc:CLIReference>
- <doc:TestingGuide>

### Connection

- ``SRTCaller``
- ``SRTListener``
- ``SRTSocket``
- ``SRTConnectionState``

### Configuration Types

- ``SRTSocketOptions``
- ``SRTPreset``
- ``SRTServerPreset``
- ``SRTConfigurationBuilder``

### Encryption

- ``SRTEncryptor``
- ``SRTDecryptor``
- ``KeyDerivation``
- ``KeyWrap``
- ``KeyRotation``
- ``KeySize``
- ``CipherMode``

### Packets

- ``SRTDataPacket``
- ``SRTControlPacket``
- ``ACKPacket``
- ``NAKPacket``
- ``HandshakePacket``
- ``KeyMaterialPacket``
- ``PacketCodec``
- ``SequenceNumber``
- ``SRTPeerAddress``

### Handshake

- ``CallerHandshake``
- ``ListenerHandshake``
- ``HandshakeConfiguration``
- ``HandshakeState``

### Reliability

- ``SendBuffer``
- ``ReceiveBuffer``
- ``LossDetector``
- ``RetransmissionManager``

### Congestion Control

- ``LiveCC``
- ``FileCC``
- ``AdaptiveCC``
- ``BandwidthEstimator``
- ``PacketPacer``
- ``CongestionControllerPlugin``

### Forward Error Correction

- ``FECConfiguration``
- ``FECEncoder``
- ``FECDecoder``

### Bonding

- ``SRTConnectionGroup``
- ``GroupConfiguration``
- ``GroupMode``
- ``GroupMember``
- ``LinkStatus``
- ``BroadcastStrategy``
- ``BackupStrategy``
- ``BalancingStrategy``
- ``PacketDeduplicator``

### Probing

- ``ProbeEngine``
- ``ProbeConfiguration``
- ``ProbeResult``
- ``BitrateMonitor``
- ``TargetQuality``

### Timing

- ``TSBPDManager``
- ``TooLatePacketDrop``
- ``DriftManager``

### Statistics

- ``SRTStatistics``
- ``SRTConnectionQuality``
- ``PrometheusExporter``
- ``StatsDExporter``

### Recording

- ``StreamRecorder``
- ``RecordingConfiguration``
- ``RecordingStatistics``
- ``RecordingFormat``

### Access Control

- ``SRTAccessControl``

### Multi-Stream

- ``MultiStreamManager``
- ``MultiCallerManager``
- ``SRTDestination``

### Reconnection

- ``SRTReconnectPolicy``
- ``ReconnectionManager``

### Transport

- ``AddressResolver``
- ``SocketIDGenerator``

### Events

- ``SRTEvent``
- ``SRTConnectionError``
- ``SRTError``
- ``SRTRejectionReason``
