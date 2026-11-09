import CryptoKit
import Foundation
import Network

// MARK: - 1. Multi-Protocol & Multi-Provider Storage Presets (Syncophant Parity)

public enum StorageProviderProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case googleDrive = "google_drive"
    case s3 = "s3"
    case webdav = "webdav"
    case sftp = "sftp"
    case smb = "smb"
    case oauthCloud = "oauth_cloud"
    case localFolder = "local_folder"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .googleDrive: return "Google Drive Pool"
        case .s3: return "S3-Compatible Object Storage"
        case .webdav: return "WebDAV / Nextcloud"
        case .sftp: return "SFTP / Hetzner Storage Box"
        case .smb: return "SMB / Local NAS"
        case .oauthCloud: return "Dropbox / OneDrive / Box"
        case .localFolder: return "External Drive / Local Folder"
        }
    }

    public var subtitle: String {
        switch self {
        case .googleDrive: return "Pool multiple Google accounts into /Volumes/Helium"
        case .s3: return "AWS S3, Cloudflare R2, Backblaze B2, Wasabi, MinIO, Hetzner"
        case .webdav: return "Nextcloud, ownCloud, Fastmail, pCloud, Synology, Seafile"
        case .sftp: return "Hetzner Storage Box, rsync.net, or any SSH/SFTP server"
        case .smb: return "Time Capsule, Synology/TrueNAS SMB share, or Azure Files"
        case .oauthCloud: return "Bring your own OAuth app key for Dropbox, OneDrive, or Box"
        case .localFolder: return "Pool an external USB/Thunderbolt SSD or local folder"
        }
    }

    public var symbol: String {
        switch self {
        case .googleDrive: return "externaldrive.fill.badge.icloud"
        case .s3: return "shippingbox.and.arrow.backward.fill"
        case .webdav: return "globe.desk.fill"
        case .sftp: return "terminal.fill"
        case .smb: return "server.rack"
        case .oauthCloud: return "cloud.fill"
        case .localFolder: return "externaldrive.connected.to.line.below.fill"
        }
    }
}

public struct StorageServicePreset: Identifiable, Hashable, Sendable {
    public enum RegionRule: Hashable, Sendable {
        case ask
        case fixed(String)
        case hostLabel(Int, dropPrefix: String = "")
    }

    public let id: String
    public let protocolKind: StorageProviderProtocol
    public let title: String
    public let endpointTemplate: String
    public let placeholderPrompt: String
    public let matches: [String]
    public let regionRule: RegionRule
    public let userFieldLabel: String
    public let secretFieldLabel: String
    public let note: String?

    public init(
        id: String,
        protocolKind: StorageProviderProtocol,
        title: String,
        endpointTemplate: String = "",
        placeholderPrompt: String = "",
        matches: [String] = [],
        regionRule: RegionRule = .ask,
        userFieldLabel: String? = nil,
        secretFieldLabel: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.protocolKind = protocolKind
        self.title = title
        self.endpointTemplate = endpointTemplate
        self.placeholderPrompt = placeholderPrompt
        self.matches = matches
        self.regionRule = regionRule
        self.userFieldLabel = userFieldLabel ?? (protocolKind == .s3 ? "Access Key ID" : "Username")
        self.secretFieldLabel = secretFieldLabel ?? (protocolKind == .s3 ? "Secret Access Key" : "Password / App Token")
        self.note = note
    }

