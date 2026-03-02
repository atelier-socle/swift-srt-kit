// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Connection group bonding mode.
public enum GroupMode: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Send on all links, receiver deduplicates.
    case broadcast
    /// One active link, standby backups with failover.
    case mainBackup
    /// Distribute packets across links for aggregate bandwidth.
    case balancing

    /// A human-readable description of this mode.
    public var description: String {
        switch self {
        case .broadcast: "Broadcast (all links)"
        case .mainBackup: "Main/Backup (failover)"
        case .balancing: "Balancing (aggregate)"
        }
    }
}
