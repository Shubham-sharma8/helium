import Darwin
import Foundation
import OrbitCore
import UniformTypeIdentifiers

// MARK: - Virtual File Entry

public struct HeliumVFSEntry: Sendable {
    public var inode: UInt64
    public var parentInode: UInt64
    public var name: String
    public var remoteID: String?
    public var isDirectory: Bool
    public var sizeBytes: Int64
    public var isKeptOffline: Bool
    public var keptDownloadedBytes: Int64
    public var createdAt: Date
    public var modifiedAt: Date
    public var stagedLocalURL: URL?
}

// MARK: - Real-Time 1 MiB Chunk-Streaming HTTP 206 Range Server & Cache Engine

/// Provides real-time 1 MiB on-demand chunk downloading, read-ahead prefetching, and an in-process HTTP 1.1 `206 Partial Content`
/// byte-range streaming server (`http://127.0.0.1:<port>/stream/<remoteID>/<fileName>`) for instant video/audio playback and scrubbing
/// while `/Volumes/Helium` is mounted as a native Local APFS Volume (`Helium` in Finder Sidebar, `Zero bytes on disk` for cloud files).
public final class HeliumRealtimeVFSServer: @unchecked Sendable {
    public static let shared = HeliumRealtimeVFSServer()

    public static let chunkSize: Int = 1_048_576 // 1 MiB real-time streaming chunks
    public static let chunkSizeBytes: Int = 1_048_576 // 1 MiB real-time streaming chunks

    private let lock = NSLock()
    private var entriesByRemoteID: [String: HeliumVFSEntry] = [:]
    private var entriesByName: [String: HeliumVFSEntry] = [:]
    private var totalPoolCapacityBytes: UInt64 = 11_000_000_000_000
    private var freePoolCapacityBytes: UInt64 = 10_950_000_000_000

    private var listenSocket: Int32 = -1
    public private(set) var listeningPort: UInt16 = 0
    private var isRunning: Bool = false
    private var inFlightChunkTasks: Set<String> = []

    public let realtimeChunksRootURL: URL
    public let offlinePinnedRootURL: URL
    public let stagingRootURL: URL

    private init() {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory

        self.realtimeChunksRootURL = caches.appendingPathComponent("Helium/RealtimeChunks", isDirectory: true)
        self.stagingRootURL = caches.appendingPathComponent("Helium/Staging", isDirectory: true)
        self.offlinePinnedRootURL = appSupport.appendingPathComponent("Helium/OfflinePinned", isDirectory: true)

        try? fm.createDirectory(at: realtimeChunksRootURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: offlinePinnedRootURL, withIntermediateDirectories: true)

        startServerIfNeeded()
    }

    // MARK: - Synchronize Snapshot from AppModel

    public func updateCatalog(
        manifests: [String: PoolItemManifest],
        pinnedFilenames: Set<String>,
        offlineDownloadBytesByName: [String: Int64],
        totalPoolBytes: Int64,
        freePoolBytes: Int64
    ) {
        updateCatalog(
            manifests: manifests,
            pinnedNames: pinnedFilenames,
            pinnedProgressByName: offlineDownloadBytesByName,
            totalPoolBytes: totalPoolBytes,
            freePoolBytes: freePoolBytes
        )
    }

