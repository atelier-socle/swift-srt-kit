# Access Control Guide

Route and filter connections with StreamID.

## Overview

SRT access control uses the StreamID mechanism to carry structured metadata during the handshake. ``SRTAccessControl`` parses and generates StreamID strings in the `#!::` format, enabling server-side routing, authentication, and content negotiation.

### StreamID Format

The standard format is `#!::key1=value1,key2=value2`:

| Key | Description | Example |
|-----|-------------|---------|
| `r` | Resource name | `r=live/feed1` |
| `m` | Mode (publish/request) | `m=publish` |
| `s` | Session ID | `s=abc123` |
| `u` | User name | `u=operator` |
| `t` | Content type | `t=stream` |

### Parsing

``SRTAccessControl/parse(_:)`` extracts structured fields from a StreamID string:

```swift
let streamID = "#!::r=live/feed1,m=publish,u=operator"
let access = SRTAccessControl.parse(streamID)

access.resource   // "live/feed1"
access.mode       // .publish
access.userName   // "operator"
```

### Generating

``SRTAccessControl/generate()`` produces a StreamID string from structured fields:

```swift
let access = SRTAccessControl(
    resource: "live/feed1",
    mode: .publish,
    userName: "operator")
let streamID = access.generate()
// "#!::r=live/feed1,m=publish,u=operator"
```

### Access Modes

| Mode | Description |
|------|-------------|
| `.request` | Receive data (caller wants to pull) |
| `.publish` | Send data (caller wants to push) |
| `.bidirectional` | Both directions |

### Content Types

| Type | Description |
|------|-------------|
| `.stream` | Live media stream |
| `.file` | File transfer |
| `.auth` | Authentication handshake |

### Usage with Caller

Set the `streamID` on the caller configuration:

```swift
let caller = SRTCaller(configuration: .init(
    host: "srt.example.com",
    port: 4200,
    streamID: "#!::r=live/cam1,m=publish"
))
try await caller.connect()
```

The StreamID is transmitted during the handshake conclusion and is available to the listener for routing decisions.

## Next Steps

- <doc:CallerGuide> — Caller configuration with StreamID
- <doc:ListenerGuide> — Listener-side access control
- <doc:ConfigurationGuide> — Full configuration options
