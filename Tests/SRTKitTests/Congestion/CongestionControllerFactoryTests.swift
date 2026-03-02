// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CongestionControllerFactory Tests")
struct CongestionControllerFactoryTests {
    @Test("Default factory has live and file registered")
    func defaultRegistered() {
        let factory = CongestionControllerFactory.default
        #expect(factory.isRegistered(name: "live"))
        #expect(factory.isRegistered(name: "file"))
    }

    @Test("create live returns LiveCC")
    func createLive() {
        let factory = CongestionControllerFactory.default
        let cc = factory.create(name: "live")
        #expect(cc != nil)
        #expect(cc?.name == "live")
    }

    @Test("create file returns FileCC")
    func createFile() {
        let factory = CongestionControllerFactory.default
        let cc = factory.create(name: "file")
        #expect(cc != nil)
        #expect(cc?.name == "file")
    }

    @Test("create unknown returns nil")
    func createUnknown() {
        let factory = CongestionControllerFactory.default
        #expect(factory.create(name: "unknown") == nil)
    }

    @Test("Register custom algorithm")
    func registerCustom() {
        var factory = CongestionControllerFactory()
        factory.register(name: "custom") { LiveCC() }
        let cc = factory.create(name: "custom")
        #expect(cc != nil)
        #expect(cc?.name == "live")  // It's a LiveCC under the hood
    }

    @Test("registeredNames contains all registered")
    func registeredNames() {
        let factory = CongestionControllerFactory.default
        let names = factory.registeredNames
        #expect(names.contains("live"))
        #expect(names.contains("file"))
        #expect(names.count == 2)
    }

    @Test("isRegistered for known and unknown names")
    func isRegistered() {
        let factory = CongestionControllerFactory.default
        #expect(factory.isRegistered(name: "live"))
        #expect(!factory.isRegistered(name: "nonexistent"))
    }

    @Test("Register same name twice replaces previous")
    func registerReplace() {
        var factory = CongestionControllerFactory()
        factory.register(name: "test") { LiveCC() }
        factory.register(name: "test") { FileCC() }
        let cc = factory.create(name: "test")
        #expect(cc?.name == "file")  // Replaced with FileCC
    }

    @Test("Empty factory has no registered names")
    func emptyFactory() {
        let factory = CongestionControllerFactory()
        #expect(factory.registeredNames.isEmpty)
        #expect(factory.create(name: "live") == nil)
    }
}
