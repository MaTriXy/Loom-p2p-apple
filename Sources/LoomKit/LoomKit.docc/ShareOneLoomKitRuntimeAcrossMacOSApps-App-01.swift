import LoomHost

let sharedHost = LoomSharedHostConfiguration(
    appGroupIdentifier: "group.com.example.studio",
    app: LoomHostAppDescriptor(
        appID: "com.example.studio.mac",
        displayName: "Studio",
        metadata: ["role": "editor"],
        supportedFeatures: ["studio.projects.v1"]
    )
)
