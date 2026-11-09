import Foundation

public struct DriveNode: Codable, Equatable, Identifiable, Sendable {
    public static let rootID: UInt64 = 2
    public static let onDiskBytes: Int64 = 0

    public var id: UInt64
    public var parentID: UInt64
    public var remoteID: String?
    public var clientID: String?
    public var name: String
    public var isFolder: Bool
    public var size: Int64
    public var contentVersion: Int64
    public var metadataVersion: Int64
    public var createdAt: Date
    public var modifiedAt: Date
    public var dirtyContent: Bool
    public var dirtyMetadata: Bool
    public var shared: Bool
    public var shareURL: String?

    public init(
        id: UInt64,
        parentID: UInt64,
        remoteID: String? = nil,
        clientID: String? = nil,
        name: String,
        isFolder: Bool,
        size: Int64 = 0,
        contentVersion: Int64 = 1,
        metadataVersion: Int64 = 1,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        dirtyContent: Bool = false,
        dirtyMetadata: Bool = false,
        shared: Bool = false,
        shareURL: String? = nil
    ) {
        self.id = id
        self.parentID = parentID
        self.remoteID = remoteID
        self.clientID = clientID
        self.name = name
        self.isFolder = isFolder
        self.size = size
        self.contentVersion = contentVersion
        self.metadataVersion = metadataVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.dirtyContent = dirtyContent
        self.dirtyMetadata = dirtyMetadata
        self.shared = shared
        self.shareURL = shareURL
    }
}

public struct PendingDelete: Codable, Equatable, Sendable {
    public let remoteID: String
    public let deletedAt: Date

    public init(remoteID: String, deletedAt: Date = Date()) {
        self.remoteID = remoteID
        self.deletedAt = deletedAt
    }
}

/// Thread-safe in-memory inode tree (`tree.json`) mapping POSIX inode numbers (`UInt64`, root = 2) to cloud `RemoteItem` IDs.
public final class DriveTree: @unchecked Sendable {
    public struct Snapshot: Codable, Sendable {
        public var nextID: UInt64
        public var seq: Int64
        public var initialSyncComplete: Bool
        public var nodes: [DriveNode]
        public var pendingDeletes: [PendingDelete]
    }

    public struct ApplyResult: Sendable {
        public let changedContent: [(remoteID: String, version: Int64)]
        public let removedRemoteIDs: [String]
        public let changedFolders: Set<String>
    }

    private let file: URL?
    private let lock = NSLock()
    private var nodesByID: [UInt64: DriveNode] = [:]
    private var idByRemoteID: [String: UInt64] = [:]
    private var childrenByParent: [UInt64: Set<UInt64>] = [:]
    private var nextID: UInt64 = 3
    public private(set) var seq: Int64 = 0
    public private(set) var initialSyncComplete: Bool = false
    private var pendingDeletes: [PendingDelete] = []

