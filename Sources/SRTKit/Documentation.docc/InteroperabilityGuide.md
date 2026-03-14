# Interoperability Guide

Connect SRTKit with libsrt and other SRT implementations.

## Overview

SRTKit is fully interoperable with libsrt 1.5.4 and MediaMTX 1.16.3, both for unencrypted and encrypted connections. This guide covers tested interop scenarios, configuration alignment, and known compatibility notes.

### Tested Interop Scenarios

SRTKit has been validated in bidirectional interop with libsrt and MediaMTX:

| Scenario | Direction | Encryption | Status |
|----------|-----------|------------|--------|
| SRTKit caller → libsrt listener | Send | None | Validated |
| SRTKit caller → libsrt listener | Send | AES-128-CTR | Validated |
| libsrt caller → SRTKit listener | Receive | None | Validated |
| libsrt caller → SRTKit listener | Receive | AES-128-CTR | Validated |
| SRTKit caller → MediaMTX 1.16.3 | MPEG-TS publish | None | Validated |

### Using srt-live-transmit

libsrt's `srt-live-transmit` is the primary interop testing tool:

```bash
# Install libsrt (macOS)
brew install srt

# Start a libsrt listener (receive from SRTKit caller)
srt-live-transmit "srt://:4200?mode=listener" file://output.ts

# Start a libsrt caller (send to SRTKit listener)
srt-live-transmit file://input.ts "srt://127.0.0.1:4200"

# With encryption
srt-live-transmit "srt://:4200?mode=listener&passphrase=my-secret-key" file://output.ts
```

### Configuration Alignment

When connecting SRTKit to libsrt, ensure these parameters match:

| Parameter | SRTKit | libsrt |
|-----------|--------|--------|
| Passphrase | `passphrase: "..."` | `passphrase=...` |
| Key size | `.aes128` / `.aes256` | `pbkeylen=16` / `pbkeylen=32` |
| Latency | `latency: 120_000` (µs) | `latency=120` (ms) |
| Mode | `.caller` / `.listener` | `mode=caller` / `mode=listener` |

### Encryption Interop Notes

- SRTKit uses AES-CTR by default, which is compatible with libsrt's default
- AES-GCM requires libsrt 1.5+ with GCM support enabled
- The handshake negotiates cipher mode, key size, and key material automatically
- Passphrase must be identical on both sides (10–79 characters)

### StreamID Interop

SRT servers use two StreamID formats. SRTKit supports both:

| Format | Example | Used By |
|--------|---------|---------|
| SRT Access Control | `#!::r=live/test,m=publish` | libsrt, Haivision |
| Short format | `publish:live/test` | MediaMTX |

```bash
# libsrt with SRT Access Control StreamID
srt-live-transmit file://input.ts "srt://127.0.0.1:4200?streamid=#!::r=live,m=publish"

# MediaMTX uses the same StreamID — it parses the #!:: prefix internally
srt-live-transmit file://input.ts "srt://127.0.0.1:8890?streamid=#!::r=live/test,m=publish"
```

### MediaMTX Integration

MediaMTX is a popular SRT/RTMP/HLS relay server. To publish MPEG-TS via SRTKit:

```swift
let caller = SRTCaller(configuration: .init(
    host: "localhost",
    port: 8890,
    streamID: "#!::r=live/test,m=publish",
    latency: 120_000
))
try await caller.connect()

// Send MPEG-TS chunks (7 × 188 = 1316 bytes each)
for chunk in tsChunks {
    _ = try await caller.send(chunk)
}
await caller.disconnect()
```

MediaMTX will log `is publishing to path 'live/test'` and relay the stream via RTMP, HLS, or WebRTC.

## Next Steps

- <doc:EncryptionGuide> — Encryption configuration details
- <doc:CLIReference> — Using srt-cli for interop testing
- <doc:TestingGuide> — Automated interop test scenarios
