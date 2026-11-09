import Foundation

public struct Account: Codable, Equatable, Sendable {
    public let email: String
    public let name: String?
    public let usedBytes: Int64
    public let quotaBytes: Int64
    public let plan: String

    public init(email: String, name: String?, usedBytes: Int64, quotaBytes: Int64, plan: String) {
        self.email = email
        self.name = name
        self.usedBytes = usedBytes
        self.quotaBytes = quotaBytes
        self.plan = plan
    }
}

public struct PrivateFiles: Codable, Equatable, Sendable {
    public let mode: String
    public let keyCheck: String?
    public let recoveryWrap: String?
    public let dropPublicKey: String?
    public let dropPrivateWrap: String?
    public let plainFiles: Int

    public init(
        mode: String = "off",
        keyCheck: String? = nil,
        recoveryWrap: String? = nil,
        dropPublicKey: String? = nil,
        dropPrivateWrap: String? = nil,
        plainFiles: Int = 0
    ) {
        self.mode = mode
        self.keyCheck = keyCheck
        self.recoveryWrap = recoveryWrap
        self.dropPublicKey = dropPublicKey
        self.dropPrivateWrap = dropPrivateWrap
        self.plainFiles = plainFiles
    }
}

public struct WireName: Codable, Equatable, Sendable {
    public let text: String
    public let locked: Bool
    public let hash: String?

    public init(text: String, locked: Bool = false, hash: String? = nil) {
        self.text = text
        self.locked = locked
        self.hash = hash
    }

    public static func plain(_ name: String) -> WireName {
        WireName(text: name, locked: false, hash: nil)
    }

    public static func locked(_ name: String, keys: ZK.AccountKeys) throws -> WireName {
        let enc = try ZK.lockName(keys, name)
        let hash = ZK.nameHash(keys, name)
        return WireName(text: enc, locked: true, hash: hash)
    }
}

public struct FileSecrets: Codable, Equatable, Sendable {
    public let key: Data
    public let nonce: Data

    public init(key: Data, nonce: Data) {
        self.key = key
        self.nonce = nonce
    }

    public static func new() -> FileSecrets {
        FileSecrets(key: ZK.random(32), nonce: ZK.random(12))
    }
}

public struct WireSecrets: Codable, Equatable, Sendable {
    public let wrapped: ZK.WrappedFile?
    public let sealPublic: String?
    public let dropFileKey: String?
    public let dropName: String?

    public init(
        wrapped: ZK.WrappedFile? = nil,
        sealPublic: String? = nil,
        dropFileKey: String? = nil,
        dropName: String? = nil
    ) {
        self.wrapped = wrapped
        self.sealPublic = sealPublic
        self.dropFileKey = dropFileKey
        self.dropName = dropName
    }
}

public struct RemoteItem: Codable, Equatable, Identifiable, Sendable {
    public static let rootID = "root"

    public enum Kind: String, Codable, Sendable {
        case file
        case folder
    }

    public let id: String
    public let parentId: String?
    public let name: String
    public let nameLocked: Bool
    public let kind: Kind
    public let size: Int64
    public let plainSize: Int64?
    public let mimeType: String?
    public let contentVersion: Int64
    public let metadataVersion: Int64
    public let createdAt: Int64
    public let modifiedAt: Int64
    public let deleted: Bool
    public let shared: Bool
    public let shareUrl: String?
    public let encryption: String?
    public let wrappedKey: String?
    public let nonce: String?
    public let sealPublicKey: String?

    public init(
        id: String,
        parentId: String?,
        name: String,
        nameLocked: Bool = false,
        kind: Kind,
        size: Int64,
        plainSize: Int64? = nil,
        mimeType: String? = nil,
        contentVersion: Int64 = 1,
        metadataVersion: Int64 = 1,
        createdAt: Int64,
        modifiedAt: Int64,
        deleted: Bool = false,
        shared: Bool = false,
        shareUrl: String? = nil,
        encryption: String? = nil,
        wrappedKey: String? = nil,
        nonce: String? = nil,
        sealPublicKey: String? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.nameLocked = nameLocked
        self.kind = kind
        self.size = size
        self.plainSize = plainSize
        self.mimeType = mimeType
        self.contentVersion = contentVersion
        self.metadataVersion = metadataVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.deleted = deleted
        self.shared = shared
        self.shareUrl = shareUrl
        self.encryption = encryption
        self.wrappedKey = wrappedKey
        self.nonce = nonce
        self.sealPublicKey = sealPublicKey
    }

    public func withUnlocked(name unlockedName: String, plainSize resolvedSize: Int64?) -> RemoteItem {
        RemoteItem(
            id: id,
            parentId: parentId,
            name: unlockedName,
            nameLocked: false,
            kind: kind,
            size: resolvedSize ?? plainSize ?? size,
            plainSize: resolvedSize ?? plainSize,
            mimeType: mimeType,
            contentVersion: contentVersion,
            metadataVersion: metadataVersion,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deleted: deleted,
            shared: shared,
            shareUrl: shareUrl,
            encryption: encryption,
            wrappedKey: wrappedKey,
            nonce: nonce,
            sealPublicKey: sealPublicKey
        )
    }
}

public struct ChangePage: Codable, Equatable, Sendable {
    public let items: [RemoteItem]
    public let seq: Int64
    public let hasMore: Bool

    public init(items: [RemoteItem], seq: Int64, hasMore: Bool = false) {
        self.items = items
        self.seq = seq
        self.hasMore = hasMore
    }
}

