import Foundation

/// Bufferbloat-aware upload congestion governor ("Polite Uploads") that monitors RTT inflation and adjusts pacing rate.
public final class UploadGovernor: @unchecked Sendable {
    public static let minRate: Double = 256 * 1024 // 256 KiB/s floor
    public static let maxRate: Double = 250 * 1_048_576 // 250 MiB/s ceiling

    private let lock = NSLock()
    private var baselineRTT: TimeInterval?
    private var currentRate: Double?

    public init() {}

    public func record(rtt: TimeInterval, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard rtt > 0 else { return }
        lock.lock()
        if let base = baselineRTT {
            baselineRTT = min(base, rtt)
        } else {
            baselineRTT = rtt
        }
        lock.unlock()
    }

    public func adjust(
        rtt: TimeInterval,
        throughput: Double,
        at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Double? {
        guard rtt > 0, throughput > 0 else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let base = min(baselineRTT ?? rtt, rtt)
        baselineRTT = base

        let standingDelay = max(0, rtt - base)
        let ratio = rtt / max(0.001, base)

        let seedRate = currentRate ?? throughput
        let nextRate: Double
        if standingDelay > 0.045 || ratio > 2.0 {
            // Congestion / bufferbloat detected: multiplicative decrease
            nextRate = max(Self.minRate, min(throughput, seedRate) * 0.72)
        } else if standingDelay < 0.015 && ratio < 1.35 {
            // Clean link: additive/multiplicative probe upward
            nextRate = min(Self.maxRate, max(throughput, seedRate) * 1.18)
        } else {
            nextRate = seedRate
        }
        currentRate = nextRate
        return nextRate
    }
}

/// Token-bucket upload pacer enforcing either a manual bandwidth cap or `UploadGovernor`'s polite rate.
public final class UploadPacer: @unchecked Sendable {
    private let lock = NSLock()
    private var rateBytesPerSec: Double?

    public init(rateBytesPerSec: Double? = nil) {
        self.rateBytesPerSec = rateBytesPerSec
    }

    public func setRate(_ bytesPerSec: Double?) {
        lock.lock()
        rateBytesPerSec = bytesPerSec
        lock.unlock()
    }

    public func currentRate() -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return rateBytesPerSec
    }
}

