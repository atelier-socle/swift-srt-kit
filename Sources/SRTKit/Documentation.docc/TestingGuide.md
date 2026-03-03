# Testing Guide

Understand the test infrastructure and write tests for SRTKit.

## Overview

SRTKit uses Swift Testing exclusively (`import Testing`, `@Test`, `@Suite`, `#expect`) with over 2,100 tests across 200+ suites. The test suite includes showcase tests as canonical API examples, unit tests for all protocol components, and coverage tests for edge cases. No XCTest is used anywhere in the project.

### Test Organization

Tests are organized by module and feature area:

```
Tests/
├── SRTKitTests/
│   ├── Showcase/           # 16 showcase test files (source of truth for docs)
│   ├── Connection/         # SRTSocket, SRTCaller, SRTListener tests
│   ├── Handshake/          # CallerHandshake, ListenerHandshake tests
│   ├── Packet/             # PacketCodec, data/control packet tests
│   ├── Reliability/        # SendBuffer, ReceiveBuffer, LossDetector tests
│   ├── Congestion/         # LiveCC, FileCC, AdaptiveCC tests
│   ├── Encryption/         # SRTEncryptor, SRTDecryptor, KeyWrap tests
│   ├── Bonding/            # SRTConnectionGroup, strategy tests
│   ├── Transport/          # AddressResolver, SocketIDGenerator tests
│   ├── Probing/            # ProbeEngine, BitrateMonitor tests
│   ├── Configuration/      # SRTSocketOptions, validation tests
│   └── ...
├── SRTKitCommandsTests/    # CLI command parsing tests
```

### Running Tests

```bash
# All tests
swift test 2>&1 | tail -30

# Core library tests only
swift test --filter SRTKitTests 2>&1 | tail -30

# CLI tests only
swift test --filter SRTKitCommandsTests 2>&1 | tail -30

# Specific test suite
swift test --filter "EncryptionShowcase" 2>&1 | tail -10
```

### Showcase Tests

The 16 showcase test files in `Tests/SRTKitTests/Showcase/` serve as the source of truth for documentation code examples. Each file demonstrates a complete feature area:

| Showcase File | Feature Area |
|--------------|-------------|
| `BondingShowcaseTests` | Group modes, strategies, deduplication |
| `CCPluginShowcaseTests` | Congestion control plugins |
| `ConfigurationShowcaseTests` | Presets, builder, server presets |
| `CongestionShowcaseTests` | LiveCC, FileCC, bandwidth estimation |
| `ConnectionShowcaseTests` | State machine, caller/listener config |
| `EncryptionShowcaseTests` | AES-CTR/GCM, key derivation, rotation |
| `HandshakeShowcaseTests` | Handshake state machines |
| `MultiStreamShowcaseTests` | Multi-stream and multi-caller |
| `PacketShowcaseTests` | Packet encoding/decoding |
| `ProbingShowcaseTests` | Probe engine, bitrate monitor |
| `ReconnectionShowcaseTests` | Reconnect policies, state machine |
| `RecordingShowcaseTests` | Stream recording |
| `ReliabilityShowcaseTests` | Sequence numbers, buffers, loss detection |
| `StatisticsShowcaseTests` | Metrics, quality scoring, export |
| `TimingShowcaseTests` | TSBPD, too-late drop, drift |
| `TransportShowcaseTests` | Address resolution, FEC |

### Code Coverage

Generate a coverage report:

```bash
swift test --enable-code-coverage 2>&1 | tail -10
```

The project targets ~97% coverage on testable code. Remaining uncovered lines are in network I/O actors that require a real UDP transport to exercise.

### Manual Testing with srt-cli

The CLI tool enables manual interop testing with libsrt:

```bash
# Terminal 1: Start SRTKit listener
.build/release/srt-cli receive --port 4200 --output /tmp/received.ts

# Terminal 2: Send with libsrt
srt-live-transmit file://input.ts "srt://127.0.0.1:4200"

# Or vice versa:
# Terminal 1: Start libsrt listener
srt-live-transmit "srt://:4200?mode=listener" file:///tmp/received.ts

# Terminal 2: Send with SRTKit
.build/release/srt-cli send --host 127.0.0.1 --port 4200 --file input.ts
```

## Next Steps

- <doc:CLIReference> — CLI command reference
- <doc:InteroperabilityGuide> — libsrt interop scenarios
- <doc:TransportDIGuide> — Testing without network