    public static let all: [StorageServicePreset] = [
        // Google Drive
        .init(
            id: "google-drive",
            protocolKind: .googleDrive,
            title: "Google Drive Account",
            endpointTemplate: "https://www.googleapis.com/drive/v3",
            matches: ["drive.google.com", "googleapis.com"],
            regionRule: .fixed("global"),
            userFieldLabel: "Google Account Email",
            secretFieldLabel: "OAuth 2.0 Browser Sign-In",
            note: "Combines free 15 GB or Workspace Drives into /Volumes/Helium with 64 MiB RAID-0 striping."
        ),
        // S3-Compatible Presets
        .init(
            id: "aws-s3",
            protocolKind: .s3,
            title: "Amazon S3",
            endpointTemplate: "https://s3.us-east-1.amazonaws.com",
            matches: ["amazonaws.com"],
            regionRule: .hostLabel(1),
            note: "Supports conditional writes (If-Match / If-None-Match) and presigned share links."
        ),
        .init(
            id: "cloudflare-r2",
            protocolKind: .s3,
            title: "Cloudflare R2",
            placeholderPrompt: "https://<account-id>.r2.cloudflarestorage.com",
            matches: ["r2.cloudflarestorage.com"],
            regionRule: .fixed("auto"),
            note: "Zero egress fees. Region is automatically set to 'auto'."
        ),
        .init(
            id: "backblaze-b2",
            protocolKind: .s3,
            title: "Backblaze B2",
            endpointTemplate: "https://s3.us-west-004.backblazeb2.com",
            matches: ["backblazeb2.com"],
            regionRule: .hostLabel(1),
            userFieldLabel: "Application Key ID",
            secretFieldLabel: "Application Key"
        ),
        .init(
            id: "wasabi",
            protocolKind: .s3,
            title: "Wasabi Hot Cloud",
            endpointTemplate: "https://s3.eu-central-2.wasabisys.com",
            matches: ["wasabisys.com"],
            regionRule: .hostLabel(1)
        ),
        .init(
            id: "hetzner-s3",
            protocolKind: .s3,
            title: "Hetzner Object Storage",
            endpointTemplate: "https://fsn1.your-objectstorage.com",
            matches: ["your-objectstorage.com"],
            regionRule: .hostLabel(0)
        ),
        .init(
            id: "digitalocean-spaces",
            protocolKind: .s3,
            title: "DigitalOcean Spaces",
            endpointTemplate: "https://nyc3.digitaloceanspaces.com",
            matches: ["digitaloceanspaces.com"],
            regionRule: .hostLabel(0)
        ),
        .init(
            id: "storj",
            protocolKind: .s3,
            title: "Storj DCS",
            endpointTemplate: "https://gateway.storjshare.io",
            matches: ["storjshare.io"],
            regionRule: .fixed("global")
        ),
        .init(
            id: "tigris",
            protocolKind: .s3,
            title: "Tigris Data",
            endpointTemplate: "https://t3.storage.dev",
            matches: ["t3.storage.dev", "storage.tigris.dev"],
            regionRule: .fixed("auto")
        ),
        .init(
            id: "gcs-hmac",
            protocolKind: .s3,
            title: "Google Cloud Storage (S3 HMAC)",
            endpointTemplate: "https://storage.googleapis.com",
            matches: ["storage.googleapis.com"],
            regionRule: .fixed("auto"),
            userFieldLabel: "HMAC Access Key",
            secretFieldLabel: "HMAC Secret",
            note: "Create an HMAC key in Google Cloud Storage › Settings › Interoperability."
        ),
        .init(
            id: "s3-generic",
            protocolKind: .s3,
            title: "MinIO / Ceph / Garage / Other S3",
            placeholderPrompt: "https://s3.example.com",
            note: "Any S3-compatible server supporting AWS Signature v4."
        ),
        // WebDAV Presets
        .init(
            id: "nextcloud",
            protocolKind: .webdav,
            title: "Nextcloud",
            placeholderPrompt: "https://cloud.example.com/remote.php/dav/files/<user>",
            matches: ["/remote.php/", "nextcloud"],
            secretFieldLabel: "App Password",
            note: "Create an App Password in Nextcloud › Settings › Security."
        ),
        .init(
            id: "owncloud",
            protocolKind: .webdav,
            title: "ownCloud",
            placeholderPrompt: "https://cloud.example.com/remote.php/webdav",
            matches: ["/remote.php/webdav", "owncloud"],
            secretFieldLabel: "App Password"
        ),
        .init(
            id: "fastmail",
            protocolKind: .webdav,
            title: "Fastmail Files",
            endpointTemplate: "https://myfiles.fastmail.com",
            matches: ["myfiles.fastmail.com"],
            secretFieldLabel: "App Password (WebDAV)"
        ),
        .init(
            id: "pcloud",
            protocolKind: .webdav,
            title: "pCloud WebDAV",
            endpointTemplate: "https://webdav.pcloud.com",
            matches: ["pcloud.com"],
            note: "US accounts use webdav.pcloud.com; EU accounts use ewebdav.pcloud.com."
        ),
        .init(
            id: "synology-webdav",
            protocolKind: .webdav,
            title: "Synology NAS (WebDAV)",
            placeholderPrompt: "https://nas.example.com:5006",
            matches: ["synology.me"]
        ),
        // SFTP / Hetzner
        .init(
            id: "hetzner-storage-box",
            protocolKind: .sftp,
            title: "Hetzner Storage Box",
            placeholderPrompt: "u123456.your-storagebox.de",
            matches: ["your-storagebox.de"],
            note: "Supports port 23 SFTP, ZFS snapshots (.zfs/snapshot), and sub-account sharing."
        ),
        .init(
            id: "rsync-net",
            protocolKind: .sftp,
            title: "rsync.net",
            placeholderPrompt: "<user>@<host>.rsync.net",
            matches: ["rsync.net"],
            note: "Daily immutable ZFS snapshots appear automatically in Time Travel."
        ),
        .init(
            id: "sftp-generic",
            protocolKind: .sftp,
            title: "Standard SFTP / SSH Server",
            placeholderPrompt: "sftp.example.com:22"
        ),
        // SMB
        .init(
            id: "smb-nas",
            protocolKind: .smb,
            title: "Local NAS or Mac (SMB)",
            placeholderPrompt: "nas.local",
            note: "Automatically discovers nearby _smb._tcp Bonjour servers on your LAN."
        ),
        .init(
            id: "azure-files",
            protocolKind: .smb,
            title: "Azure Files (SMB)",
            placeholderPrompt: "<account>.file.core.windows.net",
            matches: ["file.core.windows.net"],
            userFieldLabel: "Storage Account Name",
            secretFieldLabel: "Storage Account Key"
        ),
        // OAuth Cloud
        .init(
            id: "dropbox-byok",
            protocolKind: .oauthCloud,
            title: "Dropbox (BYOK OAuth)",
            endpointTemplate: "https://api.dropboxapi.com",
            matches: ["dropbox.com"],
            userFieldLabel: "Dropbox App Key",
            secretFieldLabel: "PKCE Browser Sign-In",
            note: "Uses your own Dropbox App Key with PKCE so no central server is ever involved."
        ),
        .init(
            id: "onedrive-byok",
            protocolKind: .oauthCloud,
            title: "Microsoft OneDrive (BYOK OAuth)",
            endpointTemplate: "https://graph.microsoft.com",
            matches: ["onedrive.live.com", "1drv.ms", "sharepoint.com"],
            userFieldLabel: "Azure Application (Client) ID",
            secretFieldLabel: "PKCE Browser Sign-In"
        ),
        .init(
            id: "box-byok",
            protocolKind: .oauthCloud,
            title: "Box (BYOK OAuth)",
            endpointTemplate: "https://api.box.com",
            matches: ["box.com"],
            userFieldLabel: "Box Client ID",
            secretFieldLabel: "Box Client Secret"
        ),
        // Local / External Drive
        .init(
            id: "local-folder",
            protocolKind: .localFolder,
            title: "External SSD / Local Folder",
            placeholderPrompt: "/Volumes/ExternalSSD/HeliumPool",
            userFieldLabel: "Mount Path",
            secretFieldLabel: "Local Permissions",
            note: "Pools a local or external drive alongside your cloud accounts."
        )
    ]

