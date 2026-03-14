# What's New in 0.3.0

Critical interoperability fixes for live streaming with MediaMTX and libsrt receivers.

## Overview

Version 0.3.0 resolves four protocol-level bugs that prevented SRTKit from successfully streaming MPEG-TS data to libsrt-based receivers such as MediaMTX, SRT Live Server, and Haivision Media Gateway.

### Data Packet Message Number

Each SRT data packet carries a 26-bit message number (bits 25–0 of header word 1). In live mode, every `send()` creates a message with a unique number. Prior to 0.3.0, SRTKit sent all data packets with `messageNumber = 0`, causing libsrt receivers to drop every packet after the first as a duplicate of "message 0."

Message numbers now start at 1 and increment on each send, wrapping at `0x03FFFFFF` (2²⁶ − 1). Value 0 is reserved for FEC control packets, matching libsrt behavior.

### ACK Processing and ACKACK Response

SRTKit previously ignored ACK control packets from the receiver (`case .ack: break`). This caused two failures:

- The send buffer was never released, overflowing after approximately 47 seconds
- No ACKACK was sent, preventing the receiver from calculating RTT

SRTKit now parses the ACK CIF (Last Acknowledged Sequence Number, RTT, buffer size), calls `processACK()` to release acknowledged packets from the send buffer, and responds with an ACKACK control packet (type `0x0006`) echoing the ACK sequence number.

### Random Initial Sequence Number

The handshake Conclusion packet now uses a random 31-bit ISN instead of a fixed value. Both caller and listener generate independent random ISNs, and the dual-ISN model is correctly propagated through the packet pipeline — send path uses the local ISN, receive buffer uses the peer's ISN.

### Dynamic Handshake Extension Flags

The listener handshake now computes the `HSRSP` extension field dynamically based on which extensions are actually present (HSRSP, KMRSP, SID) rather than hardcoding a fixed value. This ensures correct parsing by strict SRT implementations.

## Interoperability

### Tested Configurations

| Server | Version | Protocol | Status |
|--------|---------|----------|--------|
| MediaMTX | 1.16.3 | SRT → RTMP relay | Validated |
| srt-live-transmit | libsrt 1.5.4 | Direct SRT | Validated |

### StreamID Formats

SRTKit supports both StreamID formats used by SRT servers:

| Format | Example | Used By |
|--------|---------|---------|
| SRT Access Control | `#!::r=live/test,m=publish` | libsrt, Haivision |
| Short format | `publish:live/test` | MediaMTX |

Configure the StreamID on ``SRTCaller``:

```swift
let caller = SRTCaller(configuration: .init(
    host: "localhost",
    port: 8890,
    streamID: "#!::r=live/test,m=publish"
))
```

## Wire Format Reference

### Data Packet Header (IETF draft-sharabayko-srt §3.1)

```
Word 0: 0 | Sequence Number (31 bits)
Word 1: PP (2) | O (1) | KK (2) | R (1) | Message Number (26 bits)
Word 2: Timestamp (32 bits)
Word 3: Destination Socket ID (32 bits)
```

### ACKACK Packet (§3.2.2)

```
Word 0: 1 | 0x0006 (15 bits) | 0 (16 bits)
Word 1: ACK Sequence Number (echoed)
Word 2: Timestamp
Word 3: Destination Socket ID
(no CIF)
```

## Next Steps

- <doc:InteroperabilityGuide> — Full interop configuration details
- <doc:AccessControlGuide> — StreamID format and access modes
- <doc:CallerGuide> — Caller setup and configuration
