// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Factory for creating and registering congestion control algorithms.
///
/// Built-in algorithms: "live" (LiveCC), "file" (FileCC).
/// Custom algorithms can be registered by name.
public struct CongestionControllerFactory: Sendable {
    /// Type-erased creator closure.
    public typealias Creator = @Sendable () -> any CongestionController

    /// Registered algorithm creators, keyed by name.
    private var creators: [String: Creator] = [:]

    /// Shared default factory with built-in algorithms registered.
    public static var `default`: CongestionControllerFactory {
        var factory = CongestionControllerFactory()
        factory.register(name: "live") { LiveCC() }
        factory.register(name: "file") { FileCC() }
        return factory
    }

    /// Creates an empty factory.
    public init() {}

    /// Register a congestion control algorithm.
    ///
    /// - Parameters:
    ///   - name: Algorithm name (e.g., "live", "file", "custom").
    ///   - creator: Closure that creates a new instance.
    public mutating func register(name: String, creator: @escaping Creator) {
        creators[name] = creator
    }

    /// Create a congestion controller by name.
    ///
    /// - Parameter name: Algorithm name.
    /// - Returns: A new instance, or nil if name not registered.
    public func create(name: String) -> (any CongestionController)? {
        creators[name]?()
    }

    /// List of registered algorithm names.
    public var registeredNames: [String] {
        Array(creators.keys).sorted()
    }

    /// Whether a name is registered.
    ///
    /// - Parameter name: Algorithm name to check.
    /// - Returns: `true` if the name is registered.
    public func isRegistered(name: String) -> Bool {
        creators[name] != nil
    }
}
