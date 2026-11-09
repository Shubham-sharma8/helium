import Foundation
import FSKit
import OrbitCore

/// High-level FSKit Virtual Volume Adapter connecting `OrbitDrive` (backed by `LockedRemote` + `PooledGoogleDriveRemote`)
/// to macOS virtual filesystem operations (`lookup`, `enumerate`, `read`, `write`, `create`, `remove`, `xattr`, `volumeStatistics`).
public final class OrbitVirtualVolume: @unchecked Sendable {
    public struct VolumeStats: Equatable, Sendable {
        public let blockSize: Int
        public let iosize: Int
        public let totalBytes: Int64
        public let availableBytes: Int64
        public let usedBytes: Int64
        public let reportedOnDiskBytes: Int64
    }

    public let volumeName: String
    public let drive: OrbitDrive

    public init(volumeName: String = "Helium", drive: OrbitDrive) {
        self.volumeName = volumeName
        self.drive = drive
    }

    /// Returns pooled volume statistics across all linked Google Drive accounts while reporting `0` local disk bytes (`st_blocks = 0`).
    public func volumeStatistics() async throws -> VolumeStats {
        let acct = try await drive.remote.account()
        let avail = max(0, acct.quotaBytes - acct.usedBytes)
        return VolumeStats(
            blockSize: 4096,
            iosize: Int(ChunkStore.defaultChunkSize), // 1 MiB optimal I/O size
            totalBytes: acct.quotaBytes,
            availableBytes: avail,
            usedBytes: acct.usedBytes,
            reportedOnDiskBytes: DriveNode.onDiskBytes // Always 0 bytes on Mac disk
        )
    }

    public func lookup(name: String, inDirectory parentInode: UInt64) -> DriveNode? {
        drive.lookup(name, in: parentInode)
    }

    public func enumerate(directory inode: UInt64) -> [DriveNode] {
        drive.children(of: inode)
    }

    public func read(inode: UInt64, offset: Int64, length: Int) async throws -> Data {
        try await drive.read(inode, offset: offset, length: length)
    }

    public func createFile(name: String, inDirectory parentInode: UInt64) throws -> DriveNode {
        try drive.createFile(name: name, in: parentInode)
    }

    public func write(inode: UInt64, offset: Int64, data: Data) throws {
        try drive.write(inode, offset: offset, data: data)
    }

    public func closeAndFlush(inode: UInt64) async throws -> DriveNode {
        try await drive.flushFile(inode)
    }

    public func createDirectory(name: String, inDirectory parentInode: UInt64) async throws -> DriveNode {
        try await drive.createFolder(name: name, in: parentInode)
    }

    public func remove(inode: UInt64) async throws {
        try await drive.remove(inode)
    }

    public func getXattr(name: String, of inode: UInt64) throws -> Data {
        try drive.xattrs.get(name, of: inode)
    }

    public func setXattr(name: String, value: Data, of inode: UInt64, policy: XattrStore.SetPolicy = .always) throws {
        try drive.xattrs.set(name, to: value, of: inode, policy: policy)
    }

    public func listXattrs(of inode: UInt64) -> [String] {
        drive.xattrs.names(of: inode)
    }
}

let args = CommandLine.arguments
if args.contains("--version") {
    print("OrbitFS Apple FSKit Extension Ready")
    exit(0)
}
