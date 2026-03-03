# Server Presets Guide

One-line configuration for popular SRT servers.

## Overview

``SRTServerPreset`` provides pre-configured settings for common SRT server deployments including AWS MediaConnect, Nimble Streamer, Haivision SRT Gateway, and OBS Studio. Each preset configures the default port, latency, stream ID usage, and other server-specific settings.

### Available Presets

All 7 server presets:

```swift
for preset in SRTServerPreset.allCases {
    let config = preset.configuration(host: "media.example.com")
    // config.host == "media.example.com"
    // config.port > 0
}
```

| Preset | Default Port | Uses StreamID |
|--------|-------------|--------------|
| `.awsMediaConnect` | Varies | Yes |
| `.nimble` | Varies | Yes |
| `.haivision` | Varies | Yes |
| `.obsStudio` | Varies | No |
| `.wowza` | Varies | Yes |
| `.vmix` | Varies | No |
| `.srtLiveServer` | Varies | Yes |

### AWS MediaConnect

```swift
let preset = SRTServerPreset.awsMediaConnect
preset.usesStreamID   // true
preset.defaultPort    // > 0

let config = preset.configuration(host: "media.example.com")
```

### OBS Studio

```swift
let config = SRTServerPreset.obsStudio.configuration(host: "localhost")
```

### Using Presets

Presets produce a full configuration ready for ``SRTCaller``:

```swift
let config = SRTServerPreset.awsMediaConnect
    .configuration(host: "media-connect.us-east-1.amazonaws.com")

let caller = SRTCaller(configuration: .init(
    host: config.host,
    port: config.port
))
```

## Next Steps

- <doc:ConfigurationGuide> — Full configuration options
- <doc:CallerGuide> — Using configurations with a caller
- <doc:InteroperabilityGuide> — Interop with SRT servers
