//
//  LoomSSHServerTrustConfiguration.swift
//  Loom
//
//  Created by Codex on 3/10/26.
//

import CryptoKit
import Foundation
import NIOSSH

/// SSH host-certificate trust failures.
public enum LoomSSHServerTrustError: LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case missingHostCertificate
    case invalidHostCertificate(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(detail):
            "SSH server trust configuration is invalid: \(detail)"
        case .missingHostCertificate:
            "The SSH server did not present an OpenSSH host certificate."
        case let .invalidHostCertificate(detail):
            "The SSH host certificate is not trusted: \(detail)"
        }
    }
}

/// SSH server trust configuration shared by Loom bootstrap and emergency shell flows.
public struct LoomSSHServerTrustConfiguration: Sendable, Equatable, Codable {
    /// Canonical OpenSSH public keys for the host CAs trusted by the client.
    public let trustedHostAuthorities: [String]

    /// Required SSH host principal, typically derived from the Loom device ID.
    public let requiredPrincipal: String

    public init(
        trustedHostAuthorities: [String],
        requiredPrincipal: String
    ) {
        self.trustedHostAuthorities = trustedHostAuthorities
        self.requiredPrincipal = requiredPrincipal
    }

    /// Returns the canonical Loom SSH host principal for a device ID.
    public static func requiredPrincipal(for deviceID: UUID) -> String {
        "loom-device/\(deviceID.uuidString.lowercased())"
    }
}

/// Diagnostics emitted after a host certificate has been validated.
public struct LoomSSHValidatedHostCertificate: Sendable, Equatable {
    public let keyID: String
    public let principal: String
    public let hostKeyFingerprint: String

    public init(keyID: String, principal: String, hostKeyFingerprint: String) {
        self.keyID = keyID
        self.principal = principal
        self.hostKeyFingerprint = hostKeyFingerprint
    }
}

/// Shared validator for OpenSSH host certificates used by Loom-managed SSH flows.
public struct LoomSSHServerTrustValidator: Sendable {
    public let configuration: LoomSSHServerTrustConfiguration

    private let authorityKeys: [NIOSSHPublicKey]

    public init(configuration: LoomSSHServerTrustConfiguration) throws {
        let requiredPrincipal = configuration.requiredPrincipal
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requiredPrincipal.isEmpty else {
            throw LoomSSHServerTrustError.invalidConfiguration("Required principal must not be empty.")
        }

        let authorities = configuration.trustedHostAuthorities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !authorities.isEmpty else {
            throw LoomSSHServerTrustError.invalidConfiguration("At least one host CA key is required.")
        }

        do {
            authorityKeys = try authorities.map { authority in
                try NIOSSHPublicKey(openSSHPublicKey: authority)
            }
        } catch {
            throw LoomSSHServerTrustError.invalidConfiguration(
                "One or more trusted host CA public keys are invalid."
            )
        }

        self.configuration = LoomSSHServerTrustConfiguration(
            trustedHostAuthorities: authorities,
            requiredPrincipal: requiredPrincipal
        )
    }

    /// Validates a presented SSH host key and returns diagnostics about the certified leaf key.
    public func validate(hostKey: NIOSSHPublicKey) throws -> LoomSSHValidatedHostCertificate {
        guard let certifiedHostKey = NIOSSHCertifiedPublicKey(hostKey) else {
            throw LoomSSHServerTrustError.missingHostCertificate
        }

        do {
            _ = try certifiedHostKey.validate(
                principal: configuration.requiredPrincipal,
                type: .host,
                allowedAuthoritySigningKeys: authorityKeys,
                acceptableCriticalOptions: []
            )
            guard certifiedHostKey.validPrincipals == [configuration.requiredPrincipal] else {
                throw LoomSSHServerTrustError.invalidHostCertificate(
                    "The certificate must contain exactly the required Loom principal."
                )
            }

            let fingerprint = try Self.hostKeyFingerprint(for: certifiedHostKey.key)
            LoomLogger.ssh(
                "Validated SSH host certificate for \(configuration.requiredPrincipal) using leaf key \(fingerprint)"
            )
            return LoomSSHValidatedHostCertificate(
                keyID: certifiedHostKey.keyID,
                principal: configuration.requiredPrincipal,
                hostKeyFingerprint: fingerprint
            )
        } catch let error as LoomSSHServerTrustError {
            throw error
        } catch {
            throw LoomSSHServerTrustError.invalidHostCertificate(error.localizedDescription)
        }
    }

    public static func hostKeyFingerprint(for hostKey: NIOSSHPublicKey) throws -> String {
        let openSSH = String(openSSHPublicKey: hostKey)
        let components = openSSH.split(separator: " ")
        guard components.count >= 2,
              let keyData = Data(base64Encoded: String(components[1])) else {
            throw LoomSSHServerTrustError.invalidHostCertificate(
                "Failed to derive the SSH host-key fingerprint."
            )
        }

        let digest = SHA256.hash(data: keyData)
        return "SHA256:\(Data(digest).base64EncodedString())"
    }
}
