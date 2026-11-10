import Foundation
import CryptoKit
import Security

public protocol SecretStore: Sendable {
    func get(_ account: String) -> Data?
    func set(_ data: Data, for account: String) throws
    func delete(_ account: String)
}

public final class MemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    public func get(_ account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[account]
    }

    public func set(_ data: Data, for account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[account] = data
    }

    public func delete(_ account: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: account)
    }
}

/// Persistent secret store backed by an owner-only (`0600`) vault file inside the shared App Group container,
/// ensuring OAuth refresh/access tokens and encryption keys reliably survive app restarts and ad-hoc rebuilds.
public final class PersistentSecretStore: SecretStore, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var cache: [String: String] = [:]

    public init(fileURL: URL = SharedContainer.directoryURL().appendingPathComponent(".helium-secrets.json")) {
        self.fileURL = fileURL
        var loaded: [String: String] = [:]

        // Merge any earlier .*-secrets.json vault files in the same container directory first
        let dir = fileURL.deletingLastPathComponent()
        if let siblings = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for sibling in siblings where sibling != fileURL
                && sibling.lastPathComponent.hasPrefix(".")
                && sibling.lastPathComponent.hasSuffix("-secrets.json") {
                if let sibData = try? Data(contentsOf: sibling),
                   let sibDict = try? JSONDecoder().decode([String: String].self, from: sibData) {
                    for (rawKey, val) in sibDict {
                        let normalizedKey = Self.normalizeSecretKey(rawKey)
                        if loaded[normalizedKey] == nil {
                            loaded[normalizedKey] = val
                        }
                    }
                }
            }
        }

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            for (rawKey, val) in decoded {
                loaded[Self.normalizeSecretKey(rawKey)] = val
            }
        }

        self.cache = loaded
        if !loaded.isEmpty {
            try? flushLocked()
        }
    }

    private static func normalizeSecretKey(_ key: String) -> String {
        if let suffix = key.components(separatedBy: ".oauth.rt.").last, key.contains(".oauth.rt.") {
            return "helium.oauth.rt.\(suffix)"
        }
        if let suffix = key.components(separatedBy: ".oauth.at.").last, key.contains(".oauth.at.") {
            return "helium.oauth.at.\(suffix)"
        }
        if key.contains(".zk.masterKey.") {
            return "helium.zk.masterKey.v1"
        }
        return key
    }

    public func allKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cache.keys)
    }

    private func flushLocked() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(cache)
        try encoded.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func get(_ account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if let b64 = cache[account], let data = Data(base64Encoded: b64) {
            return data
        }
        return nil
    }

    public func set(_ data: Data, for account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        cache[account] = data.base64EncodedString()
        try flushLocked()
    }

    public func delete(_ account: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: account)
        try? flushLocked()
    }
}

public final class KeychainSecretStore: SecretStore, Sendable {
    public let service: String
    public let accessGroup: String?

    public init(service: String = "com.cogify.helium.keys", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func get(_ account: String) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    public func set(_ data: Data, for account: String) throws {
        delete(account)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func delete(_ account: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        SecItemDelete(query as CFDictionary)
    }
}

/// Manages the user's 256-bit Master Key (`mk`) and derived `ZK.AccountKeys`.
public final class KeyManager: @unchecked Sendable {
    private let store: any SecretStore
    private let lock = NSLock()
    private static let masterKeySlot = "helium.zk.masterKey.v1"

    public init(store: any SecretStore = MemorySecretStore()) {
        self.store = store
    }

    public func masterKey() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store.get(Self.masterKeySlot)
    }

    public func accountKeys() -> ZK.AccountKeys? {
        guard let mk = masterKey() else { return nil }
        return ZK.deriveKeys(mk)
    }

    public func saveMasterKey(_ mk: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        try store.set(mk, for: Self.masterKeySlot)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.delete(Self.masterKeySlot)
    }
}

/// On-the-fly streaming AES-256-GCM encrypting `BlobSource` that maps 1 MiB plaintext pieces to `1_048_592`-byte ciphertext pieces.
public final class LockedBlobSource: BlobSource, @unchecked Sendable {
    public let plain: any BlobSource
    public let secrets: FileSecrets
    public let size: Int64
    public let pieceCount: Int64
    private static let encPieceSize = Int64(ZK.piece + ZK.tag)

    public init(plain: any BlobSource, secrets: FileSecrets) {
        self.plain = plain
        self.secrets = secrets
        self.pieceCount = ZK.pieceCount(plain.size)
        self.size = ZK.lockedSize(plain.size)
    }

