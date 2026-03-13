//
//  LoomCloudKitPeerInfo.swift
//  Loom
//
//  Created by Ethan Lipnik on 1/28/26.
//
//  Peer information retrieved from CloudKit.
//

import Foundation
import Loom

/// Represents a peer stored in CloudKit.
public struct LoomCloudKitPeerInfo: Identifiable, Hashable, Sendable {
    public let id: LoomPeerID
    public let name: String
    public let deviceType: DeviceType
    public let advertisement: LoomPeerAdvertisement
    public let lastSeen: Date
    public let ownerUserID: String?
    public let isShared: Bool
    public let recordID: String
    public let identityPublicKey: Data?
    public let remoteAccessEnabled: Bool
    public let relaySessionID: String?
    public let bootstrapMetadata: LoomBootstrapMetadata?

    /// Typed capability view derived from the peer's current publication state.
    public var capabilities: LoomPeerCapabilities {
        LoomPeerCapabilities(
            advertisement: advertisement,
            remoteAccessEnabled: remoteAccessEnabled,
            relaySessionID: relaySessionID,
            bootstrapMetadata: bootstrapMetadata
        )
    }

    public var deviceID: UUID {
        id.deviceID
    }

    public var appID: String? {
        id.appID
    }

    public init(
        id: LoomPeerID,
        name: String,
        deviceType: DeviceType,
        advertisement: LoomPeerAdvertisement,
        lastSeen: Date,
        ownerUserID: String?,
        isShared: Bool,
        recordID: String,
        identityPublicKey: Data? = nil,
        remoteAccessEnabled: Bool = false,
        relaySessionID: String? = nil,
        bootstrapMetadata: LoomBootstrapMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.advertisement = advertisement
        self.lastSeen = lastSeen
        self.ownerUserID = ownerUserID
        self.isShared = isShared
        self.recordID = recordID
        self.identityPublicKey = identityPublicKey
        self.remoteAccessEnabled = remoteAccessEnabled
        self.relaySessionID = relaySessionID
        self.bootstrapMetadata = bootstrapMetadata
    }

    public init(
        id: UUID,
        appID: String? = nil,
        name: String,
        deviceType: DeviceType,
        advertisement: LoomPeerAdvertisement,
        lastSeen: Date,
        ownerUserID: String?,
        isShared: Bool,
        recordID: String,
        identityPublicKey: Data? = nil,
        remoteAccessEnabled: Bool = false,
        relaySessionID: String? = nil,
        bootstrapMetadata: LoomBootstrapMetadata? = nil
    ) {
        self.init(
            id: LoomPeerID(deviceID: id, appID: appID),
            name: name,
            deviceType: deviceType,
            advertisement: advertisement,
            lastSeen: lastSeen,
            ownerUserID: ownerUserID,
            isShared: isShared,
            recordID: recordID,
            identityPublicKey: identityPublicKey,
            remoteAccessEnabled: remoteAccessEnabled,
            relaySessionID: relaySessionID,
            bootstrapMetadata: bootstrapMetadata
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: LoomCloudKitPeerInfo, rhs: LoomCloudKitPeerInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CloudKit Record Keys

public extension LoomCloudKitPeerInfo {
    enum RecordKey: String {
        case deviceID
        case name
        case deviceType
        case advertisementBlob
        case identityPublicKey
        case remoteAccessEnabled
        case relaySessionID
        case bootstrapMetadataBlob
        case lastSeen
        case createdAt
    }
}
