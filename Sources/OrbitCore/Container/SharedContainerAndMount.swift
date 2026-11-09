import Foundation

/// App Group shared container (`group.com.cogify.helium`) and Darwin notification bus connecting `Helium` (`HeliumApp`), `OrbitFS`, and `OrbitFinder`.
public enum SharedContainer: Sendable {
    public static let appGroupID = "group.com.cogify.helium"
    public static let mountPointPath = "/Volumes/Helium"
    public static let legacyMountPointPath = "/Volumes/Helium"
    public static let mountHelperMachServiceName = "com.cogify.helium.MountHelper"

    public static func directoryURL() -> URL {
        // Use ~/Library/Application Support/Helium directly instead of ~/Library/Group Containers/
        // so macOS Sequoia TCC never repeatedly prompts "Helium would like to access data from other apps".
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let heliumDir = appSupport.appendingPathComponent("Helium", isDirectory: true)
        try? FileManager.default.createDirectory(at: heliumDir, withIntermediateDirectories: true)
        return heliumDir
    }

    public static func postDarwinNotification(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }
}

public struct CacheSettings: Codable, Equatable, Sendable {
    public var limitBytes: Int64

    public init(limitBytes: Int64 = 10 * 1_073_741_824) {
        self.limitBytes = limitBytes
    }
}

public struct UploadSettings: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case automaticPolite
        case manualCap
        case unlimited
    }

    public var mode: Mode
    public var manualCapBytesPerSec: Int64

    public init(mode: Mode = .automaticPolite, manualCapBytesPerSec: Int64 = 10 * 1_048_576) {
        self.mode = mode
        self.manualCapBytesPerSec = manualCapBytesPerSec
    }
}

/// Tracks files/folders pinned for offline availability ("Keep on this Mac").
public final class KeepList: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var keptRemoteIDs: Set<String> = []

    public init(fileURL: URL = SharedContainer.directoryURL().appendingPathComponent("keep-list.json")) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.keptRemoteIDs = loaded
        }
    }

    public func all() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return keptRemoteIDs
    }

    public func isKept(_ remoteID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return keptRemoteIDs.contains(remoteID)
    }

    public func setKept(_ remoteID: String, kept: Bool) {
        lock.lock()
        if kept {
            keptRemoteIDs.insert(remoteID)
        } else {
            keptRemoteIDs.remove(remoteID)
        }
        let snapshot = keptRemoteIDs
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
        SharedContainer.postDarwinNotification("com.cogify.helium.keep.changed")
    }
}

/// XPC protocol exported by `OrbitMountHelper` for mounting and unmounting the FSKit volume at `/Volumes/Helium`.
@objc(MountHelperProtocol)
public protocol MountHelperProtocol {
    func mount(mountPoint: String, ready: @escaping @Sendable (String?) -> Void)
    func unmount(mountPoint: String, force: Bool, reply: @escaping @Sendable (String?) -> Void)
    func version(reply: @escaping @Sendable (Int) -> Void)
}