    public init(file: URL?) {
        self.file = file
        if let file, let data = try? Data(contentsOf: file),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.nextID = max(3, snap.nextID)
            self.seq = snap.seq
            self.initialSyncComplete = snap.initialSyncComplete
            self.pendingDeletes = snap.pendingDeletes
            for node in snap.nodes {
                nodesByID[node.id] = node
                if let rem = node.remoteID {
                    idByRemoteID[rem] = node.id
                }
                if node.id != DriveNode.rootID {
                    childrenByParent[node.parentID, default: []].insert(node.id)
                }
            }
        }
        if nodesByID[DriveNode.rootID] == nil {
            nodesByID[DriveNode.rootID] = DriveNode(
                id: DriveNode.rootID,
                parentID: DriveNode.rootID,
                remoteID: RemoteItem.rootID,
                name: "",
                isFolder: true
            )
            idByRemoteID[RemoteItem.rootID] = DriveNode.rootID
        }
    }

    public func save() {
        guard let file else { return }
        lock.lock()
        let snap = Snapshot(
            nextID: nextID,
            seq: seq,
            initialSyncComplete: initialSyncComplete,
            nodes: Array(nodesByID.values),
            pendingDeletes: pendingDeletes
        )
        lock.unlock()
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: file, options: .atomic)
        }
    }

    public func node(_ id: UInt64) -> DriveNode? {
        lock.lock()
        defer { lock.unlock() }
        return nodesByID[id]
    }

    public func node(remoteID: String) -> DriveNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let id = idByRemoteID[remoteID] else { return nil }
        return nodesByID[id]
    }

    public func children(of parentID: UInt64) -> [DriveNode] {
        lock.lock()
        defer { lock.unlock() }
        guard let ids = childrenByParent[parentID] else { return [] }
        return ids.compactMap { nodesByID[$0] }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func lookup(_ name: String, in parentID: UInt64) -> DriveNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let ids = childrenByParent[parentID] else { return nil }
        let target = name.precomposedStringWithCanonicalMapping.lowercased()
        for id in ids {
            if let candidate = nodesByID[id],
               candidate.name.precomposedStringWithCanonicalMapping.lowercased() == target {
                return candidate
            }
        }
        return nil
    }

    public func folderPath(of id: UInt64) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return folderPathLocked(of: id)
    }

    private func folderPathLocked(of id: UInt64) -> [String] {
        var components: [String] = []
        var currentID = id
        var visited: Set<UInt64> = []
        while currentID != DriveNode.rootID, !visited.contains(currentID), let node = nodesByID[currentID] {
            visited.insert(currentID)
            components.append(node.name)
            currentID = node.parentID
        }
        return components.reversed()
    }

    @discardableResult
    public func add(
        name: String,
        in parentID: UInt64,
        isFolder: Bool,
        size: Int64 = 0,
        remote: RemoteItem? = nil
    ) throws -> DriveNode {
        lock.lock()
        defer { lock.unlock() }
        let id = nextID
        nextID += 1
        let node = DriveNode(
            id: id,
            parentID: parentID,
            remoteID: remote?.id,
            clientID: UUID().uuidString,
            name: name,
            isFolder: isFolder,
            size: remote?.size ?? size,
            contentVersion: remote?.contentVersion ?? 1,
            metadataVersion: remote?.metadataVersion ?? 1,
            dirtyContent: remote == nil && !isFolder,
            dirtyMetadata: remote == nil
        )
        nodesByID[id] = node
        childrenByParent[parentID, default: []].insert(id)
        if let remID = remote?.id {
            idByRemoteID[remID] = id
        }
        return node
    }

    public func update(_ id: UInt64, mutate: (inout DriveNode) -> Void) -> DriveNode? {
        lock.lock()
        defer { lock.unlock() }
        guard var node = nodesByID[id] else { return nil }
        let oldParent = node.parentID
        let oldRemote = node.remoteID
        mutate(&node)
        nodesByID[id] = node
        if oldParent != node.parentID {
            childrenByParent[oldParent]?.remove(id)
            childrenByParent[node.parentID, default: []].insert(id)
        }
        if oldRemote != node.remoteID {
            if let oldRemote { idByRemoteID.removeValue(forKey: oldRemote) }
            if let newRemote = node.remoteID { idByRemoteID[newRemote] = id }
        }
        return node
    }

    public func remove(_ id: UInt64) -> DriveNode? {
        lock.lock()
        defer { lock.unlock() }
        return removeLocked(id)
    }

    private func removeLocked(_ id: UInt64) -> DriveNode? {
        guard id != DriveNode.rootID, let node = nodesByID.removeValue(forKey: id) else { return nil }
        childrenByParent[node.parentID]?.remove(id)
        if let remID = node.remoteID {
            idByRemoteID.removeValue(forKey: remID)
            pendingDeletes.append(PendingDelete(remoteID: remID))
        }
        if let childIDs = childrenByParent.removeValue(forKey: id) {
            for childID in childIDs {
                _ = removeLocked(childID)
            }
        }
        return node
    }

    public func apply(_ items: [RemoteItem], seq newSeq: Int64, complete: Bool) -> ApplyResult {
        lock.lock()
        defer { lock.unlock() }

        var changedContent: [(remoteID: String, version: Int64)] = []
        var removedRemoteIDs: [String] = []
        var changedFolders: Set<String> = []

        // Sort folders first so parent folders exist before child items are linked
        let ordered = items.sorted { lhs, rhs in
            if lhs.kind == rhs.kind { return lhs.createdAt < rhs.createdAt }
            return lhs.kind == .folder
        }

        for item in ordered {
            if item.deleted {
                if let id = idByRemoteID.removeValue(forKey: item.id),
                   let existing = nodesByID.removeValue(forKey: id) {
                    childrenByParent[existing.parentID]?.remove(id)
                    let parentRel = folderPathLocked(of: existing.parentID).joined(separator: "/")
                    changedFolders.insert(parentRel)
                    removedRemoteIDs.append(item.id)
                }
                continue
            }

            let parentInode: UInt64
            if let pid = item.parentId, let mapped = idByRemoteID[pid] {
                parentInode = mapped
            } else {
                parentInode = DriveNode.rootID
            }

            let createdDate = Date(timeIntervalSince1970: TimeInterval(item.createdAt) / 1000.0)
            let modifiedDate = Date(timeIntervalSince1970: TimeInterval(item.modifiedAt) / 1000.0)

            if let existingID = idByRemoteID[item.id], var existing = nodesByID[existingID] {
                let oldParent = existing.parentID
                if existing.contentVersion != item.contentVersion {
                    changedContent.append((item.id, item.contentVersion))
                }
                existing.parentID = parentInode
                existing.name = item.name
                existing.size = item.size
                existing.contentVersion = item.contentVersion
                existing.metadataVersion = item.metadataVersion
                existing.modifiedAt = modifiedDate
                existing.shared = item.shared
                existing.shareURL = item.shareUrl
                nodesByID[existingID] = existing
                if oldParent != parentInode {
                    childrenByParent[oldParent]?.remove(existingID)
                    childrenByParent[parentInode, default: []].insert(existingID)
                }
            } else {
                let id = nextID
                nextID += 1
                let node = DriveNode(
                    id: id,
                    parentID: parentInode,
                    remoteID: item.id,
                    name: item.name,
                    isFolder: item.kind == .folder,
                    size: item.size,
                    contentVersion: item.contentVersion,
                    metadataVersion: item.metadataVersion,
                    createdAt: createdDate,
                    modifiedAt: modifiedDate,
                    shared: item.shared,
                    shareURL: item.shareUrl
                )
                nodesByID[id] = node
                idByRemoteID[item.id] = id
                childrenByParent[parentInode, default: []].insert(id)
            }

            let parentRel = folderPathLocked(of: parentInode).joined(separator: "/")
            changedFolders.insert(parentRel)
        }

        self.seq = newSeq
        if complete {
            self.initialSyncComplete = true
        }
        return ApplyResult(
            changedContent: changedContent,
            removedRemoteIDs: removedRemoteIDs,
            changedFolders: changedFolders
        )
    }

    public func allNodes() -> [DriveNode] {
        lock.lock()
        defer { lock.unlock() }
        return Array(nodesByID.values)
    }
}

