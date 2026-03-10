//
//  LoomBootstrapClientTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/9/26.
//

@testable import Loom
import Testing

@Suite("Loom Bootstrap Clients")
struct LoomBootstrapClientTests {
    @Test("SSH bootstrap records unlock requests")
    func sshBootstrapUnlockRequest() async throws {
        let client = SSHBootstrapClientSpy()
        let endpoint = LoomBootstrapEndpoint(host: "host.local", port: 22, source: .user)

        let result = try await client.unlockVolumeOverSSH(
            endpoint: endpoint,
            username: "ethan",
            password: "hunter2",
            expectedHostKeyFingerprint: "SHA256:test",
            timeout: .seconds(20)
        )

        let call = await client.recordedCall()
        #expect(call?.endpoint == endpoint)
        #expect(call?.username == "ethan")
        #expect(call?.password == "hunter2")
        #expect(call?.expectedHostKeyFingerprint == "SHA256:test")
        #expect(call?.timeout == .seconds(20))
        #expect(result.unlocked)
    }

    @Test("Bootstrap control result exposes session activity")
    func bootstrapControlResultState() {
        let ready = LoomBootstrapControlResult(state: .ready, message: "ready")
        let waiting = LoomBootstrapControlResult(
            state: .credentialsRequired,
            message: "credentials required"
        )

        #expect(ready.state == .ready)
        #expect(ready.isSessionActive)
        #expect(waiting.state == .credentialsRequired)
        #expect(!waiting.isSessionActive)
    }

    @Test("Bootstrap control records unlock requests")
    func bootstrapControlUnlockRequest() async throws {
        let client = BootstrapControlClientSpy()
        let endpoint = LoomBootstrapEndpoint(host: "host.local", port: 22, source: .auto)

        let result = try await client.requestUnlock(
            endpoint: endpoint,
            controlPort: 9849,
            controlAuthSecret: "secret",
            username: "ethan",
            password: "hunter2",
            timeout: .seconds(30)
        )

        let call = await client.recordedCall()
        #expect(call?.endpoint == endpoint)
        #expect(call?.controlPort == 9849)
        #expect(call?.controlAuthSecret == "secret")
        #expect(call?.username == "ethan")
        #expect(call?.password == "hunter2")
        #expect(call?.timeout == .seconds(30))
        #expect(result.state == .ready)
        #expect(result.isSessionActive)
    }
}

private struct SSHBootstrapCall: Sendable, Equatable {
    let endpoint: LoomBootstrapEndpoint
    let username: String
    let password: String
    let expectedHostKeyFingerprint: String
    let timeout: Duration
}

private actor SSHBootstrapClientSpy: LoomSSHBootstrapClient {
    private var lastCall: SSHBootstrapCall?

    func unlockVolumeOverSSH(
        endpoint: LoomBootstrapEndpoint,
        username: String,
        password: String,
        expectedHostKeyFingerprint: String,
        timeout: Duration
    ) async throws -> LoomSSHBootstrapResult {
        lastCall = SSHBootstrapCall(
            endpoint: endpoint,
            username: username,
            password: password,
            expectedHostKeyFingerprint: expectedHostKeyFingerprint,
            timeout: timeout
        )
        return LoomSSHBootstrapResult(unlocked: true)
    }

    func recordedCall() -> SSHBootstrapCall? {
        lastCall
    }
}

private struct BootstrapControlCall: Sendable, Equatable {
    let endpoint: LoomBootstrapEndpoint
    let controlPort: UInt16
    let controlAuthSecret: String
    let username: String
    let password: String
    let timeout: Duration
}

private actor BootstrapControlClientSpy: LoomBootstrapControlClient {
    private var lastCall: BootstrapControlCall?

    func requestStatus(
        endpoint _: LoomBootstrapEndpoint,
        controlPort _: UInt16,
        controlAuthSecret _: String,
        timeout _: Duration
    ) async throws -> LoomBootstrapControlResult {
        LoomBootstrapControlResult(state: .credentialsRequired, message: nil)
    }

    func requestUnlock(
        endpoint: LoomBootstrapEndpoint,
        controlPort: UInt16,
        controlAuthSecret: String,
        username: String,
        password: String,
        timeout: Duration
    ) async throws -> LoomBootstrapControlResult {
        lastCall = BootstrapControlCall(
            endpoint: endpoint,
            controlPort: controlPort,
            controlAuthSecret: controlAuthSecret,
            username: username,
            password: password,
            timeout: timeout
        )
        return LoomBootstrapControlResult(state: .ready, message: "ready")
    }

    func recordedCall() -> BootstrapControlCall? {
        lastCall
    }
}