    public func read(offset: Int64, length: Int) throws -> Data {
        guard length > 0, offset < size else { return Data() }
        let endOffset = min(size, offset + Int64(length))
        let firstPiece = offset / Self.encPieceSize
        let lastPiece = (endOffset - 1) / Self.encPieceSize

        var output = Data(capacity: Int(endOffset - offset))
        for p in firstPiece...lastPiece {
            let plainOffset = p * Int64(ZK.piece)
            let remainingPlain = max(0, plain.size - plainOffset)
            let plainLen = Int(min(Int64(ZK.piece), remainingPlain))
            let plainData = plainLen > 0 ? try plain.read(offset: plainOffset, length: plainLen) : Data()
            let isLast = (p == pieceCount - 1)
            let encryptedPiece = try ZK.lockPiece(
                fk: secrets.key,
                fileNonce: secrets.nonce,
                index: UInt64(p),
                last: isLast,
                plainData
            )

            let pieceStartInStream = p * Self.encPieceSize
            let sliceStart = Int(max(0, offset - pieceStartInStream))
            let sliceEnd = Int(min(Int64(encryptedPiece.count), endOffset - pieceStartInStream))
            if sliceStart < sliceEnd {
                output.append(encryptedPiece.subdata(in: sliceStart..<sliceEnd))
            }
        }
        return output
    }
}

/// Transparent Zero-Knowledge E2EE decorator around any `LockableRemote` (including `PooledGoogleDriveRemote`).
public final class LockedRemote: DriveRemote, @unchecked Sendable {
    private struct FileMeta: Codable, Sendable {
        let secrets: FileSecrets
        let plainSize: Int64
        let cipherSize: Int64
    }

    public let inner: any LockableRemote
    public let keys: ZK.AccountKeys
    public let locksWrites: Bool
    public let directory: URL?
    private let lock = NSLock()
    private var metaById: [String: FileMeta] = [:]

    public init(
        inner: any LockableRemote,
        keys: ZK.AccountKeys,
        locksWrites: Bool = true,
        directory: URL? = nil
    ) {
        self.inner = inner
        self.keys = keys
        self.locksWrites = locksWrites
        self.directory = directory
        loadCachedMeta()
    }

    private var cacheFileURL: URL? {
        directory?.appendingPathComponent("locked-meta.json")
    }