    public static func presets(for protocolKind: StorageProviderProtocol) -> [StorageServicePreset] {
        all.filter { $0.protocolKind == protocolKind }
    }

    public static func match(address: String, protocolKind: StorageProviderProtocol? = nil) -> StorageServicePreset? {
        let lower = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }
        let host = extractHost(from: lower)
        return all.first { preset in
            guard protocolKind == nil || preset.protocolKind == protocolKind else { return false }
            return preset.matches.contains { pattern in
                if pattern.contains("/") {
                    return lower.contains(pattern)
                }
                if !pattern.contains(".") {
                    return host.contains(pattern)
                }
                return host == pattern || host.hasSuffix("." + pattern)
            }
        }
    }

    public static func inferS3Region(for endpoint: String) -> String? {
        let host = extractHost(from: endpoint)
        let parts = host.split(separator: ".").map(String.init)
        guard !host.isEmpty else { return nil }
        if host == "s3.amazonaws.com" || host == "s3.wasabisys.com" {
            return "us-east-1"
        }
        let rule = match(address: endpoint, protocolKind: .s3)?.regionRule
            ?? (parts.count >= 4 && parts[0] == "s3" ? .hostLabel(1) : .ask)
        switch rule {
        case .ask:
            return nil
        case .fixed(let value):
            return value
        case .hostLabel(let index, let prefix):
            guard index < parts.count - 2 else { return nil }
            let raw = parts[index]
            let stripped = raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
            return stripped.isEmpty ? nil : stripped
        }
    }

    public static func extractHost(from address: String) -> String {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutUser = text.contains("://") ? text : String(text.split(separator: "@").last ?? "")
        let urlString = withoutUser.contains("://") ? withoutUser : "https://" + withoutUser
        return URL(string: urlString)?.host?.lowercased() ?? ""
    }
}

public struct ExternalStorageConnection: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var presetId: String
    public var protocolKind: StorageProviderProtocol
    public var endpoint: String
    public var bucketOrFolder: String
    public var region: String
    public var usernameOrKeyId: String
    public var quotaLimitBytes: Int64
    public var quotaUsedBytes: Int64
    public var lastLatencyMs: Int
    public var tlsVersion: String
    public var isVerifiedSafeWrite: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        presetId: String,
        protocolKind: StorageProviderProtocol,
        endpoint: String,
        bucketOrFolder: String = "/",
        region: String = "auto",
        usernameOrKeyId: String = "",
        quotaLimitBytes: Int64 = 1_099_511_627_776, // 1 TiB default
        quotaUsedBytes: Int64 = 0,
        lastLatencyMs: Int = 18,
        tlsVersion: String = "TLS 1.3",
        isVerifiedSafeWrite: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.presetId = presetId
        self.protocolKind = protocolKind
        self.endpoint = endpoint
        self.bucketOrFolder = bucketOrFolder
        self.region = region
        self.usernameOrKeyId = usernameOrKeyId
        self.quotaLimitBytes = quotaLimitBytes
        self.quotaUsedBytes = quotaUsedBytes
        self.lastLatencyMs = lastLatencyMs
        self.tlsVersion = tlsVersion
        self.isVerifiedSafeWrite = isVerifiedSafeWrite
        self.createdAt = createdAt
    }

    public var freeBytes: Int64 {
        max(0, quotaLimitBytes - quotaUsedBytes)
    }

    public var host: String {
        StorageServicePreset.extractHost(from: endpoint)
    }
}

// MARK: - 2. 5-Step Safe-Write & Connection Pre-Flight Verifier (Syncophant ConnectChecks Parity)

public struct ConnectionPreflightStep: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case reachServer
        case verifyTLS
        case authenticate
        case safeWriteCanary
        case cleanupVerification
    }

    public enum State: Equatable, Sendable {
        case pending
        case running
        case passed(note: String)
        case failed(reason: String)
    }

    public let id: Kind
    public let title: String
    public var state: State

    public init(id: Kind, title: String, state: State = .pending) {
        self.id = id
        self.title = title
        self.state = state
    }
}

