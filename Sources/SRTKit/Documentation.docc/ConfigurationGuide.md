# Configuration Guide

Tune SRT connections with ``SRTSocketOptions`` and presets.

## Overview

SRTKit provides a layered configuration system: ``SRTSocketOptions`` for fine-grained control, ``SRTPreset`` for common use cases, ``SRTConfigurationBuilder`` for fluent API construction, and ``SRTServerPreset`` for server-specific defaults.

### Socket Options

``SRTSocketOptions`` controls timing, buffers, network, congestion, encryption, FEC, and timeouts.

Key option categories:

| Category | Options |
|----------|---------|
| Timing | `latency`, `peerLatency`, `tsbpd`, `tlpktdrop` |
| Buffers | `sendBufferSize`, `receiveBufferSize`, `flowWindowSize` |
| Network | `maxPayloadSize`, `ipTTL`, `ipTOS` |
| Congestion | `congestionControl`, `maxBandwidth`, `inputBandwidth`, `overheadPercent` |
| Encryption | `passphrase`, `keySize`, `cipherMode`, `kmRefreshRate`, `kmPreAnnounce`, `enforcedEncryption` |
| FEC | `fecConfiguration` |
| Timeouts | `connectTimeout`, `keepaliveInterval`, `keepaliveTimeout` |

### Presets

``SRTPreset`` provides six named configurations:

```swift
for preset in SRTPreset.allCases {
    let config = preset.configuration(
        host: "srt.example.com", port: 4200)
}
```

| Preset | Description |
|--------|-------------|
| `.lowLatency` | Minimal delay, lower latency than balanced |
| `.balanced` | Default, general-purpose settings |
| `.reliable` | Higher latency, prioritizes delivery |
| `.highBandwidth` | Optimized for high-throughput |
| `.broadcast` | Production broadcast settings |
| `.fileTransfer` | TSBPD disabled, file CC mode |

```swift
// Low latency prioritizes minimal delay
let lowLatency = SRTPreset.lowLatency.socketOptions()
let balanced = SRTPreset.balanced.socketOptions()
// lowLatency.latency <= balanced.latency

// File transfer disables TSBPD and uses file CC
let fileTransfer = SRTPreset.fileTransfer.socketOptions()
// fileTransfer.tsbpd == false
// fileTransfer.tlpktdrop == false
// fileTransfer.congestionControl == "file"
```

### Configuration Builder

``SRTConfigurationBuilder`` provides a fluent API:

```swift
let config = try SRTConfigurationBuilder(
    host: "srt.example.com", port: 4200
)
.mode(.caller)
.latency(microseconds: 120_000)
.encryption(
    passphrase: "my-secret-key-phrase",
    keySize: .aes256,
    cipherMode: .ctr
)
.build()
```

Apply a preset then customize:

```swift
let config = try SRTConfigurationBuilder(
    host: "live.example.com"
)
.preset(.broadcast)
.build()
```

### Option Validation

``SRTSocketOptions`` validates option values:

- Passphrase: 10–79 characters
- Payload size: within protocol limits
- Buffer sizes: positive integers
- TTL and TOS: valid IP field ranges

## Next Steps

- <doc:CallerGuide> — Applying configuration to a caller
- <doc:ListenerGuide> — Applying configuration to a listener
- <doc:ServerPresetsGuide> — Server-specific presets
