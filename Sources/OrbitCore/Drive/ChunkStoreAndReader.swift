import Foundation

public struct ChunkKey: Hashable, Codable, Sendable {
    public let remoteID: String
    public let version: Int64
    public let index: Int

    public init(remoteID: String, version: Int64, index: Int) {
        self.remoteID = remoteID
        self.version = version
        self.index = index
    }
}

/// Content-addressed 1 MiB chunk store with 6-tier disk pressure watermarks and `KeepList` pinning protection.
public final class ChunkStore: @unchecked Sendable {
    public static let defaultChunkSize: Int64 = 1_048_576

    public struct Limits: Codable, Equatable, Sendable {
        public let maxBytes: Int64
        public let minFreeBytes: Int64
        public let streamingBytes: Int64
        public let criticalFreeBytes: Int64
        public let lastResortBytes: Int64
        public let outOfSpaceFreeBytes: Int64

        public init(
            maxBytes: Int64,
            minFreeBytes: Int64,
            streamingBytes: Int64,
            criticalFreeBytes: Int64,
            lastResortBytes: Int64,
            outOfSpaceFreeBytes: Int64
        ) {
            self.maxBytes = maxBytes
            self.minFreeBytes = minFreeBytes
            self.streamingBytes = streamingBytes
            self.criticalFreeBytes = criticalFreeBytes
            self.lastResortBytes = lastResortBytes
            self.outOfSpaceFreeBytes = outOfSpaceFreeBytes
        }

        public static func defaults(diskCapacity: Int64) -> Limits {
            let tenPercent = max(512 * 1_048_576, diskCapacity / 10)
            return Limits(
                maxBytes: min(20 * 1_073_741_824, tenPercent),
                minFreeBytes: 5 * 1_073_741_824,
                streamingBytes: 2 * 1_073_741_824,
                criticalFreeBytes: 2 * 1_073_741_824,
                lastResortBytes: 256 * 1_048_576,
                outOfSpaceFreeBytes: 512 * 1_048_576
            )
        }
    }

    private struct Entry {
        let key: ChunkKey
        let size: Int64
        var lastAccess: UInt64
    }

    public let root: URL
    public let chunkSize: Int64
    private var limits: Limits
    private let freeSpaceProvider: (@Sendable () -> Int64?)?
    private let lock = NSLock()
    private var entries: [ChunkKey: Entry] = [:]
    private var accessCounter: UInt64 = 0
    private var keptIDs: Set<String> = []
    private var totalBytesUsed: Int64 = 0

    public init(
        root: URL,
        chunkSize: Int64 = ChunkStore.defaultChunkSize,
        limits: Limits,
        freeSpace: (@Sendable () -> Int64?)? = nil
    ) {
        self.root = root
        self.chunkSize = chunkSize
        self.limits = limits
        self.freeSpaceProvider = freeSpace
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func fileURL(for key: ChunkKey) -> URL {
        let safeID = key.remoteID.replacingOccurrences(of: "/", with: "_")
        return root.appendingPathComponent("\(safeID)_v\(key.version)_c\(key.index).chunk")
    }

    public func setKept(_ ids: Set<String>) {
        lock.lock()
        keptIDs = ids
        lock.unlock()
    }

    public func setMaxBytes(_ maxBytes: Int64) {
        lock.lock()
        limits = Limits(
            maxBytes: maxBytes,
            minFreeBytes: limits.minFreeBytes,
            streamingBytes: limits.streamingBytes,
            criticalFreeBytes: limits.criticalFreeBytes,
            lastResortBytes: limits.lastResortBytes,
            outOfSpaceFreeBytes: limits.outOfSpaceFreeBytes
        )
        lock.unlock()
        trim()
    }

    public func contains(_ key: ChunkKey) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries[key] != nil && FileManager.default.fileExists(atPath: fileURL(for: key).path)
    }

    public func get(_ key: ChunkKey) -> Data? {
        lock.lock()
        guard var entry = entries[key] else {
            lock.unlock()
            return nil
        }
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else {
            totalBytesUsed = max(0, totalBytesUsed - entry.size)
            entries.removeValue(forKey: key)
            lock.unlock()
            return nil
        }
        accessCounter += 1
        entry.lastAccess = accessCounter
        entries[key] = entry
        lock.unlock()
        return data
    }

    public func put(_ key: ChunkKey, _ data: Data) {
        let url = fileURL(for: key)
        lock.lock()
        if let free = freeSpaceProvider?(), free < limits.outOfSpaceFreeBytes, !keptIDs.contains(key.remoteID) {
            lock.unlock()
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            if let existing = entries[key] {
                totalBytesUsed = max(0, totalBytesUsed - existing.size)
            }
            accessCounter += 1
            let newSize = Int64(data.count)
            entries[key] = Entry(key: key, size: newSize, lastAccess: accessCounter)
            totalBytesUsed += newSize
        } catch {
            // Ignore cache write failure
        }
        lock.unlock()
    }