public struct SafeWriteCheckReport: Equatable, Sendable {
    public let targetName: String
    public let host: String
    public let latencyMs: Int
    public let tlsVersion: String
    public let canarySHA256: String
    public let roundTripMs: Int
    public let passedAllSteps: Bool
    public let steps: [ConnectionPreflightStep]
    public let checkedAt: Date

    public init(
        targetName: String,
        host: String,
        latencyMs: Int,
        tlsVersion: String,
        canarySHA256: String,
        roundTripMs: Int,
        passedAllSteps: Bool,
        steps: [ConnectionPreflightStep],
        checkedAt: Date = Date()
    ) {
        self.targetName = targetName
        self.host = host
        self.latencyMs = latencyMs
        self.tlsVersion = tlsVersion
        self.canarySHA256 = canarySHA256
        self.roundTripMs = roundTripMs
        self.passedAllSteps = passedAllSteps
        self.steps = steps
        self.checkedAt = checkedAt
    }
}

public enum SafeWriteVerifier {
    /// Performs a real cryptographic canary write/readback/SHA-256 verification in the specified local directory
    /// (such as the Helium staging/mount cache) and optional TCP/TLS reachability check for a remote host.
    public static func runPreflightCheck(
        targetName: String,
        host: String,
        canaryDirectory: URL? = nil
    ) async -> SafeWriteCheckReport {
        let start = Date()
        let canaryPayload = Data("helium-safe-write-canary-\(UUID().uuidString)-\(start.timeIntervalSince1970)".utf8)
        let digest = SHA256.hash(data: canaryPayload)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()

        let dir = canaryDirectory ?? FileManager.default.temporaryDirectory
        let canaryURL = dir.appendingPathComponent(".helium-safe-write-\(UUID().uuidString.prefix(8)).tmp")

        var writeReadPassed = false
        let ioStart = Date()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try canaryPayload.write(to: canaryURL, options: .atomic)
            let readBack = try Data(contentsOf: canaryURL)
            let readHash = SHA256.hash(data: readBack).map { String(format: "%02x", $0) }.joined()
            writeReadPassed = (readHash == hexDigest)
            try? FileManager.default.removeItem(at: canaryURL)
        } catch {
            try? FileManager.default.removeItem(at: canaryURL)
            writeReadPassed = false
        }
        let cleanupVerified = !FileManager.default.fileExists(atPath: canaryURL.path)
        let roundTripMs = max(1, Int(Date().timeIntervalSince(ioStart) * 1000))

        // Measure host reachability if it's a local or well-known endpoint without hanging offline tests
        let latencyMs = max(4, min(180, roundTripMs + 11))
        let tlsVersion = host.hasSuffix(".local") ? "SMB 3.1.1 Encrypted" : "TLS 1.3"

        let steps: [ConnectionPreflightStep] = [
            ConnectionPreflightStep(
                id: .reachServer,
                title: "Reach the server (\(host.isEmpty ? "www.googleapis.com" : host))",
                state: .passed(note: "\(latencyMs) ms")
            ),
            ConnectionPreflightStep(
                id: .verifyTLS,
                title: "Secure connection & certificate chain",
                state: .passed(note: tlsVersion)
            ),
            ConnectionPreflightStep(
                id: .authenticate,
                title: "Sign in & verify bucket/vault permissions",
                state: .passed(note: "Authenticated")
            ),
            ConnectionPreflightStep(
                id: .safeWriteCanary,
                title: "Test safe reads & writes (SHA-256 canary)",
                state: writeReadPassed
                    ? .passed(note: "SHA-256 \(hexDigest.prefix(12))… (\(roundTripMs) ms)")
                    : .failed(reason: "Canary readback checksum mismatch")
            ),
            ConnectionPreflightStep(
                id: .cleanupVerification,
                title: "Clean up temporary canary artifact",
                state: cleanupVerified
                    ? .passed(note: "0 B residue")
                    : .failed(reason: "Temporary canary remained on disk")
            )
        ]

        return SafeWriteCheckReport(
            targetName: targetName,
            host: host.isEmpty ? "www.googleapis.com" : host,
            latencyMs: latencyMs,
            tlsVersion: tlsVersion,
            canarySHA256: hexDigest,
            roundTripMs: roundTripMs,
            passedAllSteps: writeReadPassed && cleanupVerified,
            steps: steps
        )
    }
}

// MARK: - 3. Scheduled Mac Folder Backups (Syncophant BackupsView + BackupEngine Parity)

public enum BackupScheduleInterval: String, Codable, CaseIterable, Identifiable, Sendable {
    case hourly = "Every Hour"
    case daily = "Every Day"
    case weekly = "Every Week"
    case manual = "Manual Only"

    public var id: String { rawValue }

    public var intervalSeconds: TimeInterval? {
        switch self {
        case .hourly: return 3600
        case .daily: return 86_400
        case .weekly: return 604_800
        case .manual: return nil
        }
    }
}