/// Write-back staging store (`staging/<inode>`) for dirty local writes prior to cloud upload completion.
public final class Staging: @unchecked Sendable {
    public let root: URL
    private let lock = NSLock()

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func fileURL(for nodeID: UInt64) -> URL {
        root.appendingPathComponent("inode_\(nodeID).stage")
    }

    public func create(_ nodeID: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: nodeID)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
    }

    public func exists(_ nodeID: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return FileManager.default.fileExists(atPath: fileURL(for: nodeID).path)
    }

    public func size(_ nodeID: UInt64) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: nodeID)
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    public func write(_ nodeID: UInt64, offset: Int64, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: nodeID)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let currentEnd = Int64(try handle.seekToEnd())
        if offset > currentEnd {
            let padding = Data(count: Int(offset - currentEnd))
            try handle.write(contentsOf: padding)
        }
        try handle.seek(toOffset: UInt64(max(0, offset)))
        try handle.write(contentsOf: data)
    }

    public func read(_ nodeID: UInt64, offset: Int64, length: Int) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: nodeID)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, offset)))
        return try handle.read(upToCount: max(0, length)) ?? Data()
    }

    public func resize(_ nodeID: UInt64, to newSize: Int64) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: nodeID)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(max(0, newSize)))
    }

    public func remove(_ nodeID: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL(for: nodeID))
    }
}

