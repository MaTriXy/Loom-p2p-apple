# Loom

Loom is a Swift package for building trusted device-to-device connections on Apple platforms.

It gives you the networking layer for apps that need to find nearby peers, establish sessions, verify identity, and support remote reachability without baking product-specific behavior into the transport stack.

Used in [MirageKit](https://github.com/EthanLipnik/MirageKit).

## Why Loom

- Discover peers over Bonjour with peer-to-peer support
- Establish direct sessions with `Network.framework`
- Generate and rotate stable device identity with `LoomIdentityManager`
- Plug in trust policy with `LoomTrustProvider` and `LoomTrustStore`
- Add remote coordination with relay presence and STUN probing
- Support bootstrap flows such as Wake-on-LAN, SSH, and control-channel credential exchange
- Capture networking diagnostics and instrumentation

## Modules

- `Loom`: Core discovery, identity, trust, sessions, relay, bootstrap, and diagnostics APIs
- `LoomCloudKit`: Optional CloudKit-backed peer sharing and trust integration

## Requirements

- Swift 6.2+
- macOS 14+
- iOS 17.4+
- visionOS 26+

## Installation

Add Loom to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/EthanLipnik/Loom.git", branch: "main")
]
```

Then depend on either product:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Loom", package: "Loom"),
        // .product(name: "LoomCloudKit", package: "Loom"),
    ]
)
```

## Quick Start

Create a node:

```swift
import Loom

let node = LoomNode(
    configuration: LoomNetworkConfiguration(
        serviceType: "_myapp._tcp",
        enablePeerToPeer: true
    ),
    identityManager: LoomIdentityManager.shared
)
```

Advertise your device:

```swift
import Foundation

let identity = try LoomIdentityManager.shared.currentIdentity()

let advertisement = LoomPeerAdvertisement(
    deviceID: UUID(),
    identityKeyID: identity.keyID,
    deviceType: .mac,
    metadata: [
        "app.version": "1",
        "role": "host",
    ]
)

let port = try await node.startAdvertising(
    serviceName: "My Mac",
    advertisement: advertisement
) { session in
    session.start(queue: .main)
}

print("Advertising on port \(port)")
```

Discover peers:

```swift
let discovery = node.makeDiscovery()

discovery.onPeersChanged = { peers in
    for peer in peers {
        print("Found \(peer.name) at \(peer.endpoint)")
    }
}

discovery.startDiscovery()
```

Connect to a peer:

```swift
import Network

let connection = NWConnection(to: peer.endpoint, using: .tcp)
let session = node.makeSession(connection: connection)

session.setStateUpdateHandler { state in
    print("Session state:", state)
}

session.start(queue: .main)
```

## CloudKit Integration

If your app needs shared peer membership or CloudKit-backed trust decisions, add `LoomCloudKit`.

The module includes:

- `LoomCloudKitManager` for CloudKit lifecycle and identity registration
- `LoomCloudKitPeerProvider` for fetching shared peers
- `LoomCloudKitTrustProvider` for trust evaluation backed by CloudKit participants
- `LoomCloudKitShareManager` for sharing UI and participant management

Start with `LoomCloudKitConfiguration(containerIdentifier: "iCloud.com.yourapp.container")` and customize the record type names only if your app needs different schema names.

## Documentation

- [API docs](https://ethanlipnik.github.io/Loom/documentation/loom/)
- [Architecture notes](Architecture.md)

## Development

```bash
swift build
swift test --scratch-path .build-local
```