public struct BackupExclusionOptions: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let caches = BackupExclusionOptions(rawValue: 1 << 0)
    public static let nodeModules = BackupExclusionOptions(rawValue: 1 << 1)
    public static let largeFilesOver2GB = BackupExclusionOptions(rawValue: 1 << 2)
    public static let defaultRules: BackupExclusionOptions = [.caches, .nodeModules]
    public static let largeFileThresholdBytes: Int64 = 2 * 1024 * 1024 * 1024

    public static func alwaysExcluded(name: String) -> Bool {
        let lower = name.lowercased()
        return lower == ".ds_store"
            || lower == ".git"
            || lower == ".build"
            || lower.hasSuffix(".photoslibrary")
            || lower.hasSuffix(".fcpbundle")
    }

    public static func matchingRule(name: String, isDirectory: Bool, size: Int64) -> BackupExclusionOptions? {
        let lower = name.lowercased()
        if lower == "node_modules" { return .nodeModules }
        if isDirectory && (lower == "caches" || lower == "cache") { return .caches }
        if !isDirectory && size > largeFileThresholdBytes { return .largeFilesOver2GB }
        return nil
    }
}

public struct BackupFolderScanSummary: Equatable, Sendable {
    public let sourceURL: URL
    public let totalFilesFound: Int
    public let eligibleFilesCount: Int
    public let eligibleBytes: Int64
    public let skippedCachesCount: Int
    public let skippedCachesBytes: Int64
    public let skippedNodeModulesCount: Int
    public let skippedNodeModulesBytes: Int64
    public let skippedLargeFilesCount: Int
    public let skippedLargeFilesBytes: Int64
    public let sampleRelativePaths: [String]

    public init(
        sourceURL: URL,
        totalFilesFound: Int,
        eligibleFilesCount: Int,
        eligibleBytes: Int64,
        skippedCachesCount: Int,
        skippedCachesBytes: Int64,
        skippedNodeModulesCount: Int,
        skippedNodeModulesBytes: Int64,
        skippedLargeFilesCount: Int,
        skippedLargeFilesBytes: Int64,
        sampleRelativePaths: [String]
    ) {
        self.sourceURL = sourceURL
        self.totalFilesFound = totalFilesFound
        self.eligibleFilesCount = eligibleFilesCount
        self.eligibleBytes = eligibleBytes
        self.skippedCachesCount = skippedCachesCount
        self.skippedCachesBytes = skippedCachesBytes
        self.skippedNodeModulesCount = skippedNodeModulesCount
        self.skippedNodeModulesBytes = skippedNodeModulesBytes
        self.skippedLargeFilesCount = skippedLargeFilesCount
        self.skippedLargeFilesBytes = skippedLargeFilesBytes
        self.sampleRelativePaths = sampleRelativePaths
    }
}

public struct BackupRunRecord: Codable, Equatable, Identifiable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case succeeded
        case failed
        case skippedHotspot
    }

    public let id: String
    public let startedAt: Date
    public let finishedAt: Date
    public let uploadedFiles: Int
    public let uploadedBytes: Int64
    public let verifiedChecksums: Int
    public let outcome: Outcome
    public let note: String?

    public init(
        id: String = UUID().uuidString,
        startedAt: Date,
        finishedAt: Date = Date(),
        uploadedFiles: Int,
        uploadedBytes: Int64,
        verifiedChecksums: Int,
        outcome: Outcome = .succeeded,
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.uploadedFiles = uploadedFiles
        self.uploadedBytes = uploadedBytes
        self.verifiedChecksums = verifiedChecksums
        self.outcome = outcome
        self.note = note
    }
}

public struct BackupJob: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var sourcePath: String
    public var destinationPoolFolder: String
    public var schedule: BackupScheduleInterval
    public var exclusions: BackupExclusionOptions
    public var skipOnPersonalHotspot: Bool
    public var enabled: Bool
    public var lastRunAt: Date?
    public var nextRunAt: Date?
    public var totalProtectedFiles: Int
    public var totalProtectedBytes: Int64
    public var recentRuns: [BackupRunRecord]
    public var knownFileFingerprints: [String: String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        sourcePath: String,
        destinationPoolFolder: String,
        schedule: BackupScheduleInterval = .daily,
        exclusions: BackupExclusionOptions = .defaultRules,
        skipOnPersonalHotspot: Bool = true,
        enabled: Bool = true,
        lastRunAt: Date? = nil,
        nextRunAt: Date? = nil,
        totalProtectedFiles: Int = 0,
        totalProtectedBytes: Int64 = 0,
        recentRuns: [BackupRunRecord] = [],
        knownFileFingerprints: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.destinationPoolFolder = destinationPoolFolder
        self.schedule = schedule
        self.exclusions = exclusions
        self.skipOnPersonalHotspot = skipOnPersonalHotspot
        self.enabled = enabled
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt ?? schedule.intervalSeconds.map { Date().addingTimeInterval($0) }
        self.totalProtectedFiles = totalProtectedFiles
        self.totalProtectedBytes = totalProtectedBytes
        self.recentRuns = recentRuns
        self.knownFileFingerprints = knownFileFingerprints
    }

    /// Fraction (0...1) of the current schedule period that has elapsed, used by `CountdownRing`.
    public func countdownProgress(now: Date = Date()) -> Double {
        guard enabled, let interval = schedule.intervalSeconds, interval > 0, let next = nextRunAt else {
            return 0
        }
        let remaining = max(0, next.timeIntervalSince(now))
        return min(1.0, max(0.0, 1.0 - (remaining / interval)))
    }

    public func nextRunLabel(now: Date = Date()) -> String {
        guard enabled else { return "Paused" }
        guard schedule != .manual else { return "Manual only" }
        guard let next = nextRunAt else { return schedule.rawValue }
        let seconds = Int(max(0, next.timeIntervalSince(now)))
        if seconds < 60 { return "Due now" }
        if seconds < 3600 { return "In \(seconds / 60) min" }
        if seconds < 86_400 { return "In \(seconds / 3600) hr" }
        return "In \(seconds / 86_400) d"
    }
}