    public func updateCatalog(
        manifests: [String: PoolItemManifest],
        pinnedNames: Set<String>,
        pinnedProgressByName: [String: Int64],
        totalPoolBytes: Int64,
        freePoolBytes: Int64
    ) {
        lock.withLock {
            if totalPoolBytes > 0 {
                self.totalPoolCapacityBytes = UInt64(totalPoolBytes)
                self.freePoolCapacityBytes = UInt64(max(0, freePoolBytes))
            }

            var byRemote: [String: HeliumVFSEntry] = [:]
            var byName: [String: HeliumVFSEntry] = [:]
            var nextIno: UInt64 = 100

            for manifest in manifests.values where !manifest.item.deleted && manifest.item.kind == .file {
                let canonicalName = manifest.item.name.precomposedStringWithCanonicalMapping
                if canonicalName.hasPrefix("pool_file_") || canonicalName.hasSuffix(".blob") {
                    continue
                }
                let isPinned = pinnedNames.contains(canonicalName) || pinnedNames.contains(manifest.item.name)
                let keptBytes = isPinned ? (pinnedProgressByName[canonicalName] ?? manifest.item.size) : 0
                let entry = HeliumVFSEntry(
                    inode: nextIno,
                    parentInode: 1,
                    name: canonicalName,
                    remoteID: manifest.item.id,
                    isDirectory: false,
                    sizeBytes: max(0, manifest.item.size),
                    isKeptOffline: isPinned,
                    keptDownloadedBytes: keptBytes,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(manifest.item.createdAt) / 1000.0),
                    modifiedAt: Date(timeIntervalSince1970: TimeInterval(manifest.item.modifiedAt) / 1000.0),
                    stagedLocalURL: nil
                )
                nextIno += 1
                byRemote[manifest.item.id] = entry
                byName[canonicalName] = entry
            }

            self.entriesByRemoteID = byRemote
            self.entriesByName = byName
        }
    }

    /// Returns the local HTTP 206 Range streaming URL (`http://127.0.0.1:<port>/stream/<remoteID>/<fileName>`) for instant video/audio streaming.
    public func streamURL(forRemoteID remoteID: String, fileName: String) -> URL? {
        startServerIfNeeded()
        guard listeningPort > 0 else { return nil }
        let encodedID = remoteID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remoteID
        let encodedName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "stream.mp4"
        return URL(string: "http://127.0.0.1:\(listeningPort)/stream/\(encodedID)/\(encodedName)")
    }

    public func ensureStartedAndMounted(at mountURL: URL) -> Bool {
        startServerIfNeeded()
        // Ensure any old 127.0.0.1 NFS mount is unmounted so Finder Sidebar never shows "127.0.0.1"
        var st = statfs()
        if statfs(mountURL.path, &st) == 0 {
            let fstype = withUnsafePointer(to: &st.f_fstypename) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                    String(cString: $0)
                }
            }
            if fstype == "nfs" {
                _ = Darwin.unmount(mountURL.path, MNT_FORCE)
            }
        }
        return listeningPort > 0
    }

    // MARK: - Loopback HTTP 1.1 206 Partial Content Byte-Range Server

    public func startServerIfNeeded() {
        lock.lock()
        if isRunning && listenSocket >= 0 && listeningPort > 0 {
            lock.unlock()
            return
        }

        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            lock.unlock()
            return
        }
        var yes: Int32 = 1
        Darwin.setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        Darwin.setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var boundPort: UInt16 = 0
        for candidatePort in UInt16(20540) ... UInt16(20590) {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = candidatePort.bigEndian
            addr.sin_addr.s_addr = Darwin.inet_addr("127.0.0.1")
            let res = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if res == 0 {
                boundPort = candidatePort
                break
            }
        }

        guard boundPort > 0, Darwin.listen(sock, 32) == 0 else {
            Darwin.close(sock)
            lock.unlock()
            return
        }

        self.listenSocket = sock
        self.listeningPort = boundPort
        self.isRunning = true
        lock.unlock()

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.acceptLoop(serverSocket: sock)
        }
    }

    private func acceptLoop(serverSocket: Int32) {
        while true {
            let client = Darwin.accept(serverSocket, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            var yes: Int32 = 1
            Darwin.setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            Darwin.setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &yes, socklen_t(MemoryLayout<Int32>.size))
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    Darwin.close(client)
                    return
                }
                Task {
                    await self.handleHTTPClient(client)
                }
            }
        }
    }

    private func handleHTTPClient(_ client: Int32) async {
        defer { Darwin.close(client) }
        var buf = [UInt8](repeating: 0, count: 16_384)
        let n = Darwin.read(client, &buf, buf.count)
        guard n > 0, let requestStr = String(bytes: buf.prefix(n), encoding: .utf8) else { return }

        let lines = requestStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        let method = String(parts[0]).uppercased()
        let rawPath = String(parts[1])

        // Expected path: /stream/<remoteID>/<fileName>
        let pathComponents = rawPath.split(separator: "/", omittingEmptySubsequences: true)
        guard pathComponents.count >= 2, pathComponents[0] == "stream" else {
            Self.writeAll(client, data: Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n".utf8))
            return
        }
        let remoteID = String(pathComponents[1]).removingPercentEncoding ?? String(pathComponents[1])
        let fileName = pathComponents.count >= 3
            ? (String(pathComponents[2]).removingPercentEncoding ?? String(pathComponents[2]))
            : "stream.bin"

        let entry: HeliumVFSEntry? = lock.withLock {
            entriesByRemoteID[remoteID] ?? entriesByName[fileName.precomposedStringWithCanonicalMapping]
        }
        guard let entry, entry.sizeBytes > 0 else {
            Self.writeAll(client, data: Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n".utf8))
            return
        }

        let totalSize = entry.sizeBytes
        let mimeType = Self.mimeType(for: entry.name)

        // Parse optional Range: bytes=start-end header
        var rangeStart: Int64 = 0
        var rangeEnd: Int64 = min(totalSize - 1, Int64(Self.chunkSize * 2) - 1)
        var hasRangeHeader = false

        for line in lines.dropFirst() {
            if line.lowercased().hasPrefix("range:") {
                let val = line.dropFirst("range:".count).trimmingCharacters(in: .whitespaces)
                if val.lowercased().hasPrefix("bytes=") {
                    hasRangeHeader = true
                    let spec = val.dropFirst("bytes=".count)
                    let bounds = spec.split(separator: "-", omittingEmptySubsequences: false)
                    if bounds.count == 2 {
                        let startStr = String(bounds[0]).trimmingCharacters(in: .whitespaces)
                        let endStr = String(bounds[1]).trimmingCharacters(in: .whitespaces)
                        if startStr.isEmpty, let suffixLen = Int64(endStr), suffixLen > 0 {
                            rangeStart = max(0, totalSize - suffixLen)
                            rangeEnd = totalSize - 1
                        } else if let s = Int64(startStr) {
                            rangeStart = max(0, min(totalSize - 1, s))
                            if let e = Int64(endStr) {
                                rangeEnd = max(rangeStart, min(totalSize - 1, e))
                            } else {
                                // Cap open-ended video range requests at 2 MiB (2 chunks) so AVPlayer receives immediate 206 responses and requests subsequent chunks smoothly
                                rangeEnd = min(totalSize - 1, rangeStart + Int64(Self.chunkSize * 2) - 1)
                            }
                        }
                    }
                }
                break
            }
        }

        if method == "HEAD" {
            let headers = [
                "HTTP/1.1 200 OK",
                "Content-Type: \(mimeType)",
                "Accept-Ranges: bytes",
                "Content-Length: \(totalSize)",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(client, data: Data(headers.utf8))
            return
        }

        let lengthToRead = Int(max(0, rangeEnd - rangeStart + 1))
        let payload = await readByteRange(for: entry, offset: UInt64(rangeStart), count: lengthToRead)
        let actualEnd = rangeStart + Int64(max(1, payload.count)) - 1

        if hasRangeHeader {
            let headers = [
                "HTTP/1.1 206 Partial Content",
                "Content-Type: \(mimeType)",
                "Accept-Ranges: bytes",
                "Content-Range: bytes \(rangeStart)-\(actualEnd)/\(totalSize)",
                "Content-Length: \(payload.count)",
                "Cache-Control: no-store",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(client, data: Data(headers.utf8))
            Self.writeAll(client, data: payload)
        } else {
            let headers = [
                "HTTP/1.1 200 OK",
                "Content-Type: \(mimeType)",
                "Accept-Ranges: bytes",
                "Content-Length: \(payload.count)",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(client, data: Data(headers.utf8))
            Self.writeAll(client, data: payload)
        }
    }

    private static func writeAll(_ fd: Int32, data: Data) {
        _ = data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return 0 }
            var sent = 0
            while sent < data.count {
                let w = Darwin.write(fd, base.advanced(by: sent), data.count - sent)
                if w <= 0 { break }
                sent += w
            }
            return sent
        }
    }

    private static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext),
           let mime = utType.preferredMIMEType {
            return mime
        }
        switch ext {
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mkv": return "video/x-matroska"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Real-Time 1 MiB Chunk Streaming & Read-Ahead Prefetching

    public func readByteRange(for item: HeliumVFSEntry, offset: UInt64, count: Int) async -> Data {
        guard count > 0, Int64(offset) < item.sizeBytes else { return Data() }
        let length = min(count, Int(item.sizeBytes - Int64(offset)))
        guard length > 0 else { return Data() }

        // 1. Check Offline Pinned file ("Keep on this Mac") or Stream Cache
        let offlineURL = offlinePinnedRootURL.appendingPathComponent(item.name)
        let streamURL = AppModel.streamCacheDirectoryURL.appendingPathComponent(item.name)

        for candidate in [offlineURL, streamURL] {
            if AppModel.isHydratedLocalFile(candidate),
               let fileSize = (try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize),
               Int64(fileSize) == item.sizeBytes,
               let slice = Self.preadSlice(from: candidate, offset: offset, length: length) {
                return slice
            }
        }

        // 2. Real-Time 1 MiB Chunk Streaming from Google Drive Pool!
        guard let remoteID = item.remoteID else { return Data(repeating: 0, count: length) }
        let chunkSize = Self.chunkSize
        let startByte = Int(offset)
        let endByte = startByte + length - 1
        let firstChunkIdx = startByte / chunkSize
        let lastChunkIdx = endByte / chunkSize
        let totalChunks = max(1, Int((item.sizeBytes + Int64(chunkSize) - 1) / Int64(chunkSize)))

        var assembled = Data(capacity: (lastChunkIdx - firstChunkIdx + 1) * chunkSize)
        for chunkIdx in firstChunkIdx ... lastChunkIdx {
            let chunkData = await fetchOrReadChunk(
                remoteID: remoteID,
                fileName: item.name,
                fileSize: item.sizeBytes,
                chunkIndex: chunkIdx,
                totalChunks: totalChunks
            )
            assembled.append(chunkData)
        }

        // Trigger non-blocking read-ahead prefetch for next chunk (smooth video playback & scrubbing!)
        let nextChunkIdx = lastChunkIdx + 1
        if nextChunkIdx < totalChunks {
            Task.detached(priority: .utility) { [weak self] in
                _ = await self?.fetchOrReadChunk(
                    remoteID: remoteID,
                    fileName: item.name,
                    fileSize: item.sizeBytes,
                    chunkIndex: nextChunkIdx,
                    totalChunks: totalChunks,
                    isPrefetch: true
                )
            }
        }

        let relativeStart = startByte - (firstChunkIdx * chunkSize)
        guard relativeStart >= 0, relativeStart < assembled.count else {
            return Data()
        }
        let relativeEnd = min(assembled.count, relativeStart + length)
        return assembled.subdata(in: relativeStart ..< relativeEnd)
    }

    public func fetchOrReadChunk(
        remoteID: String,
        fileName: String,
        fileSize: Int64,
        chunkIndex: Int,
        totalChunks: Int,
        isPrefetch: Bool = false
    ) async -> Data {
        let chunkSize = Self.chunkSize
        let chunkStart = Int64(chunkIndex) * Int64(chunkSize)
        guard chunkStart < fileSize else { return Data() }
        let expectedLen = Int(min(Int64(chunkSize), fileSize - chunkStart))

        let safeID = remoteID.replacingOccurrences(of: "/", with: "_")
        let itemChunkDir = realtimeChunksRootURL.appendingPathComponent(safeID, isDirectory: true)
        let chunkFileURL = itemChunkDir.appendingPathComponent("chunk_\(chunkIndex).bin")

        if let existingSize = try? chunkFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           existingSize == expectedLen,
           let cachedData = try? Data(contentsOf: chunkFileURL) {
            if !isPrefetch {
                Task { @MainActor in
                    AppModel.shared?.recordRealtimeChunkRead(
                        fileName: fileName,
                        chunkIndex: chunkIndex,
                        totalChunks: totalChunks,
                        bytesCount: expectedLen,
                        fromCache: true
                    )
                }
            }
            return cachedData
        }

        let taskKey = "\(safeID)::\(chunkIndex)"
        if isPrefetch {
            let alreadyInFlight: Bool = lock.withLock {
                let exists = inFlightChunkTasks.contains(taskKey)
                if !exists {
                    inFlightChunkTasks.insert(taskKey)
                }
                return exists
            }
            if alreadyInFlight { return Data() }
        }
        defer {
            if isPrefetch {
                _ = lock.withLock {
                    inFlightChunkTasks.remove(taskKey)
                }
            }
        }

        guard let model = await MainActor.run(body: { AppModel.shared }) else {
            return Data(repeating: 0, count: expectedLen)
        }

        do {
            let data = try await model.fetchRealtimeChunkFromPool(
                remoteID: remoteID,
                offset: chunkStart,
                length: expectedLen
            )
            try? FileManager.default.createDirectory(at: itemChunkDir, withIntermediateDirectories: true)
            try? data.write(to: chunkFileURL, options: .atomic)
            if !isPrefetch {
                Task { @MainActor in
                    AppModel.shared?.recordRealtimeChunkRead(
                        fileName: fileName,
                        chunkIndex: chunkIndex,
                        totalChunks: totalChunks,
                        bytesCount: data.count,
                        fromCache: false
                    )
                }
            }
            return data
        } catch {
            return Data(repeating: 0, count: expectedLen)
        }
    }

    public func cachedChunkIndices(forRemoteID remoteID: String, totalChunks: Int) -> Set<Int> {
        let safeID = remoteID.replacingOccurrences(of: "/", with: "_")
        let itemChunkDir = realtimeChunksRootURL.appendingPathComponent(safeID, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: itemChunkDir.path) else { return [] }
        var indices = Set<Int>()
        for idx in 0 ..< max(0, totalChunks) {
            let chunkURL = itemChunkDir.appendingPathComponent("chunk_\(idx).bin")
            if fm.fileExists(atPath: chunkURL.path) {
                indices.insert(idx)
            }
        }
        return indices
    }

    public func clearUnpinnedRealtimeChunks(pinnedFilenames: Set<String> = [], keepingRemoteIDs: Set<String> = []) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: realtimeChunksRootURL, includingPropertiesForKeys: nil) else {
            return
        }
        var keepIDs = keepingRemoteIDs
        lock.withLock {
            for entry in entriesByRemoteID.values where entry.isKeptOffline || pinnedFilenames.contains(entry.name) {
                if let remID = entry.remoteID {
                    keepIDs.insert(remID)
                }
            }
        }
        let safeKeep = Set(keepIDs.map { $0.replacingOccurrences(of: "/", with: "_") })
        for dir in dirs where !safeKeep.contains(dir.lastPathComponent) {
            try? fm.removeItem(at: dir)
        }
    }

    private static func preadSlice(from fileURL: URL, offset: UInt64, length: Int) -> Data? {
        let fd = Darwin.open(fileURL.path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { Darwin.close(fd) }
        var buf = [UInt8](repeating: 0, count: length)
        let n = Darwin.pread(fd, &buf, length, off_t(offset))
        guard n > 0 else { return nil }
        return Data(bytes: buf, count: n)
    }
}
