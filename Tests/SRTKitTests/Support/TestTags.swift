// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif


extension Tag {
    /// Tests that perform real network I/O (UDP loopback).
    @Tag static var network: Self
}

/// Detects CI environment (GitHub Actions, etc.) without importing Foundation.
///
/// Uses C stdlib `getenv` — no Foundation dependency.
var isCI: Bool {
    getenv("CI") != nil || getenv("GITHUB_ACTIONS") != nil
}