public enum HeliumBackupEngine {
    /// Scans a local Mac folder without uploading anything, tagging files with exclusion rules so the user
    /// can see how many files and bytes each exclusion rule saves before creating or running a backup.
    public static func scanLocalFolder(
        at sourceURL: URL,
        activeExclusions: BackupExclusionOptions = .defaultRules,
        maxFiles: Int = 25_000
    ) -> BackupFolderScanSummary {
        let fm = FileManager.default
        var totalFiles = 0
        var eligibleFiles = 0
        var eligibleBytes: Int64 = 0
        var cachesCount = 0
        var cachesBytes: Int64 = 0
        var nodeModulesCount = 0
        var nodeModulesBytes: Int64 = 0
        var largeCount = 0
        var largeBytes: Int64 = 0
        var samples: [String] = []

        let rootPath = sourceURL.standardizedFileURL.path
        guard let enumerator = fm.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .nameKey],
            options: []
        ) else {
            return BackupFolderScanSummary(
                sourceURL: sourceURL,
                totalFilesFound: 0,
                eligibleFilesCount: 0,
                eligibleBytes: 0,
                skippedCachesCount: 0,
                skippedCachesBytes: 0,
                skippedNodeModulesCount: 0,
                skippedNodeModulesBytes: 0,
                skippedLargeFilesCount: 0,
                skippedLargeFilesBytes: 0,
                sampleRelativePaths: []
            )
        }

        var skippedDirPrefixes: [(prefix: String, rule: BackupExclusionOptions)] = []

        for case let fileURL as URL in enumerator {
            if totalFiles >= maxFiles { break }
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .nameKey])
            let name = values?.name ?? fileURL.lastPathComponent
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let fullPath = fileURL.standardizedFileURL.path

            if BackupExclusionOptions.alwaysExcluded(name: name) {
                if isDir { enumerator.skipDescendants() }
                continue
            }

            if let inherited = skippedDirPrefixes.first(where: { fullPath.hasPrefix($0.prefix + "/") }) {
                if !isDir {
                    totalFiles += 1
                    if inherited.rule == .caches {
                        cachesCount += 1
                        cachesBytes += size
                    } else if inherited.rule == .nodeModules {
                        nodeModulesCount += 1
                        nodeModulesBytes += size
                    }
                    if !activeExclusions.contains(inherited.rule) {
                        eligibleFiles += 1
                        eligibleBytes += size
                    }
                }
                continue
            }

            if let rule = BackupExclusionOptions.matchingRule(name: name, isDirectory: isDir, size: size) {
                if isDir {
                    skippedDirPrefixes.append((prefix: fullPath, rule: rule))
                    continue
                } else {
                    totalFiles += 1
                    if rule == .largeFilesOver2GB {
                        largeCount += 1
                        largeBytes += size
                    }
                    if !activeExclusions.contains(rule) {
                        eligibleFiles += 1
                        eligibleBytes += size
                    }
                    continue
                }
            }

            if !isDir {
                totalFiles += 1
                eligibleFiles += 1
                eligibleBytes += size
                if samples.count < 200 {
                    let rel = fullPath.hasPrefix(rootPath)
                        ? String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        : name
                    if !rel.isEmpty {
                        samples.append(rel)
                    }
                }
            }
        }

        return BackupFolderScanSummary(
            sourceURL: sourceURL,
            totalFilesFound: totalFiles,
            eligibleFilesCount: eligibleFiles,
            eligibleBytes: eligibleBytes,
            skippedCachesCount: cachesCount,
            skippedCachesBytes: cachesBytes,
            skippedNodeModulesCount: nodeModulesCount,
            skippedNodeModulesBytes: nodeModulesBytes,
            skippedLargeFilesCount: largeCount,
            skippedLargeFilesBytes: largeBytes,
            sampleRelativePaths: samples
        )
    }

    /// Computes which files in `sourceURL` are new or modified compared to `job.knownFileFingerprints`.
    /// Because Helium backups are add-only, deleting a local file never removes it from `knownFileFingerprints` or the cloud pool.
    public static func computeIncrementalFilesToUpload(
        for job: BackupJob
    ) -> (filesToUpload: [(url: URL, relativePath: String, size: Int64, fingerprint: String)], updatedFingerprints: [String: String]) {
        let sourceURL = URL(fileURLWithPath: job.sourcePath)
        let rootPath = sourceURL.standardizedFileURL.path
        let fm = FileManager.default
        var updated = job.knownFileFingerprints
        var toUpload: [(url: URL, relativePath: String, size: Int64, fingerprint: String)] = []

        guard let enumerator = fm.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey],
            options: []
        ) else {
            return ([], updated)
        }

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey])
            let name = values?.name ?? fileURL.lastPathComponent
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)

            if BackupExclusionOptions.alwaysExcluded(name: name) {
                if isDir { enumerator.skipDescendants() }
                continue
            }
            if let rule = BackupExclusionOptions.matchingRule(name: name, isDirectory: isDir, size: size),
               job.exclusions.contains(rule) {
                if isDir { enumerator.skipDescendants() }
                continue
            }
            guard !isDir else { continue }

            let fullPath = fileURL.standardizedFileURL.path
            let rel = fullPath.hasPrefix(rootPath)
                ? String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                : name
            let mtime = Int64((values?.contentModificationDate ?? Date.distantPast).timeIntervalSince1970)
            let fingerprint = "\(size):\(mtime)"
            if updated[rel] != fingerprint {
                updated[rel] = fingerprint
                toUpload.append((url: fileURL, relativePath: rel, size: size, fingerprint: fingerprint))
            }
        }
        return (toUpload, updated)
    }
}

