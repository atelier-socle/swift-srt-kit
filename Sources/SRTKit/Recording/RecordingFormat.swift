// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Supported recording output formats.
public enum RecordingFormat: String, Sendable, CaseIterable {
    /// Raw binary — write payload bytes as-is.
    case raw
    /// MPEG-TS — packets are already MPEG-TS (188-byte aligned).
    case mpegts
}
