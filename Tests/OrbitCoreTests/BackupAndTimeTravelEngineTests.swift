import Foundation
import Testing
@testable import OrbitCore

@Suite("Syncophant Parity: Multi-Protocol Presets, Safe-Write, Backups, Time Travel & Privacy Ledger")
struct BackupAndTimeTravelEngineTests {
    @Test("Service presets auto-detect provider and infer S3 signing region from endpoint URLs")
    func servicePresetDetectionAndRegionInference() {
        let r2 = StorageServicePreset.match(address: "https://abc12345.r2.cloudflarestorage.com")
        #expect(r2?.id == "cloudflare-r2")
        #expect(StorageServicePreset.inferS3Region(for: "https://abc12345.r2.cloudflarestorage.com") == "auto")

        let aws = StorageServicePreset.match(address: "https://s3.eu-west-1.amazonaws.com")
        #expect(aws?.id == "aws-s3")
        #expect(StorageServicePreset.inferS3Region(for: "https://s3.eu-west-1.amazonaws.com") == "eu-west-1")

        let b2 = StorageServicePreset.match(address: "https://s3.us-west-004.backblazeb2.com")
        #expect(b2?.id == "backblaze-b2")
        #expect(StorageServicePreset.inferS3Region(for: "https://s3.us-west-004.backblazeb2.com") == "us-west-004")

        let nextcloud = StorageServicePreset.match(address: "https://cloud.example.org/remote.php/dav/files/alice")
        #expect(nextcloud?.id == "nextcloud")
        #expect(nextcloud?.protocolKind == .webdav)

        let hetznerBox = StorageServicePreset.match(address: "u999999.your-storagebox.de")
        #expect(hetznerBox?.id == "hetzner-storage-box")
        #expect(hetznerBox?.protocolKind == .sftp)
    }