    public func trim() {
        lock.lock()
        defer { lock.unlock() }

        let targetCap = effectiveCeilingLocked()
        guard totalBytesUsed > targetCap else { return }

        // Sort unkept entries by oldest access time first (LRU)
        let evictable = entries.values
            .filter { !keptIDs.contains($0.key.remoteID) }
            .sorted { $0.lastAccess < $1.lastAccess }

        for candidate in evictable {
            guard totalBytesUsed > targetCap else { break }
            let url = fileURL(for: candidate.key)
            try? FileManager.default.removeItem(at: url)
            entries.removeValue(forKey: candidate.key)
            totalBytesUsed = max(0, totalBytesUsed - candidate.size)
        }
    }

    private func effectiveCeilingLocked() -> Int64 {
        guard let free = freeSpaceProvider?() else {
            return limits.maxBytes
        }
        if free < limits.outOfSpaceFreeBytes {
            return 0
        } else if free < limits.criticalFreeBytes {
            return min(limits.maxBytes, limits.lastResortBytes)
        } else if free < limits.minFreeBytes {
            return min(limits.maxBytes, limits.streamingBytes)
        }
        return limits.maxBytes
    }

    public func remove(remoteID: String, keeping version: Int64? = nil) {
        lock.lock()
        defer { lock.unlock() }
        let matching = entries.keys.filter { key in
            key.remoteID == remoteID && (version == nil || key.version != version)
        }
        for key in matching {
            if let entry = entries.removeValue(forKey: key) {
                totalBytesUsed = max(0, totalBytesUsed - entry.size)
            }
            try? FileManager.default.removeItem(at: fileURL(for: key))
        }
    }

    @discardableResult
    public func removeRecent() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        var freed: Int64 = 0
        let removable = entries.keys.filter { !keptIDs.contains($0.remoteID) }
        for key in removable {
            if let entry = entries.removeValue(forKey: key) {
                freed += entry.size
                totalBytesUsed = max(0, totalBytesUsed - entry.size)
            }
            try? FileManager.default.removeItem(at: fileURL(for: key))
        }
        return freed
    }

    public func recentBytes() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return entries.values
            .filter { !keptIDs.contains($0.key.remoteID) }
            .reduce(0) { $0 + $1.size }
    }

    public func keptBytes(for remoteID: String) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return entries.values
            .filter { $0.key.remoteID == remoteID }
            .reduce(0) { $0 + $1.size }
    }
}

/// Coalescing byte-range reader that translates arbitrary FSKit reads into 1 MiB chunk lookups and remote range fetches.
public actor ContentReader {
    public struct FileRef: Hashable, Sendable {
        public let remoteID: String
        public let version: Int64
        public let size: Int64

        public init(remoteID: String, version: Int64, size: Int64) {
            self.remoteID = remoteID
            self.version = version
            self.size = size
        }
    }

    private let remote: any DriveRemote
    private let store: ChunkStore
    private let onDownloadActivity: (@Sendable (Bool) -> Void)?
    private var inflight: [ChunkKey: Task<Data, Error>] = [:]
    private var activeDownloads = 0

    public init(
        remote: any DriveRemote,
        store: ChunkStore,
        onDownloadActivity: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.remote = remote
        self.store = store
        self.onDownloadActivity = onDownloadActivity
    }

    public func read(_ file: FileRef, offset: Int64, length: Int) async throws -> Data {
        guard length > 0, offset < file.size else { return Data() }
        let clampedEnd = min(file.size, offset + Int64(length))
        let chunkSize = store.chunkSize
        let firstChunk = Int(offset / chunkSize)
        let lastChunk = Int((clampedEnd - 1) / chunkSize)

        var result = Data(capacity: Int(clampedEnd - offset))
        for index in firstChunk...lastChunk {
            let chunkData = try await fetchChunk(file: file, index: index)
            let chunkStart = Int64(index) * chunkSize
            let sliceStart = Int(max(0, offset - chunkStart))
            let sliceEnd = Int(min(Int64(chunkData.count), clampedEnd - chunkStart))
            if sliceStart < sliceEnd {
                result.append(chunkData.subdata(in: sliceStart..<sliceEnd))
            }
        }
        return result
    }

    private func fetchChunk(file: FileRef, index: Int) async throws -> Data {
        let key = ChunkKey(remoteID: file.remoteID, version: file.version, index: index)
        if let cached = store.get(key) {
            return cached
        }
        if let existingTask = inflight[key] {
            return try await existingTask.value
        }

        let chunkSize = store.chunkSize
        let chunkOffset = Int64(index) * chunkSize
        let expectedLen = Int(min(chunkSize, max(0, file.size - chunkOffset)))
        let remoteRef = remote
        let storeRef = store

        activeDownloads += 1
        if activeDownloads == 1 {
            onDownloadActivity?(true)
        }

        let task = Task<Data, Error> {
            let data = try await remoteRef.fetchRange(id: file.remoteID, offset: chunkOffset, length: expectedLen)
            storeRef.put(key, data)
            storeRef.trim()
            return data
        }
        inflight[key] = task

        do {
            let data = try await task.value
            inflight.removeValue(forKey: key)
            decrementActivity()
            return data
        } catch {
            inflight.removeValue(forKey: key)
            decrementActivity()
            throw error
        }
    }

    private func decrementActivity() {
        activeDownloads = max(0, activeDownloads - 1)
        if activeDownloads == 0 {
            onDownloadActivity?(false)
        }
    }
}
