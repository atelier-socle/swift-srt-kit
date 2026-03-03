// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PluginRegistryError Tests")
struct PluginRegistryErrorTests {
    @Test("Each error has meaningful description")
    func descriptions() {
        #expect(
            PluginRegistryError.pluginAlreadyRegistered(name: "test")
                .description == "Plugin already registered: test")
        #expect(
            PluginRegistryError.pluginNotFound(name: "x")
                .description == "Plugin not found: x")
        #expect(
            PluginRegistryError.invalidConfiguration(reason: "bad")
                .description == "Invalid plugin configuration: bad")
    }

    @Test("Equatable: same cases are equal")
    func equatableSame() {
        #expect(
            PluginRegistryError.pluginAlreadyRegistered(name: "a")
                == PluginRegistryError.pluginAlreadyRegistered(name: "a"))
    }

    @Test("Equatable: different cases are not equal")
    func equatableDifferent() {
        #expect(
            PluginRegistryError.pluginAlreadyRegistered(name: "a")
                != PluginRegistryError.pluginNotFound(name: "a"))
    }
}