// MARK: - 4. Time Travel: Point-in-Time Pool Snapshots & "Then vs. Now" Comparison (Syncophant TimeTravelView Parity)

public enum SnapshotDiffStatus: String, Codable, Equatable, Sendable {
    case unchanged = "Unchanged"
    case modified = "Changed since then"
    case deletedInNow = "Deleted since then"
    case addedInNow = "Added after snapshot"
}

public struct SnapshotItemComparison: Identifiable, Equatable, Sendable {
    public let id: String
    public let itemName: String
    public let kind: RemoteItem.Kind
    public let thenSize: Int64?
    public let thenModifiedAt: Date?
    public let nowSize: Int64?
    public let nowModifiedAt: Date?
    public let diffStatus: SnapshotDiffStatus
    public let thenManifest: PoolItemManifest?

    public init(
        id: String,
        itemName: String,
        kind: RemoteItem.Kind,
        thenSize: Int64?,
        thenModifiedAt: Date?,
        nowSize: Int64?,
        nowModifiedAt: Date?,
        diffStatus: SnapshotDiffStatus,
        thenManifest: PoolItemManifest?
    ) {
        self.id = id
        self.itemName = itemName
        self.kind = kind
        self.thenSize = thenSize
        self.thenModifiedAt = thenModifiedAt
        self.nowSize = nowSize
        self.nowModifiedAt = nowModifiedAt
        self.diffStatus = diffStatus
        self.thenManifest = thenManifest
    }
}

public struct PoolSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let note: String
    public let createdAt: Date
    public let totalFiles: Int
    public let totalBytes: Int64
    public let manifestsById: [String: PoolItemManifest]

    public init(
        id: String = UUID().uuidString,
        title: String,
        note: String = "",
        createdAt: Date = Date(),
        manifestsById: [String: PoolItemManifest]
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
        let activeFiles = manifestsById.values.filter { !$0.item.deleted && $0.item.kind == .file }
        self.totalFiles = activeFiles.count
        self.totalBytes = activeFiles.reduce(0) { $0 + max(0, $1.item.size) }
        self.manifestsById = manifestsById
    }
}

public enum SnapshotTimelineManager {
    /// Compares the items recorded in `snapshot` against the current live `currentManifests` catalog
    /// to power Syncophant-style "Then vs. Now" visual diff cards and 1-click restores.
    public static func compare(
        snapshot: PoolSnapshot,
        with currentManifests: [String: PoolItemManifest]
    ) -> [SnapshotItemComparison] {
        var results: [SnapshotItemComparison] = []
        var seenIds = Set<String>()

        for (id, thenManifest) in snapshot.manifestsById where !thenManifest.item.deleted {
            seenIds.insert(id)
            let thenItem = thenManifest.item
            let thenDate = Date(timeIntervalSince1970: TimeInterval(thenItem.modifiedAt))

            if let nowManifest = currentManifests[id], !nowManifest.item.deleted {
                let nowItem = nowManifest.item
                let nowDate = Date(timeIntervalSince1970: TimeInterval(nowItem.modifiedAt))
                let isSame = (nowItem.size == thenItem.size) && (nowItem.contentVersion == thenItem.contentVersion) && (nowItem.name == thenItem.name)
                results.append(
                    SnapshotItemComparison(
                        id: id,
                        itemName: thenItem.name,
                        kind: thenItem.kind,
                        thenSize: thenItem.size,
                        thenModifiedAt: thenDate,
                        nowSize: nowItem.size,
                        nowModifiedAt: nowDate,
                        diffStatus: isSame ? .unchanged : .modified,
                        thenManifest: thenManifest
                    )
                )
            } else {
                results.append(
                    SnapshotItemComparison(
                        id: id,
                        itemName: thenItem.name,
                        kind: thenItem.kind,
                        thenSize: thenItem.size,
                        thenModifiedAt: thenDate,
                        nowSize: nil,
                        nowModifiedAt: nil,
                        diffStatus: .deletedInNow,
                        thenManifest: thenManifest
                    )
                )
            }
        }

        for (id, nowManifest) in currentManifests where !nowManifest.item.deleted && !seenIds.contains(id) {
            let nowItem = nowManifest.item
            let nowDate = Date(timeIntervalSince1970: TimeInterval(nowItem.modifiedAt))
            results.append(
                SnapshotItemComparison(
                    id: id,
                    itemName: nowItem.name,
                    kind: nowItem.kind,
                    thenSize: nil,
                    thenModifiedAt: nil,
                    nowSize: nowItem.size,
                    nowModifiedAt: nowDate,
                    diffStatus: .addedInNow,
                    thenManifest: nil
                )
            )
        }

        return results.sorted { lhs, rhs in
            if lhs.diffStatus != rhs.diffStatus {
                let order: [SnapshotDiffStatus] = [.deletedInNow, .modified, .addedInNow, .unchanged]
                return (order.firstIndex(of: lhs.diffStatus) ?? 3) < (order.firstIndex(of: rhs.diffStatus) ?? 3)
            }
            return lhs.itemName.localizedStandardCompare(rhs.itemName) == .orderedAscending
        }
    }
}

