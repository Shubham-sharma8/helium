import Foundation

/// High-level remote storage protocol consumed by `OrbitDrive` and `ContentReader`.
public protocol DriveRemote: Sendable {
    func account() async throws -> Account
    func listChanges(since seq: Int64) async throws -> ChangePage
    func listChildren(folderId: String, cursor: String?) async throws -> ChildrenPage
    func fetchRange(id: String, offset: Int64, length: Int) async throws -> Data
    func createFolder(name: String, parentId: String) async throws -> RemoteItem
    func rename(id: String, newName: String) async throws -> RemoteItem
    func move(id: String, toParent parentId: String, newName: String?) async throws -> RemoteItem
    func delete(id: String) async throws
    func uploadNewFile(
        from fileURL: URL,
        name: String,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem
    func uploadOverwrite(
        id: String,
        from fileURL: URL,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem
}

/// Low-level remote protocol wrapped by `LockedRemote` so encryption happens transparently before network transport.
public protocol LockableRemote: DriveRemote {
    func createFolder(name: WireName, parentId: String) async throws -> RemoteItem
    func rename(id: String, name: WireName) async throws -> RemoteItem
    func move(id: String, toParent parentId: String, name: WireName?) async throws -> RemoteItem
    func putBlob(
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        name: WireName,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> SaveResult
    func replaceBlob(
        id: String,
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem
}

public protocol KeysRemote: Sendable {
    func fetchServerKeys() async throws -> ServerKeys
    func enableZeroKnowledge(
        keyCheck: String,
        recoveryWrap: String,
        dropPublicKey: String,
        dropPrivateWrap: String,
        ownerProof: String
    ) async throws
}

public protocol PrivacySwitch: Sendable {
    func unencryptedItems() async throws -> [RemoteItem]
    func upgradeItemToEncrypted(
        id: String,
        name: WireName,
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets
    ) async throws -> RemoteItem
}

public protocol ShareRemote: Sendable {
    func listShares() async throws -> [SharedLink]
    func createShare(itemId: String, keyWrap: String?, wrap: String?) async throws -> SharedLink
    func revokeShare(id: String) async throws
    func listFileRequests() async throws -> [FileRequest]
    func createFileRequest(folderId: String, title: String, note: String?) async throws -> FileRequest
    func closeFileRequest(id: String) async throws
}

/// In-memory `LockableRemote` implementation used for fast deterministic unit tests and local demos.
public actor InMemoryLockableRemote: LockableRemote {
    private var itemsById: [String: RemoteItem] = [:]
    private var blobsById: [String: Data] = [:]
    private var seqCounter: Int64 = 0
    public private(set) var fetchCallCount: Int = 0
    private var accountInfo = Account(
        email: "demo@cogify.me/helium",
        name: "Demo User",
        usedBytes: 0,
        quotaBytes: 45 * 1_073_741_824,
        plan: "Pooled Google Drive"
    )

    public init() {}

    @discardableResult
    public func seedFile(name: String, parentId: String, data: Data) -> RemoteItem {
        let id = "mem_\(UUID().uuidString)"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        seqCounter += 1
        let item = RemoteItem(
            id: id,
            parentId: parentId,
            name: name,
            kind: .file,
            size: Int64(data.count),
            plainSize: Int64(data.count),
            contentVersion: 1,
            metadataVersion: seqCounter,
            createdAt: now,
            modifiedAt: now
        )
        itemsById[id] = item
        blobsById[id] = data
        return item
    }

    public func account() async throws -> Account {
        let used = blobsById.values.reduce(Int64(0)) { $0 + Int64($1.count) }
        return Account(
            email: accountInfo.email,
            name: accountInfo.name,
            usedBytes: used,
            quotaBytes: accountInfo.quotaBytes,
            plan: accountInfo.plan
        )
    }

    public func listChanges(since seq: Int64) async throws -> ChangePage {
        let changed = itemsById.values.filter { $0.metadataVersion > seq }.sorted { $0.metadataVersion < $1.metadataVersion }
        return ChangePage(items: changed, seq: seqCounter, hasMore: false)
    }

    public func listChildren(folderId: String, cursor: String?) async throws -> ChildrenPage {
        let children = itemsById.values.filter { !$0.deleted && ($0.parentId ?? RemoteItem.rootID) == folderId }
        return ChildrenPage(items: children, nextCursor: nil)
    }

    public func fetchRange(id: String, offset: Int64, length: Int) async throws -> Data {
        fetchCallCount += 1
        guard let blob = blobsById[id] else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard offset < blob.count, length > 0 else { return Data() }
        let start = Int(max(0, offset))
        let end = min(blob.count, start + length)
        return blob.subdata(in: start..<end)
    }

    public func createFolder(name: String, parentId: String) async throws -> RemoteItem {
        try await createFolder(name: .plain(name), parentId: parentId)
    }

    public func createFolder(name: WireName, parentId: String) async throws -> RemoteItem {
        let id = "folder_\(UUID().uuidString)"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        seqCounter += 1
        let item = RemoteItem(
            id: id,
            parentId: parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: .folder,
            size: 0,
            contentVersion: 1,
            metadataVersion: seqCounter,
            createdAt: now,
            modifiedAt: now
        )
        itemsById[id] = item
        return item
    }

    public func rename(id: String, newName: String) async throws -> RemoteItem {
        try await rename(id: id, name: .plain(newName))
    }

    public func rename(id: String, name: WireName) async throws -> RemoteItem {
        guard let old = itemsById[id] else { throw CocoaError(.fileNoSuchFile) }
        seqCounter += 1
        let updated = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: old.deleted,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        itemsById[id] = updated
        return updated
    }

    public func move(id: String, toParent parentId: String, newName: String?) async throws -> RemoteItem {
        try await move(id: id, toParent: parentId, name: newName.map(WireName.plain))
    }

    public func move(id: String, toParent parentId: String, name: WireName?) async throws -> RemoteItem {
        guard let old = itemsById[id] else { throw CocoaError(.fileNoSuchFile) }
        seqCounter += 1
        let updated = RemoteItem(
            id: old.id,
            parentId: parentId,
            name: name?.text ?? old.name,
            nameLocked: name?.locked ?? old.nameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: old.deleted,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        itemsById[id] = updated
        return updated
    }

    public func delete(id: String) async throws {
        guard let old = itemsById[id] else { return }
        seqCounter += 1
        let tombstone = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: old.name,
            nameLocked: old.nameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: true
        )
        itemsById[id] = tombstone
        blobsById.removeValue(forKey: id)
    }

    public func uploadNewFile(
        from fileURL: URL,
        name: String,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        let source = try FileBlobSource(fileURL)
        let saved = try await putBlob(
            source: source,
            plainSize: source.size,
            secrets: nil,
            name: .plain(name),
            parentId: parentId,
            clientId: clientId,
            modifiedAt: modifiedAt,
            link: link,
            progress: progress
        )
        return saved.item
    }

    public func uploadOverwrite(
        id: String,
        from fileURL: URL,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        let source = try FileBlobSource(fileURL)
        return try await replaceBlob(
            id: id,
            source: source,
            plainSize: source.size,
            secrets: nil,
            expectedVersion: expectedVersion,
            modifiedAt: modifiedAt,
            progress: progress
        )
    }

    public func putBlob(
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        name: WireName,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> SaveResult {
        let data = try source.read(offset: 0, length: Int(source.size))
        progress?(Int64(data.count))
        let id = "file_\(UUID().uuidString)"
        let now = Int64(modifiedAt.timeIntervalSince1970 * 1000)
        seqCounter += 1
        let item = RemoteItem(
            id: id,
            parentId: parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: .file,
            size: source.size,
            plainSize: plainSize,
            contentVersion: 1,
            metadataVersion: seqCounter,
            createdAt: now,
            modifiedAt: now,
            deleted: false,
            shared: link,
            shareUrl: link ? "https://cogify.me/helium/s/\(id)" : nil,
            encryption: secrets?.wrapped != nil ? "zk-v1" : nil,
            wrappedKey: secrets?.wrapped?.key,
            nonce: secrets?.wrapped?.nonce,
            sealPublicKey: secrets?.sealPublic
        )
        itemsById[id] = item
        blobsById[id] = data
        return SaveResult(item: item, shareUrl: item.shareUrl)
    }

    public func replaceBlob(
        id: String,
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        guard let old = itemsById[id] else { throw CocoaError(.fileNoSuchFile) }
        let data = try source.read(offset: 0, length: Int(source.size))
        progress?(Int64(data.count))
        seqCounter += 1
        let updated = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: old.name,
            nameLocked: old.nameLocked,
            kind: .file,
            size: source.size,
            plainSize: plainSize,
            contentVersion: old.contentVersion + 1,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(modifiedAt.timeIntervalSince1970 * 1000),
            deleted: false,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: secrets?.wrapped != nil ? "zk-v1" : nil,
            wrappedKey: secrets?.wrapped?.key,
            nonce: secrets?.wrapped?.nonce,
            sealPublicKey: secrets?.sealPublic
        )
        itemsById[id] = updated
        blobsById[id] = data
        return updated
    }
}
