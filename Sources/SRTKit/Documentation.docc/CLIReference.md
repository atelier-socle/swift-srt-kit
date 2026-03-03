# CLI Reference

Use `srt-cli` for sending, receiving, probing, and diagnostics.

## Overview

`srt-cli` provides command-line tools for SRT operations: sending files or stdin to a listener, receiving data from a caller, probing available bandwidth, monitoring real-time statistics, running loopback tests, and displaying library information.

### Installation

```bash
swift build -c release
cp .build/release/srt-cli /usr/local/bin/
```

### Commands

| Command | Description |
|---------|-------------|
| `send` | Send data to an SRT listener |
| `receive` | Receive data from an SRT caller |
| `probe` | Probe available bandwidth and get recommendations |
| `stats` | Display real-time connection statistics |
| `test` | Run a loopback performance test |
| `info` | Display version and feature information |

### send

Send data to a remote SRT listener:

```bash
# Send a file
srt-cli send --host srt.example.com --port 4200 --file input.ts

# Send with encryption
srt-cli send --host srt.example.com --port 4200 --file input.ts \
    --passphrase "my-secret-key-phrase"

# Send with StreamID and preset
srt-cli send --host srt.example.com --port 4200 --file input.ts \
    --stream-id "#!::r=live,m=publish" --preset broadcast

# Send with custom latency
srt-cli send --host srt.example.com --port 4200 --file input.ts \
    --latency 250
```

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | `127.0.0.1` | Remote host |
| `--port` | `4200` | Remote port |
| `--file` | stdin | File to send |
| `--stream-id` | — | StreamID for access control |
| `--passphrase` | — | Encryption passphrase |
| `--preset` | — | Configuration preset |
| `--latency` | — | Latency in milliseconds |

### receive

Receive data from a remote SRT caller:

```bash
# Receive to file
srt-cli receive --port 4200 --output received.ts

# Receive with encryption
srt-cli receive --port 4200 --output received.ts \
    --passphrase "my-secret-key-phrase"

# Receive with duration limit
srt-cli receive --port 4200 --output received.ts --duration 60

# Bind to specific address
srt-cli receive --port 4200 --bind 192.168.1.1 --output received.ts
```

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | `4200` | Listen port |
| `--bind` | `0.0.0.0` | Bind address |
| `--output` | stdout | Output file |
| `--passphrase` | — | Encryption passphrase |
| `--latency` | — | Latency in milliseconds |
| `--duration` | `0` (unlimited) | Max duration in seconds |

### probe

Probe available bandwidth and generate recommendations:

```bash
# Standard probe
srt-cli probe --host srt.example.com --port 4200

# Quick probe with quality target
srt-cli probe --host srt.example.com --mode quick --target quality

# Thorough probe for low-latency optimization
srt-cli probe --host srt.example.com --mode thorough --target lowLatency
```

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | `127.0.0.1` | Remote host |
| `--port` | `4200` | Remote port |
| `--mode` | `standard` | Probe mode: `quick`, `standard`, `thorough` |
| `--target` | `balanced` | Target quality: `quality`, `balanced`, `lowLatency` |

### stats

Display real-time connection statistics:

```bash
# Monitor a connection
srt-cli stats --host srt.example.com --port 4200

# With quality scoring and 5-second interval
srt-cli stats --host srt.example.com --port 4200 \
    --interval 5 --quality
```

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | `127.0.0.1` | Remote host |
| `--port` | `4200` | Remote port |
| `--interval` | `2` | Refresh interval in seconds |
| `--stream-id` | — | StreamID |
| `--passphrase` | — | Encryption passphrase |
| `--quality` | `false` | Show quality score |

### test

Run a loopback performance test:

```bash
# Default: 5-second test at 5 Mbps on port 9999
srt-cli test

# Custom parameters
srt-cli test --duration 30 --bitrate 20000 --port 8888 --latency 250
```

| Option | Default | Description |
|--------|---------|-------------|
| `--duration` | `5` | Test duration in seconds |
| `--bitrate` | `5000` | Target bitrate in kbps |
| `--port` | `9999` | Loopback port |
| `--latency` | `120` | Latency in milliseconds |

### info

Display version and feature information:

```bash
srt-cli info
srt-cli info --verbose
```

| Option | Default | Description |
|--------|---------|-------------|
| `--verbose` | `false` | Show detailed feature list |

## Next Steps

- <doc:InteroperabilityGuide> — Using srt-cli with libsrt
- <doc:ProbingGuide> — Probe engine details
- <doc:TestingGuide> — Manual testing scenarios
