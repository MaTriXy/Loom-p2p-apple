//
//  LoomCloudKitPeerProvider.swift
//  Loom
//
//  Created by Ethan Lipnik on 1/28/26.
//
//  Fetches peer information from CloudKit.
//

import CloudKit
import Foundation
import Loom
import Observation

/// Fetches peer information from CloudKit for display in app-owned UIs.
@Observable
@MainActor
public final class LoomCloudKitPeerProvider {
    public private(set) var ownPeers: [LoomCloudKitPeerInfo] = []
    public private(set) var isLoading = false
    public private(set) var lastError: Error?

    private let cloudKitManager: LoomCloudKitManager
    private let peerZoneID: CKRecordZone.ID
    private let peerRecordParser = PeerRecordSnapshotParser()

    public init(cloudKitManager: LoomCloudKitManager) {
        self.cloudKitManager = cloudKitManager
        peerZoneID = CKRecordZone.ID(
            zoneName: cloudKitManager.configuration.peerZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    public func fetchPeers() async {
        guard cloudKitManager.isAvailable else {
            LoomLogger.cloud("CloudKit unavailable, skipping peer fetch")
            return
        }

        isLoading = true
        defer { isLoading = false }
        lastError = nil

        await refreshOwnPeers()
    }

    public func refreshOwnPeers() async {
        guard let container = cloudKitManager.container else { return }

        let query = CKQuery(
            recordType: cloudKitManager.configuration.peerRecordType,
            predicate: NSPredicate(value: true)
        )

        do {
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: peerZoneID
            )

            let snapshots = makeSnapshots(
                from: results
            )
            let peers = await peerRecordParser.parse(snapshots)
            ownPeers = peers.sorted { $0.name < $1.name }
            LoomLogger.cloud("Fetched \(peers.count) own peers from CloudKit")
        } catch {
            LoomLogger.error(.cloud, error: error, message: "Failed to fetch own peers: ")
            lastError = error
        }
    }

    public func removeOwnPeer(deviceID: UUID) async throws {
        guard let container = cloudKitManager.container else { throw LoomCloudKitError.containerUnavailable }

        let recordIDs = try await queryPeerRecordIDs(
            database: container.privateCloudDatabase,
            zoneID: peerZoneID,
            deviceID: deviceID
        )

        if recordIDs.isEmpty {
            ownPeers.removeAll { $0.deviceID == deviceID }
            return
        }

        _ = try await container.privateCloudDatabase.modifyRecords(
            saving: [],
            deleting: recordIDs
        )
        ownPeers.removeAll { $0.deviceID == deviceID }
        LoomLogger.cloud("Removed own CloudKit peer record(s) for \(deviceID)")
    }

    public func removePeer(_ peer: LoomCloudKitPeerInfo) async throws {
        try await removeOwnPeer(deviceID: peer.deviceID)
    }

    private func makeSnapshots(
        from results: [(CKRecord.ID, Result<CKRecord, any Error>)]
    ) -> [PeerRecordSnapshot] {
        var snapshots: [PeerRecordSnapshot] = []
        for (_, result) in results {
            guard case let .success(record) = result else { continue }
            snapshots.append(
                PeerRecordSnapshot(
                    recordID: record.recordID.recordName,
                    deviceIDString: record[LoomCloudKitPeerInfo.RecordKey.deviceID.rawValue] as? String,
                    name: record[LoomCloudKitPeerInfo.RecordKey.name.rawValue] as? String,
                    deviceTypeRawValue: record[LoomCloudKitPeerInfo.RecordKey.deviceType.rawValue] as? String,
                    advertisementBlob: record[LoomCloudKitPeerInfo.RecordKey.advertisementBlob.rawValue] as? Data,
                    identityPublicKey: record[LoomCloudKitPeerInfo.RecordKey.identityPublicKey.rawValue] as? Data,
                    remoteAccessEnabled: (record[LoomCloudKitPeerInfo.RecordKey.remoteAccessEnabled.rawValue] as? Int64).map { $0 != 0 },
                    signalingSessionID: record[LoomCloudKitPeerInfo.RecordKey.signalingSessionID.rawValue] as? String,
                    bootstrapMetadataBlob: record[LoomCloudKitPeerInfo.RecordKey.bootstrapMetadataBlob.rawValue] as? Data,
                    overlayHintsBlob: record[LoomCloudKitPeerInfo.RecordKey.overlayHintsBlob.rawValue] as? Data,
                    lastSeen: record[LoomCloudKitPeerInfo.RecordKey.lastSeen.rawValue] as? Date
                )
            )
        }
        return snapshots
    }

    private func queryPeerRecordIDs(
        database: CKDatabase,
        zoneID: CKRecordZone.ID,
        deviceID: UUID
    ) async throws -> [CKRecord.ID] {
        let query = CKQuery(
            recordType: cloudKitManager.configuration.peerRecordType,
            predicate: NSPredicate(
                format: "%K == %@",
                LoomCloudKitPeerInfo.RecordKey.deviceID.rawValue,
                deviceID.uuidString
            )
        )
        let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            try? result.get().recordID
        }
    }
}

private struct PeerRecordSnapshot: Sendable {
    let recordID: String
    let deviceIDString: String?
    let name: String?
    let deviceTypeRawValue: String?
    let advertisementBlob: Data?
    let identityPublicKey: Data?
    let remoteAccessEnabled: Bool?
    let signalingSessionID: String?
    let bootstrapMetadataBlob: Data?
    let overlayHintsBlob: Data?
    let lastSeen: Date?
}

private actor PeerRecordSnapshotParser {
    func parse(_ snapshots: [PeerRecordSnapshot]) -> [LoomCloudKitPeerInfo] {
        snapshots.flatMap(parsePeerRecord)
    }

    private func parsePeerRecord(_ snapshot: PeerRecordSnapshot) -> [LoomCloudKitPeerInfo] {
        guard let rawDeviceID = snapshot.deviceIDString,
              let deviceID = UUID(uuidString: rawDeviceID) else {
            LoomLogger.cloud("Skipping peer record with invalid deviceID: \(snapshot.recordID)")
            return []
        }

        let deviceType = snapshot.deviceTypeRawValue.flatMap(DeviceType.init(rawValue:)) ?? .unknown
        let advertisement = snapshot.advertisementBlob.flatMap {
            try? JSONDecoder().decode(LoomPeerAdvertisement.self, from: $0)
        } ?? LoomPeerAdvertisement(
            deviceID: deviceID,
            deviceType: deviceType
        )
        let bootstrapMetadata = snapshot.bootstrapMetadataBlob.flatMap {
            try? JSONDecoder().decode(LoomBootstrapMetadata.self, from: $0)
        }
        let overlayHints = snapshot.overlayHintsBlob.flatMap {
            try? JSONDecoder().decode([LoomCloudKitOverlayHint].self, from: $0)
        } ?? []

        let projections = LoomHostCatalogCodec.projections(
            peerName: snapshot.name ?? "Unknown Peer",
            advertisement: advertisement
        )
        return projections.map { projection in
            LoomCloudKitPeerInfo(
                id: projection.peerID,
                name: projection.displayName,
                deviceType: deviceType,
                advertisement: projection.advertisement,
                lastSeen: snapshot.lastSeen ?? Date.distantPast,
                recordID: snapshot.recordID,
                identityPublicKey: snapshot.identityPublicKey,
                remoteAccessEnabled: snapshot.remoteAccessEnabled ?? false,
                signalingSessionID: snapshot.signalingSessionID,
                bootstrapMetadata: bootstrapMetadata,
                overlayHints: overlayHints
            )
        }
    }
}