public struct ChildrenPage: Codable, Equatable, Sendable {
    public let items: [RemoteItem]
    public let nextCursor: String?

    public init(items: [RemoteItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct ContentURL: Codable, Equatable, Sendable {
    public let url: URL
    public let expiresAt: Date

    public init(url: URL, expiresAt: Date) {
        self.url = url
        self.expiresAt = expiresAt
    }
}

public struct SaveResult: Codable, Equatable, Sendable {
    public let item: RemoteItem
    public let shareUrl: String?

    public init(item: RemoteItem, shareUrl: String? = nil) {
        self.item = item
        self.shareUrl = shareUrl
    }
}

public struct StreamBlob: Codable, Equatable, Sendable {
    public let uploadId: String
    public let size: Int64

    public init(uploadId: String, size: Int64) {
        self.uploadId = uploadId
        self.size = size
    }
}

public struct ServerKeys: Codable, Equatable, Sendable {
    public let mode: String
    public let keyCheck: String?
    public let recoveryWrap: String?
    public let dropPublicKey: String?
    public let dropPrivateWrap: String?

    public init(
        mode: String,
        keyCheck: String?,
        recoveryWrap: String?,
        dropPublicKey: String?,
        dropPrivateWrap: String?
    ) {
        self.mode = mode
        self.keyCheck = keyCheck
        self.recoveryWrap = recoveryWrap
        self.dropPublicKey = dropPublicKey
        self.dropPrivateWrap = dropPrivateWrap
    }
}

public struct WaitingDevice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let publicKey: String
    public let createdAt: Int64

    public init(id: String, name: String, publicKey: String, createdAt: Int64) {
        self.id = id
        self.name = name
        self.publicKey = publicKey
        self.createdAt = createdAt
    }
}

public struct SharedLink: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let itemId: String
    public let name: String
    public let kind: String
    public let size: Int64
    public let url: String
    public let createdAt: Int64
    public let expiresAt: Int64?
    public let hasPassword: Bool
    public let views: Int
    public let downloads: Int

    public init(
        id: String,
        itemId: String,
        name: String,
        kind: String,
        size: Int64,
        url: String,
        createdAt: Int64,
        expiresAt: Int64? = nil,
        hasPassword: Bool = false,
        views: Int = 0,
        downloads: Int = 0
    ) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.kind = kind
        self.size = size
        self.url = url
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.hasPassword = hasPassword
        self.views = views
        self.downloads = downloads
    }
}

public struct StaleShare: Codable, Equatable, Sendable {
    public let shareId: String
    public let itemId: String
    public let keyWrap: String

    public init(shareId: String, itemId: String, keyWrap: String) {
        self.shareId = shareId
        self.itemId = itemId
        self.keyWrap = keyWrap
    }
}

public struct FolderLinkMissing: Codable, Equatable, Sendable {
    public let folderId: String
    public let itemId: String

    public init(folderId: String, itemId: String) {
        self.folderId = folderId
        self.itemId = itemId
    }
}

public struct FolderWrap: Codable, Equatable, Sendable {
    public let itemId: String
    public let wrap: String

    public init(itemId: String, wrap: String) {
        self.itemId = itemId
        self.wrap = wrap
    }
}

public struct FileRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let folderId: String
    public let folderName: String
    public let title: String
    public let note: String?
    public let url: String
    public let createdAt: Int64
    public let expiresAt: Int64?
    public let open: Bool
    public let uploads: Int

    public init(
        id: String,
        folderId: String,
        folderName: String,
        title: String,
        note: String? = nil,
        url: String,
        createdAt: Int64,
        expiresAt: Int64? = nil,
        open: Bool = true,
        uploads: Int = 0
    ) {
        self.id = id
        self.folderId = folderId
        self.folderName = folderName
        self.title = title
        self.note = note
        self.url = url
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.open = open
        self.uploads = uploads
    }
}

public struct TrashItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nameLocked: Bool
    public let kind: String
    public let size: Int64
    public let plainSize: Int64?
    public let deletedAt: Int64
    public let wrappedKey: String?
    public let nonce: String?

    public init(
        id: String,
        name: String,
        nameLocked: Bool = false,
        kind: String,
        size: Int64,
        plainSize: Int64? = nil,
        deletedAt: Int64,
        wrappedKey: String? = nil,
        nonce: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameLocked = nameLocked
        self.kind = kind
        self.size = size
        self.plainSize = plainSize
        self.deletedAt = deletedAt
        self.wrappedKey = wrappedKey
        self.nonce = nonce
    }
}

/// Byte-addressable stream source for uploads.
public protocol BlobSource: Sendable {
    var size: Int64 { get }
    func read(offset: Int64, length: Int) throws -> Data
}

/// File-backed `BlobSource` reading slices on demand without loading entire multi-GB files into memory.
public final class FileBlobSource: BlobSource, @unchecked Sendable {
    public let url: URL
    public let size: Int64
    private let lock = NSLock()

    public init(_ url: URL) throws {
        self.url = url
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        self.size = Int64(values.fileSize ?? 0)
    }

    public func read(offset: Int64, length: Int) throws -> Data {
        guard length > 0, offset < size else { return Data() }
        lock.lock()
        defer { lock.unlock() }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, offset)))
        let clamped = min(length, Int(size - offset))
        return try handle.read(upToCount: clamped) ?? Data()
    }
}
