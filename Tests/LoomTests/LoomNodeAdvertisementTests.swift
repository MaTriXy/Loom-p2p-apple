//
//  LoomNodeAdvertisementTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/26/26.
//

@testable import Loom
import Foundation
import Testing

@Suite("Loom Node Advertisement")
struct LoomNodeAdvertisementTests {
    @Test("Advertisement leaves hostName unset when no explicit host name is provided")
    func advertisementLeavesHostNameUnsetWithoutExplicitValue() {
        let advertisement = LoomPeerAdvertisement(
            deviceID: UUID(),
            deviceType: .mac
        )

        let updated = LoomNode.advertisement(
            advertisement,
            withDirectTransportPorts: [:],
            serviceName: "Mirage Host"
        )

        #expect(updated.hostName == nil)
    }

    @Test("Advertisement preserves an explicit host name when one is already present")
    func advertisementPreservesExplicitHostName() {
        let advertisement = LoomPeerAdvertisement(
            deviceID: UUID(),
            deviceType: .mac,
            hostName: "existing.local"
        )

        let updated = LoomNode.advertisement(
            advertisement,
            withDirectTransportPorts: [:],
            serviceName: "Mirage Host"
        )

        #expect(updated.hostName == "existing.local")
    }
}