/// Extended attribute (`xattr`) sidecar store supporting Finder tags, `com.apple.FinderInfo`, and resource forks.
public final class XattrStore: @unchecked Sendable {
    public static let finderInfoName = "com.apple.FinderInfo"
    public static let quarantineName = "com.apple.quarantine"
    public static let resourceForkName = "com.apple.ResourceFork"

    public enum SetPolicy: Sendable {
        case always
        case create
        case replace
    }

    public let root: URL
    private let lock = NSLock()

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func fileURL(for nodeID: UInt64) -> URL {
        root.appendingPathComponent("xattr_\(nodeID).json")
    }

    private func loadMapLocked(_ nodeID: UInt64) -> [String: Data] {
        guard let raw = try? Data(contentsOf: fileURL(for: nodeID)),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: raw) else {
            return [:]
        }
        return decoded
    }

    private func saveMapLocked(_ map: [String: Data], for nodeID: UInt64) throws {
        let url = fileURL(for: nodeID)
        if map.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else {
            let encoded = try JSONEncoder().encode(map)
            try encoded.write(to: url, options: .atomic)
        }
    }

    public func names(of nodeID: UInt64) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(loadMapLocked(nodeID).keys).sorted()
    }

    public func get(_ name: String, of nodeID: UInt64) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let value = loadMapLocked(nodeID)[name] else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOATTR))
        }
        return value
    }

    public func set(_ name: String, to data: Data, of nodeID: UInt64, policy: SetPolicy = .always) throws {
        lock.lock()
        defer { lock.unlock() }
        var map = loadMapLocked(nodeID)
        switch policy {
        case .create:
            if map[name] != nil {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EEXIST))
            }
        case .replace:
            if map[name] == nil {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOATTR))
            }
        case .always:
            break
        }
        map[name] = data
        try saveMapLocked(map, for: nodeID)
    }

    public func remove(_ name: String, of nodeID: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        var map = loadMapLocked(nodeID)
        guard map.removeValue(forKey: name) != nil else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOATTR))
        }
        try saveMapLocked(map, for: nodeID)
    }
}

public enum SearchKind: String, CaseIterable, Sendable {
    case all
    case folders
    case documents
    case photos
    case videos
    case audio

    public static func classify(name: String, isFolder: Bool) -> SearchKind {
        if isFolder { return .folders }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mov", "mp4", "m4v", "mkv", "avi", "webm", "prores":
            return .videos
        case "jpg", "jpeg", "png", "heic", "gif", "webp", "tiff", "raw", "dng", "svg":
            return .photos
        case "wav", "mp3", "m4a", "flac", "aac", "aiff", "ogg":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf", "pages", "numbers", "key", "csv":
            return .documents
        default:
            return .all
        }
    }
}

public struct SearchResult: Equatable, Identifiable, Sendable {
    public var id: UInt64 { node.id }
    public let node: DriveNode
    public let folders: [String]
    public let score: Int

    public init(node: DriveNode, folders: [String], score: Int) {
        self.node = node
        self.folders = folders
        self.score = score
    }
}

/// Instant in-memory search index over `DriveTree` for the `⌃⌥O` floating search panel.
public final class SearchIndex: @unchecked Sendable {
    public let tree: DriveTree

    public init(tree: DriveTree) {
        self.tree = tree
    }

    public func search(_ query: String, kind: SearchKind = .all, limit: Int = 25) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let nodes = tree.allNodes().filter { $0.id != DriveNode.rootID }

        var matches: [SearchResult] = []
        for node in nodes {
            if kind != .all {
                let nodeKind = SearchKind.classify(name: node.name, isFolder: node.isFolder)
                if nodeKind != kind { continue }
            }

            let lowerName = node.name.lowercased()
            let score: Int
            if trimmed.isEmpty {
                score = 1
            } else if lowerName == trimmed {
                score = 100
            } else if lowerName.hasPrefix(trimmed) {
                score = 80
            } else if lowerName.contains(trimmed) {
                score = 50
            } else {
                continue
            }

            var path = tree.folderPath(of: node.id)
            if !path.isEmpty {
                path.removeLast()
            }
            matches.append(SearchResult(node: node, folders: path, score: score))
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.node.modifiedAt > rhs.node.modifiedAt
            }
            .prefix(max(1, limit))
            .map { $0 }
    }
}
