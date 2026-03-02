// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Whether a FEC packet protects a row or column group.
public enum FECDirection: Sendable, Equatable {
    /// Row FEC: XOR across columns within one row.
    case row
    /// Column FEC: XOR across rows within one column.
    case column
}