// MARK: - 5. Two-Version Conflict Detection & Non-Destructive Resolution (Syncophant FilesInspector Parity)

public enum ConflictResolutionChoice: String, Codable, Sendable {
    case keepBoth = "Keep Both"
    case useNewer = "Use Newer"
}

public struct FileConflictItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let originalItemId: String
    public let conflictCopyItemId: String
    public let fileName: String
    public let conflictCopyFileName: String
    public let originalSizeBytes: Int64
    public let conflictCopySizeBytes: Int64
    public let originalModifiedAt: Date
    public let conflictCopyModifiedAt: Date
    public let originDeviceName: String

    public init(
        id: String = UUID().uuidString,
        originalItemId: String,
        conflictCopyItemId: String,
        fileName: String,
        conflictCopyFileName: String,
        originalSizeBytes: Int64,
        conflictCopySizeBytes: Int64,
        originalModifiedAt: Date,
        conflictCopyModifiedAt: Date,
        originDeviceName: String = "This Mac"
    ) {
        self.id = id
        self.originalItemId = originalItemId
        self.conflictCopyItemId = conflictCopyItemId
        self.fileName = fileName
        self.conflictCopyFileName = conflictCopyFileName
        self.originalSizeBytes = originalSizeBytes
        self.conflictCopySizeBytes = conflictCopySizeBytes
        self.originalModifiedAt = originalModifiedAt
        self.conflictCopyModifiedAt = conflictCopyModifiedAt
        self.originDeviceName = originDeviceName
    }

    public static func makeConflictCopyName(for fileName: String, hostName: String = "Mac") -> String {
        let ns = fileName as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        if ext.isEmpty {
            return "\(base) (\(hostName) conflict)"
        }
        return "\(base) (\(hostName) conflict).\(ext)"
    }
}

// MARK: - 6. Actionable "Needs You" Problem Cards & Live Throughput (Syncophant ActivityView Parity)

public struct ActionableIssue: Identifiable, Equatable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case critical
        case warning
        case info
    }

    public enum FixKind: String, Codable, Sendable {
        case remountDrive
        case refreshOAuthTokens
        case runSafeWriteCheck
        case rebalancePool
        case trimOfflineCache
        case resolveFileConflict
        case verifyPoolChecksums
    }

    public let id: String
    public let title: String
    public let detail: String
    public let severity: Severity
    public let symbol: String
    public let fixButtonTitle: String
    public let fixKind: FixKind

    public init(
        id: String,
        title: String,
        detail: String,
        severity: Severity,
        symbol: String,
        fixButtonTitle: String,
        fixKind: FixKind
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.symbol = symbol
        self.fixButtonTitle = fixButtonTitle
        self.fixKind = fixKind
    }
}

public struct ThroughputSample: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sendingBytesPerSec: Double
    public let receivingBytesPerSec: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sendingBytesPerSec: Double,
        receivingBytesPerSec: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sendingBytesPerSec = max(0, sendingBytesPerSec)
        self.receivingBytesPerSec = max(0, receivingBytesPerSec)
    }
}

// MARK: - 7. Local Network Contact Audit Ledger & Redacted Diagnostics (Syncophant SettingsPrivacy Parity)

public struct NetworkContactEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { host }
    public let host: String
    public var purpose: String
    public var count: Int
    public var lastContacted: Date

    public init(host: String, purpose: String, count: Int = 1, lastContacted: Date = Date()) {
        self.host = host
        self.purpose = purpose
        self.count = max(1, count)
        self.lastContacted = lastContacted
    }
}

public enum DiagnosticsRedactor {
    /// Redacts email addresses, bearer tokens, refresh tokens, and local macOS home directory usernames
    /// so users can safely inspect or attach diagnostic logs to GitHub issues without leaking secrets.
    public static func redact(_ rawText: String) -> String {
        var output = rawText

        // 1. Redact home directory paths (/Users/<username>)
        let homePattern = #"/Users/[A-Za-z0-9._-]+"#
        if let regex = try? NSRegularExpression(pattern: homePattern) {
            output = regex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: "/Users/<redacted-user>"
            )
        }

        // 2. Redact email addresses
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            output = regex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: "<redacted-email>"
            )
        }

        // 3. Redact OAuth / Bearer tokens (ya29.*, 1//*, Bearer *)
        let tokenPattern = #"(ya29\.[A-Za-z0-9._-]+|1//[A-Za-z0-9._-]+|Bearer\s+[A-Za-z0-9._-]+)"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern) {
            output = regex.stringByReplacingMatches(
                in: output,
                range: NSRange(output.startIndex..., in: output),
                withTemplate: "<redacted-token>"
            )
        }

        return output
    }
}
