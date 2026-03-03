// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the congestion controller plugin system.
public enum PluginRegistryError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Plugin name already registered.
    case pluginAlreadyRegistered(name: String)

    /// Plugin not found.
    case pluginNotFound(name: String)

    /// Invalid plugin configuration.
    case invalidConfiguration(reason: String)

    /// Human-readable description.
    public var description: String {
        switch self {
        case .pluginAlreadyRegistered(let name):
            return "Plugin already registered: \(name)"
        case .pluginNotFound(let name):
            return "Plugin not found: \(name)"
        case .invalidConfiguration(let reason):
            return "Invalid plugin configuration: \(reason)"
        }
    }
}
