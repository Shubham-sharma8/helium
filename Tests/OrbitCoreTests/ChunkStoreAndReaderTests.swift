import XCTest
@testable import OrbitCore

final class ChunkStoreAndReaderTests: XCTestCase {

    func testChunkStoreLRUEvictionAndKeepListProtection() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let chunkSize: Int64 = 1024
        let simulatedFreeSpace: Int64 = 100_000
        let limits = ChunkStore.Limits(
            maxBytes: 3072, // Max 3 chunks of 1024 bytes
            minFreeBytes: 10_000,
            streamingBytes: 2048,
            criticalFreeBytes: 5_000,
            lastResortBytes: 1024,
            outOfSpaceFreeBytes: 1_000
        )

        let store = ChunkStore(root: tempRoot, chunkSize: chunkSize, limits: limits) {
            simulatedFreeSpace
        }

        let k1 = ChunkKey(remoteID: "fileA", version: 1, index: 0)
        let k2 = ChunkKey(remoteID: "fileB", version: 1, index: 0)
        let k3 = ChunkKey(remoteID: "fileC", version: 1, index: 0)
        let k4 = ChunkKey(remoteID: "fileD", version: 1, index: 0)

        let d1 = Data(repeating: 0xAA, count: 1024)
        let d2 = Data(repeating: 0xBB, count: 1024)
        let d3 = Data(repeating: 0xCC, count: 1024)
        let d4 = Data(repeating: 0xDD, count: 1024)

        // Pin fileA in KeepList so it is immune to LRU eviction
        store.setKept(["fileA"])

        store.put(k1, d1)
        store.put(k2, d2)
        store.put(k3, d3)

        // Touch k2 so k3 is older than k2, while k1 is pinned
        _ = store.get(k2)

        // Adding k4 exceeds maxBytes (3072 -> 4096); k1 is kept, k2 was just accessed, so k3 should be evicted
        store.put(k4, d4)
        store.trim()

        XCTAssertTrue(store.contains(k1), "Kept fileA must not be evicted")
        XCTAssertTrue(store.contains(k2), "Recently accessed fileB should remain")
        XCTAssertFalse(store.contains(k3), "Least recently used unpinned fileC should be evicted")
        XCTAssertTrue(store.contains(k4), "Newly added fileD should remain")

        // Test version invalidation
        store.remove(remoteID: "fileB", keeping: 2)
        XCTAssertFalse(store.contains(k2))

        // Test removeRecent purges non-kept chunks
        let freed = store.removeRecent()
        XCTAssertGreaterThan(freed, 0)
        XCTAssertTrue(store.contains(k1), "Kept fileA must survive removeRecent()")
        XCTAssertFalse(store.contains(k4))
    }

    func testContentReaderCrossChunkReadingAndCaching() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let limits = ChunkStore.Limits.defaults(diskCapacity: 100_000_000_000)
        let chunkSize = ChunkStore.defaultChunkSize // 1 MiB
        let store = ChunkStore(root: tempRoot, chunkSize: chunkSize, limits: limits, freeSpace: nil)

        // Create a 2.5 MiB test payload inside MockDriveRemote
        let totalSize = Int(chunkSize * 2 + 524_288)
        var payload = Data(count: totalSize)
        for i in 0..<totalSize {
            payload[i] = UInt8((i * 13 + 5) & 0xFF)
        }

        let mockRemote = InMemoryLockableRemote()
        let item = await mockRemote.seedFile(name: "Movie.mov", parentId: "root", data: payload)

        let reader = ContentReader(remote: mockRemote, store: store) { _ in }
        let fileRef = ContentReader.FileRef(remoteID: item.id, version: item.contentVersion, size: item.size)

        // Read across the boundary between chunk 0 and chunk 1 (offset 1 MiB - 500, length 1000)
        let readOffset = chunkSize - 500
        let slice = try await reader.read(fileRef, offset: readOffset, length: 1000)
        XCTAssertEqual(slice, payload.subdata(in: Int(readOffset)..<Int(readOffset + 1000)))

        // Both chunk 0 and chunk 1 should now be cached in ChunkStore
        XCTAssertTrue(store.contains(ChunkKey(remoteID: item.id, version: 1, index: 0)))
        XCTAssertTrue(store.contains(ChunkKey(remoteID: item.id, version: 1, index: 1)))

        let fetchesAfterFirstRead = await mockRemote.fetchCallCount
        XCTAssertGreaterThanOrEqual(fetchesAfterFirstRead, 2)

        // Second read from chunk 0 should be served 100% from ChunkStore without hitting remote
        let cachedSlice = try await reader.read(fileRef, offset: 128, length: 4096)
        XCTAssertEqual(cachedSlice, payload.subdata(in: 128..<(128 + 4096)))
    }
}