    @Test("5-Step Safe-Write verifier writes canary, verifies SHA-256 readback, and cleans up with zero residue")
    func safeWritePreflightCheck() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("helium-safewrite-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let report = await SafeWriteVerifier.runPreflightCheck(
            targetName: "Test Pool Node",
            host: "www.googleapis.com",
            canaryDirectory: tempDir
        )
        #expect(report.passedAllSteps == true)
        #expect(report.steps.count == 5)
        #expect(report.canarySHA256.count == 64)

        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        #expect(leftovers.isEmpty)
    }

    @Test("Scheduled Mac folder backup scanner respects exclusions and enforces add-only safety")
    func backupScannerAndAddOnlyIncrementalEngine() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("helium-backup-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let docsDir = root.appendingPathComponent("Projects", isDirectory: true)
        let nodeModulesDir = root.appendingPathComponent("node_modules/pkg", isDirectory: true)
        let cachesDir = root.appendingPathComponent("Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeModulesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)

        let keepFile1 = docsDir.appendingPathComponent("spec.md")
        let keepFile2 = docsDir.appendingPathComponent("video.mov")
        let ignoredNM = nodeModulesDir.appendingPathComponent("index.js")
        let ignoredCache = cachesDir.appendingPathComponent("thumb.cache")
        try Data("hello spec".utf8).write(to: keepFile1)
        try Data(repeating: 0xAB, count: 4096).write(to: keepFile2)
        try Data("module.exports = {}".utf8).write(to: ignoredNM)
        try Data("cached".utf8).write(to: ignoredCache)

        let scan = HeliumBackupEngine.scanLocalFolder(at: root, activeExclusions: [.caches, .nodeModules])
        #expect(scan.eligibleFilesCount == 2)
        #expect(scan.skippedNodeModulesCount == 1)
        #expect(scan.skippedCachesCount == 1)

        var job = BackupJob(
            name: "Workspace",
            sourcePath: root.path,
            destinationPoolFolder: "/Backups/Workspace",
            schedule: .daily,
            exclusions: [.caches, .nodeModules]
        )

        let firstPass = HeliumBackupEngine.computeIncrementalFilesToUpload(for: job)
        #expect(firstPass.filesToUpload.count == 2)
        job.knownFileFingerprints = firstPass.updatedFingerprints

        // Second pass with no changes uploads 0 files
        let secondPass = HeliumBackupEngine.computeIncrementalFilesToUpload(for: job)
        #expect(secondPass.filesToUpload.isEmpty)

        // Deleting a local file on the Mac NEVER deletes its backup record (add-only safety)
        try FileManager.default.removeItem(at: keepFile1)
        let thirdPass = HeliumBackupEngine.computeIncrementalFilesToUpload(for: job)
        #expect(thirdPass.filesToUpload.isEmpty)
        #expect(thirdPass.updatedFingerprints["Projects/spec.md"] != nil)
    }

    @Test("Time Travel snapshot comparison computes Then vs. Now statuses accurately")
    func snapshotThenVsNowComparison() {
        let itemUnchanged = RemoteItem(
            id: "f1",
            parentId: "root",
            name: "contract.pdf",
            kind: .file,
            size: 1024,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: 1_700_000_000,
            modifiedAt: 1_700_000_000
        )
        let itemModifiedThen = RemoteItem(
            id: "f2",
            parentId: "root",
            name: "edit.fcpxml",
            kind: .file,
            size: 2048,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: 1_700_000_000,
            modifiedAt: 1_700_000_000
        )
        let itemDeletedInNow = RemoteItem(
            id: "f3",
            parentId: "root",
            name: "old-take.mov",
            kind: .file,
            size: 8192,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: 1_700_000_000,
            modifiedAt: 1_700_000_000
        )

        let thenCatalog: [String: PoolItemManifest] = [
            "f1": PoolItemManifest(item: itemUnchanged, placementMode: .wholeFileSmartPlacement, segments: []),
            "f2": PoolItemManifest(item: itemModifiedThen, placementMode: .wholeFileSmartPlacement, segments: []),
            "f3": PoolItemManifest(item: itemDeletedInNow, placementMode: .wholeFileSmartPlacement, segments: [])
        ]
        let snapshot = PoolSnapshot(title: "Morning Cut", note: "Before color grade", manifestsById: thenCatalog)

        let itemModifiedNow = RemoteItem(
            id: "f2",
            parentId: "root",
            name: "edit.fcpxml",
            kind: .file,
            size: 4096,
            contentVersion: 2,
            metadataVersion: 2,
            createdAt: 1_700_000_000,
            modifiedAt: 1_700_003_600
        )
        let itemAddedNow = RemoteItem(
            id: "f4",
            parentId: "root",
            name: "final-render.mp4",
            kind: .file,
            size: 65_536,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: 1_700_007_200,
            modifiedAt: 1_700_007_200
        )

        let nowCatalog: [String: PoolItemManifest] = [
            "f1": PoolItemManifest(item: itemUnchanged, placementMode: .wholeFileSmartPlacement, segments: []),
            "f2": PoolItemManifest(item: itemModifiedNow, placementMode: .wholeFileSmartPlacement, segments: []),
            "f4": PoolItemManifest(item: itemAddedNow, placementMode: .wholeFileSmartPlacement, segments: [])
        ]

        let diffs = SnapshotTimelineManager.compare(snapshot: snapshot, with: nowCatalog)
        #expect(diffs.count == 4)
        #expect(diffs.first(where: { $0.id == "f1" })?.diffStatus == .unchanged)
        #expect(diffs.first(where: { $0.id == "f2" })?.diffStatus == .modified)
        #expect(diffs.first(where: { $0.id == "f3" })?.diffStatus == .deletedInNow)
        #expect(diffs.first(where: { $0.id == "f4" })?.diffStatus == .addedInNow)
    }

    @Test("DiagnosticsRedactor strips emails, OAuth tokens, and local macOS usernames")
    func diagnosticsRedactorStripsSensitiveData() {
        let raw = "User /Users/alice connected alice.smith@example.com with token ya29.a0AfH6SMB_secret123 and refresh 1//0gSecretRefreshToken999"
        let redacted = DiagnosticsRedactor.redact(raw)
        #expect(!redacted.contains("/Users/alice"))
        #expect(!redacted.contains("alice.smith@example.com"))
        #expect(!redacted.contains("ya29.a0AfH6SMB_secret123"))
        #expect(!redacted.contains("1//0gSecretRefreshToken999"))
        #expect(redacted.contains("/Users/<redacted-user>"))
        #expect(redacted.contains("<redacted-email>"))
        #expect(redacted.contains("<redacted-token>"))
    }
}