/// Orchestrates `DriveTree`, `Staging`, `ChunkStore`, `ContentReader`, and background cloud sync for the mounted Helium volume.
public final class OrbitDrive: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let directory: URL
        public let deviceName: String
        public let cacheLimits: ChunkStore.Limits

        public init(directory: URL, deviceName: String, cacheLimits: ChunkStore.Limits) {
            self.directory = directory
            self.deviceName = deviceName
            self.cacheLimits = cacheLimits
        }
    }

    public struct UploadFile: Equatable, Identifiable, Sendable {
        public var id: UInt64 { nodeID }
        public let nodeID: UInt64
        public let name: String
        public let sentBytes: Int64
        public let totalBytes: Int64
        public let failedMessage: String?

        public init(nodeID: UInt64, name: String, sentBytes: Int64, totalBytes: Int64, failedMessage: String? = nil) {
            self.nodeID = nodeID
            self.name = name
            self.sentBytes = sentBytes
            self.totalBytes = totalBytes
            self.failedMessage = failedMessage
        }
    }

    public struct Status: Equatable, Sendable {
        public var syncing: Bool
        public var downloading: Bool
        public var uploadingCount: Int
        public var uploadBytesRemaining: Int64
        public var uploadSpeedBytesPerSec: Int64?
        public var uploadsPaused: Bool
        public var lastSyncAt: Date?
        public var errorMessage: String?
        public var account: Account?

        public init(
            syncing: Bool = false,
            downloading: Bool = false,
            uploadingCount: Int = 0,
            uploadBytesRemaining: Int64 = 0,
            uploadSpeedBytesPerSec: Int64? = nil,
            uploadsPaused: Bool = false,
            lastSyncAt: Date? = nil,
            errorMessage: String? = nil,
            account: Account? = nil
        ) {
            self.syncing = syncing
            self.downloading = downloading
            self.uploadingCount = uploadingCount
            self.uploadBytesRemaining = uploadBytesRemaining
            self.uploadSpeedBytesPerSec = uploadSpeedBytesPerSec
            self.uploadsPaused = uploadsPaused
            self.lastSyncAt = lastSyncAt
            self.errorMessage = errorMessage
            self.account = account
        }
    }

    public let remote: any DriveRemote
    public let configuration: Configuration
    public let tree: DriveTree
    public let staging: Staging
    public let xattrs: XattrStore
    public let chunkStore: ChunkStore
    public let searchIndex: SearchIndex
    public let governor = UploadGovernor()
    public let pacer = UploadPacer()
    private var reader: ContentReader!
    private let lock = NSLock()
    private var currentStatus = Status()

    public init(remote: any DriveRemote, configuration: Configuration) {
        self.remote = remote
        self.configuration = configuration
        try? FileManager.default.createDirectory(at: configuration.directory, withIntermediateDirectories: true)
        self.tree = DriveTree(file: configuration.directory.appendingPathComponent("tree.json"))
        self.staging = Staging(root: configuration.directory.appendingPathComponent("staging"))
        self.xattrs = XattrStore(root: configuration.directory.appendingPathComponent("xattrs"))
        self.chunkStore = ChunkStore(
            root: configuration.directory.appendingPathComponent("chunks"),
            chunkSize: ChunkStore.defaultChunkSize,
            limits: configuration.cacheLimits
        )
        self.searchIndex = SearchIndex(tree: tree)
        self.reader = ContentReader(remote: remote, store: chunkStore) { [weak self] active in
            self?.setDownloading(active)
        }
    }

    private func setDownloading(_ active: Bool) {
        lock.lock()
        currentStatus.downloading = active
        lock.unlock()
    }

    public func status() -> Status {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }

    public func start() async throws {
        try await sync()
    }

    public func sync() async throws {
        lock.withLock {
            currentStatus.syncing = true
        }
        defer {
            lock.withLock {
                currentStatus.syncing = false
                currentStatus.lastSyncAt = Date()
            }
        }

        let acct = try await remote.account()
        lock.withLock {
            currentStatus.account = acct
        }

        var cursorSeq = tree.seq
        var hasMore = true
        while hasMore {
            let page = try await remote.listChanges(since: cursorSeq)
            let applied = tree.apply(page.items, seq: page.seq, complete: !page.hasMore)
            for changed in applied.changedContent {
                chunkStore.remove(remoteID: changed.remoteID, keeping: changed.version)
            }
            for removedID in applied.removedRemoteIDs {
                chunkStore.remove(remoteID: removedID)
            }
            cursorSeq = page.seq
            hasMore = page.hasMore
        }
        tree.save()
    }

    public func lookup(_ name: String, in parentID: UInt64) -> DriveNode? {
        tree.lookup(name, in: parentID)
    }

    public func children(of parentID: UInt64) -> [DriveNode] {
        tree.children(of: parentID)
    }

    public func node(_ id: UInt64) -> DriveNode? {
        tree.node(id)
    }

    public func read(_ nodeID: UInt64, offset: Int64, length: Int) async throws -> Data {
        if staging.exists(nodeID) {
            return try staging.read(nodeID, offset: offset, length: length)
        }
        guard let node = tree.node(nodeID), let remoteID = node.remoteID else {
            throw CocoaError(.fileNoSuchFile)
        }
        let ref = ContentReader.FileRef(remoteID: remoteID, version: node.contentVersion, size: node.size)
        return try await reader.read(ref, offset: offset, length: length)
    }

    public func createFile(name: String, in parentID: UInt64) throws -> DriveNode {
        let node = try tree.add(name: name, in: parentID, isFolder: false, size: 0)
        try staging.create(node.id)
        tree.save()
        return node
    }

    public func write(_ nodeID: UInt64, offset: Int64, data: Data) throws {
        try staging.write(nodeID, offset: offset, data: data)
        let newSize = staging.size(nodeID)
        _ = tree.update(nodeID) { node in
            node.size = newSize
            node.modifiedAt = Date()
            node.dirtyContent = true
        }
    }

    public func flushFile(_ nodeID: UInt64) async throws -> DriveNode {
        guard let node = tree.node(nodeID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard staging.exists(nodeID) else { return node }
        let stageURL = staging.fileURL(for: nodeID)
        let parentRemoteID = tree.node(node.parentID)?.remoteID ?? RemoteItem.rootID

        let remoteItem: RemoteItem
        if let existingRemoteID = node.remoteID {
            remoteItem = try await remote.uploadOverwrite(
                id: existingRemoteID,
                from: stageURL,
                expectedVersion: node.contentVersion,
                modifiedAt: node.modifiedAt,
                progress: nil
            )
        } else {
            remoteItem = try await remote.uploadNewFile(
                from: stageURL,
                name: node.name,
                parentId: parentRemoteID,
                clientId: node.clientID ?? UUID().uuidString,
                modifiedAt: node.modifiedAt,
                link: false,
                progress: nil
            )
        }

        staging.remove(nodeID)
        let updated = tree.update(nodeID) { n in
            n.remoteID = remoteItem.id
            n.size = remoteItem.size
            n.contentVersion = remoteItem.contentVersion
            n.metadataVersion = remoteItem.metadataVersion
            n.dirtyContent = false
            n.dirtyMetadata = false
        }
        tree.save()
        return updated ?? node
    }

    public func createFolder(name: String, in parentID: UInt64) async throws -> DriveNode {
        let parentRemoteID = tree.node(parentID)?.remoteID ?? RemoteItem.rootID
        let remoteFolder = try await remote.createFolder(name: name, parentId: parentRemoteID)
        if let existing = tree.node(remoteID: remoteFolder.id) {
            return existing
        }
        let node = try tree.add(name: name, in: parentID, isFolder: true, remote: remoteFolder)
        tree.save()
        return node
    }

    public func rename(_ nodeID: UInt64, newName: String) async throws -> DriveNode {
        guard let existing = tree.node(nodeID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        if let remoteID = existing.remoteID {
            let updatedRemote = try await remote.rename(id: remoteID, newName: newName)
            let updated = tree.update(nodeID) { n in
                n.name = updatedRemote.name
                n.metadataVersion = updatedRemote.metadataVersion
                n.modifiedAt = Date()
            }
            tree.save()
            return updated ?? existing
        } else {
            let updated = tree.update(nodeID) { n in
                n.name = newName
                n.modifiedAt = Date()
                n.dirtyMetadata = true
            }
            tree.save()
            return updated ?? existing
        }
    }

    public func remove(_ nodeID: UInt64) async throws {
        guard let removed = tree.remove(nodeID) else { return }
        staging.remove(nodeID)
        if let remoteID = removed.remoteID {
            chunkStore.remove(remoteID: remoteID)
            try await remote.delete(id: remoteID)
        }
        tree.save()
    }
}