    private func loadCachedMeta() {
        guard let url = cacheFileURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: FileMeta].self, from: data) else {
            return
        }
        lock.lock()
        metaById = decoded
        lock.unlock()
    }

    private func saveCachedMeta() {
        guard let url = cacheFileURL else { return }
        lock.lock()
        let snapshot = metaById
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func rememberMeta(for item: RemoteItem, explicitSecrets: FileSecrets? = nil, plainSize: Int64? = nil) {
        if let explicitSecrets {
            let pSize = plainSize ?? item.plainSize ?? item.size
            lock.lock()
            metaById[item.id] = FileMeta(
                secrets: explicitSecrets,
                plainSize: pSize,
                cipherSize: ZK.lockedSize(pSize)
            )
            lock.unlock()
            saveCachedMeta()
            return
        }
        guard let wrappedKey = item.wrappedKey, let nonce = item.nonce else { return }
        let wrapped = ZK.WrappedFile(key: wrappedKey, nonce: nonce)
        if let unwrapped = try? ZK.unwrapFileKey(keys, wrapped) {
            let pSize = plainSize ?? item.plainSize ?? max(0, item.size - Int64(ZK.tag))
            lock.lock()
            metaById[item.id] = FileMeta(
                secrets: FileSecrets(key: unwrapped.fk, nonce: unwrapped.fileNonce),
                plainSize: pSize,
                cipherSize: ZK.lockedSize(pSize)
            )
            lock.unlock()
            saveCachedMeta()
        }
    }

    private func unlockItem(_ item: RemoteItem) -> RemoteItem {
        rememberMeta(for: item)
        let resolvedName: String
        if item.nameLocked, let decName = try? ZK.unlockName(keys, item.name) {
            resolvedName = decName
        } else {
            resolvedName = item.name
        }
        lock.lock()
        let meta = metaById[item.id]
        lock.unlock()
        let resolvedPlainSize = item.plainSize ?? meta?.plainSize
        return item.withUnlocked(name: resolvedName, plainSize: resolvedPlainSize)
    }

    public func account() async throws -> Account {
        try await inner.account()
    }

    public func listChanges(since seq: Int64) async throws -> ChangePage {
        let page = try await inner.listChanges(since: seq)
        return ChangePage(items: page.items.map(unlockItem), seq: page.seq, hasMore: page.hasMore)
    }

    public func listChildren(folderId: String, cursor: String?) async throws -> ChildrenPage {
        let page = try await inner.listChildren(folderId: folderId, cursor: cursor)
        return ChildrenPage(items: page.items.map(unlockItem), nextCursor: page.nextCursor)
    }

    public func fetchRange(id: String, offset: Int64, length: Int) async throws -> Data {
        guard length > 0 else { return Data() }
        let meta = lock.withLock { metaById[id] }

        guard let meta else {
            return try await inner.fetchRange(id: id, offset: offset, length: length)
        }

        guard offset < meta.plainSize else { return Data() }
        let clampedEnd = min(meta.plainSize, offset + Int64(length))
        let pieceSize = Int64(ZK.piece)
        let encPieceSize = Int64(ZK.piece + ZK.tag)
        let totalPieces = ZK.pieceCount(meta.plainSize)

        let firstPiece = offset / pieceSize
        let lastPiece = (clampedEnd - 1) / pieceSize

        var output = Data(capacity: Int(clampedEnd - offset))
        for p in firstPiece...lastPiece {
            let plainPieceOffset = p * pieceSize
            let plainPieceLen = Int(min(pieceSize, meta.plainSize - plainPieceOffset))
            let encOffset = p * encPieceSize
            let encLen = plainPieceLen + ZK.tag
            let cipherAndTag = try await inner.fetchRange(id: id, offset: encOffset, length: encLen)
            let isLast = (p == totalPieces - 1)
            let decryptedPiece = try ZK.unlockPiece(
                fk: meta.secrets.key,
                fileNonce: meta.secrets.nonce,
                index: UInt64(p),
                last: isLast,
                cipherAndTag
            )

            let sliceStart = Int(max(0, offset - plainPieceOffset))
            let sliceEnd = Int(min(Int64(decryptedPiece.count), clampedEnd - plainPieceOffset))
            if sliceStart < sliceEnd {
                output.append(decryptedPiece.subdata(in: sliceStart..<sliceEnd))
            }
        }
        return output
    }

    public func createFolder(name: String, parentId: String) async throws -> RemoteItem {
        let wireName = locksWrites ? try WireName.locked(name, keys: keys) : .plain(name)
        let created = try await inner.createFolder(name: wireName, parentId: parentId)
        return unlockItem(created)
    }

    public func rename(id: String, newName: String) async throws -> RemoteItem {
        let wireName = locksWrites ? try WireName.locked(newName, keys: keys) : .plain(newName)
        let renamed = try await inner.rename(id: id, name: wireName)
        return unlockItem(renamed)
    }

    public func move(id: String, toParent parentId: String, newName: String?) async throws -> RemoteItem {
        let wireName: WireName?
        if let newName {
            wireName = locksWrites ? try WireName.locked(newName, keys: keys) : .plain(newName)
        } else {
            wireName = nil
        }
        let moved = try await inner.move(id: id, toParent: parentId, name: wireName)
        return unlockItem(moved)
    }

    public func delete(id: String) async throws {
        try await inner.delete(id: id)
        _ = lock.withLock {
            metaById.removeValue(forKey: id)
        }
        saveCachedMeta()
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
        let plainSource = try FileBlobSource(fileURL)
        guard locksWrites else {
            let saved = try await inner.putBlob(
                source: plainSource,
                plainSize: plainSource.size,
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

        let fileSecrets = FileSecrets.new()
        let wrapped = try ZK.wrapFileKey(keys, fk: fileSecrets.key, fileNonce: fileSecrets.nonce)
        let wireSecrets = WireSecrets(wrapped: wrapped)
        let wireName = try WireName.locked(name, keys: keys)
        let lockedSource = LockedBlobSource(plain: plainSource, secrets: fileSecrets)

        let saved = try await inner.putBlob(
            source: lockedSource,
            plainSize: plainSource.size,
            secrets: wireSecrets,
            name: wireName,
            parentId: parentId,
            clientId: clientId,
            modifiedAt: modifiedAt,
            link: link,
            progress: progress
        )
        rememberMeta(for: saved.item, explicitSecrets: fileSecrets, plainSize: plainSource.size)
        return unlockItem(saved.item)
    }

    public func uploadOverwrite(
        id: String,
        from fileURL: URL,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        let plainSource = try FileBlobSource(fileURL)
        guard locksWrites else {
            return try await inner.replaceBlob(
                id: id,
                source: plainSource,
                plainSize: plainSource.size,
                secrets: nil,
                expectedVersion: expectedVersion,
                modifiedAt: modifiedAt,
                progress: progress
            )
        }

        let fileSecrets = FileSecrets.new()
        let wrapped = try ZK.wrapFileKey(keys, fk: fileSecrets.key, fileNonce: fileSecrets.nonce)
        let wireSecrets = WireSecrets(wrapped: wrapped)
        let lockedSource = LockedBlobSource(plain: plainSource, secrets: fileSecrets)

        let updated = try await inner.replaceBlob(
            id: id,
            source: lockedSource,
            plainSize: plainSource.size,
            secrets: wireSecrets,
            expectedVersion: expectedVersion,
            modifiedAt: modifiedAt,
            progress: progress
        )
        rememberMeta(for: updated, explicitSecrets: fileSecrets, plainSize: plainSource.size)
        return unlockItem(updated)
    }
}
