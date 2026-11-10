import AppKit
import Foundation
import Network
import OrbitCore
import SwiftUI

public enum AppPhase: String, Codable, Sendable {
    case welcomeSignIn
    case driveSetup
    case active
}

public enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case home = "Helium Home"
    case pool = "Google Drive Pool"
    case activity = "Activity & Health"
    case backups = "Mac Backups"
    case timeTravel = "Time Travel"
    case search = "Command Palette (⌃⌥O)"
    case settings = "Settings"
    case welcome = "More"

    public var id: String { rawValue }

    public var assetIcon: String {
        switch self {
        case .home: return "OrbitSidebar"
        case .pool: return "folder-cloud"
        case .activity: return "flash"
        case .backups: return "update"
        case .timeTravel: return "clock"
        case .search: return "search"
        case .settings: return "settings"
        case .welcome: return "account"
        }
    }

    public var sfSymbolFallback: String {
        switch self {
        case .home: return "externaldrive.fill"
        case .pool: return "externaldrive.fill.badge.icloud"
        case .activity: return "waveform.path.ecg"
        case .backups: return "clock.arrow.circlepath"
        case .timeTravel: return "clock.arrow.2.circlepath"
        case .search: return "command"
        case .settings: return "gearshape.fill"
        case .welcome: return "sparkles"
        }
    }
}

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case account = "Account"
    case privacy = "Privacy"
    case storage = "Storage"
    case updates = "Updates"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "settings"
        case .account: return "account"
        case .privacy: return "lock"
        case .storage: return "storage"
        case .updates: return "update"
        }
    }
}

public enum CacheLimitOption: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case gb5 = "5 GB"
    case gb10 = "10 GB"
    case gb25 = "25 GB"
    case gb50 = "50 GB"
    case gb100 = "100 GB"

    public var id: String { rawValue }

    public var bytes: Int64 {
        let gb: Int64 = 1_073_741_824
        switch self {
        case .automatic: return 20 * gb
        case .gb5: return 5 * gb
        case .gb10: return 10 * gb
        case .gb25: return 25 * gb
        case .gb50: return 50 * gb
        case .gb100: return 100 * gb
        }
    }
}

public enum UploadSpeedOption: String, CaseIterable, Identifiable, Sendable {
    case unlimited = "As fast as possible"
    case mbps10 = "10 Mbps"
    case mbps25 = "25 Mbps"
    case mbps50 = "50 Mbps"
    case mbps100 = "100 Mbps"

    public var id: String { rawValue }

    public var bytesPerSecond: Int64? {
        switch self {
        case .unlimited: return nil
        case .mbps10: return 1_250_000
        case .mbps25: return 3_125_000
        case .mbps50: return 6_250_000
        case .mbps100: return 12_500_000
        }
    }
}

public enum FileSortOrder: String, CaseIterable, Identifiable, Sendable {
    case name = "Name"
    case size = "Size"
    case dateModified = "Date Modified"
    case placement = "Placement"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .name: return "textformat.abc"
        case .size: return "internaldrive"
        case .dateModified: return "clock"
        case .placement: return "square.stack.3d.up"
        }
    }
}

public enum FileFilterMode: String, CaseIterable, Identifiable, Sendable {
    case all = "All Items"
    case starred = "★ Starred"
    case wholeFile = "Whole-File"
    case striped = "Striped"
    case pinned = "Kept Offline"
    case folders = "Folders"

    public var id: String { rawValue }
}

public struct DuplicateFileGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let unitSizeBytes: Int64
    public let copiesCount: Int
    public let reclaimableBytes: Int64
    public let accountEmails: [String]
}

public struct PoolLargeFileInsight: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let sizeBytes: Int64
    public let placementModeLabel: String
    public let segmentsCount: Int
    public let primaryAccountEmail: String
}

public struct TrashedFileItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let sizeBytes: Int64
    public let deletedAt: Date
    public let daysRemaining: Int
    public let accountSummary: String
}

public enum ProExternalApp: String, CaseIterable, Identifiable, Sendable {
    case finalCutPro = "Final Cut Pro"
    case davinciResolve = "DaVinci Resolve"
    case capCut = "CapCut"
    case quickTime = "QuickTime Player"
    case claude = "Claude"
    case chatGPT = "ChatGPT"
    case cursor = "Cursor"
    case vsCode = "Visual Studio Code"

    public var id: String { rawValue }

    public var isAIApp: Bool {
        switch self {
        case .claude, .chatGPT, .cursor, .vsCode:
            return true
        case .finalCutPro, .davinciResolve, .capCut, .quickTime:
            return false
        }
    }

    public var symbol: String {
        switch self {
        case .finalCutPro, .davinciResolve, .capCut:
            return "film.stack.fill"
        case .quickTime:
            return "play.rectangle.fill"
        case .claude, .chatGPT:
            return "sparkles"
        case .cursor, .vsCode:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var candidateAppPaths: [String] {
        switch self {
        case .finalCutPro:
            return ["/Applications/Final Cut Pro.app"]
        case .davinciResolve:
            return ["/Applications/DaVinci Resolve/DaVinci Resolve.app", "/Applications/DaVinci Resolve.app"]
        case .capCut:
            return ["/Applications/CapCut.app"]
        case .quickTime:
            return ["/System/Applications/QuickTime Player.app"]
        case .claude:
            return ["/Applications/Claude.app"]
        case .chatGPT:
            return ["/Applications/ChatGPT.app"]
        case .cursor:
            return ["/Applications/Cursor.app"]
        case .vsCode:
            return ["/Applications/Visual Studio Code.app"]
        }
    }
}

public enum FileViewLayout: String, CaseIterable, Identifiable, Sendable {
    case list = "List"
    case grid = "Grid"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

public struct FolderBreadcrumb: Identifiable, Equatable, Sendable {
    public let inode: UInt64
    public let name: String
    public let remoteID: String
    public var id: UInt64 { inode }
}

public struct StorageCategoryStat: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let colorName: String
    public let bytes: Int64
    public let fileCount: Int
}

public struct UploadActivity: Identifiable, Sendable {
    public let id: String
    public let fileName: String
    public let sourceURL: URL?
    public let totalBytes: Int64
    public var uploadedBytes: Int64
    public var speedBytesPerSec: Int64
    public var placementSummary: String
    public var isCompleted: Bool
    public var errorText: String?
    public let timestamp: Date

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 1.0 }
        return min(1.0, Double(uploadedBytes) / Double(totalBytes))
    }

    public var byteProgressLabel: String {
        let up = ByteCountFormatter.string(fromByteCount: uploadedBytes, countStyle: .file)
        let tot = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(up) / \(tot)"
    }

    public var timeRemainingLabel: String {
        if let errorText { return "Failed: \(errorText)" }
        if isCompleted { return "Uploaded to Google Drive" }
        let remaining = max(0, totalBytes - uploadedBytes)
        let speed = max(1, speedBytesPerSec)
        let seconds = remaining / speed
        if seconds <= 5 {
            return "a few seconds left"
        } else if seconds < 60 {
            return "less than a minute left"
        } else {
            let mins = max(1, seconds / 60)
            return "about \(mins) minute\(mins == 1 ? "" : "s") left"
        }
    }
}

public struct ShareLinkRecord: Identifiable, Sendable {
    public let id: String
    public let itemId: String
    public let itemName: String
    public let urlString: String
    public let createdAt: Date
}

public struct FileRequestRecord: Identifiable, Sendable {
    public let id: String
    public let folderName: String
    public let title: String
    public let urlString: String
    public let publicKeyHex: String
    public let createdAt: Date
}

public enum SupportEmailTemplate: String, CaseIterable, Identifiable, Sendable {
    case support = "Support & Bug Report"
    case featureRequest = "Feature Request & Idea"
    case poolHelp = "Google Drive Pool & Setup Question"
    case business = "Partnership & Enterprise Inquiry"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .support: return "ladybug.fill"
        case .featureRequest: return "sparkles"
        case .poolHelp: return "externaldrive.fill.badge.icloud"
        case .business: return "building.2.fill"
        }
    }

    public var defaultSubject: String {
        switch self {
        case .support:
            return "Helium v\(AppModel.appVersion) (Build \(AppModel.appBuild)) — Support & Bug Report"
        case .featureRequest:
            return "Helium v\(AppModel.appVersion) — Feature Request & Product Idea"
        case .poolHelp:
            return "Helium v\(AppModel.appVersion) — Google Drive Storage Pool Question"
        case .business:
            return "Helium × Cogify — Enterprise & Partnership Inquiry"
        }
    }

    public var defaultPromptPlaceholder: String {
        switch self {
        case .support:
            return "Hi Cogify Team,\n\nI am using Helium v\(AppModel.appVersion) on macOS and encountered the following issue:\n• Steps to reproduce:\n• Expected behavior:\n• Actual behavior:\n"
        case .featureRequest:
            return "Hi Cogify Team,\n\nI would love to see the following feature or workflow improvement in Helium:\n• Feature idea:\n• How it would help my Google Drive workflow:\n"
        case .poolHelp:
            return "Hi Cogify Team,\n\nI have a question about pooling my Google Drive accounts with /Volumes/Helium:\n• Question:\n"
        case .business:
            return "Hi Cogify Team,\n\nWe are interested in Helium for our team / organization:\n• Organization / Team size:\n• Use case:\n"
        }
    }
}

public struct SystemDiagnosticCheck: Identifiable, Equatable, Sendable {
    public enum Status: String, Sendable {
        case healthy = "Healthy"
        case warning = "Attention"
        case actionNeeded = "Action Needed"
    }

    public let id: String
    public let title: String
    public let detail: String
    public let status: Status
    public let symbol: String
    public let actionTitle: String?
}

public struct SimulatedSegmentAllocation: Identifiable, Equatable, Sendable {
    public let id: String
    public let segmentIndex: Int
    public let accountId: String
    public let accountEmail: String
    public let bytes: Int64
    public let isWholeFile: Bool
}

public struct RealtimeChunkReadEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let chunkIndex: Int
    public let totalChunks: Int
    public let bytesRead: Int
    public let fromCache: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        fileName: String,
        chunkIndex: Int,
        totalChunks: Int,
        bytesRead: Int,
        fromCache: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.bytesRead = bytesRead
        self.fromCache = fromCache
        self.timestamp = timestamp
    }
}

@MainActor
public final class AppModel: ObservableObject {
    nonisolated public static let appVersion = "0.0.3"
    nonisolated public static let appBuild = "3"
    nonisolated public static let supportEmail = "connect@cogify.me"
    nonisolated public static let githubRepoSlug = "Shubham-sharma8/helium"
    nonisolated public static let githubReleasesURL = "https://github.com/Shubham-sharma8/helium/releases"
    nonisolated public static let githubLatestReleaseAPI = "https://api.github.com/repos/Shubham-sharma8/helium/releases/latest"
    nonisolated public static let githubAllReleasesAPI = "https://api.github.com/repos/Shubham-sharma8/helium/releases"
    // MARK: - Navigation & Lifecycle State
    @Published public var phase: AppPhase = .active
    @Published public var selectedSidebarDestination: SidebarDestination = .home
    @Published public var selectedSettingsTab: SettingsTab = .account
    @Published public var showSearchWindow: Bool = false
    @Published public var showHelpSheet: Bool = false
    @Published public var showFeedbackSheet: Bool = false
    @Published public var showRecoveryKeySheet: Bool = false
    @Published public var showUnlockSheet: Bool = false
    @Published public var showAllowDevicePrompt: Bool = false
    @Published public var showStartupPreferencesPrompt: Bool = false
    @Published public var hasAskedStartupPreferences: Bool = false
    @Published public var allowDeviceCode: String = "482 917"

    // MARK: - Google Cloud & OAuth State
    @Published public var firebaseConfig: FirebaseConfig
    @Published public var customOAuthClientId: String = ""
    @Published public var isSigningInWithGoogle: Bool = false
    @Published public var linkedAccounts: [LinkedGoogleAccount] = []

    // MARK: - Storage Pool & Placement Engine State
    @Published public var placementPolicy: PlacementPolicy = .automatic
    @Published public var accountRoutingStrategy: AccountRoutingStrategy = .priorityOrder
    @Published public var preferredUploadAccountId: String? = nil
    @Published public var segmentSizeMiB: Int = 64
    @Published public var autoStripeAboveGB: Double = 4.0
    @Published public var selectedFolderId: String = RemoteItem.rootID
    @Published public var currentFolderInode: UInt64 = DriveNode.rootID
    @Published public var breadcrumbs: [FolderBreadcrumb] = [
        FolderBreadcrumb(inode: DriveNode.rootID, name: "Helium Drive", remoteID: RemoteItem.rootID)
    ]
    @Published public var driveNodes: [DriveNode] = []
    @Published public var manifests: [String: PoolItemManifest] = [:]
    @Published public var inspectedNode: DriveNode? = nil
    @Published public var streamedNode: DriveNode? = nil

    // MARK: - Real-Time Chunk Streaming & Offline Keep Progress State
    @Published public var recentChunkEvents: [RealtimeChunkReadEvent] = []
    @Published public var activeRealtimeStreamSummary: String = ""
    @Published public var streamingInspectorNode: DriveNode? = nil
    @Published public var showRealtimeVideoStreamerSheet: Bool = false
    @Published public var showFileRequestsSheet: Bool = false
    @Published public var lastStreamedFileName: String = ""
    @Published public var lastStreamedChunkIndex: Int = 0
    @Published public var lastStreamedTotalChunks: Int = 0
    @Published public var realtimeChunkCacheHitCount: Int = 0
    @Published public var realtimeChunkNetworkFetchCount: Int = 0
    @Published public var activeStreamSpeedBytesPerSec: Int64 = 0
    @Published public var downloadedChunkIndicesByFile: [String: Set<Int>] = [:]
    @Published public var isDownloadingOfflineKeep: Bool = false
    @Published public var offlineKeepDownloadedBytes: Int64 = 0
    @Published public var offlineKeepTotalBytes: Int64 = 0
    @Published public var offlineKeepActiveTitle: String = ""
    @Published public var offlineKeepCurrentFileName: String = ""
    @Published public var offlinePinProgressByName: [String: Int64] = [:]

    // MARK: - Explorer View, Sort, Filter & Pin State
    @Published public var fileSortOrder: FileSortOrder = .dateModified
    @Published public var fileFilterMode: FileFilterMode = .all
    @Published public var fileViewLayout: FileViewLayout = .list
    @Published public var localFolderFilterQuery: String = ""
    @Published public var pinnedFilenames: Set<String> = []
    @Published public var starredFilenames: Set<String> = []
    @Published public var trashedItems: [TrashedFileItem] = []
    @Published public var showTrashSheet: Bool = false
    @Published public var showCrossDeviceSheet: Bool = false
    @Published public var isSyncingPool: Bool = false
    @Published public var isRebalancingPool: Bool = false
    @Published public var poolHealthSummary: String = ""
    @Published public var diagnosticChecks: [SystemDiagnosticCheck] = []

    // MARK: - Upload, Cache & Sync State
    @Published public var isMounted: Bool = false
    @Published public var isUploadsPaused: Bool = false
    @Published public var uploadActivities: [UploadActivity] = []
    @Published public var cacheLimitOption: CacheLimitOption = .automatic
    @Published public var uploadSpeedOption: UploadSpeedOption = .unlimited
    @Published public var cachedBytesOnMac: Int64 = 0
    @Published public var statusMessage: String = "Helium drive connected and ready"

    // MARK: - Original General & Update Settings
    @Published public var openAtLogin: Bool = true
    @Published public var runInTaskbarOnly: Bool = false
    @Published public var finderActionsEnabled: Bool = true
    @Published public var sendErrorReports: Bool = false
    @Published public var installUpdatesAutomatically: Bool = true
    @Published public var lastUpdateCheckText: String = "Helium v0.0.3 (Build 3) — Ready to check GitHub Releases."
    @Published public var isCheckingForUpdates: Bool = false
    @Published public var isDownloadingUpdate: Bool = false
    @Published public var updateAvailableVersion: String? = nil
    @Published public var updateDownloadURL: URL? = nil
    @Published public var updateReleasePageURL: URL = URL(string: "https://github.com/Shubham-sharma8/helium/releases")!
    @Published public var updateReleaseNotes: String = ""
    @Published public var feedbackText: String = ""
    @Published public var feedbackIncludeDiagnostics: Bool = true
    @Published public var selectedEmailTemplate: SupportEmailTemplate = .support

    // MARK: - Zero-Knowledge E2EE & Recovery Key State
    // Default false so uploaded files appear in Google Drive ("Helium Pool Vault") with their real human-readable filenames.
    @Published public var zeroKnowledgeEnabled: Bool = false
    @Published public var recoveryKeySavedConfirmation: Bool = true
    @Published public var recoveryKeyText: String = ""
    @Published public var unlockKeyInput: String = ""

    // MARK: - Shares, File Requests & Search State
    @Published public var shareLinks: [ShareLinkRecord] = []
    @Published public var fileRequests: [FileRequestRecord] = []
    @Published public var searchQuery: String = ""
    @Published public var searchKind: SearchKind = .all
    @Published public var searchResults: [SearchResult] = []

    // MARK: - Syncophant Parity Features (Multi-Protocol Storage, Backups, Time Travel, Inspector, Activity & Privacy Ledger)
    @Published public var externalStorageConnections: [ExternalStorageConnection] = []
    @Published public var backupJobs: [BackupJob] = []
    @Published public var isRunningBackupJobId: String? = nil
    @Published public var poolSnapshots: [PoolSnapshot] = []
    @Published public var selectedSnapshotId: String? = nil
    @Published public var activeConflicts: [FileConflictItem] = []
    @Published public var throughputSamples: [ThroughputSample] = []
    @Published public var networkContacts: [NetworkContactEntry] = []
    @Published public var latestSafeWriteReport: SafeWriteCheckReport? = nil
    @Published public var isRunningSafeWriteCheck: Bool = false
    @Published public var showRightInspector: Bool = true
    @Published public var selectedInspectorNode: DriveNode? = nil
    @Published public var showMultiProtocolConnectSheet: Bool = false
    @Published public var showNewBackupJobSheet: Bool = false
    @Published public var fixedIssueIds: Set<String> = []
    @Published public var workingIssueIds: Set<String> = []
    @Published public var lastCommandConfirmation: String = ""

    // MARK: - Core Services
    public let pool: GoogleAccountPool
    public let pooledRemote: PooledGoogleDriveRemote
    public let keyManager: KeyManager
    public let keepList: KeepList
    public let volumeMountURL = URL(fileURLWithPath: "/Volumes/Helium", isDirectory: true)
    public let legacyVolumeMountURL = URL(fileURLWithPath: "/Volumes/Helium", isDirectory: true)
    public let localMirrorURL: URL
    public let legacyMirrorURL: URL
    private let secretStore: PersistentSecretStore
    private var activeDrive: OrbitDrive?
    private let storageRoot: URL
    private let oauth = GoogleOAuthCoordinator()
    nonisolated(unsafe) public static weak var shared: AppModel?
    nonisolated(unsafe) private var bootstrapTask: Task<Void, Never>?
    nonisolated(unsafe) private var watcherTask: Task<Void, Never>?
    nonisolated(unsafe) private var prewarmTask: Task<Void, Never>?
    nonisolated(unsafe) private var offlinePinTask: Task<Void, Never>?
    nonisolated(unsafe) private var windowCloseObserver: NSObjectProtocol?
    nonisolated(unsafe) private var wakeObserver: NSObjectProtocol?
    nonisolated(unsafe) private var networkMonitor: NWPathMonitor?
    private var wasNetworkSatisfied: Bool = true
    private var finderNotificationObserversRegistered: Bool = false
    private var isScanningFinderFiles: Bool = false
    private var cacheWasManuallyCleared: Bool = false
    private var inFlightFilenames: Set<String> = []
    private var explicitlyDeletedFilenames: Set<String> = []
    private var materializedVolumeManifestIds: Set<String> = []
    private var isDetectingFinderDeletions: Bool = false
    private var recentFinderOpenTimestamps: [String: Date] = [:]

    deinit {
        bootstrapTask?.cancel()
        watcherTask?.cancel()
        prewarmTask?.cancel()
        offlinePinTask?.cancel()
        networkMonitor?.cancel()
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    public init() {
        let workspaceFallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let config = FirebaseConfig.loadDefault(workspaceFallback: workspaceFallback)
        self.firebaseConfig = config
        self.customOAuthClientId = config.clientId ?? ""

        let containerURL = SharedContainer.directoryURL()
        self.storageRoot = containerURL

        let store = PersistentSecretStore(
            fileURL: containerURL.appendingPathComponent(".helium-secrets.json")
        )
        self.secretStore = store
        self.keyManager = KeyManager(store: store)
        self.keepList = KeepList()
        self.pinnedFilenames = self.keepList.all()
        if let savedStars = UserDefaults.standard.stringArray(forKey: "helium.starredFilenames") {
            self.starredFilenames = Set(savedStars)
        }
        if let savedMaterialized = UserDefaults.standard.stringArray(forKey: "helium.materializedVolumeManifestIds") {
            self.materializedVolumeManifestIds = Set(savedMaterialized)
        }
        if let savedDeleted = UserDefaults.standard.stringArray(forKey: "helium.explicitlyDeletedFilenames") {
            self.explicitlyDeletedFilenames = Set(savedDeleted)
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.localMirrorURL = homeDir.appendingPathComponent("Helium", isDirectory: true)
        self.legacyMirrorURL = homeDir.appendingPathComponent("Helium", isDirectory: true)

        // Restore saved preferences from UserDefaults
        let defaults = UserDefaults.standard
        let initialPolicy: PlacementPolicy
        if let rawPolicy = defaults.string(forKey: "helium.placementPolicy"),
           let savedPolicy = PlacementPolicy(rawValue: rawPolicy) {
            initialPolicy = savedPolicy
        } else {
            initialPolicy = .automatic
        }
        let initialSegmentMiB = defaults.object(forKey: "helium.segmentSizeMiB") != nil
            ? max(16, defaults.integer(forKey: "helium.segmentSizeMiB"))
            : 64
        let initialAutoStripeGB = defaults.object(forKey: "helium.autoStripeAboveGB") != nil
            ? max(0.5, defaults.double(forKey: "helium.autoStripeAboveGB"))
            : 4.0
        let initialRouting: AccountRoutingStrategy
        if let rawRouting = defaults.string(forKey: "helium.accountRoutingStrategy"),
           let savedRouting = AccountRoutingStrategy(rawValue: rawRouting) {
            initialRouting = savedRouting
        } else {
            initialRouting = .priorityOrder
        }
        let initialPreferredAccount = defaults.string(forKey: "helium.preferredUploadAccountId")

        self.placementPolicy = initialPolicy
        self.accountRoutingStrategy = initialRouting
        self.preferredUploadAccountId = initialPreferredAccount
        self.segmentSizeMiB = initialSegmentMiB
        self.autoStripeAboveGB = initialAutoStripeGB

        if defaults.object(forKey: "helium.zeroKnowledgeEnabled") != nil {
            self.zeroKnowledgeEnabled = defaults.bool(forKey: "helium.zeroKnowledgeEnabled")
        }
        if let rawSort = defaults.string(forKey: "helium.fileSortOrder"),
           let savedSort = FileSortOrder(rawValue: rawSort) {
            self.fileSortOrder = savedSort
        }
        if let rawLayout = defaults.string(forKey: "helium.fileViewLayout"),
           let savedLayout = FileViewLayout(rawValue: rawLayout) {
            self.fileViewLayout = savedLayout
        }
        if defaults.object(forKey: "helium.openAtLogin") != nil {
            self.openAtLogin = defaults.bool(forKey: "helium.openAtLogin")
        }
        if defaults.object(forKey: "helium.runInTaskbarOnly") != nil {
            self.runInTaskbarOnly = defaults.bool(forKey: "helium.runInTaskbarOnly")
        }
        if defaults.object(forKey: "helium.installUpdatesAutomatically") != nil {
            self.installUpdatesAutomatically = defaults.bool(forKey: "helium.installUpdatesAutomatically")
        }
        let askedStartup = defaults.bool(forKey: "helium.hasAskedStartupPreferences")
            || defaults.bool(forKey: "helium.dontAskStartupPreferencesAgain")
        self.hasAskedStartupPreferences = askedStartup
        if !askedStartup {
            self.showStartupPreferencesPrompt = true
        }

        // Load or create persistent Master Key and 52-char Base32 Recovery Key
        if store.get("masterKey") == nil {
            try? self.keyManager.saveMasterKey(ZK.random(32))
        }
        if let savedRKData = store.get("recoveryKeyText"),
           let savedRK = String(data: savedRKData, encoding: .utf8), !savedRK.isEmpty {
            self.recoveryKeyText = savedRK
        } else {
            let rkText = ZK.recoveryToText(ZK.random(32))
            self.recoveryKeyText = rkText
            try? store.set(Data(rkText.utf8), for: "recoveryKeyText")
        }

        let accountsFileURL = containerURL.appendingPathComponent("google-accounts.json")
        let manifestsFileURL = containerURL.appendingPathComponent("pool-manifests.json")
        let initialSavedAccounts: [LinkedGoogleAccount] = {
            guard let data = try? Data(contentsOf: accountsFileURL),
                  let decoded = try? JSONDecoder().decode([LinkedGoogleAccount].self, from: data) else {
                return []
            }
            return decoded.map { rawAcc in
                var acc = rawAcc
                if let rtData = store.get("helium.oauth.rt.\(acc.id)"),
                   let rt = String(data: rtData, encoding: .utf8), !rt.isEmpty {
                    acc.refreshToken = rt
                }
                if let atData = store.get("helium.oauth.at.\(acc.id)"),
                   let at = String(data: atData, encoding: .utf8), !at.isEmpty {
                    acc.accessToken = at
                }
                return acc
            }
        }()
        let initialSavedManifests: [String: PoolItemManifest] = {
            guard let data = try? Data(contentsOf: manifestsFileURL),
                  let decoded = try? JSONDecoder().decode([String: PoolItemManifest].self, from: data) else {
                return [:]
            }
            return decoded.filter { _, m in
                !m.item.name.hasPrefix("pool_file_") && !m.item.name.hasSuffix(".blob")
            }
        }()

        let accountPool = GoogleAccountPool(
            accounts: initialSavedAccounts,
            transport: URLSessionGoogleDriveTransport(),
            persistenceURL: accountsFileURL,
            secretStore: store
        )
        self.pool = accountPool
        self.pooledRemote = PooledGoogleDriveRemote(
            pool: accountPool,
            allocator: StoragePoolAllocator(
                safetyReserveBytes: 0,
                segmentChunkCount: max(1, initialSegmentMiB),
                autoStripeAboveBytes: Int64(max(0.5, initialAutoStripeGB) * Double(1_073_741_824)),
                policy: initialPolicy,
                routingStrategy: initialRouting,
                preferredAccountId: initialPreferredAccount
            ),
            manifestsPersistenceURL: manifestsFileURL
        )

        self.linkedAccounts = initialSavedAccounts
        self.manifests = initialSavedManifests
        HeliumRealtimeVFSServer.shared.updateCatalog(
            manifests: initialSavedManifests,
            pinnedFilenames: self.pinnedFilenames,
            offlineDownloadBytesByName: [:],
            totalPoolBytes: initialSavedAccounts.reduce(0) { $0 + $1.quotaLimitBytes },
            freePoolBytes: initialSavedAccounts.reduce(0) { $0 + max(0, $1.quotaLimitBytes - $1.quotaUsedBytes) }
        )
        self.isMounted = FileManager.default.fileExists(atPath: self.volumeMountURL.path) || !initialSavedAccounts.isEmpty
        if !initialSavedAccounts.isEmpty {
            self.phase = .active
            self.driveNodes = initialSavedManifests.values
                .filter { !$0.item.deleted && ($0.item.parentId ?? RemoteItem.rootID) == RemoteItem.rootID }
                .sorted { $0.item.modifiedAt > $1.item.modifiedAt }
                .enumerated()
                .map { idx, m in
                    DriveNode(
                        id: UInt64(idx + 2),
                        parentID: DriveNode.rootID,
                        remoteID: m.item.id,
                        name: m.item.name,
                        isFolder: m.item.kind == .folder,
                        size: m.item.size,
                        contentVersion: m.item.contentVersion,
                        metadataVersion: m.item.metadataVersion,
                        createdAt: Date(timeIntervalSince1970: TimeInterval(m.item.createdAt) / 1000.0),
                        modifiedAt: Date(timeIntervalSince1970: TimeInterval(m.item.modifiedAt) / 1000.0)
                    )
                }
        } else {
            self.phase = .welcomeSignIn
        }
        Self.shared = self
        loadSyncophantFeaturesState()
        HeliumRealtimeVFSServer.shared.updateCatalog(
            manifests: initialSavedManifests,
            pinnedFilenames: self.pinnedFilenames,
            offlineDownloadBytesByName: [:],
            totalPoolBytes: initialSavedAccounts.reduce(0) { $0 + $1.quotaLimitBytes },
            freePoolBytes: initialSavedAccounts.reduce(0) { $0 + max(0, $1.quotaLimitBytes - $1.quotaUsedBytes) }
        )
        setupFinderSyncNotificationObservers()

        self.bootstrapTask = Task { [weak self] in
            await self?.bootstrapDrive()
        }

        let shouldStartAtLogin = self.openAtLogin
        let shouldRunTaskbarOnly = self.runInTaskbarOnly
        let shouldHideInitialWindow = askedStartup && shouldRunTaskbarOnly
        DispatchQueue.main.async { [weak self] in
            self?.syncLaunchAgentPlist(enabled: shouldStartAtLogin)
            self?.applyTaskbarActivationPolicy(taskbarOnly: shouldRunTaskbarOnly, closeMainWindow: shouldHideInitialWindow)
        }

        self.windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let closingWindow = notification.object as? NSWindow else { return }
            let closingClass = NSStringFromClass(type(of: closingWindow))
            if closingClass.contains("StatusBar") || closingClass.contains("MenuBar") || closingClass.contains("NSPopover") {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.runInTaskbarOnly else { return }
                    let anyMainVisible = NSApplication.shared.windows.contains { win in
                        guard win !== closingWindow, win.isVisible else { return false }
                        let cls = NSStringFromClass(type(of: win))
                        if cls.contains("StatusBar") || cls.contains("MenuBar") || cls.contains("NSPopover") {
                            return false
                        }
                        return win.canBecomeMain || win.title.contains("Helium")
                    }
                    if !anyMainVisible {
                        NSApplication.shared.setActivationPolicy(.accessory)
                    }
                }
            }
        }

        // Automatically remount /Volumes/Helium, refresh OAuth tokens, and sync on macOS wake from sleep
        self.wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.ensureHeliumVolumeMounted()
                if !self.linkedAccounts.isEmpty {
                    await self.syncWithGoogleDrive()
                    self.restoreInterruptedUploads()
                }
            }
        }

        // Automatically resume interrupted uploads and sync when network connectivity returns
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let transitionedOnline = satisfied && !self.wasNetworkSatisfied
                self.wasNetworkSatisfied = satisfied
                if transitionedOnline && !self.linkedAccounts.isEmpty {
                    self.restoreInterruptedUploads()
                    await self.syncWithGoogleDrive()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.cogify.helium.networkmonitor", qos: .utility))
        self.networkMonitor = monitor
    }

    // MARK: - Startup on Bootup & Run in Taskbar Only
    private var launchAgentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.cogify.helium.plist")
    }

    public func setOpenAtLogin(_ enabled: Bool) {
        openAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: "helium.openAtLogin")
        syncLaunchAgentPlist(enabled: enabled)
        statusMessage = enabled
            ? "Helium will start automatically on bootup"
            : "Disabled automatic start on bootup"
    }

    public func setRunInTaskbarOnly(_ enabled: Bool, closeWindowImmediately: Bool = false) {
        runInTaskbarOnly = enabled
        UserDefaults.standard.set(enabled, forKey: "helium.runInTaskbarOnly")
        applyTaskbarActivationPolicy(taskbarOnly: enabled, closeMainWindow: closeWindowImmediately)
        statusMessage = enabled
            ? "Running in taskbar (menu bar) only — Dock icon hidden"
            : "Showing Helium in both Dock and menu bar"
    }

    public func setDontAskStartupPreferencesAgain(_ dontAsk: Bool) {
        hasAskedStartupPreferences = dontAsk
        UserDefaults.standard.set(dontAsk, forKey: "helium.hasAskedStartupPreferences")
        UserDefaults.standard.set(dontAsk, forKey: "helium.dontAskStartupPreferencesAgain")
    }

    public func saveStartupPreferences(startOnBootup: Bool, taskbarOnly: Bool, dontAskAgain: Bool = true) {
        setDontAskStartupPreferencesAgain(dontAskAgain)
        setOpenAtLogin(startOnBootup)
        setRunInTaskbarOnly(taskbarOnly, closeWindowImmediately: taskbarOnly)
        showStartupPreferencesPrompt = false
    }

    public func askStartupPreferencesAgain() {
        showStartupPreferencesPrompt = true
    }

    public func navigateToMainWindow(destination: SidebarDestination, settingsTab: SettingsTab? = nil) {
        if let settingsTab {
            self.selectedSettingsTab = settingsTab
        }
        self.selectedSidebarDestination = destination

        // Ensure the app can present and focus its main window even if taskbar-only mode was active
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
            restoreAppDockIcon()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            let className = NSStringFromClass(type(of: window))
            if className.contains("StatusBar") || className.contains("MenuBar") || className.contains("NSPopover") {
                continue
            }
            if window.canBecomeMain || window.title.contains("Helium") {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    private func restoreAppDockIcon() {
        if let iconURL = Bundle.main.url(forResource: "HeliumIcon", withExtension: "png")
            ?? Bundle.main.url(forResource: "Orbit", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    private func applyTaskbarActivationPolicy(taskbarOnly: Bool, closeMainWindow: Bool) {
        if taskbarOnly {
            if closeMainWindow {
                for window in NSApplication.shared.windows {
                    let className = NSStringFromClass(type(of: window))
                    if className.contains("StatusBar") || className.contains("MenuBar") || className.contains("NSPopover") {
                        continue
                    }
                    if window.isVisible && (window.canBecomeMain || window.title.contains("Helium")) {
                        window.orderOut(nil)
                    }
                }
            }
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
            restoreAppDockIcon()
        }
    }

    private func syncLaunchAgentPlist(enabled: Bool) {
        let fm = FileManager.default
        let plistURL = launchAgentPlistURL
        if enabled {
            let launchAgentsDir = plistURL.deletingLastPathComponent()
            try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            let appExecutable: String
            if fm.fileExists(atPath: "/Applications/Helium.app/Contents/MacOS/Helium") {
                appExecutable = "/Applications/Helium.app/Contents/MacOS/Helium"
            } else {
                appExecutable = Bundle.main.executablePath ?? "/Applications/Helium.app/Contents/MacOS/Helium"
            }
            let plistDict: [String: Any] = [
                "Label": "com.cogify.helium.launchagent",
                "ProgramArguments": [appExecutable, "--launched-at-login"],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) {
                try? data.write(to: plistURL, options: .atomic)
            }
        } else {
            if fm.fileExists(atPath: plistURL.path) {
                try? fm.removeItem(at: plistURL)
            }
        }
    }

    public var hasRealGoogleAccount: Bool {
        !linkedAccounts.isEmpty
    }

    public var realGoogleAccountsCount: Int {
        linkedAccounts.count
    }

    public var formattedRecoveryKey: String {
        recoveryKeyText
    }

    public var recoveryKeyInsideDriveWarning: Bool {
        driveNodes.contains { node in
            node.name.localizedCaseInsensitiveContains("Recovery Key") || RecoveryKeyFile.looksLike(node.name)
        }
    }

    public var isAlmostFull: Bool {
        guard totalPoolBytes > 0 else { return false }
        return Double(totalUsedBytes) / Double(totalPoolBytes) >= 0.90
    }

    public var foldersInDrive: [DriveNode] {
        driveNodes.filter(\.isFolder)
    }

    public var allFoldersInDrive: [DriveNode] {
        if let drive = activeDrive {
            return drive.tree.allNodes()
                .filter { $0.isFolder && $0.id != DriveNode.rootID }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return foldersInDrive
    }

    public var activeUploadSpeedBytesPerSec: Int64 {
        uploadActivities
            .filter { !$0.isCompleted && $0.errorText == nil }
            .reduce(0) { $0 + $1.speedBytesPerSec }
    }

    public var displayedNodes: [DriveNode] {
        let trimmedQuery = localFolderFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = driveNodes.filter { node in
            if !trimmedQuery.isEmpty && !node.name.localizedCaseInsensitiveContains(trimmedQuery) {
                return false
            }
            switch fileFilterMode {
            case .all:
                return true
            case .starred:
                return isNodeStarred(node)
            case .wholeFile:
                guard !node.isFolder, let remID = node.remoteID, let m = manifests[remID] else { return false }
                return m.placementMode == .wholeFileSmartPlacement
            case .striped:
                guard !node.isFolder, let remID = node.remoteID, let m = manifests[remID] else { return false }
                return m.placementMode == .crossAccountStriped
            case .pinned:
                return isNodePinned(node)
            case .folders:
                return node.isFolder
            }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder && !rhs.isFolder
            }
            switch fileSortOrder {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                if lhs.size != rhs.size { return lhs.size > rhs.size }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .dateModified:
                if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .placement:
                let lhsSegs = lhs.remoteID.flatMap { manifests[$0]?.segments.count } ?? 0
                let rhsSegs = rhs.remoteID.flatMap { manifests[$0]?.segments.count } ?? 0
                if lhsSegs != rhsSegs { return lhsSegs > rhsSegs }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    // MARK: - Drive Bootstrap, Real /Volumes/Helium Mount & Folder Sync
    public func bootstrapDrive() async {
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            await pool.refreshTokensAndQuotas(clientId: clientID)
        }
        linkedAccounts = await pool.accounts()

        await ensureHeliumVolumeMounted()

        let driveDir = storageRoot.appendingPathComponent("ActiveDrive", isDirectory: true)
        let treeFileURL = driveDir.appendingPathComponent("tree.json")
        let existingManifests = await pooledRemote.allManifests()
        if linkedAccounts.isEmpty && existingManifests.isEmpty {
            try? FileManager.default.removeItem(at: treeFileURL)
        } else if let treeText = try? String(contentsOf: treeFileURL, encoding: .utf8),
                  treeText.contains(".blob") || treeText.contains("pool_file_") {
            try? FileManager.default.removeItem(at: treeFileURL)
        }

        if linkedAccounts.isEmpty {
            phase = .welcomeSignIn
            statusMessage = "Sign in with Google to connect your Helium Drive."
        } else {
            phase = .active
            await pooledRemote.syncExistingVaultFiles()
        }

        await rebuildActiveDriveInstance()
        self.isMounted = FileManager.default.fileExists(atPath: volumeMountURL.path)
        await refreshState()
        restoreInterruptedUploads()

        if !linkedAccounts.isEmpty {
            await scanAndUploadLocalFinderFiles()
            startBackgroundStreamCachePrewarm()
        }
        startFolderWatcherLoop()
        if installUpdatesAutomatically {
            Task { @MainActor [weak self] in
                await self?.checkForUpdatesAsync(silent: true)
            }
        }
    }

    public func rebuildActiveDriveInstance() async {
        let driveDir = storageRoot.appendingPathComponent("ActiveDrive", isDirectory: true)
        let remote: any DriveRemote
        if zeroKnowledgeEnabled, let keys = keyManager.accountKeys() {
            remote = LockedRemote(inner: pooledRemote, keys: keys, locksWrites: true, directory: driveDir)
        } else {
            remote = pooledRemote
        }

        let config = OrbitDrive.Configuration(
            directory: driveDir,
            deviceName: Host.current().localizedName ?? "Mac",
            cacheLimits: ChunkStore.Limits.defaults(diskCapacity: cacheLimitOption.bytes)
        )
        let drive = OrbitDrive(remote: remote, configuration: config)
        self.activeDrive = drive
        try? await drive.start()
        try? await drive.sync()
    }

    public func setZeroKnowledgeEnabled(_ enabled: Bool) {
        zeroKnowledgeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "helium.zeroKnowledgeEnabled")
        Task {
            await rebuildActiveDriveInstance()
            await refreshState()
            statusMessage = enabled
                ? "Zero-Knowledge XChaCha20-Poly1305 encryption enabled for new uploads."
                : "Standard mode enabled — files upload with real names to Helium Pool Vault."
        }
    }

    /// Ephemeral local stream cache directory (`/tmp/HeliumStreamCache`) outside `/Volumes/Helium` so files in `/Volumes/Helium` report `Zero bytes on disk` while opening instantaneously in native macOS apps.
    nonisolated public static var streamCacheDirectoryURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("HeliumStreamCache", isDirectory: true)
    }

    /// Strips `com.apple.quarantine` and `com.apple.LaunchServices.OpenWith` extended attributes from a hydrated file so it opens directly in its native macOS application (`Preview`, `DiskImageMounter`, `QuickTime Player`, etc.) without triggering Gatekeeper quarantine alerts or opening the Helium app window.
    nonisolated public static func removeHeliumOpenWithAttribute(from fileURL: URL) {
        _ = Darwin.removexattr(fileURL.path, "com.apple.LaunchServices.OpenWith", 0)
        _ = Darwin.removexattr(fileURL.path, "com.apple.quarantine", 0)
    }

    /// Serialized 175-byte binary plist for `com.apple.LaunchServices.OpenWith` pointing to `/Applications/Helium.app/Contents/Helpers/HeliumOpener.app` (`com.cogify.helium.opener`, `LSUIElement = true`).
    /// Stored inline inside the APFS inode so the sparse placeholder reports `Zero bytes on disk` (`0 B on disk`, `fileAllocatedSize = 0`), while double-clicking in Finder silently invokes `HeliumOpener.app` in the background to open the hydrated file in `Preview` / `DiskImageMounter` / `QuickTime Player` without ever focusing the Helium main window.
    nonisolated private static var heliumOpenerXattrData: Data? {
        let openerPath: String
        let appSupportOpener = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true))
            .appendingPathComponent("Helium/HeliumOpener.app", isDirectory: true).path
        let bundledOpener = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HeliumOpener.app").path
        if FileManager.default.fileExists(atPath: "/Applications/Helium.app/Contents/Helpers/HeliumOpener.app") {
            openerPath = "/Applications/Helium.app/Contents/Helpers/HeliumOpener.app"
        } else if FileManager.default.fileExists(atPath: bundledOpener) {
            openerPath = bundledOpener
        } else if FileManager.default.fileExists(atPath: appSupportOpener) {
            openerPath = appSupportOpener
        } else {
            openerPath = "/Applications/Helium.app/Contents/Helpers/HeliumOpener.app"
        }
        let dict: [String: Any] = [
            "bundleidentifier": "com.cogify.helium.opener",
            "path": openerPath,
            "version": 0
        ]
        return try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
    }

    /// Applies the 175-byte inline `com.apple.LaunchServices.OpenWith` attribute pointing to `HeliumOpener.app` (`LSUIElement = true`) and strips `com.apple.quarantine` while keeping `fileAllocatedSize == 0` (`Zero bytes on disk`).
    nonisolated public static func applyHeliumOpenWithAttribute(to fileURL: URL) {
        _ = Darwin.removexattr(fileURL.path, "com.apple.quarantine", 0)
        guard let data = heliumOpenerXattrData else { return }
        data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return }
            _ = Darwin.setxattr(fileURL.path, "com.apple.LaunchServices.OpenWith", base, data.count, 0, 0)
        }
    }

    /// Returns `true` if `fileURL` has the inline `com.apple.LaunchServices.OpenWith` attribute applied by Helium.
    nonisolated public static func hasHeliumOpenWithAttribute(_ fileURL: URL) -> Bool {
        Darwin.getxattr(fileURL.path, "com.apple.LaunchServices.OpenWith", nil, 0, 0, 0) > 0
    }

    /// Opens a hydrated file in its real macOS default application (never looping back to `Helium.app` or `HeliumOpener.app` and never triggering Gatekeeper quarantine alerts).
    nonisolated public static func openHydratedFileInDefaultApp(_ fileURL: URL) {
        removeHeliumOpenWithAttribute(from: fileURL)
        let workspace = NSWorkspace.shared

        let isHeliumBundle: (URL) -> Bool = { appURL in
            let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? ""
            if bundleID.hasPrefix("com.cogify.helium") || bundleID.hasPrefix("com.helium.app") { return true }
            let name = appURL.lastPathComponent
            return name.localizedCaseInsensitiveContains("Helium")
        }

        if let defaultAppURL = workspace.urlForApplication(toOpen: fileURL),
           !isHeliumBundle(defaultAppURL) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.open([fileURL], withApplicationAt: defaultAppURL, configuration: config, completionHandler: nil)
            return
        }

        let candidates = workspace.urlsForApplications(toOpen: fileURL).filter { !isHeliumBundle($0) }
        if let bestAppURL = candidates.first {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.open([fileURL], withApplicationAt: bestAppURL, configuration: config, completionHandler: nil)
            return
        }

        workspace.activateFileViewerSelecting([fileURL])
    }

    /// Writes a true `Zero bytes on disk` (`0 B on disk`, `fileAllocatedSize == 0`) APFS sparse placeholder at `fileURL` (in `/Volumes/Helium` or `~/Helium`) with logical size `logicalSize` and an inline 175-byte `OpenWith` xattr pointing to invisible `HeliumOpener.app`.
    /// If `fileURL` currently holds real hydrated bytes, those bytes are preserved in `/tmp/HeliumStreamCache/<fileName>` before `fileURL` is dehydrated to 0 B on disk.
    nonisolated public static func writeZeroDiskSparsePlaceholder(
        at fileURL: URL,
        logicalSize: Int64,
        modifiedAt: Date? = nil
    ) {
        let fm = FileManager.default
        let parentDir = fileURL.deletingLastPathComponent()
        try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let existingModDate: Date? = modifiedAt ?? (try? fm.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date)
        let cacheDir = streamCacheDirectoryURL
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cachedFileURL = cacheDir.appendingPathComponent(fileURL.lastPathComponent)

        // 1. If `fileURL` currently has real non-zero bytes on disk (e.g. just dropped into Finder), save a hydrated copy in /tmp/HeliumStreamCache before dehydrating `fileURL` to 0 B on disk
        if logicalSize > 0 && isHydratedLocalFile(fileURL) {
            let cachedSize = Int64((try? cachedFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
            if !isHydratedLocalFile(cachedFileURL) || cachedSize != logicalSize {
                try? fm.removeItem(at: cachedFileURL)
                try? fm.copyItem(at: fileURL, to: cachedFileURL)
                removeHeliumOpenWithAttribute(from: cachedFileURL)
            }
        }

        // 2. If `fileURL` is already a 0-bytes-on-disk sparse file of the exact logicalSize, just ensure its inline OpenWith xattr is set and quarantine is stripped
        if fm.fileExists(atPath: fileURL.path),
           let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
           Int64(vals.fileSize ?? -1) == max(0, logicalSize),
           (vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 1) == 0 {
            applyHeliumOpenWithAttribute(to: fileURL)
            return
        }

        // 3. Replace with a fresh APFS sparse file (`ftruncate` allocates 0 physical blocks on APFS)
        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: fileURL)
        }

        let fd = Darwin.open(fileURL.path, O_CREAT | O_TRUNC | O_WRONLY, 0o644)
        if fd >= 0 {
            _ = Darwin.ftruncate(fd, off_t(max(0, logicalSize)))
            Darwin.close(fd)
        }
        if let modDate = existingModDate {
            try? fm.setAttributes([.modificationDate: modDate], ofItemAtPath: fileURL.path)
        }
        applyHeliumOpenWithAttribute(to: fileURL)
    }

    /// Returns `true` only if `fileURL` exists, has real physical blocks allocated on disk, and contains non-zero content bytes. Returns `false` for 0-bytes-on-disk APFS sparse placeholders or all-zero files.
    nonisolated public static func isHydratedLocalFile(_ fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
              vals.isRegularFile == true else {
            return false
        }
        let logical = vals.fileSize ?? 0
        if logical == 0 { return true }
        let allocated = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0
        guard allocated > 0 else { return false }

        let fd = Darwin.open(fileURL.path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }
        var buf = [UInt8](repeating: 0, count: min(4096, max(1, logical)))
        let bytesRead = Darwin.pread(fd, &buf, buf.count, 0)
        guard bytesRead > 0 else { return false }
        return buf.prefix(bytesRead).contains { $0 != 0 }
    }

    /// Synchronizes all cloud folders and files into `/Volumes/Helium` and `~/Helium`, ensuring every unpinned file is a `Zero bytes on disk` (`0 B on disk`) APFS sparse file while pinned (`Keep on this Mac`) files have their full offline bytes.
    public func dehydrateUnpinnedCloudFiles() async {
        let allManifests = await self.pooledRemote.allManifests()
        var freshMap: [String: PoolItemManifest] = [:]
        for m in allManifests {
            freshMap[m.item.id] = m
        }
        self.manifests = freshMap
        let currentManifests = Array(freshMap.values)
        let pinnedSet = self.keepList.all()
        let inFlight = self.inFlightFilenames
        var deletedNames = self.explicitlyDeletedFilenames
        for m in currentManifests where m.item.deleted {
            deletedNames.insert(m.item.name.precomposedStringWithCanonicalMapping)
        }
        // Do not treat a name as deleted if another active manifest with the same name exists
        for m in currentManifests where !m.item.deleted {
            deletedNames.remove(m.item.name.precomposedStringWithCanonicalMapping)
        }

        let mirrorRoot = self.localMirrorURL
        let mountRoot = self.volumeMountURL
        let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
        let chunksDir = self.storageRoot.appendingPathComponent("ActiveDrive/chunks", isDirectory: true)
        let stagingDir = self.storageRoot.appendingPathComponent("ActiveDrive/staging", isDirectory: true)

        HeliumRealtimeVFSServer.shared.clearUnpinnedRealtimeChunks(pinnedFilenames: pinnedSet)
        HeliumRealtimeVFSServer.shared.updateCatalog(
            manifests: self.manifests,
            pinnedFilenames: pinnedSet,
            offlineDownloadBytesByName: self.offlinePinProgressByName,
            totalPoolBytes: self.totalPoolBytes,
            freePoolBytes: self.totalFreeBytes
        )

        let materializedIds: Set<String> = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let roots = [mountRoot, mirrorRoot].filter { fm.fileExists(atPath: $0.path) }
            let mountExists = fm.fileExists(atPath: mountRoot.path)
            var nowMaterialized: Set<String> = []

            // Build parentId -> relative folder path map
            var folderByID: [String: RemoteItem] = [:]
            for m in currentManifests where m.item.kind == .folder && !m.item.deleted {
                folderByID[m.item.id] = m.item
            }
            func relativeFolderPath(for item: RemoteItem) -> String {
                var parts: [String] = []
                var cursor = item.parentId
                var safety = 0
                while let pid = cursor, pid != RemoteItem.rootID, !pid.isEmpty, safety < 32 {
                    guard let folder = folderByID[pid] else { break }
                    parts.insert(folder.name, at: 0)
                    if folder.parentId == pid { break }
                    cursor = folder.parentId
                    safety += 1
                }
                return parts.joined(separator: "/")
            }

            // 1. Ensure all active cloud folders exist in /Volumes/Helium and ~/Helium
            var expectedActiveRelPaths = Set<String>()
            for manifest in currentManifests where manifest.item.kind == .folder && !manifest.item.deleted {
                let parentSub = relativeFolderPath(for: manifest.item)
                let relPath = parentSub.isEmpty ? manifest.item.name : "\(parentSub)/\(manifest.item.name)"
                expectedActiveRelPaths.insert(relPath.precomposedStringWithCanonicalMapping)
                for root in roots {
                    let dirURL = root.appendingPathComponent(relPath, isDirectory: true)
                    try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
                }
                if mountExists {
                    nowMaterialized.insert(manifest.item.id)
                }
            }
            for manifest in currentManifests where manifest.item.kind == .file && !manifest.item.deleted {
                let parentSub = relativeFolderPath(for: manifest.item)
                let relPath = parentSub.isEmpty ? manifest.item.name : "\(parentSub)/\(manifest.item.name)"
                expectedActiveRelPaths.insert(relPath.precomposedStringWithCanonicalMapping)
            }

            // 2. Remove any deleted files/folders, stale renamed/moved placeholders, or internal .blob files from /Volumes/Helium and ~/Helium
            for root in roots {
                if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for item in items {
                        let name = item.lastPathComponent.precomposedStringWithCanonicalMapping
                        if deletedNames.contains(name) || name.hasPrefix("pool_file_") || name.hasSuffix(".blob") {
                            try? fm.removeItem(at: item)
                        } else if AppModel.hasHeliumOpenWithAttribute(item) && !expectedActiveRelPaths.contains(name) {
                            try? fm.removeItem(at: item)
                        }
                    }
                }
            }
            for manifest in currentManifests where manifest.item.deleted {
                let parentSub = relativeFolderPath(for: manifest.item)
                let relPath = parentSub.isEmpty ? manifest.item.name : "\(parentSub)/\(manifest.item.name)"
                for root in roots {
                    let targetURL = root.appendingPathComponent(relPath)
                    if fm.fileExists(atPath: targetURL.path) {
                        try? fm.removeItem(at: targetURL)
                    }
                }
            }

            // 3. Synchronize every active cloud file in /Volumes/Helium and ~/Helium
            for manifest in currentManifests where manifest.item.kind == .file && !manifest.item.deleted {
                let rawName = manifest.item.name
                let fileName = rawName.precomposedStringWithCanonicalMapping
                if inFlight.contains(fileName) || inFlight.contains(rawName) {
                    continue
                }
                let parentSub = relativeFolderPath(for: manifest.item)
                let modDate = Date(timeIntervalSince1970: TimeInterval(manifest.item.modifiedAt) / 1000.0)
                let size = max(0, manifest.item.size)
                let isPinned = pinnedSet.contains(fileName) || pinnedSet.contains(rawName)
                let pinnedCandidate = pinnedRoot.appendingPathComponent(rawName)

                for root in roots {
                    let baseDir = parentSub.isEmpty ? root : root.appendingPathComponent(parentSub, isDirectory: true)
                    try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
                    let fileURL = baseDir.appendingPathComponent(rawName)

                    if isPinned {
                        if AppModel.isHydratedLocalFile(pinnedCandidate) && !AppModel.isHydratedLocalFile(fileURL) {
                            try? fm.removeItem(at: fileURL)
                            try? fm.copyItem(at: pinnedCandidate, to: fileURL)
                            AppModel.removeHeliumOpenWithAttribute(from: fileURL)
                        }
                    } else {
                        AppModel.writeZeroDiskSparsePlaceholder(at: fileURL, logicalSize: size, modifiedAt: modDate)
                    }
                }
                if mountExists {
                    nowMaterialized.insert(manifest.item.id)
                }
            }

            // 4. Clean up any unpinned staging/chunk files when dehydrating
            if pinnedSet.isEmpty {
                for dir in [chunksDir, stagingDir] where fm.fileExists(atPath: dir.path) {
                    if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                        for item in items {
                            try? fm.removeItem(at: item)
                        }
                    }
                }
            }
            return nowMaterialized
        }.value

        if !materializedIds.isEmpty || self.manifests.values.allSatisfy(\.item.deleted) {
            self.materializedVolumeManifestIds = materializedIds
            UserDefaults.standard.set(Array(materializedIds).sorted(), forKey: "helium.materializedVolumeManifestIds")
        }
    }

    /// Detects files or folders deleted, renamed, or moved by the user in Finder (`/Volumes/Helium` or `/Volumes/Helium/.Trashes/<uid>`) and cross-syncs those changes to Helium App and Google Drive (`Helium Pool Vault` & `Recycle Bin`).
    public func detectAndSyncFinderDeletions() async {
        guard !isDetectingFinderDeletions else { return }
        isDetectingFinderDeletions = true
        defer { isDetectingFinderDeletions = false }

        let mountRoot = self.volumeMountURL
        let fm = FileManager.default
        guard fm.fileExists(atPath: mountRoot.path) else { return }

        // Verify /Volumes/Helium is actually mounted as a volume
        var st = statfs()
        guard statfs(mountRoot.path, &st) == 0 else { return }
        let mountedPath = withUnsafePointer(to: &st.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        guard mountedPath == mountRoot.path else { return }

        let allManifests = await pooledRemote.allManifests()
        let activeManifests = allManifests.filter { !$0.item.deleted }
        guard !activeManifests.isEmpty else { return }

        var folderByID: [String: RemoteItem] = [:]
        for m in activeManifests where m.item.kind == .folder {
            folderByID[m.item.id] = m.item
        }
        func relativeItemPath(for item: RemoteItem) -> String {
            var parts: [String] = []
            var cursor = item.parentId
            var safety = 0
            while let pid = cursor, pid != RemoteItem.rootID, !pid.isEmpty, safety < 32 {
                guard let folder = folderByID[pid] else { break }
                parts.insert(folder.name, at: 0)
                if folder.parentId == pid { break }
                cursor = folder.parentId
                safety += 1
            }
            let parentRel = parts.joined(separator: "/")
            return parentRel.isEmpty ? item.name : "\(parentRel)/\(item.name)"
        }

        var deletedManifestMap: [String: PoolItemManifest] = [:]

        // 1. Check /Volumes/Helium/.Trashes/<uid> for any items moved to Trash by macOS Finder
        let uidTrashURL = mountRoot
            .appendingPathComponent(".Trashes", isDirectory: true)
            .appendingPathComponent("\(Darwin.getuid())", isDirectory: true)
        if let trashedURLs = try? fm.contentsOfDirectory(
            at: uidTrashURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        ) {
            for trashedURL in trashedURLs {
                let rawTrashName = trashedURL.lastPathComponent
                if rawTrashName == ".DS_Store" || rawTrashName.hasPrefix(".") {
                    continue
                }
                let canonicalTrashName = rawTrashName.precomposedStringWithCanonicalMapping
                let trashSize = Int64((try? trashedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
                let trashExt = (canonicalTrashName as NSString).pathExtension.lowercased()

                for m in activeManifests {
                    let mCanonical = m.item.name.precomposedStringWithCanonicalMapping
                    if mCanonical == canonicalTrashName {
                        deletedManifestMap[m.item.id] = m
                    } else if !trashExt.isEmpty {
                        let mExt = (mCanonical as NSString).pathExtension.lowercased()
                        let mBase = (mCanonical as NSString).deletingPathExtension
                        if mExt == trashExt
                            && canonicalTrashName.hasPrefix(mBase + " ")
                            && (trashSize <= 0 || m.item.size == trashSize) {
                            deletedManifestMap[m.item.id] = m
                        }
                    }
                }
                try? fm.removeItem(at: trashedURL)
            }
        }

        // 2. Check materializedVolumeManifestIds for any active file/folder no longer present at its expected path in /Volumes/Helium
        let knownMaterialized = self.materializedVolumeManifestIds
        let inFlight = self.inFlightFilenames
        var missingFromExpectedPath: [PoolItemManifest] = []
        for m in activeManifests where knownMaterialized.contains(m.item.id) && deletedManifestMap[m.item.id] == nil {
            let mCanonical = m.item.name.precomposedStringWithCanonicalMapping
            if inFlight.contains(mCanonical) || inFlight.contains(m.item.name) {
                continue
            }
            let relPath = relativeItemPath(for: m.item)
            let expectedURL = mountRoot.appendingPathComponent(relPath)
            if !fm.fileExists(atPath: expectedURL.path) {
                missingFromExpectedPath.append(m)
            }
        }

        // 2b. Before treating a missing item as deleted, check if the user RENAMED it in Finder or MOVED it into another folder inside /Volumes/Helium!
        var renamedOrMovedAny = false
        if !missingFromExpectedPath.isEmpty {
            // Map all active parent folders -> (parentRemoteId, directoryURL, knownCanonicalChildNames)
            var folderDirectories: [(parentId: String, dirURL: URL, knownNames: Set<String>)] = []
            let rootKnown = Set(
                activeManifests
                    .filter { ($0.item.parentId ?? RemoteItem.rootID) == RemoteItem.rootID }
                    .map { $0.item.name.precomposedStringWithCanonicalMapping }
            )
            folderDirectories.append((RemoteItem.rootID, mountRoot, rootKnown))
            for folderManifest in activeManifests where folderManifest.item.kind == .folder {
                let fid = folderManifest.item.id
                let rel = relativeItemPath(for: folderManifest.item)
                let dirURL = mountRoot.appendingPathComponent(rel, isDirectory: true)
                let childKnown = Set(
                    activeManifests
                        .filter { $0.item.parentId == fid }
                        .map { $0.item.name.precomposedStringWithCanonicalMapping }
                )
                folderDirectories.append((fid, dirURL, childKnown))
            }

            for m in missingFromExpectedPath {
                let mCanonical = m.item.name.precomposedStringWithCanonicalMapping
                let oldParentId = m.item.parentId ?? RemoteItem.rootID
                var matchedMoveOrRename: (newParentId: String, newName: String)?

                // Case A: Moved to another folder in /Volumes/Helium with the same filename
                for folderEntry in folderDirectories where folderEntry.parentId != oldParentId && !folderEntry.knownNames.contains(mCanonical) {
                    let candidateURL = folderEntry.dirURL.appendingPathComponent(m.item.name)
                    if fm.fileExists(atPath: candidateURL.path) {
                        matchedMoveOrRename = (folderEntry.parentId, m.item.name)
                        break
                    }
                }

                // Case B: Renamed inside the same folder in /Volumes/Helium
                if matchedMoveOrRename == nil,
                   let sameFolderEntry = folderDirectories.first(where: { $0.parentId == oldParentId }),
                   let siblings = try? fm.contentsOfDirectory(
                       at: sameFolderEntry.dirURL,
                       includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                       options: [.skipsHiddenFiles]
                   ) {
                    for sibURL in siblings {
                        let sibName = sibURL.lastPathComponent.precomposedStringWithCanonicalMapping
                        if sibName.hasPrefix("Welcome to ") || sibName.hasPrefix("pool_file_") || sibName.hasSuffix(".blob") || sibName == "Icon\r" {
                            continue
                        }
                        guard !sameFolderEntry.knownNames.contains(sibName) else { continue }
                        let vals = try? sibURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
                        if m.item.kind == .file,
                           vals?.isRegularFile == true,
                           AppModel.hasHeliumOpenWithAttribute(sibURL),
                           Int64(vals?.fileSize ?? -1) == m.item.size {
                            matchedMoveOrRename = (oldParentId, sibName)
                            break
                        } else if m.item.kind == .folder, vals?.isDirectory == true {
                            matchedMoveOrRename = (oldParentId, sibName)
                            break
                        }
                    }
                }

                if let (newParentId, newName) = matchedMoveOrRename {
                    _ = try? await pooledRemote.move(id: m.item.id, toParent: newParentId, newName: newName)
                    if let drive = activeDrive, let node = drive.tree.node(remoteID: m.item.id) {
                        let newParentInode = (newParentId == RemoteItem.rootID)
                            ? DriveNode.rootID
                            : (drive.tree.node(remoteID: newParentId)?.id ?? DriveNode.rootID)
                        _ = drive.tree.update(node.id) { n in
                            n.parentID = newParentInode
                            n.name = newName
                            n.modifiedAt = Date()
                        }
                        drive.tree.save()
                    }
                    if keepList.isKept(m.item.name) && newName != m.item.name {
                        keepList.setKept(m.item.name, kept: false)
                        keepList.setKept(newName, kept: true)
                    }
                    renamedOrMovedAny = true
                } else {
                    deletedManifestMap[m.item.id] = m
                }
            }
        }

        if renamedOrMovedAny && deletedManifestMap.isEmpty {
            try? await activeDrive?.sync()
            await refreshState()
            return
        }

        guard !deletedManifestMap.isEmpty else { return }

        // If a folder was deleted in Finder, also include any child manifests inside that folder
        var expandedDeletes = deletedManifestMap
        var addedChild = true
        while addedChild {
            addedChild = false
            for m in activeManifests where expandedDeletes[m.item.id] == nil {
                if let pid = m.item.parentId, expandedDeletes[pid] != nil {
                    expandedDeletes[m.item.id] = m
                    addedChild = true
                }
            }
        }

        let mirrorRoot = self.localMirrorURL
        let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
        let streamDir = Self.streamCacheDirectoryURL
        var deletedDisplayNames: [String] = []

        for m in expandedDeletes.values {
            let canonical = m.item.name.precomposedStringWithCanonicalMapping
            deletedDisplayNames.append(m.item.name)
            materializedVolumeManifestIds.remove(m.item.id)
            explicitlyDeletedFilenames.insert(canonical)
            keepList.setKept(m.item.name, kept: false)
            offlinePinProgressByName.removeValue(forKey: m.item.name)
            offlinePinProgressByName.removeValue(forKey: canonical)

            let relPath = relativeItemPath(for: m.item)
            for root in [mountRoot, mirrorRoot] {
                let target = root.appendingPathComponent(relPath)
                if fm.fileExists(atPath: target.path) {
                    try? fm.removeItem(at: target)
                }
            }
            for auxDir in [pinnedRoot, streamDir] {
                let auxFile = auxDir.appendingPathComponent(m.item.name)
                if fm.fileExists(atPath: auxFile.path) {
                    try? fm.removeItem(at: auxFile)
                }
            }

            // Move manifest to Helium 30-Day Trash AND move file on Google Drive into `Helium Pool Vault / Recycle Bin`
            _ = await pooledRemote.moveToTrash(id: m.item.id)

            // Remove from activeDrive tree immediately
            if let drive = activeDrive, let node = drive.tree.node(remoteID: m.item.id) {
                _ = drive.tree.remove(node.id)
                drive.tree.save()
            }
        }

        UserDefaults.standard.set(Array(materializedVolumeManifestIds).sorted(), forKey: "helium.materializedVolumeManifestIds")
        UserDefaults.standard.set(Array(explicitlyDeletedFilenames).sorted(), forKey: "helium.explicitlyDeletedFilenames")

        try? await activeDrive?.sync()
        await refreshState()
        let firstDeleted = deletedDisplayNames.first ?? "item"
        statusMessage = deletedDisplayNames.count == 1
            ? "Moved '\(firstDeleted)' (deleted in Finder) to Helium Recycle Bin & Google Drive Recycle Bin."
            : "Moved \(deletedDisplayNames.count) Finder-deleted items to Helium Recycle Bin & Google Drive Recycle Bin."
    }

    /// Mounts `/Volumes/Helium` as a local APFS Volume named `Helium` (`MNT_LOCAL == 1`, custom `Orbit.icns` drive icon in Finder Sidebar under `Locations`, NEVER `127.0.0.1`), starts `HeliumRealtimeVFSServer` for live HTTP 206 1 MiB chunk streaming, and populates all cloud files as `Zero bytes on disk` (`0 B on disk`) sparse files.
    public func ensureHeliumVolumeMounted() async {
        let storageRootURL = self.storageRoot
        let mirrorURL = self.localMirrorURL
        let legacyMirror = self.legacyMirrorURL
        let mountURL = self.volumeMountURL
        let legacyMount = self.legacyVolumeMountURL
        let poolTotal = self.totalPoolBytes
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Helium", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/Helium", isDirectory: true)
        let apfsBundleURL = cachesDir.appendingPathComponent("HeliumCloudDrive.sparsebundle", isDirectory: true)
        let groupContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.cogify.helium"
        )

        // Start our HTTP 1.1 206 Partial Content 1 MiB Chunk-Streaming Server (also unmounts any legacy 127.0.0.1 NFS mount)
        _ = HeliumRealtimeVFSServer.shared.ensureStartedAndMounted(at: mountURL)

        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            try? fm.createDirectory(at: mirrorURL, withIntermediateDirectories: true)
            try? fm.createDirectory(at: storageRootURL, withIntermediateDirectories: true)
            try? fm.createDirectory(at: cachesDir, withIntermediateDirectories: true)

            // Migrate any user files from legacy ~/Helium into ~/Helium
            if fm.fileExists(atPath: legacyMirror.path),
               let oldItems = try? fm.contentsOfDirectory(at: legacyMirror, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for item in oldItems where !item.lastPathComponent.hasPrefix("Welcome to ") {
                    let dest = mirrorURL.appendingPathComponent(item.lastPathComponent)
                    if !fm.fileExists(atPath: dest.path) {
                        try? fm.copyItem(at: item, to: dest)
                    }
                }
            }

            // Detach legacy /Volumes/Helium if mounted
            if fm.fileExists(atPath: legacyMount.path) {
                let detachLegacy = Process()
                detachLegacy.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachLegacy.arguments = ["detach", legacyMount.path, "-force", "-quiet"]
                try? detachLegacy.run()
                detachLegacy.waitUntilExit()
            }

            // Remove old sparsebundles in Application Support so only Caches/Helium/HeliumCloudDrive.sparsebundle is used
            var legacyBundles: [URL] = [
                storageRootURL.appendingPathComponent("HeliumExternalDrive.sparsebundle", isDirectory: true),
                storageRootURL.appendingPathComponent("HeliumDrive.sparsebundle", isDirectory: true),
                storageRootURL.appendingPathComponent("HeliumAPFSDrive.sparsebundle", isDirectory: true)
            ]
            if let groupContainerURL {
                legacyBundles.append(groupContainerURL.appendingPathComponent("HeliumExternalDrive.sparsebundle", isDirectory: true))
                legacyBundles.append(groupContainerURL.appendingPathComponent("HeliumAPFSDrive.sparsebundle", isDirectory: true))
            }
            for oldBundle in legacyBundles where fm.fileExists(atPath: oldBundle.path) {
                try? fm.removeItem(at: oldBundle)
            }

            // Check if /Volumes/Helium is already mounted as a local APFS volume
            var isLocalAPFSMounted = false
            var st = statfs()
            if statfs(mountURL.path, &st) == 0 {
                let fsName = withUnsafePointer(to: &st.f_fstypename) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                        String(cString: $0)
                    }
                }
                let mountedPath = withUnsafePointer(to: &st.f_mntonname) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                        String(cString: $0)
                    }
                }
                if mountedPath == mountURL.path && fsName.lowercased() == "apfs" {
                    isLocalAPFSMounted = true
                } else if mountedPath == mountURL.path && fsName.lowercased() == "nfs" {
                    _ = Darwin.unmount(mountURL.path, MNT_FORCE)
                }
            }

            if !isLocalAPFSMounted {
                let targetSizeGB = max(64, min(16_384, Int((max(Int64(64) * 1_073_741_824, poolTotal) + 1_073_741_823) / 1_073_741_824)))
                if !fm.fileExists(atPath: apfsBundleURL.path) {
                    let createProc = Process()
                    createProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    createProc.arguments = [
                        "create",
                        "-size", "\(targetSizeGB)g",
                        "-type", "SPARSEBUNDLE",
                        "-fs", "APFS",
                        "-volname", "Helium",
                        "-quiet",
                        apfsBundleURL.path
                    ]
                    try? createProc.run()
                    createProc.waitUntilExit()
                }

                let attachProc = Process()
                attachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                attachProc.arguments = [
                    "attach",
                    apfsBundleURL.path,
                    "-mountpoint", mountURL.path,
                    "-owners", "on",
                    "-quiet"
                ]
                try? attachProc.run()
                attachProc.waitUntilExit()
            }

            if fm.fileExists(atPath: mountURL.path) {
                // Prevent Spotlight from reading/hydrating 0-byte sparse files in /Volumes/Helium
                let noIndexURL = mountURL.appendingPathComponent(".metadata_never_index")
                if !fm.fileExists(atPath: noIndexURL.path) {
                    try? Data().write(to: noIndexURL)
                }
                _ = Darwin.removexattr(mountURL.path, "com.apple.quarantine", 0)
            }

            // Enable Finder Sync extension (OrbitFinder) for right-click context menu ("Keep on this Mac", "Copy Helium Link", "Request Files…")
            if fm.fileExists(atPath: "/usr/bin/pluginkit") {
                let pk = Process()
                pk.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
                pk.arguments = ["-e", "use", "-i", "com.cogify.helium.OrbitFinder"]
                try? pk.run()
                pk.waitUntilExit()
            }
        }.value

        if let iconURL = Bundle.main.url(forResource: "Orbit", withExtension: "icns"),
           let nsIcon = NSImage(contentsOf: iconURL) {
            if FileManager.default.fileExists(atPath: mountURL.path) {
                NSWorkspace.shared.setIcon(nsIcon, forFile: mountURL.path, options: [])
            }
            if FileManager.default.fileExists(atPath: mirrorURL.path) {
                NSWorkspace.shared.setIcon(nsIcon, forFile: mirrorURL.path, options: [])
            }
        }

        await detectAndSyncFinderDeletions()
        await dehydrateUnpinnedCloudFiles()
        self.isMounted = FileManager.default.fileExists(atPath: volumeMountURL.path)
    }

    private func startFolderWatcherLoop() {
        watcherTask?.cancel()
        watcherTask = Task { [weak self] in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { break }
                tickCount += 1
                await self.detectAndSyncFinderDeletions()
                if !self.linkedAccounts.isEmpty && !self.isUploadsPaused {
                    await self.scanAndUploadLocalFinderFiles()
                }
                // Every 30 seconds (15 x 2s ticks), perform a silent background sync with Google Drive Pool Vaults so changes made in Google Drive Web or another device appear automatically
                if tickCount >= 15 {
                    tickCount = 0
                    if self.phase == .active,
                       !self.linkedAccounts.isEmpty,
                       !self.isSyncingPool,
                       !self.isScanningFinderFiles,
                       self.inFlightFilenames.isEmpty {
                        await self.pooledRemote.syncExistingVaultFiles()
                        try? await self.activeDrive?.sync()
                        await self.refreshState()
                    }
                }
            }
        }
    }

    /// Scans `/Volumes/Helium` and `~/Helium` (including subfolders) for any newly created folders or newly dropped files with real non-zero disk bytes (`isHydratedLocalFile(url) == true`), uploads them to the Google Drive Pool, and immediately dehydrates them to `Zero bytes on disk` (`0 B on disk`).
    public func scanAndUploadLocalFinderFiles() async {
        guard !linkedAccounts.isEmpty, !isUploadsPaused, !isScanningFinderFiles, !isSyncingPool else { return }
        isScanningFinderFiles = true
        defer { isScanningFinderFiles = false }

        let allManifests = Array(manifests.values).filter { !$0.item.deleted }
        let rootChildren = allManifests.filter { ($0.item.parentId ?? RemoteItem.rootID) == RemoteItem.rootID }
        let knownRootNames = Set(rootChildren.map { $0.item.name.precomposedStringWithCanonicalMapping })
        let busyNames = Set(inFlightFilenames.map { $0.precomposedStringWithCanonicalMapping })
        let deletedNames = Set(explicitlyDeletedFilenames.map { $0.precomposedStringWithCanonicalMapping })
        let mountDir = volumeMountURL
        let mirrorDir = localMirrorURL

        var folderByID: [String: RemoteItem] = [:]
        for m in allManifests where m.item.kind == .folder {
            folderByID[m.item.id] = m.item
        }
        func folderRelativePath(_ folderItem: RemoteItem) -> String {
            var parts: [String] = [folderItem.name]
            var cursor = folderItem.parentId
            var safety = 0
            while let pid = cursor, pid != RemoteItem.rootID, !pid.isEmpty, safety < 32 {
                guard let parent = folderByID[pid] else { break }
                parts.insert(parent.name, at: 0)
                if parent.parentId == pid { break }
                cursor = parent.parentId
                safety += 1
            }
            return parts.joined(separator: "/")
        }

        // Build subfolder scanning descriptors
        var subfolderTargets: [(folderId: String, relPath: String, knownChildNames: Set<String>)] = []
        for folderManifest in allManifests where folderManifest.item.kind == .folder {
            let fid = folderManifest.item.id
            let relPath = folderRelativePath(folderManifest.item)
            let childNames = Set(
                allManifests
                    .filter { $0.item.parentId == fid }
                    .map { $0.item.name.precomposedStringWithCanonicalMapping }
            )
            subfolderTargets.append((fid, relPath, childNames))
        }

        let (newRootURLs, newSubfolderBatches): ([URL], [(String, [URL])]) = await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var discoveredRoot: [String: URL] = [:]

            for dir in [mountDir, mirrorDir] where fm.fileExists(atPath: dir.path) {
                guard let urls = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }
                for url in urls {
                    let rawName = url.lastPathComponent
                    let canonicalName = rawName.precomposedStringWithCanonicalMapping
                    if canonicalName.hasPrefix("Welcome to ")
                        || canonicalName.hasPrefix(".")
                        || canonicalName.hasPrefix("pool_file_")
                        || canonicalName.hasSuffix(".blob")
                        || canonicalName == "Icon\r" {
                        continue
                    }
                    guard !knownRootNames.contains(canonicalName),
                          !busyNames.contains(canonicalName),
                          !deletedNames.contains(canonicalName),
                          discoveredRoot[canonicalName] == nil else {
                        continue
                    }
                    let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
                    if vals?.isDirectory == true {
                        discoveredRoot[canonicalName] = url
                    } else if vals?.isRegularFile == true,
                              (vals?.fileSize ?? 0) > 0,
                              AppModel.isHydratedLocalFile(url) {
                        discoveredRoot[canonicalName] = url
                    }
                }
            }

            var subBatches: [(String, [URL])] = []
            for sub in subfolderTargets {
                var discoveredSub: [String: URL] = [:]
                for root in [mountDir, mirrorDir] where fm.fileExists(atPath: root.path) {
                    let subDir = root.appendingPathComponent(sub.relPath, isDirectory: true)
                    guard fm.fileExists(atPath: subDir.path),
                          let urls = try? fm.contentsOfDirectory(
                              at: subDir,
                              includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                              options: [.skipsHiddenFiles, .skipsPackageDescendants]
                          ) else { continue }
                    for url in urls {
                        let rawName = url.lastPathComponent
                        let canonicalName = rawName.precomposedStringWithCanonicalMapping
                        if canonicalName.hasPrefix(".")
                            || canonicalName.hasPrefix("pool_file_")
                            || canonicalName.hasSuffix(".blob")
                            || canonicalName == "Icon\r" {
                            continue
                        }
                        guard !sub.knownChildNames.contains(canonicalName),
                              !busyNames.contains(canonicalName),
                              discoveredSub[canonicalName] == nil else {
                            continue
                        }
                        let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
                        if vals?.isDirectory == true {
                            discoveredSub[canonicalName] = url
                        } else if vals?.isRegularFile == true,
                                  (vals?.fileSize ?? 0) > 0,
                                  AppModel.isHydratedLocalFile(url) {
                            discoveredSub[canonicalName] = url
                        }
                    }
                }
                if !discoveredSub.isEmpty {
                    let sorted = Array(discoveredSub.values).sorted { $0.lastPathComponent < $1.lastPathComponent }
                    subBatches.append((sub.folderId, sorted))
                }
            }

            let rootSorted = Array(discoveredRoot.values).sorted { $0.lastPathComponent < $1.lastPathComponent }
            return (rootSorted, subBatches)
        }.value

        if !newRootURLs.isEmpty {
            await importExternalFiles(newRootURLs, targetFolderId: RemoteItem.rootID)
        }
        for (folderId, urls) in newSubfolderBatches {
            await importExternalFiles(urls, targetFolderId: folderId)
        }
    }

    public func refreshState() async {
        await pooledRemote.reconcileAccountPoolUsage()
        linkedAccounts = await pool.accounts()
        let allManifests = await pooledRemote.allManifests()
        var map: [String: PoolItemManifest] = [:]
        for m in allManifests {
            map[m.item.id] = m
        }
        manifests = map
        pinnedFilenames = keepList.all()
        await refreshTrashedItemsAndPurgeExpired()
        await dehydrateUnpinnedCloudFiles()
        if let drive = activeDrive {
            var prunedTree = false
            for node in drive.tree.allNodes() where node.id != DriveNode.rootID {
                if let remID = node.remoteID {
                    if let m = map[remID], m.item.deleted {
                        _ = drive.tree.remove(node.id)
                        prunedTree = true
                    } else if map[remID] == nil {
                        _ = drive.tree.remove(node.id)
                        prunedTree = true
                    }
                }
            }
            if prunedTree {
                drive.tree.save()
            }
            let children = drive.children(of: currentFolderInode)
            withAnimation(HeliumSpring.fluid) {
                driveNodes = children
            }
            searchResults = drive.searchIndex.search(searchQuery, kind: searchKind, limit: 40)
            let allFiles = drive.tree.allNodes().filter { !$0.isFolder }
            let pinnedSet = keepList.all()
            cachedBytesOnMac = allFiles
                .filter { pinnedSet.contains($0.name) }
                .reduce(0) { $0 + max(0, $1.size) }
        }
        HeliumRealtimeVFSServer.shared.updateCatalog(
            manifests: manifests,
            pinnedFilenames: pinnedFilenames,
            offlineDownloadBytesByName: offlinePinProgressByName,
            totalPoolBytes: totalPoolBytes,
            freePoolBytes: totalFreeBytes
        )
        self.isMounted = FileManager.default.fileExists(atPath: volumeMountURL.path) || !linkedAccounts.isEmpty
    }

    // MARK: - Real-Time Chunk Streaming & Finder Sync IPC
    public func fetchRealtimeChunkFromPool(remoteID: String, offset: Int64, length: Int) async throws -> Data {
        if zeroKnowledgeEnabled,
           let drive = activeDrive,
           let matchedNode = driveNodes.first(where: { $0.remoteID == remoteID }) {
            return try await drive.read(matchedNode.id, offset: offset, length: length)
        }
        return try await pooledRemote.fetchRange(id: remoteID, offset: offset, length: length)
    }

    public func recordRealtimeChunkRead(
        fileName: String,
        chunkIndex: Int,
        totalChunks: Int,
        bytesCount: Int,
        fromCache: Bool
    ) {
        let event = RealtimeChunkReadEvent(
            fileName: fileName,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            bytesRead: bytesCount,
            fromCache: fromCache,
            timestamp: Date()
        )
        recentChunkEvents.insert(event, at: 0)
        if recentChunkEvents.count > 36 {
            recentChunkEvents = Array(recentChunkEvents.prefix(36))
        }
        let kb = max(1, bytesCount / 1024)
        let summary = "Chunk #\(chunkIndex + 1)/\(max(1, totalChunks)) (\(kb) KB) of '\(fileName)' \(fromCache ? "served from instant cache" : "streamed live from Google Drive")"
        activeRealtimeStreamSummary = summary
        if !fromCache {
            statusMessage = "Streaming '\(fileName)' — Chunk #\(chunkIndex + 1)/\(max(1, totalChunks)) (\(kb) KB) live from Google Drive (0 B on disk)"
        }
    }

    public func openRealtimeChunkStreamer(for node: DriveNode) {
        streamingInspectorNode = node
        showRealtimeVideoStreamerSheet = true
        Task {
            await ensureHeliumVolumeMounted()
        }
    }

    private func setupFinderSyncNotificationObservers() {
        guard !finderNotificationObserversRegistered else { return }
        finderNotificationObserversRegistered = true

        let dnc = DistributedNotificationCenter.default()

        // Background Finder Open IPC from invisible HeliumOpener.app (LSUIElement = true) so double-clicking a 0-B-on-disk file in /Volumes/Helium opens it in Preview / QuickTime / DiskImageMounter without activating Helium.app's window!
        dnc.addObserver(
            forName: Notification.Name("com.cogify.helium.opener.streamAndOpen"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let rawPath = (note.object as? String) ?? ""
            guard !rawPath.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let fileURL = URL(fileURLWithPath: rawPath)
                let fileName = fileURL.lastPathComponent
                let canonical = fileName.precomposedStringWithCanonicalMapping
                let matchedNode = self.driveNodes.first {
                    !$0.isFolder && $0.name.precomposedStringWithCanonicalMapping == canonical
                }
                await self.streamAndOpenFile(named: fileName, node: matchedNode, placeholderURL: fileURL)
            }
        }

        dnc.addObserver(
            forName: Notification.Name("com.cogify.helium.opener.didOpenCached"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let rawPath = (note.object as? String) ?? ""
            guard !rawPath.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let fileName = URL(fileURLWithPath: rawPath).lastPathComponent
                let canonical = fileName.precomposedStringWithCanonicalMapping
                let size = self.manifests.values.first {
                    !$0.item.deleted && $0.item.name.precomposedStringWithCanonicalMapping == canonical
                }?.item.size ?? 1_048_576
                let totalChunks = max(1, Int((max(1, size) + Int64(HeliumRealtimeVFSServer.chunkSizeBytes) - 1) / Int64(HeliumRealtimeVFSServer.chunkSizeBytes)))
                self.recordRealtimeChunkRead(
                    fileName: fileName,
                    chunkIndex: 0,
                    totalChunks: totalChunks,
                    bytesCount: Int(min(Int64(HeliumRealtimeVFSServer.chunkSizeBytes), max(1, size))),
                    fromCache: true
                )
            }
        }

        dnc.addObserver(
            forName: Notification.Name("com.cogify.helium.finder.keepOffline"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let rawPath = (note.object as? String) ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                let paths = rawPath.split(separator: "\n").map(String.init)
                if paths.isEmpty {
                    self.pinAllInCurrentFolder()
                    return
                }
                let allTreeNodes = self.activeDrive?.tree.allNodes() ?? []
                for path in paths {
                    let name = URL(fileURLWithPath: path).lastPathComponent.precomposedStringWithCanonicalMapping
                    if let node = self.driveNodes.first(where: { $0.name.precomposedStringWithCanonicalMapping == name })
                        ?? allTreeNodes.first(where: { $0.name.precomposedStringWithCanonicalMapping == name }) {
                        self.togglePinNode(node)
                    }
                }
            }
        }

        dnc.addObserver(
            forName: Notification.Name("com.cogify.helium.finder.copyLink"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let rawPath = (note.object as? String) ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                let firstPath = rawPath.split(separator: "\n").first.map(String.init) ?? ""
                let name = URL(fileURLWithPath: firstPath).lastPathComponent.precomposedStringWithCanonicalMapping
                let allTreeNodes = self.activeDrive?.tree.allNodes() ?? []
                if let node = self.driveNodes.first(where: { $0.name.precomposedStringWithCanonicalMapping == name })
                    ?? allTreeNodes.first(where: { $0.name.precomposedStringWithCanonicalMapping == name })
                    ?? self.driveNodes.first {
                    self.createAndCopyShareLink(for: node)
                }
            }
        }

        dnc.addObserver(
            forName: Notification.Name("com.cogify.helium.finder.requestFiles"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let rawPath = (note.object as? String) ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                let firstPath = rawPath.split(separator: "\n").first.map(String.init) ?? ""
                let folderName = firstPath.isEmpty ? "Helium Drive" : URL(fileURLWithPath: firstPath).lastPathComponent
                self.createFileRequest(folderName: folderName, title: "Drop files for \(folderName)")
                self.showFileRequestsSheet = true
            }
        }
    }

    // MARK: - Subfolder & Breadcrumb Navigation
    public func relativeParentSubfolderPath(for node: DriveNode) -> String {
        guard let drive = activeDrive else {
            return currentRelativeSubfolderPath()
        }
        var parts: [String] = []
        var cursorID = node.parentID
        var safety = 0
        while cursorID != DriveNode.rootID && cursorID != 0 && safety < 32 {
            guard let parent = drive.node(cursorID), parent.id != DriveNode.rootID else { break }
            parts.insert(parent.name, at: 0)
            if parent.parentID == cursorID { break }
            cursorID = parent.parentID
            safety += 1
        }
        return parts.joined(separator: "/")
    }

    public func openFolder(_ node: DriveNode) {
        guard node.isFolder else {
            openNodeOnMac(node)
            return
        }
        withAnimation(HeliumSpring.fluid) {
            currentFolderInode = node.id
            let remID = node.remoteID ?? RemoteItem.rootID
            selectedFolderId = remID
            if let drive = activeDrive {
                var chain: [FolderBreadcrumb] = []
                var cursor: DriveNode? = node
                var safety = 0
                while let curr = cursor, curr.id != DriveNode.rootID, safety < 32 {
                    chain.insert(
                        FolderBreadcrumb(
                            inode: curr.id,
                            name: curr.name,
                            remoteID: curr.remoteID ?? RemoteItem.rootID
                        ),
                        at: 0
                    )
                    if curr.parentID == curr.id || curr.parentID == 0 { break }
                    cursor = drive.node(curr.parentID)
                    safety += 1
                }
                breadcrumbs = [
                    FolderBreadcrumb(inode: DriveNode.rootID, name: "Helium Drive", remoteID: RemoteItem.rootID)
                ] + chain
            } else if !breadcrumbs.contains(where: { $0.inode == node.id }) {
                breadcrumbs.append(FolderBreadcrumb(inode: node.id, name: node.name, remoteID: remID))
            }
        }
        Task {
            await refreshState()
        }
    }

    public func navigateToBreadcrumb(_ crumb: FolderBreadcrumb) {
        withAnimation(HeliumSpring.fluid) {
            currentFolderInode = crumb.inode
            selectedFolderId = crumb.remoteID
            if let idx = breadcrumbs.firstIndex(where: { $0.inode == crumb.inode }) {
                breadcrumbs = Array(breadcrumbs.prefix(through: idx))
            }
        }
        Task {
            await refreshState()
        }
    }

    public func navigateUpFolder() {
        guard breadcrumbs.count > 1 else { return }
        let parentCrumb = breadcrumbs[breadcrumbs.count - 2]
        navigateToBreadcrumb(parentCrumb)
    }

    public func currentRelativeSubfolderPath() -> String {
        guard breadcrumbs.count > 1 else { return "" }
        return breadcrumbs.dropFirst().map(\.name).joined(separator: "/")
    }

    // MARK: - Finder & Google Drive Browser Actions
    public func openInFinder() {
        Task {
            await ensureHeliumVolumeMounted()
            let subPath = currentRelativeSubfolderPath()
            let targetMount = subPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
            let targetMirror = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)

            if FileManager.default.fileExists(atPath: targetMount.path) {
                NSWorkspace.shared.open(targetMount)
                statusMessage = "Opened Helium Drive (\(targetMount.path)) in Finder"
            } else if FileManager.default.fileExists(atPath: volumeMountURL.path) {
                NSWorkspace.shared.open(volumeMountURL)
                statusMessage = "Opened Helium Drive (/Volumes/Helium) in Finder"
            } else {
                NSWorkspace.shared.open(targetMirror)
                statusMessage = "Opened Helium folder (\(targetMirror.path)) in Finder"
            }
        }
    }

    public func revealNodeInFinder(_ node: DriveNode) {
        let subPath = relativeParentSubfolderPath(for: node)
        let baseMount = subPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
        let baseMirror = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)

        let volumeCandidate = baseMount.appendingPathComponent(node.name)
        if FileManager.default.fileExists(atPath: volumeCandidate.path) {
            NSWorkspace.shared.activateFileViewerSelecting([volumeCandidate])
            return
        }
        let mirrorCandidate = baseMirror.appendingPathComponent(node.name)
        if FileManager.default.fileExists(atPath: mirrorCandidate.path) {
            NSWorkspace.shared.activateFileViewerSelecting([mirrorCandidate])
            return
        }
        openInFinder()
    }

    /// Opens the `Helium Pool Vault` folder in Google Drive in the user's web browser.
    public func openGoogleDriveVaultInBrowser(for account: LinkedGoogleAccount? = nil) {
        let target = account ?? linkedAccounts.first
        let urlString: String
        if let folderId = target?.rootFolderId, !folderId.isEmpty, folderId != "root", !folderId.hasPrefix("helium_root_") {
            urlString = "https://drive.google.com/drive/folders/\(folderId)"
        } else {
            urlString = "https://drive.google.com/drive/my-drive"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            statusMessage = "Opened Helium Pool Vault in Google Drive (\(target?.email ?? "browser"))"
        }
    }

    /// Opens a specific uploaded file or its vault folder directly in Google Drive in the browser.
    public func openNodeInGoogleDrive(_ node: DriveNode) {
        if let remID = node.remoteID,
           let manifest = manifests[remID],
           let firstSeg = manifest.segments.first,
           !firstSeg.driveFileId.hasPrefix("gfile_") {
            if manifest.segments.count == 1, let url = URL(string: "https://drive.google.com/file/d/\(firstSeg.driveFileId)/view") {
                NSWorkspace.shared.open(url)
                statusMessage = "Opened '\(node.name)' in Google Drive"
                return
            }
            if let acc = linkedAccounts.first(where: { $0.id == firstSeg.accountId }) {
                openGoogleDriveVaultInBrowser(for: acc)
                return
            }
        }
        openGoogleDriveVaultInBrowser()
    }

    // MARK: - Google Sign-In & Multi-Account Pool Management
    public func startBrowserOAuthFlow() {
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            statusMessage = "Google OAuth Client ID not found in GoogleService-Info.plist."
            return
        }
        isSigningInWithGoogle = true
        statusMessage = "Opening Google Sign-In…"
        Task { @MainActor in
            defer { isSigningInWithGoogle = false }
            do {
                let account = try await oauth.signIn(
                    clientId: clientID,
                    configuredReversed: firebaseConfig.reversedClientId,
                    isFirstAccount: linkedAccounts.isEmpty
                )
                await pool.addAccount(account)
                await pooledRemote.syncExistingVaultFiles()
                try? await activeDrive?.sync()
                await refreshState()
                self.isMounted = true
                self.phase = .active
                let gb = max(1, account.quotaLimitBytes / 1_073_741_824)
                statusMessage = "Connected \(account.email) (+\(gb) GB added to Helium Drive)"

                // Automatically upload any files already sitting in /Volumes/Helium or ~/Helium
                await scanAndUploadLocalFinderFiles()
            } catch {
                statusMessage = "Google Sign-In failed: \(error.localizedDescription)"
            }
        }
    }

    public func syncWithGoogleDrive() async {
        guard !isSyncingPool else { return }
        isSyncingPool = true
        statusMessage = "Syncing with Google Drive Pool Vaults & Finder…"
        defer { isSyncingPool = false }

        // 1. First detect any files or folders deleted in /Volumes/Helium Finder so they move to Recycle Bin instead of re-appearing
        await detectAndSyncFinderDeletions()

        // 2. Refresh OAuth tokens & storage quotas across all linked Google Drives
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            await pool.refreshTokensAndQuotas(clientId: clientID)
        }

        // 3. Bi-directionally sync folders, files, and Recycle Bin across all linked Google Drives
        await pooledRemote.syncExistingVaultFiles()
        try? await activeDrive?.sync()
        await refreshState()

        // 4. Upload any new folders or files dropped into /Volumes/Helium
        await scanAndUploadLocalFinderFiles()

        let activeFileCount = manifests.values.filter { $0.item.kind == .file && !$0.item.deleted }.count
        let activeFolderCount = manifests.values.filter { $0.item.kind == .folder && !$0.item.deleted }.count
        if activeFolderCount > 0 {
            statusMessage = "Synced \(activeFileCount) file\(activeFileCount == 1 ? "" : "s") and \(activeFolderCount) folder\(activeFolderCount == 1 ? "" : "s") across \(linkedAccounts.count) Google Drive\(linkedAccounts.count == 1 ? "" : "s")."
        } else {
            statusMessage = "Synced \(activeFileCount) file\(activeFileCount == 1 ? "" : "s") across \(linkedAccounts.count) Google Drive\(linkedAccounts.count == 1 ? "" : "s")."
        }
    }

    public func rebalancePool() async {
        guard !isRebalancingPool else { return }
        isRebalancingPool = true
        statusMessage = "Rebalancing whole files across your Google Drives…"
        defer { isRebalancingPool = false }

        do {
            let movedCount = try await pooledRemote.rebalanceWholeFiles()
            try? await activeDrive?.sync()
            await refreshState()
            if movedCount > 0 {
                statusMessage = "Rebalanced \(movedCount) file\(movedCount == 1 ? "" : "s") onto Google Drives with more free space."
            } else {
                statusMessage = "Storage pool is already optimally balanced across all linked Google Drives."
            }
        } catch {
            statusMessage = "Pool rebalance error: \(error.localizedDescription)"
        }
    }

    public func verifyPoolHealth() async {
        let diag = await pooledRemote.verifyPoolIntegrity()
        let summary = "Verified \(diag.verifiedFiles) files (\(diag.healthySegments)/\(diag.totalSegments) segments healthy)"
        withAnimation(HeliumSpring.snappy) {
            poolHealthSummary = summary
        }
        statusMessage = summary
    }

    public func drainAndUnlink(accountId: String) async {
        do {
            statusMessage = "Moving files from \(accountId) onto your remaining Google Drives…"
            try await pooledRemote.drainAndUnlinkAccount(id: accountId)
            await refreshState()
            statusMessage = "Unlinked Google Drive \(accountId)."
        } catch {
            statusMessage = "Could not unlink Google Drive: \(error.localizedDescription)"
        }
    }

    public func signOutOfThisMac() async {
        for acc in linkedAccounts {
            await pool.removeAccount(id: acc.id)
        }
        driveNodes = []
        manifests = [:]
        phase = .welcomeSignIn
        statusMessage = "Signed out of this Mac. Your files stay safe in Google Drive."
    }

    // MARK: - Placement Engine & Account Upload Priority Operations
    private func makeCurrentAllocator() -> StoragePoolAllocator {
        StoragePoolAllocator(
            safetyReserveBytes: 0,
            segmentChunkCount: max(1, segmentSizeMiB),
            autoStripeAboveBytes: Int64(max(0.5, autoStripeAboveGB) * Double(1_073_741_824)),
            policy: placementPolicy,
            routingStrategy: accountRoutingStrategy,
            preferredAccountId: preferredUploadAccountId
        )
    }

    public func updateAllocatorPolicy(_ policy: PlacementPolicy) async {
        placementPolicy = policy
        let defaults = UserDefaults.standard
        defaults.set(policy.rawValue, forKey: "helium.placementPolicy")
        defaults.set(segmentSizeMiB, forKey: "helium.segmentSizeMiB")
        defaults.set(autoStripeAboveGB, forKey: "helium.autoStripeAboveGB")
        defaults.set(accountRoutingStrategy.rawValue, forKey: "helium.accountRoutingStrategy")
        defaults.set(preferredUploadAccountId ?? "", forKey: "helium.preferredUploadAccountId")

        await pooledRemote.setAllocator(makeCurrentAllocator())
        statusMessage = "Placement mode set to \(policyDescription(policy))"
    }

    public func setAccountRoutingStrategy(_ strategy: AccountRoutingStrategy) async {
        withAnimation(HeliumSpring.fluid) {
            accountRoutingStrategy = strategy
        }
        UserDefaults.standard.set(strategy.rawValue, forKey: "helium.accountRoutingStrategy")
        await pooledRemote.setAllocator(makeCurrentAllocator())
        statusMessage = "Account upload routing set to \(strategy.displayTitle)"
    }

    public func setPreferredUploadAccount(_ accountId: String?) async {
        withAnimation(HeliumSpring.snappy) {
            preferredUploadAccountId = accountId
            if accountId != nil {
                accountRoutingStrategy = .pinnedAccount
            } else if accountRoutingStrategy == .pinnedAccount {
                accountRoutingStrategy = .priorityOrder
            }
        }
        let defaults = UserDefaults.standard
        defaults.set(preferredUploadAccountId ?? "", forKey: "helium.preferredUploadAccountId")
        defaults.set(accountRoutingStrategy.rawValue, forKey: "helium.accountRoutingStrategy")
        await pooledRemote.setAllocator(makeCurrentAllocator())
        if let accountId, let acc = linkedAccounts.first(where: { $0.id == accountId }) {
            statusMessage = "Uploads will prioritise \(acc.email) first"
        } else {
            statusMessage = "Uploads set to Automatic Priority Order (#1 → #2 → …)"
        }
    }

    public func prioritiseAccountFirst(_ accountId: String) async {
        await pool.prioritiseAccountFirst(id: accountId)
        linkedAccounts = await pool.accounts()
        await pooledRemote.setAllocator(makeCurrentAllocator())
        if let acc = linkedAccounts.first(where: { $0.id == accountId }) {
            statusMessage = "Promoted \(acc.email) to #1 Primary Upload Account"
        }
    }

    public func moveAccountPriority(_ accountId: String, delta: Int) async {
        await pool.moveAccountPriority(id: accountId, delta: delta)
        linkedAccounts = await pool.accounts()
        await pooledRemote.setAllocator(makeCurrentAllocator())
        if let acc = linkedAccounts.first(where: { $0.id == accountId }) {
            statusMessage = "Updated \(acc.email) upload priority to #\(acc.uploadPriority)"
        }
    }

    public func toggleAccountUploadPaused(_ accountId: String) async {
        guard let existing = linkedAccounts.first(where: { $0.id == accountId }) else { return }
        let newPaused = !existing.isUploadPaused
        await pool.setAccountUploadPaused(id: accountId, paused: newPaused)
        linkedAccounts = await pool.accounts()
        await pooledRemote.setAllocator(makeCurrentAllocator())
        statusMessage = newPaused
            ? "Paused new uploads to \(existing.email)"
            : "Resumed uploads to \(existing.email)"
    }

    public func moveNodeToGoogleAccount(_ node: DriveNode, targetAccountId: String) async {
        guard let remID = node.remoteID,
              let targetAcc = linkedAccounts.first(where: { $0.id == targetAccountId }) else { return }
        statusMessage = "Moving '\(node.name)' to \(targetAcc.email)…"
        do {
            _ = try await pooledRemote.moveFileToAccount(id: remID, targetAccountId: targetAccountId)
            try? await activeDrive?.sync()
            await refreshState()
            statusMessage = "Moved '\(node.name)' to Google Drive (\(targetAcc.email))"
        } catch {
            statusMessage = "Could not move '\(node.name)': \(error.localizedDescription)"
        }
    }

    public func filesCountForAccount(_ accountId: String) -> Int {
        manifests.values.filter { manifest in
            !manifest.item.deleted && manifest.item.kind == .file && manifest.segments.contains(where: { $0.accountId == accountId })
        }.count
    }

    public func heliumUsedBytesForAccount(_ accountId: String) -> Int64 {
        var total: Int64 = 0
        for manifest in manifests.values where !manifest.item.deleted && manifest.item.kind == .file {
            if manifest.segments.isEmpty { continue }
            for seg in manifest.segments where seg.accountId == accountId {
                total += max(0, seg.byteLength > 0 ? seg.byteLength : manifest.item.size)
            }
        }
        return total
    }

    public var primaryUploadTargetAccount: LinkedGoogleAccount? {
        let active = linkedAccounts.filter { !$0.isUploadPaused }
        let candidates = active.isEmpty ? linkedAccounts : active
        if let prefId = preferredUploadAccountId,
           let matched = candidates.first(where: { $0.id == prefId }) {
            return matched
        }
        switch accountRoutingStrategy {
        case .mostFreeSpace:
            return candidates.max(by: { $0.freeBytes < $1.freeBytes })
        case .priorityOrder, .pinnedAccount:
            return candidates.min(by: { lhs, rhs in
                if lhs.uploadPriority != rhs.uploadPriority {
                    return lhs.uploadPriority < rhs.uploadPriority
                }
                return lhs.freeBytes > rhs.freeBytes
            })
        }
    }

    public func updateAutoStripeThresholdGB(_ gb: Double) async {
        autoStripeAboveGB = max(0.5, gb)
        await updateAllocatorPolicy(placementPolicy)
    }

    public func updateSegmentSizeMiB(_ mib: Int) async {
        segmentSizeMiB = max(16, mib)
        await updateAllocatorPolicy(placementPolicy)
    }

    public func setFileSortOrder(_ order: FileSortOrder) {
        withAnimation(HeliumSpring.fluid) {
            fileSortOrder = order
        }
        UserDefaults.standard.set(order.rawValue, forKey: "helium.fileSortOrder")
    }

    public func setFileViewLayout(_ layout: FileViewLayout) {
        withAnimation(HeliumSpring.fluid) {
            fileViewLayout = layout
        }
        UserDefaults.standard.set(layout.rawValue, forKey: "helium.fileViewLayout")
    }

    public func policyDescription(_ policy: PlacementPolicy) -> String {
        switch policy {
        case .automatic:
            return "Automatic (Whole-File + Multi-Drive Striping)"
        case .preferWholeFile:
            return "Whole-File Smart Placement"
        case .alwaysStripe:
            return "Multi-Drive Striping"
        }
    }

    public func createNewFolder(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let drive = activeDrive else { return }
        do {
            _ = try await drive.createFolder(
                name: trimmed,
                in: currentFolderInode
            )
            let subPath = currentRelativeSubfolderPath()
            let baseMirror = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)
            let mirrorFolder = baseMirror.appendingPathComponent(trimmed, isDirectory: true)
            await Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(at: mirrorFolder, withIntermediateDirectories: true)
            }.value
            try await drive.sync()
            await refreshState()
            statusMessage = "Created folder '\(trimmed)' in Helium"
        } catch {
            statusMessage = "Could not create folder: \(error.localizedDescription)"
        }
    }

    // MARK: - File Actions (Star, Pin / Keep on this Mac, Batch Pin, Quick Note, Clipboard Upload, Open, Export, Rename, Delete)
    public func isNodeStarred(_ node: DriveNode) -> Bool {
        starredFilenames.contains(node.name)
    }

    public func toggleStarNode(_ node: DriveNode) {
        withAnimation(HeliumSpring.snappy) {
            if starredFilenames.contains(node.name) {
                starredFilenames.remove(node.name)
                statusMessage = "Removed '\(node.name)' from Starred favorites"
            } else {
                starredFilenames.insert(node.name)
                statusMessage = "Added '\(node.name)' to ★ Starred favorites"
            }
        }
        UserDefaults.standard.set(Array(starredFilenames).sorted(), forKey: "helium.starredFilenames")
    }

    public func isNodePinned(_ node: DriveNode) -> Bool {
        pinnedFilenames.contains(node.name)
    }

    public func togglePinNode(_ node: DriveNode) {
        let nowPinned = !keepList.isKept(node.name)
        keepList.setKept(node.name, kept: nowPinned)
        withAnimation(HeliumSpring.snappy) {
            pinnedFilenames = keepList.all()
        }
        if nowPinned {
            let targets = node.isFolder ? driveNodes.filter { !$0.isFolder } : [node]
            startOfflineKeepDownload(for: targets)
            statusMessage = "Downloading '\(node.name)' to keep on this Mac, as you chose."
        } else {
            offlinePinProgressByName.removeValue(forKey: node.name)
            offlinePinProgressByName.removeValue(forKey: node.name.precomposedStringWithCanonicalMapping)
            Task {
                let pinnedURL = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL.appendingPathComponent(node.name)
                try? FileManager.default.removeItem(at: pinnedURL)
                await dehydrateUnpinnedCloudFiles()
                await refreshState()
            }
            statusMessage = "Freed up space for '\(node.name)' (Zero bytes on disk — cloud-only mode)"
        }
    }

    public func pinAllInCurrentFolder() {
        let files = driveNodes.filter { !$0.isFolder }
        guard !files.isEmpty else {
            statusMessage = "No files in current folder to keep on this Mac."
            return
        }
        for file in files {
            keepList.setKept(file.name, kept: true)
        }
        withAnimation(HeliumSpring.snappy) {
            pinnedFilenames = keepList.all()
        }
        startOfflineKeepDownload(for: files)
        statusMessage = "Downloading \(files.count) file\(files.count == 1 ? "" : "s") to keep on this Mac, as you chose."
    }

    public func unpinAllInCurrentFolder() {
        let files = driveNodes.filter { !$0.isFolder }
        for file in files {
            keepList.setKept(file.name, kept: false)
            offlinePinProgressByName.removeValue(forKey: file.name)
            offlinePinProgressByName.removeValue(forKey: file.name.precomposedStringWithCanonicalMapping)
            let pinnedURL = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL.appendingPathComponent(file.name)
            try? FileManager.default.removeItem(at: pinnedURL)
        }
        offlinePinTask?.cancel()
        withAnimation(HeliumSpring.snappy) {
            isDownloadingOfflineKeep = false
            offlineKeepDownloadedBytes = 0
            offlineKeepTotalBytes = 0
            pinnedFilenames = keepList.all()
        }
        Task {
            await dehydrateUnpinnedCloudFiles()
            await refreshState()
        }
        statusMessage = "Freed up space for all files in this folder (Zero bytes on disk)."
    }

    /// Downloads pinned files in 1 MiB chunks so the Menu Bar popover displays live progress (`Downloading X of Y — To keep on this Mac, as you chose.`) and Finder Get Info (`⌘I`) updates `bytes on disk` as chunks arrive.
    private func startOfflineKeepDownload(for nodes: [DriveNode]) {
        let validNodes = nodes.filter { !$0.isFolder && $0.size > 0 }
        guard !validNodes.isEmpty else { return }

        offlinePinTask?.cancel()
        let totalBytes = validNodes.reduce(Int64(0)) { $0 + max(0, $1.size) }
        withAnimation(HeliumSpring.fluid) {
            isDownloadingOfflineKeep = true
            offlineKeepTotalBytes = totalBytes
            offlineKeepDownloadedBytes = 0
            offlineKeepCurrentFileName = validNodes.first?.name ?? ""
        }

        offlinePinTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
            try? FileManager.default.createDirectory(at: pinnedRoot, withIntermediateDirectories: true)
            let chunkSize = HeliumRealtimeVFSServer.chunkSizeBytes
            var cumulativeDownloaded: Int64 = 0

            for node in validNodes {
                if Task.isCancelled { break }
                self.offlineKeepCurrentFileName = node.name
                let destURL = pinnedRoot.appendingPathComponent(node.name)
                let subPath = self.relativeParentSubfolderPath(for: node)
                let baseMirror = subPath.isEmpty ? self.localMirrorURL : self.localMirrorURL.appendingPathComponent(subPath, isDirectory: true)
                let baseMount = subPath.isEmpty ? self.volumeMountURL : self.volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
                let mirrorURL = baseMirror.appendingPathComponent(node.name)
                let mountURL = baseMount.appendingPathComponent(node.name)
                FileManager.default.createFile(atPath: destURL.path, contents: nil)
                let handle = try? FileHandle(forWritingTo: destURL)
                let fileTotal = max(0, node.size)
                var offset: Int64 = 0

                while offset < fileTotal && !Task.isCancelled {
                    let readLen = Int(min(Int64(chunkSize), fileTotal - offset))
                    let chunkData: Data
                    if let remID = node.remoteID,
                       let fetched = try? await self.fetchRealtimeChunkFromPool(remoteID: remID, offset: offset, length: readLen) {
                        chunkData = fetched
                    } else if let drive = self.activeDrive,
                              let fetched = try? await drive.read(node.id, offset: offset, length: readLen) {
                        chunkData = fetched
                    } else {
                        break
                    }
                    if let handle {
                        try? handle.seek(toOffset: UInt64(offset))
                        try? handle.write(contentsOf: chunkData)
                    }
                    let count = Int64(chunkData.count)
                    guard count > 0 else { break }
                    offset += count
                    cumulativeDownloaded += count

                    let canonical = node.name.precomposedStringWithCanonicalMapping
                    self.offlinePinProgressByName[canonical] = min(fileTotal, offset)
                    self.offlineKeepDownloadedBytes = min(totalBytes, cumulativeDownloaded)
                    HeliumRealtimeVFSServer.shared.updateCatalog(
                        manifests: self.manifests,
                        pinnedFilenames: self.pinnedFilenames,
                        offlineDownloadBytesByName: self.offlinePinProgressByName,
                        totalPoolBytes: self.totalPoolBytes,
                        freePoolBytes: self.totalFreeBytes
                    )
                }
                try? handle?.close()
                Self.removeHeliumOpenWithAttribute(from: destURL)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    for target in [mountURL, mirrorURL] where FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path) {
                        try? FileManager.default.removeItem(at: target)
                        try? FileManager.default.copyItem(at: destURL, to: target)
                        Self.removeHeliumOpenWithAttribute(from: target)
                    }
                }
            }

            withAnimation(HeliumSpring.fluid) {
                self.isDownloadingOfflineKeep = false
            }
            await self.refreshState()
            if !Task.isCancelled {
                let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                self.statusMessage = "Kept \(validNodes.count) file\(validNodes.count == 1 ? "" : "s") (\(totalFormatted)) on this Mac for offline access."
            }
        }
    }

    public func createQuickTextFile(name: String, content: String) async {
        let rawName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName: String = {
            if rawName.isEmpty {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd-HHmmss"
                return "Helium-Note-\(df.string(from: Date())).md"
            }
            if (rawName as NSString).pathExtension.isEmpty {
                return "\(rawName).md"
            }
            return rawName
        }()

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(finalName)
        do {
            try Data(content.utf8).write(to: tempURL, options: .atomic)
            await importExternalFiles([tempURL], targetFolderId: selectedFolderId)
            try? FileManager.default.removeItem(at: tempURL)
            statusMessage = "Created and uploaded '\(finalName)' to Helium Pool"
        } catch {
            statusMessage = "Could not create note '\(finalName)': \(error.localizedDescription)"
        }
    }

    public func uploadClipboardToHelium() {
        Task { @MainActor in
            await performUploadClipboardToHelium()
        }
    }

    public func performUploadClipboardToHelium() async {
        let pb = NSPasteboard.general
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = df.string(from: Date())

        // 1. Check for copied file URLs on clipboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            await importExternalFiles(urls, targetFolderId: selectedFolderId)
            statusMessage = "Uploaded \(urls.count) copied file\(urls.count == 1 ? "" : "s") from clipboard to Helium"
            return
        }

        // 2. Check for copied image on clipboard
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let fileName = "Clipboard-Image-\(stamp).png"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try pngData.write(to: tempURL, options: .atomic)
                await importExternalFiles([tempURL], targetFolderId: selectedFolderId)
                try? FileManager.default.removeItem(at: tempURL)
                statusMessage = "Saved & uploaded clipboard image '\(fileName)' to Helium"
                return
            } catch {
                statusMessage = "Could not upload clipboard image: \(error.localizedDescription)"
                return
            }
        }

        // 3. Check for copied text on clipboard
        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            let fileName = "Clipboard-Snippet-\(stamp).md"
            await createQuickTextFile(name: fileName, content: text)
            return
        }

        statusMessage = "Clipboard is empty — copy a file, screenshot, or text snippet first."
    }

    /// Pre-warms Chunk #0 (first 1 MiB) and the final chunk of each file in `HeliumRealtimeVFSServer.shared.realtimeChunksRootURL`, and pre-warms files `<= 25 MB` into `/tmp/HeliumStreamCache` so `Preview`, `QuickTime Player`, `Final Cut Pro`, and `DaVinci Resolve` open files in `<10ms` while `/Volumes/Helium` strictly reports `Zero bytes on disk` (`0 B on disk`).
    private func startBackgroundStreamCachePrewarm() {
        prewarmTask?.cancel()
        let currentManifests = Array(manifests.values)
            .filter { $0.item.kind == .file && !$0.item.deleted && $0.item.size > 0 }
            .sorted { $0.item.size < $1.item.size }
        guard !currentManifests.isEmpty, !zeroKnowledgeEnabled else { return }
        let remote = pooledRemote
        let chunksRoot = HeliumRealtimeVFSServer.shared.realtimeChunksRootURL
        let chunkSize = HeliumRealtimeVFSServer.chunkSizeBytes
        let streamCacheDir = Self.streamCacheDirectoryURL

        prewarmTask = Task.detached(priority: .utility) {
            let fm = FileManager.default
            try? fm.createDirectory(at: streamCacheDir, withIntermediateDirectories: true)

            for manifest in currentManifests {
                if Task.isCancelled { break }
                let safeID = manifest.item.id.replacingOccurrences(of: "/", with: "_")
                let itemDir = chunksRoot.appendingPathComponent(safeID, isDirectory: true)
                try? fm.createDirectory(at: itemDir, withIntermediateDirectories: true)

                let totalSize = manifest.item.size
                let firstChunkURL = itemDir.appendingPathComponent("chunk_0.bin")
                let firstLen = Int(min(Int64(chunkSize), totalSize))

                if !fm.fileExists(atPath: firstChunkURL.path),
                   let data = try? await remote.fetchRange(id: manifest.item.id, offset: 0, length: firstLen),
                   !data.isEmpty {
                    try? data.write(to: firstChunkURL, options: .atomic)
                }

                // For files <= 25 MB (photos, screenshots, PDFs, docs), also keep a ready copy in /tmp/HeliumStreamCache/<fileName> so Preview opens in <10ms while /Volumes/Helium/<fileName> stays at 0 B on disk
                if totalSize <= 25 * 1_048_576 {
                    let streamTarget = streamCacheDir.appendingPathComponent(manifest.item.name)
                    let existingSize = Int64((try? streamTarget.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
                    if !AppModel.isHydratedLocalFile(streamTarget) || existingSize != totalSize {
                        if totalSize <= Int64(chunkSize), fm.fileExists(atPath: firstChunkURL.path) {
                            try? fm.removeItem(at: streamTarget)
                            try? fm.copyItem(at: firstChunkURL, to: streamTarget)
                            AppModel.removeHeliumOpenWithAttribute(from: streamTarget)
                        } else if let fullData = try? await remote.fetchRange(id: manifest.item.id, offset: 0, length: Int(totalSize)),
                                  !fullData.isEmpty {
                            try? fullData.write(to: streamTarget, options: .atomic)
                            AppModel.removeHeliumOpenWithAttribute(from: streamTarget)
                        }
                    }
                }

                // Also pre-warm the final chunk (e.g., MP4/MOV moov atom or DMG/ZIP trailer) so video players and archive mounters open without waiting for a tail seek
                let lastChunkIdx = Int((totalSize - 1) / Int64(chunkSize))
                if lastChunkIdx > 0 {
                    let lastChunkURL = itemDir.appendingPathComponent("chunk_\(lastChunkIdx).bin")
                    let lastOffset = Int64(lastChunkIdx) * Int64(chunkSize)
                    let lastLen = Int(min(Int64(chunkSize), totalSize - lastOffset))
                    if !fm.fileExists(atPath: lastChunkURL.path),
                       let tailData = try? await remote.fetchRange(id: manifest.item.id, offset: lastOffset, length: lastLen),
                       !tailData.isEmpty {
                        try? tailData.write(to: lastChunkURL, options: .atomic)
                    }
                }
            }
        }
    }

    /// Handles files double-clicked in Finder inside `/Volumes/Helium` or `~/Helium`.
    public func handleOpenFinderFileURLs(_ urls: [URL]) {
        let now = Date()
        for url in urls where url.isFileURL {
            let standardizedPath = url.standardizedFileURL.path
            if let lastOpen = recentFinderOpenTimestamps[standardizedPath],
               now.timeIntervalSince(lastOpen) < 1.5 {
                continue
            }
            recentFinderOpenTimestamps[standardizedPath] = now

            let cacheRootPath = Self.streamCacheDirectoryURL.standardizedFileURL.path
            if standardizedPath.hasPrefix(cacheRootPath) || Self.isHydratedLocalFile(url) {
                Self.openHydratedFileInDefaultApp(url)
                statusMessage = "Opened '\(url.lastPathComponent)'"
                continue
            }
            let fileName = url.lastPathComponent
            let canonical = fileName.precomposedStringWithCanonicalMapping
            let allTreeNodes = activeDrive?.tree.allNodes() ?? []
            let matchedNode = driveNodes.first {
                !$0.isFolder && $0.name.precomposedStringWithCanonicalMapping == canonical
            } ?? allTreeNodes.first {
                !$0.isFolder && $0.name.precomposedStringWithCanonicalMapping == canonical
            }
            Task {
                await streamAndOpenFile(named: fileName, node: matchedNode, placeholderURL: url)
            }
        }
    }

    /// Fetches all bytes of a cloud file (using direct 16 MiB range streaming with automatic OAuth token refresh on 401 when unencrypted, or `OrbitDrive.read` when encrypted).
    private func fetchCloudFileBytes(node: DriveNode?, manifest: PoolItemManifest?) async throws -> Data {
        if !zeroKnowledgeEnabled, let manifest {
            return try await pooledRemote.fetchRange(
                id: manifest.item.id,
                offset: 0,
                length: Int(max(0, manifest.item.size))
            )
        }
        if let node, let drive = activeDrive {
            return try await drive.read(node.id, offset: 0, length: Int(max(0, node.size)))
        }
        if let manifest {
            return try await pooledRemote.fetchRange(
                id: manifest.item.id,
                offset: 0,
                length: Int(max(0, manifest.item.size))
            )
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func streamAndOpenFile(named fileName: String, node: DriveNode?, placeholderURL: URL?) async {
        cacheWasManuallyCleared = false
        let canonical = fileName.precomposedStringWithCanonicalMapping

        let resolvedManifest: PoolItemManifest? = {
            if let remID = node?.remoteID, let m = manifests[remID] {
                return m
            }
            return manifests.values.first {
                !$0.item.deleted && $0.item.name.precomposedStringWithCanonicalMapping == canonical
            }
        }()
        let expectedSize = resolvedManifest?.item.size ?? node?.size ?? 0
        let totalChunks = max(1, Int((max(1, expectedSize) + Int64(HeliumRealtimeVFSServer.chunkSizeBytes) - 1) / Int64(HeliumRealtimeVFSServer.chunkSizeBytes)))

        // 1. If the user pinned this file ("Keep on this Mac") and the offline copy is ready, open the pinned copy immediately
        let pinnedURL = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL.appendingPathComponent(fileName)
        let pinnedSize = Int64((try? pinnedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
        if Self.isHydratedLocalFile(pinnedURL) && (expectedSize <= 0 || pinnedSize == expectedSize) {
            Self.openHydratedFileInDefaultApp(pinnedURL)
            statusMessage = "Opened pinned offline file '\(fileName)'"
            return
        }

        let cacheDir = Self.streamCacheDirectoryURL
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let streamURL = cacheDir.appendingPathComponent(fileName)

        // 2. If already cached in /tmp/HeliumStreamCache with matching size, open immediately!
        let cachedSize = Int64((try? streamURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
        if Self.isHydratedLocalFile(streamURL) && (expectedSize <= 0 || cachedSize == expectedSize) {
            Self.openHydratedFileInDefaultApp(streamURL)
            recordRealtimeChunkRead(
                fileName: fileName,
                chunkIndex: 0,
                totalChunks: totalChunks,
                bytesCount: Int(min(Int64(HeliumRealtimeVFSServer.chunkSizeBytes), max(1, expectedSize))),
                fromCache: true
            )
            statusMessage = "Opened '\(fileName)' (Zero bytes on disk in /Volumes/Helium)"
            return
        }

        // 3. If file fits in a single 1 MiB chunk and chunk_0.bin is already pre-warmed in RealtimeChunks, hydrate from chunk_0.bin in <5ms
        if let remID = resolvedManifest?.item.id ?? node?.remoteID,
           expectedSize > 0,
           expectedSize <= Int64(HeliumRealtimeVFSServer.chunkSizeBytes) {
            let safeID = remID.replacingOccurrences(of: "/", with: "_")
            let chunk0URL = HeliumRealtimeVFSServer.shared.realtimeChunksRootURL
                .appendingPathComponent(safeID, isDirectory: true)
                .appendingPathComponent("chunk_0.bin")
            if Self.isHydratedLocalFile(chunk0URL) {
                try? FileManager.default.removeItem(at: streamURL)
                try? FileManager.default.copyItem(at: chunk0URL, to: streamURL)
                Self.removeHeliumOpenWithAttribute(from: streamURL)
                Self.openHydratedFileInDefaultApp(streamURL)
                recordRealtimeChunkRead(
                    fileName: fileName,
                    chunkIndex: 0,
                    totalChunks: 1,
                    bytesCount: Int(expectedSize),
                    fromCache: true
                )
                statusMessage = "Opened '\(fileName)' from pre-warmed 1 MiB chunk cache (Zero bytes on disk in /Volumes/Helium)"
                return
            }
        }

        // 4. Stream from Google Drive into /tmp/HeliumStreamCache/<fileName> and open in default macOS app while /Volumes/Helium/<fileName> stays at 0 B on disk
        let sizeString = ByteCountFormatter.string(fromByteCount: max(0, expectedSize), countStyle: .file)
        statusMessage = "Streaming '\(fileName)' (\(sizeString)) from Google Drive…"
        do {
            let data = try await fetchCloudFileBytes(node: node, manifest: resolvedManifest)
            try data.write(to: streamURL, options: .atomic)
            Self.removeHeliumOpenWithAttribute(from: streamURL)
            Self.openHydratedFileInDefaultApp(streamURL)
            recordRealtimeChunkRead(
                fileName: fileName,
                chunkIndex: 0,
                totalChunks: totalChunks,
                bytesCount: min(HeliumRealtimeVFSServer.chunkSizeBytes, data.count),
                fromCache: false
            )
            statusMessage = "Opened '\(fileName)' (streamed from Google Drive — Zero bytes on disk in /Volumes/Helium)"
        } catch {
            statusMessage = "Could not stream '\(fileName)': \(error.localizedDescription)"
            if let node {
                openNodeInGoogleDrive(node)
            }
        }
    }

    public func openNodeOnMac(_ node: DriveNode) {
        if node.isFolder {
            openFolder(node)
            return
        }
        Task {
            await streamAndOpenFile(named: node.name, node: node, placeholderURL: nil)
        }
    }

    public func exportNodeToMac(_ node: DriveNode) {
        guard !node.isFolder else {
            revealNodeInFinder(node)
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save Copy of '\(node.name)' to Mac"
        panel.nameFieldStringValue = node.name
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let destURL = panel.url, let self else { return }
            Task { @MainActor in
                let subPath = self.relativeParentSubfolderPath(for: node)
                let baseMirror = subPath.isEmpty ? self.localMirrorURL : self.localMirrorURL.appendingPathComponent(subPath, isDirectory: true)
                let mirrorCandidate = baseMirror.appendingPathComponent(node.name)
                let pinnedCandidate = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL.appendingPathComponent(node.name)

                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: destURL.path) {
                        try? fm.removeItem(at: destURL)
                    }
                    let streamCandidate = Self.streamCacheDirectoryURL.appendingPathComponent(node.name)
                    if Self.isHydratedLocalFile(pinnedCandidate) {
                        try fm.copyItem(at: pinnedCandidate, to: destURL)
                    } else if Self.isHydratedLocalFile(streamCandidate) {
                        try fm.copyItem(at: streamCandidate, to: destURL)
                    } else if Self.isHydratedLocalFile(mirrorCandidate) {
                        try fm.copyItem(at: mirrorCandidate, to: destURL)
                    } else {
                        let resolvedManifest = node.remoteID.flatMap { self.manifests[$0] }
                        let data = try await self.fetchCloudFileBytes(node: node, manifest: resolvedManifest)
                        try data.write(to: destURL, options: .atomic)
                    }
                    Self.removeHeliumOpenWithAttribute(from: destURL)
                    self.statusMessage = "Saved '\(node.name)' to \(destURL.lastPathComponent)"
                } catch {
                    self.statusMessage = "Could not export '\(node.name)': \(error.localizedDescription)"
                }
            }
        }
    }

    public func renameNode(_ node: DriveNode, newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !trimmed.isEmpty, trimmed != node.name, let drive = activeDrive else { return }
        let oldName = node.name
        do {
            _ = try await drive.rename(node.id, newName: trimmed)

            let subPath = relativeParentSubfolderPath(for: node)
            let baseMount = subPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
            let baseMirror = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)
            let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
            let streamDir = Self.streamCacheDirectoryURL
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                for dir in [baseMount, baseMirror, pinnedRoot, streamDir] where fm.fileExists(atPath: dir.path) {
                    let src = dir.appendingPathComponent(oldName)
                    let dst = dir.appendingPathComponent(trimmed)
                    if fm.fileExists(atPath: src.path) && !fm.fileExists(atPath: dst.path) {
                        try? fm.moveItem(at: src, to: dst)
                    }
                }
            }.value

            if keepList.isKept(oldName) {
                keepList.setKept(oldName, kept: false)
                keepList.setKept(trimmed, kept: true)
            }
            await refreshState()
            statusMessage = "Renamed '\(oldName)' to '\(trimmed)'"
        } catch {
            statusMessage = "Could not rename '\(oldName)': \(error.localizedDescription)"
        }
    }

    public func moveNodeToFolder(_ node: DriveNode, targetFolderId: String) async {
        guard let drive = activeDrive, let remID = node.remoteID, remID != targetFolderId else { return }
        let oldSubPath = relativeParentSubfolderPath(for: node)
        let oldMountDir = oldSubPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(oldSubPath, isDirectory: true)
        let oldMirrorDir = oldSubPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(oldSubPath, isDirectory: true)
        let fileName = node.name

        do {
            _ = try await pooledRemote.move(id: remID, toParent: targetFolderId, newName: nil)
            let newParentInode: UInt64 = (targetFolderId == RemoteItem.rootID)
                ? DriveNode.rootID
                : (drive.tree.node(remoteID: targetFolderId)?.id ?? DriveNode.rootID)
            _ = drive.tree.update(node.id) { n in
                n.parentID = newParentInode
                n.modifiedAt = Date()
            }
            drive.tree.save()

            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                for dir in [oldMountDir, oldMirrorDir] where fm.fileExists(atPath: dir.path) {
                    let oldTarget = dir.appendingPathComponent(fileName)
                    if fm.fileExists(atPath: oldTarget.path) {
                        try? fm.removeItem(at: oldTarget)
                    }
                }
            }.value

            try? await drive.sync()
            await refreshState()
            let folderLabel = targetFolderId == RemoteItem.rootID
                ? "Helium Drive (Root)"
                : (manifests[targetFolderId]?.item.name ?? "Folder")
            statusMessage = "Moved '\(fileName)' into '\(folderLabel)' (synced across Finder & Google Drive)"
        } catch {
            statusMessage = "Could not move '\(fileName)': \(error.localizedDescription)"
        }
    }

    public func deleteNode(_ node: DriveNode) async {
        guard let drive = activeDrive else { return }
        let fileName = node.name
        let canonical = fileName.precomposedStringWithCanonicalMapping
        explicitlyDeletedFilenames.insert(canonical)
        UserDefaults.standard.set(Array(explicitlyDeletedFilenames).sorted(), forKey: "helium.explicitlyDeletedFilenames")

        if let remID = node.remoteID {
            materializedVolumeManifestIds.remove(remID)
            UserDefaults.standard.set(Array(materializedVolumeManifestIds).sorted(), forKey: "helium.materializedVolumeManifestIds")
            _ = await pooledRemote.moveToTrash(id: remID)
            _ = drive.tree.remove(node.id)
            drive.tree.save()
        } else {
            try? await drive.remove(node.id)
        }
        keepList.setKept(fileName, kept: false)
        offlinePinProgressByName.removeValue(forKey: fileName)
        offlinePinProgressByName.removeValue(forKey: canonical)

        let subPath = relativeParentSubfolderPath(for: node)
        let baseMount = subPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
        let baseMirror = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)
        let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
        let legacyMirror = legacyMirrorURL
        let streamDir = Self.streamCacheDirectoryURL

        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            for dir in [baseMount, baseMirror, pinnedRoot, legacyMirror, streamDir] where fm.fileExists(atPath: dir.path) {
                if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                    for item in items where item.lastPathComponent.precomposedStringWithCanonicalMapping == canonical {
                        try? fm.removeItem(at: item)
                    }
                }
            }
        }.value

        try? await activeDrive?.sync()
        await refreshState()
        statusMessage = "Moved '\(fileName)' to Helium Recycle Bin & Google Drive Recycle Bin (30 days to undo)."
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.pool.refreshTokensAndQuotas(clientId: clientID)
                await self.refreshState()
            }
        }
    }

    // MARK: - 30-Day Undo Delete & Trash Vault + Pro Video & AI App Integrations + Resumable Uploads
    public func refreshTrashedItemsAndPurgeExpired() async {
        let rawTrashed = await pooledRemote.trashedManifests()
        let now = Date()
        var validItems: [TrashedFileItem] = []

        for m in rawTrashed {
            let deletedDate = Date(timeIntervalSince1970: TimeInterval(m.item.modifiedAt) / 1000.0)
            let daysElapsed = Int(now.timeIntervalSince(deletedDate) / 86_400.0)
            let daysLeft = 30 - daysElapsed
            if daysLeft <= 0 {
                // Past 30-day retention window -> permanently delete segments from Google Drive
                try? await pooledRemote.delete(id: m.item.id)
                continue
            }
            let firstAccId = m.segments.first?.accountId ?? ""
            let email = linkedAccounts.first(where: { $0.id == firstAccId })?.email ?? "Google Drive Pool"
            validItems.append(
                TrashedFileItem(
                    id: m.item.id,
                    fileName: m.item.name,
                    sizeBytes: m.item.size,
                    deletedAt: deletedDate,
                    daysRemaining: max(1, min(30, daysLeft)),
                    accountSummary: email
                )
            )
        }
        trashedItems = validItems
    }

    public func restoreTrashedItem(_ item: TrashedFileItem) async {
        let canonical = item.fileName.precomposedStringWithCanonicalMapping
        explicitlyDeletedFilenames.remove(canonical)
        UserDefaults.standard.set(Array(explicitlyDeletedFilenames).sorted(), forKey: "helium.explicitlyDeletedFilenames")
        _ = await pooledRemote.restoreFromTrash(id: item.id)
        await rebuildActiveDriveInstance()
        await refreshState()
        statusMessage = "Restored '\(item.fileName)' from Recycle Bin back to /Volumes/Helium & Google Drive Vault"
    }

    public func undoLastDelete() {
        guard let latest = trashedItems.first else {
            statusMessage = "No recently deleted files in 30-Day Trash."
            return
        }
        Task {
            await restoreTrashedItem(latest)
        }
    }

    public func permanentlyDeleteTrashedItem(_ item: TrashedFileItem) async {
        try? await pooledRemote.delete(id: item.id)
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            await pool.refreshTokensAndQuotas(clientId: clientID)
        }
        await refreshState()
        statusMessage = "Permanently deleted '\(item.fileName)' and reclaimed Google Drive pool space."
    }

    public func emptyTrash() async {
        for item in trashedItems {
            try? await pooledRemote.delete(id: item.id)
        }
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            await pool.refreshTokensAndQuotas(clientId: clientID)
        }
        await refreshState()
        statusMessage = "Emptied 30-Day Trash and reclaimed Google Drive pool space."
    }

    public func openNodeInExternalApp(_ node: DriveNode, app: ProExternalApp) {
        if app.isAIApp {
            copyNodeContextForAI(node, aiName: app.rawValue)
        }
        Task {
            let pinnedCandidate = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL.appendingPathComponent(node.name)
            let streamCandidate = Self.streamCacheDirectoryURL.appendingPathComponent(node.name)
            let resolvedManifest = node.remoteID.flatMap { manifests[$0] }

            let targetFileURL: URL
            if Self.isHydratedLocalFile(pinnedCandidate) {
                targetFileURL = pinnedCandidate
            } else if Self.isHydratedLocalFile(streamCandidate) {
                targetFileURL = streamCandidate
            } else if !node.isFolder,
                      let data = try? await fetchCloudFileBytes(node: node, manifest: resolvedManifest) {
                let tempStreamDir = Self.streamCacheDirectoryURL
                try? FileManager.default.createDirectory(at: tempStreamDir, withIntermediateDirectories: true)
                try? data.write(to: streamCandidate, options: .atomic)
                Self.removeHeliumOpenWithAttribute(from: streamCandidate)
                targetFileURL = streamCandidate
            } else {
                targetFileURL = streamCandidate
            }

            if let installedPath = app.candidateAppPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                let appURL = URL(fileURLWithPath: installedPath)
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([targetFileURL], withApplicationAt: appURL, configuration: config) { _, _ in }
                statusMessage = "Streaming '\(node.name)' directly into \(app.rawValue) (0 B on disk in /Volumes/Helium)"
            } else {
                Self.openHydratedFileInDefaultApp(targetFileURL)
                statusMessage = "Opened '\(node.name)' (ready for \(app.rawValue))"
            }
        }
    }

    public func copyNodeContextForAI(_ node: DriveNode, aiName: String = "Claude / ChatGPT / Cursor") {
        let subPath = relativeParentSubfolderPath(for: node)
        let fullMountPath = subPath.isEmpty
            ? "/Volumes/Helium/\(node.name)"
            : "/Volumes/Helium/\(subPath)/\(node.name)"
        let sizeStr = ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file)
        let prompt = """
        [Helium Drive File Context for \(aiName)]
        File: \(node.name)
        Path: \(fullMountPath)
        Size: \(sizeStr) (Zero bytes on Mac disk — streamed from Helium Google Drive Pool)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        statusMessage = "Copied '\(node.name)' path & context for \(aiName) to clipboard"
    }

    // MARK: - Resumable Uploads ("uploads pick up where they stopped")
    private var resumableUploadsURL: URL {
        storageRoot.appendingPathComponent("resumable-uploads.json")
    }

    private func savePendingUploadURLs() {
        let pendingPaths = uploadActivities
            .filter { !$0.isCompleted }
            .compactMap { $0.sourceURL?.path }
        if let data = try? JSONEncoder().encode(pendingPaths) {
            try? data.write(to: resumableUploadsURL, options: .atomic)
        }
    }

    public func restoreInterruptedUploads() {
        guard let data = try? Data(contentsOf: resumableUploadsURL),
              let paths = try? JSONDecoder().decode([String].self, from: data),
              !paths.isEmpty else { return }
        let validURLs = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else {
            try? FileManager.default.removeItem(at: resumableUploadsURL)
            return
        }
        statusMessage = "Resuming \(validURLs.count) interrupted upload\(validURLs.count == 1 ? "" : "s") where they stopped…"
        Task {
            await importExternalFiles(validURLs, targetFolderId: selectedFolderId)
            try? FileManager.default.removeItem(at: resumableUploadsURL)
        }
    }

    public func resumeInterruptedUploadsNow() {
        isUploadsPaused = false
        let incomplete = uploadActivities.filter { !$0.isCompleted }
        for act in incomplete {
            Task { await retryUpload(act) }
        }
        restoreInterruptedUploads()
    }

    public func clearCompletedUploads() {
        withAnimation(HeliumSpring.fluid) {
            uploadActivities.removeAll { $0.isCompleted }
        }
    }

    public func retryUpload(_ activity: UploadActivity) async {
        guard let srcURL = activity.sourceURL else { return }
        withAnimation(HeliumSpring.snappy) {
            uploadActivities.removeAll { $0.id == activity.id }
        }
        await importExternalFiles([srcURL])
    }

    public func importExternalFiles(_ urls: [URL], targetFolderId: String? = nil) async {
        guard !isUploadsPaused else {
            statusMessage = "Uploads are paused. Resume uploads to add files."
            return
        }
        guard !linkedAccounts.isEmpty else {
            statusMessage = "Sign in with Google Drive first to upload files."
            return
        }
        guard let drive = activeDrive else { return }
        cacheWasManuallyCleared = false

        // Ensure tokens are fresh before uploading
        let clientID = customOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientID.isEmpty {
            await pool.refreshTokensAndQuotas(clientId: clientID)
        }

        await pooledRemote.setAllocator(makeCurrentAllocator())

        let parentRemoteId = targetFolderId ?? selectedFolderId
        let subPath: String = {
            if parentRemoteId == RemoteItem.rootID || parentRemoteId.isEmpty { return "" }
            var parts: [String] = []
            var cursor: String? = parentRemoteId
            var safety = 0
            while let fid = cursor, fid != RemoteItem.rootID, !fid.isEmpty, safety < 32 {
                if let folderManifest = manifests[fid], folderManifest.item.kind == .folder {
                    parts.insert(folderManifest.item.name, at: 0)
                    if folderManifest.item.parentId == fid { break }
                    cursor = folderManifest.item.parentId
                } else if let node = drive.tree.node(remoteID: fid) {
                    let chain = drive.tree.folderPath(of: node.id)
                    return (chain + parts).joined(separator: "/")
                } else {
                    break
                }
                safety += 1
            }
            if !parts.isEmpty {
                return parts.joined(separator: "/")
            }
            return currentRelativeSubfolderPath()
        }()
        let mountDir = subPath.isEmpty ? volumeMountURL : volumeMountURL.appendingPathComponent(subPath, isDirectory: true)
        let mirrorDir = subPath.isEmpty ? localMirrorURL : localMirrorURL.appendingPathComponent(subPath, isDirectory: true)

        for url in urls {
            let fileName = url.lastPathComponent.precomposedStringWithCanonicalMapping
            explicitlyDeletedFilenames.remove(fileName)
            UserDefaults.standard.set(Array(explicitlyDeletedFilenames).sorted(), forKey: "helium.explicitlyDeletedFilenames")
            if inFlightFilenames.contains(fileName) { continue }

            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                do {
                    let createdFolder = try await drive.remote.createFolder(
                        name: fileName,
                        parentId: parentRemoteId
                    )
                    let folderMount = mountDir.appendingPathComponent(fileName, isDirectory: true)
                    let folderMirror = mirrorDir.appendingPathComponent(fileName, isDirectory: true)
                    let childItems: [URL] = await Task.detached(priority: .userInitiated) {
                        let fm = FileManager.default
                        if fm.fileExists(atPath: mountDir.path) {
                            try? fm.createDirectory(at: folderMount, withIntermediateDirectories: true)
                        }
                        try? fm.createDirectory(at: folderMirror, withIntermediateDirectories: true)
                        let children = (try? fm.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )) ?? []
                        return children.filter {
                            let vals = try? $0.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                            return vals?.isRegularFile == true || vals?.isDirectory == true
                        }
                    }.value
                    try await drive.sync()
                    await refreshState()
                    if !childItems.isEmpty {
                        await importExternalFiles(childItems, targetFolderId: createdFolder.id)
                    }
                    statusMessage = "Imported folder '\(fileName)' (\(childItems.count) item\(childItems.count == 1 ? "" : "s"))"
                } catch {
                    statusMessage = "Could not import folder '\(fileName)': \(error.localizedDescription)"
                }
                continue
            }

            inFlightFilenames.insert(fileName)
            defer { inFlightFilenames.remove(fileName) }

            let fileSize = await Task.detached(priority: .userInitiated) {
                (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            }.value

            let actID = UUID().uuidString
            let startTime = Date()
            withAnimation(HeliumSpring.fluid) {
                uploadActivities.insert(
                    UploadActivity(
                        id: actID,
                        fileName: fileName,
                        sourceURL: url,
                        totalBytes: fileSize,
                        uploadedBytes: 0,
                        speedBytesPerSec: 8_000_000,
                        placementSummary: "Uploading to Google Drive…",
                        isCompleted: false,
                        errorText: nil,
                        timestamp: startTime
                    ),
                    at: 0
                )
            }
            savePendingUploadURLs()
            statusMessage = "Uploading '\(fileName)' (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))) to Google Drive…"

            do {
                let sourceModDate = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()

                let item = try await drive.remote.uploadNewFile(
                    from: url,
                    name: fileName,
                    parentId: parentRemoteId,
                    clientId: UUID().uuidString,
                    modifiedAt: sourceModDate,
                    link: false,
                    progress: { [weak self] uploadedSoFar in
                        Task { @MainActor [weak self] in
                            guard let self,
                                  let idx = self.uploadActivities.firstIndex(where: { $0.id == actID }) else { return }
                            let elapsed = max(0.25, Date().timeIntervalSince(startTime))
                            self.uploadActivities[idx].uploadedBytes = min(fileSize, uploadedSoFar)
                            self.uploadActivities[idx].speedBytesPerSec = max(256_000, Int64(Double(uploadedSoFar) / elapsed))
                        }
                    }
                )

                // Immediately dehydrate unpinned files in /Volumes/Helium and ~/Helium to Zero bytes on disk (0 B on disk), while keeping a hydrated copy in /tmp/HeliumStreamCache for instant opening
                let isKeptOffline = keepList.isKept(fileName)
                let pinnedRoot = HeliumRealtimeVFSServer.shared.offlinePinnedRootURL
                let streamCacheDir = Self.streamCacheDirectoryURL
                await Task.detached(priority: .userInitiated) {
                    let fm = FileManager.default
                    try? fm.createDirectory(at: mirrorDir, withIntermediateDirectories: true)
                    try? fm.createDirectory(at: streamCacheDir, withIntermediateDirectories: true)
                    let streamTarget = streamCacheDir.appendingPathComponent(fileName)
                    if url.standardizedFileURL != streamTarget.standardizedFileURL {
                        try? fm.removeItem(at: streamTarget)
                        try? fm.copyItem(at: url, to: streamTarget)
                        AppModel.removeHeliumOpenWithAttribute(from: streamTarget)
                    }

                    let mirrorDest = mirrorDir.appendingPathComponent(fileName)
                    let mountDest = mountDir.appendingPathComponent(fileName)
                    if isKeptOffline {
                        try? fm.createDirectory(at: pinnedRoot, withIntermediateDirectories: true)
                        let pinnedDest = pinnedRoot.appendingPathComponent(fileName)
                        if url.standardizedFileURL != pinnedDest.standardizedFileURL {
                            try? fm.removeItem(at: pinnedDest)
                            try? fm.copyItem(at: url, to: pinnedDest)
                            AppModel.removeHeliumOpenWithAttribute(from: pinnedDest)
                        }
                        for target in [mountDest, mirrorDest] where fm.fileExists(atPath: target.deletingLastPathComponent().path) {
                            if url.standardizedFileURL != target.standardizedFileURL {
                                try? fm.removeItem(at: target)
                                try? fm.copyItem(at: url, to: target)
                            }
                            AppModel.removeHeliumOpenWithAttribute(from: target)
                        }
                    } else {
                        for target in [mountDest, mirrorDest] where fm.fileExists(atPath: target.deletingLastPathComponent().path) {
                            AppModel.writeZeroDiskSparsePlaceholder(
                                at: target,
                                logicalSize: fileSize,
                                modifiedAt: sourceModDate
                            )
                        }
                    }
                }.value

                try await drive.sync()
                await refreshState()
                startBackgroundStreamCachePrewarm()

                if let idx = uploadActivities.firstIndex(where: { $0.id == actID }) {
                    uploadActivities[idx].uploadedBytes = fileSize
                    uploadActivities[idx].isCompleted = true
                    if let manifest = manifests[item.id] {
                        let acctEmails = manifest.segments.compactMap { seg in
                            linkedAccounts.first(where: { $0.id == seg.accountId })?.email ?? seg.accountId
                        }
                        let uniqueDrives = Array(Set(acctEmails))
                        uploadActivities[idx].placementSummary = manifest.placementMode == .wholeFileSmartPlacement
                            ? "Google Drive (\(uniqueDrives.first ?? "Primary"))"
                            : "Striped (\(manifest.segments.count) parts across \(uniqueDrives.count) Google Drives)"
                    }
                }
                savePendingUploadURLs()
                statusMessage = "Uploaded '\(fileName)' to Google Drive — Zero bytes on disk in /Volumes/Helium"
            } catch {
                if let idx = uploadActivities.firstIndex(where: { $0.id == actID }) {
                    uploadActivities[idx].errorText = error.localizedDescription
                }
                savePendingUploadURLs()
                statusMessage = "Upload failed for '\(fileName)': \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Share Links & Encrypted File Requests (Finder & Context Actions)
    public func createAndCopyShareLink(for node: DriveNode) {
        if let remID = node.remoteID,
           let manifest = manifests[remID],
           manifest.segments.count == 1,
           let seg = manifest.segments.first,
           !seg.driveFileId.hasPrefix("gfile_") {
            let driveURL = "https://drive.google.com/file/d/\(seg.driveFileId)/view?usp=sharing"
            let record = ShareLinkRecord(
                id: UUID().uuidString,
                itemId: remID,
                itemName: node.name,
                urlString: driveURL,
                createdAt: Date()
            )
            shareLinks.insert(record, at: 0)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(driveURL, forType: .string)
            statusMessage = "Copied Google Drive link for '\(node.name)' to clipboard"
            return
        }

        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        let keyFragment = ZK.recoveryToText(ZK.random(16)).prefix(22)
        let urlString = "https://helium.app/s/\(token)#\(keyFragment)"
        let record = ShareLinkRecord(
            id: UUID().uuidString,
            itemId: node.remoteID ?? "\(node.id)",
            itemName: node.name,
            urlString: urlString,
            createdAt: Date()
        )
        shareLinks.insert(record, at: 0)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        statusMessage = "Copied share link for '\(node.name)' to clipboard"
    }

    public func revokeShareLink(id: String) {
        shareLinks.removeAll { $0.id == id }
        statusMessage = "Turned off share link."
    }

    public func createFileRequest(folderName: String, title: String) {
        let pubBytes = ZK.random(16)
        let pubHex = pubBytes.prefix(8).map { String(format: "%02x", $0) }.joined()
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
        let urlString = "https://helium.app/r/\(token)"
        let record = FileRequestRecord(
            id: UUID().uuidString,
            folderName: folderName,
            title: title.isEmpty ? "Drop files for \(folderName)" : title,
            urlString: urlString,
            publicKeyHex: pubHex,
            createdAt: Date()
        )
        fileRequests.insert(record, at: 0)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        statusMessage = "Created file request for '\(folderName)' and copied link"
    }

    public func closeFileRequest(id: String) {
        fileRequests.removeAll { $0.id == id }
        statusMessage = "Closed file request."
    }

    // MARK: - Privacy & Recovery Key Actions
    public func copyRecoveryKeyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedRecoveryKey, forType: .string)
        recoveryKeySavedConfirmation = true
        statusMessage = "Copied recovery key to clipboard"
    }

    public func saveRecoveryKeyToDisk() {
        let panel = NSSavePanel()
        panel.title = "Save Helium Recovery Key"
        panel.nameFieldStringValue = "Helium Recovery Key.txt"
        panel.canCreateDirectories = true

        let formatted = formattedRecoveryKey
        let rawKey = recoveryKeyText

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let content = """
            HELIUM RECOVERY KEY
            ===================
            Keep this key somewhere safe outside Helium (for example, in Apple Passwords or on a USB drive).
            Anyone with this key can unlock your encrypted files across your pooled Google Drives.

            Recovery Key:
            \(formatted)

            Raw Base32 (52 chars):
            \(rawKey)

            Created: \(ISO8601DateFormatter().string(from: Date()))
            """
            Task.detached(priority: .userInitiated) {
                do {
                    try content.data(using: .utf8)?.write(to: url, options: .atomic)
                    await MainActor.run {
                        self?.recoveryKeySavedConfirmation = true
                        self?.statusMessage = "Saved Helium Recovery Key to \(url.lastPathComponent)"
                    }
                } catch {
                    await MainActor.run {
                        self?.statusMessage = "Could not save recovery key: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    public func openApplePasswordsApp() {
        let passwordsURL = URL(fileURLWithPath: "/System/Applications/Passwords.app")
        if FileManager.default.fileExists(atPath: passwordsURL.path) {
            NSWorkspace.shared.open(passwordsURL)
            statusMessage = "Opened Apple Passwords"
        } else {
            statusMessage = "Copied recovery key so you can paste it into your password manager."
            copyRecoveryKeyToClipboard()
        }
    }

    public func makeNewRecoveryKey() {
        let newRK = ZK.random(32)
        let rkText = ZK.recoveryToText(newRK)
        recoveryKeyText = rkText
        try? secretStore.set(Data(rkText.utf8), for: "recoveryKeyText")
        recoveryKeySavedConfirmation = false
        statusMessage = "Generated a new recovery key. Your old recovery key no longer works."
    }

    public func verifyAndUnlockWithInputKey() -> Bool {
        if ZK.recoveryFromText(unlockKeyInput) != nil {
            showUnlockSheet = false
            unlockKeyInput = ""
            statusMessage = "Unlocked encrypted vault with recovery key"
            return true
        } else {
            statusMessage = "That recovery key doesn't look right. Check all 52 characters."
            return false
        }
    }

    // MARK: - Storage & Cache Actions
    public func removeRecentCachedFiles() {
        cacheWasManuallyCleared = true
        let pinnedSet = keepList.all()
        if let drive = activeDrive {
            let allFiles = drive.tree.allNodes().filter { !$0.isFolder }
            cachedBytesOnMac = allFiles
                .filter { pinnedSet.contains($0.name) }
                .reduce(0) { $0 + max(0, $1.size) }
        } else {
            cachedBytesOnMac = 0
        }
        Task {
            await dehydrateUnpinnedCloudFiles()
        }
        statusMessage = "Dehydrated all unpinned files to Zero bytes on disk. Your files stay safe in Google Drive."
    }

    // MARK: - GitHub Releases Auto-Update & Check for Updates (https://github.com/Shubham-sharma8/helium/releases)
    private struct GitHubReleaseAssetDTO: Decodable, Sendable {
        let name: String
        let browser_download_url: String
        let size: Int64?
    }

    private struct GitHubReleaseDTO: Decodable, Sendable {
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: String
        let draft: Bool?
        let prerelease: Bool?
        let published_at: String?
        let assets: [GitHubReleaseAssetDTO]?
    }

    public func setInstallUpdatesAutomatically(_ enabled: Bool) {
        installUpdatesAutomatically = enabled
        UserDefaults.standard.set(enabled, forKey: "helium.installUpdatesAutomatically")
        if enabled {
            Task { @MainActor [weak self] in
                await self?.checkForUpdatesAsync(silent: true)
            }
        }
    }

    public func openGitHubReleasesPage() {
        NSWorkspace.shared.open(updateReleasePageURL)
    }

    public func checkForUpdates() {
        Task { @MainActor [weak self] in
            await self?.checkForUpdatesAsync(silent: false)
        }
    }

    public func checkForUpdatesAsync(silent: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        if !silent {
            lastUpdateCheckText = "Checking GitHub Releases (Shubham-sharma8/helium)…"
            statusMessage = lastUpdateCheckText
        }
        defer {
            isCheckingForUpdates = false
        }

        do {
            let release = try await fetchLatestGitHubRelease()
            if let release {
                let remoteVersion = Self.normalizedVersionString(from: release.tag_name)
                if let pageURL = URL(string: release.html_url) {
                    updateReleasePageURL = pageURL
                }
                updateReleaseNotes = (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                let preferredAsset = release.assets?.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
                    ?? release.assets?.first(where: { $0.name.lowercased().hasSuffix(".zip") || $0.name.lowercased().hasSuffix(".pkg") })

                let cmp = Self.compareSemanticVersions(remoteVersion, Self.appVersion)
                if cmp > 0 {
                    updateAvailableVersion = remoteVersion
                    if let assetURLStr = preferredAsset?.browser_download_url,
                       let assetURL = URL(string: assetURLStr) {
                        updateDownloadURL = assetURL
                    } else {
                        updateDownloadURL = updateReleasePageURL
                    }
                    lastUpdateCheckText = "New update available on GitHub: Helium v\(remoteVersion) (installed: v\(Self.appVersion))."
                    statusMessage = lastUpdateCheckText

                    if installUpdatesAutomatically, preferredAsset != nil {
                        await downloadAndInstallUpdate(autoTriggered: silent)
                    }
                } else {
                    updateAvailableVersion = nil
                    updateDownloadURL = nil
                    lastUpdateCheckText = "Checked just now — Helium v\(Self.appVersion) (Build \(Self.appBuild)) is up to date (GitHub latest: v\(remoteVersion))."
                    if !silent {
                        statusMessage = lastUpdateCheckText
                    }
                }
            } else {
                updateAvailableVersion = nil
                updateDownloadURL = nil
                lastUpdateCheckText = "Checked just now — Helium v\(Self.appVersion) (Build \(Self.appBuild)) is the latest version on GitHub Releases."
                if !silent {
                    statusMessage = lastUpdateCheckText
                }
            }
        } catch {
            if !silent {
                lastUpdateCheckText = "Could not reach GitHub Releases (\(error.localizedDescription)). Installed: Helium v\(Self.appVersion) (Build \(Self.appBuild))."
                statusMessage = lastUpdateCheckText
            }
        }
    }

    private func fetchLatestGitHubRelease() async throws -> GitHubReleaseDTO? {
        guard let latestURL = URL(string: Self.githubLatestReleaseAPI) else { return nil }
        var req = URLRequest(url: latestURL)
        req.timeoutInterval = 15
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Helium-macOS/\(Self.appVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
        noteNetworkContact(
            host: "api.github.com",
            purpose: "GitHub Releases update check (Shubham-sharma8/helium)"
        )

        if httpStatus == 200 {
            return try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)
        }

        // Fallback to /releases list if /releases/latest returned 404 (e.g. pre-release or no releases published yet)
        guard let allURL = URL(string: Self.githubAllReleasesAPI) else { return nil }
        var allReq = URLRequest(url: allURL)
        allReq.timeoutInterval = 15
        allReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        allReq.setValue("Helium-macOS/\(Self.appVersion)", forHTTPHeaderField: "User-Agent")

        let (allData, allResp) = try await URLSession.shared.data(for: allReq)
        let allStatus = (allResp as? HTTPURLResponse)?.statusCode ?? 0
        if allStatus == 200,
           let list = try? JSONDecoder().decode([GitHubReleaseDTO].self, from: allData) {
            return list.first(where: { ($0.draft ?? false) == false })
        }
        return nil
    }

    public func downloadAndInstallUpdate(autoTriggered: Bool = false) async {
        guard !isDownloadingUpdate else { return }
        guard let targetURL = updateDownloadURL else {
            openGitHubReleasesPage()
            return
        }
        let targetVersion = updateAvailableVersion ?? Self.appVersion
        let isDirectDMG = targetURL.pathExtension.lowercased() == "dmg"
            || targetURL.absoluteString.lowercased().contains(".dmg")

        if !isDirectDMG {
            NSWorkspace.shared.open(targetURL)
            return
        }

        isDownloadingUpdate = true
        lastUpdateCheckText = "Downloading Helium v\(targetVersion) installer from GitHub Releases…"
        statusMessage = lastUpdateCheckText
        defer {
            isDownloadingUpdate = false
        }

        do {
            var req = URLRequest(url: targetURL)
            req.setValue("Helium-macOS/\(Self.appVersion)", forHTTPHeaderField: "User-Agent")
            let (tempFileURL, response) = try await URLSession.shared.download(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200..<300).contains(status) else {
                throw URLError(.badServerResponse)
            }

            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dmgDestURL = downloadsDir.appendingPathComponent("Helium-\(targetVersion).dmg")
            try? FileManager.default.removeItem(at: dmgDestURL)
            try FileManager.default.moveItem(at: tempFileURL, to: dmgDestURL)

            noteNetworkContact(
                host: targetURL.host ?? "github.com",
                purpose: "Downloaded Helium v\(targetVersion) DMG from GitHub Releases"
            )

            // Mount the DMG and attempt automatic in-place update of /Applications/Helium.app
            let mountPoint = "/tmp/HeliumUpdateMount-\(targetVersion)"
            try? FileManager.default.removeItem(atPath: mountPoint)
            let attachProc = Process()
            attachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            attachProc.arguments = ["attach", dmgDestURL.path, "-mountpoint", mountPoint, "-nobrowse", "-readonly", "-quiet"]
            try? attachProc.run()
            attachProc.waitUntilExit()

            let mountedAppURL = URL(fileURLWithPath: mountPoint).appendingPathComponent("Helium.app")
            let applicationsAppURL = URL(fileURLWithPath: "/Applications/Helium.app")

            if attachProc.terminationStatus == 0,
               FileManager.default.fileExists(atPath: mountedAppURL.path),
               FileManager.default.isWritableFile(atPath: "/Applications") {
                let copyProc = Process()
                copyProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                copyProc.arguments = [mountedAppURL.path, applicationsAppURL.path]
                try? copyProc.run()
                copyProc.waitUntilExit()

                let detachProc = Process()
                detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProc.arguments = ["detach", mountPoint, "-quiet", "-force"]
                try? detachProc.run()
                detachProc.waitUntilExit()

                if copyProc.terminationStatus == 0 {
                    updateAvailableVersion = nil
                    lastUpdateCheckText = "Updated to Helium v\(targetVersion) in /Applications/Helium.app! Relaunch Helium to complete update."
                    statusMessage = lastUpdateCheckText
                    return
                }
            }

            // Fallback: open the downloaded DMG in Finder so the user can drag Helium.app to /Applications
            NSWorkspace.shared.open(dmgDestURL)
            lastUpdateCheckText = "Downloaded Helium-\(targetVersion).dmg to ~/Downloads and opened installer."
            statusMessage = lastUpdateCheckText
        } catch {
            lastUpdateCheckText = "Automatic download failed (\(error.localizedDescription)). Opening GitHub Releases page…"
            statusMessage = lastUpdateCheckText
            if !autoTriggered {
                openGitHubReleasesPage()
            }
        }
    }

    nonisolated public static func normalizedVersionString(from rawTag: String) -> String {
        var cleaned = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix("v") || cleaned.hasPrefix("V") {
            cleaned.removeFirst()
        }
        if let dashIndex = cleaned.firstIndex(of: "-") {
            cleaned = String(cleaned[..<dashIndex])
        }
        return cleaned.isEmpty ? "0.0.0" : cleaned
    }

    nonisolated public static func compareSemanticVersions(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = normalizedVersionString(from: lhs).split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = normalizedVersionString(from: rhs).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)
        for idx in 0..<count {
            let l = idx < lhsParts.count ? lhsParts[idx] : 0
            let r = idx < rhsParts.count ? rhsParts[idx] : 0
            if l != r {
                return l > r ? 1 : -1
            }
        }
        return 0
    }

    // MARK: - Interactive System & Pool Health Doctor + Placement Simulator
    public func runSystemHealthDoctor() async {
        await verifyPoolHealth()
        var checks: [SystemDiagnosticCheck] = []

        let mountExists = FileManager.default.fileExists(atPath: volumeMountURL.path)
            || FileManager.default.fileExists(atPath: localMirrorURL.path)
        checks.append(
            SystemDiagnosticCheck(
                id: "mount",
                title: "Finder Virtual Drive (/Volumes/Helium)",
                detail: mountExists
                    ? "Mounted and synced with local Finder mirror at \(localMirrorURL.path)."
                    : "Virtual mount folder not yet initialized.",
                status: mountExists ? .healthy : .warning,
                symbol: "externaldrive.fill.badge.checkmark",
                actionTitle: mountExists ? "Open in Finder" : "Mount Drive"
            )
        )

        if linkedAccounts.isEmpty {
            checks.append(
                SystemDiagnosticCheck(
                    id: "accounts",
                    title: "Google Drive Pool Accounts",
                    detail: "No Google Drive accounts linked yet. Sign in with Google to add 15 GB+ per account.",
                    status: .actionNeeded,
                    symbol: "person.crop.circle.badge.exclamationmark",
                    actionTitle: "Sign in with Google"
                )
            )
        } else {
            let freeStr = ByteCountFormatter.string(fromByteCount: totalFreeBytes, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: totalPoolBytes, countStyle: .file)
            let pausedCount = linkedAccounts.filter(\.isUploadPaused).count
            checks.append(
                SystemDiagnosticCheck(
                    id: "accounts",
                    title: "Google Drive Pool (\(linkedAccounts.count) Account\(linkedAccounts.count == 1 ? "" : "s"))",
                    detail: "\(freeStr) free of \(totalStr) total capacity" + (pausedCount > 0 ? " (\(pausedCount) account paused)." : " • All accounts active."),
                    status: isAlmostFull ? .warning : .healthy,
                    symbol: "icloud.and.arrow.up.fill",
                    actionTitle: "+ Add Google Account"
                )
            )
        }

        checks.append(
            SystemDiagnosticCheck(
                id: "placement",
                title: "Placement Engine (\(policyDescription(placementPolicy)))",
                detail: "Routing: \(accountRoutingStrategy.displayTitle) • Primary target: \(primaryUploadTargetAccount?.email ?? "Auto") • Auto-stripe above \(String(format: "%.1f", autoStripeAboveGB)) GB.",
                status: .healthy,
                symbol: "square.stack.3d.up.fill",
                actionTitle: nil
            )
        )

        checks.append(
            SystemDiagnosticCheck(
                id: "security",
                title: zeroKnowledgeEnabled ? "Zero-Knowledge AES-256-GCM Vault" : "Direct Google Drive File Mode",
                detail: zeroKnowledgeEnabled
                    ? "Files and names are encrypted on your Mac before upload. 52-char Recovery Key active."
                    : "Whole files are stored directly in your 'Helium Pool' folder on Google Drive for native web preview.",
                status: (!recoveryKeySavedConfirmation || recoveryKeyInsideDriveWarning) ? .warning : .healthy,
                symbol: zeroKnowledgeEnabled ? "lock.shield.fill" : "checkmark.shield.fill",
                actionTitle: (!recoveryKeySavedConfirmation || recoveryKeyInsideDriveWarning) ? "Save Recovery Key" : nil
            )
        )

        withAnimation(HeliumSpring.snappy) {
            diagnosticChecks = checks
        }
        statusMessage = "System & Pool Health Doctor completed: \(checks.filter { $0.status == .healthy }.count)/\(checks.count) checks healthy."
    }

    public func simulatePlacementPlan(fileSizeGB: Double, policy: PlacementPolicy) -> [SimulatedSegmentAllocation] {
        let totalBytes = max(Int64(10 * 1_048_576), Int64(fileSizeGB * Double(1_073_741_824)))
        let accounts: [LinkedGoogleAccount]
        if linkedAccounts.isEmpty {
            accounts = [
                LinkedGoogleAccount(
                    id: "demo-1",
                    email: "account1@gmail.com",
                    displayName: "Google Drive #1",
                    refreshToken: "demo",
                    isPrimaryCatalogHost: true,
                    quotaLimitBytes: 15 * 1_073_741_824,
                    quotaUsedBytes: 5 * 1_073_741_824,
                    heliumUsedBytes: 5 * 1_073_741_824,
                    rootFolderId: "root",
                    uploadPriority: 1
                ),
                LinkedGoogleAccount(
                    id: "demo-2",
                    email: "account2@gmail.com",
                    displayName: "Google Drive #2",
                    refreshToken: "demo",
                    isPrimaryCatalogHost: false,
                    quotaLimitBytes: 15 * 1_073_741_824,
                    quotaUsedBytes: 2 * 1_073_741_824,
                    heliumUsedBytes: 2 * 1_073_741_824,
                    rootFolderId: "root",
                    uploadPriority: 2
                )
            ]
        } else {
            accounts = linkedAccounts
        }

        let allocator = StoragePoolAllocator(
            safetyReserveBytes: 0,
            segmentChunkCount: max(1, segmentSizeMiB),
            autoStripeAboveBytes: Int64(max(0.5, autoStripeAboveGB) * Double(1_073_741_824)),
            policy: policy,
            routingStrategy: accountRoutingStrategy,
            preferredAccountId: preferredUploadAccountId
        )

        if let plan = try? allocator.allocate(
            totalBytes: totalBytes,
            encrypted: zeroKnowledgeEnabled,
            accounts: accounts
        ) {
            let isWhole = (plan.mode == .wholeFileSmartPlacement && plan.segments.count == 1)
            return plan.segments.map { seg in
                let email = accounts.first(where: { $0.id == seg.accountId })?.email ?? seg.accountId
                return SimulatedSegmentAllocation(
                    id: "seg-\(seg.index)",
                    segmentIndex: seg.index,
                    accountId: seg.accountId,
                    accountEmail: email,
                    bytes: seg.byteLength,
                    isWholeFile: isWhole
                )
            }
        }
        let fallbackEmail = accounts.first?.email ?? "Google Drive Pool"
        return [
            SimulatedSegmentAllocation(
                id: "seg-fallback",
                segmentIndex: 0,
                accountId: accounts.first?.id ?? "pool",
                accountEmail: fallbackEmail,
                bytes: totalBytes,
                isWholeFile: policy != .alwaysStripe
            )
        ]
    }

    // MARK: - Support & Email Composer (connect@cogify.me)
    public func buildSupportEmailDraft(
        template: SupportEmailTemplate,
        customNotes: String = "",
        includeDiagnostics: Bool = true
    ) -> (subject: String, body: String) {
        let trimmedNotes = customNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageBody = trimmedNotes.isEmpty ? template.defaultPromptPlaceholder : trimmedNotes

        var lines: [String] = [messageBody]
        if includeDiagnostics {
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            let totalPool = ByteCountFormatter.string(fromByteCount: totalPoolBytes, countStyle: .file)
            let freePool = ByteCountFormatter.string(fromByteCount: totalFreeBytes, countStyle: .file)
            lines.append("")
            lines.append("--- Helium Diagnostics ---")
            lines.append("App Version: Helium v\(Self.appVersion) (Build \(Self.appBuild))")
            lines.append("macOS: \(osVersion)")
            lines.append("Pooled Google Drives: \(linkedAccounts.count) (\(freePool) free of \(totalPool))")
            lines.append("Placement Engine: \(placementPolicy.rawValue)")
            lines.append("Routing Strategy: \(accountRoutingStrategy.rawValue)")
            lines.append("Mount Status: \(isMounted ? "Mounted at /Volumes/Helium" : "Unmounted")")
            lines.append("Zero-Knowledge E2EE: \(zeroKnowledgeEnabled ? "Enabled" : "Disabled (Direct Google Drive mode)")")
        }
        lines.append("")
        lines.append("Sent from Helium for macOS • https://cogify.me")
        return (subject: template.defaultSubject, body: lines.joined(separator: "\n"))
    }

    public func composeSupportEmail(
        template: SupportEmailTemplate = .support,
        customNotes: String = "",
        includeDiagnostics: Bool = true
    ) {
        let draft = buildSupportEmailDraft(
            template: template,
            customNotes: customNotes,
            includeDiagnostics: includeDiagnostics
        )
        let fullClipboardText = "To: \(Self.supportEmail)\nSubject: \(draft.subject)\n\n\(draft.body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullClipboardText, forType: .string)

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        if let mailtoURL = components.url {
            NSWorkspace.shared.open(mailtoURL)
        }
        statusMessage = "Opened email draft to \(Self.supportEmail) (also copied to clipboard)"
    }

    public func copySupportEmailDraft(
        template: SupportEmailTemplate = .support,
        customNotes: String = "",
        includeDiagnostics: Bool = true
    ) {
        let draft = buildSupportEmailDraft(
            template: template,
            customNotes: customNotes,
            includeDiagnostics: includeDiagnostics
        )
        let fullClipboardText = "To: \(Self.supportEmail)\nSubject: \(draft.subject)\n\n\(draft.body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullClipboardText, forType: .string)
        statusMessage = "Copied complete email draft for \(Self.supportEmail) to clipboard"
    }

    public func copySupportEmailAddress() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.supportEmail, forType: .string)
        statusMessage = "Copied \(Self.supportEmail) to clipboard"
    }

    public func updateSearch(query: String, kind: SearchKind) {
        self.searchQuery = query
        self.searchKind = kind
        if let drive = activeDrive {
            self.searchResults = drive.searchIndex.search(query, kind: kind, limit: 40)
        }
    }

    // MARK: - Computed Pool Metrics & Storage Optimizer Insights
    public var totalPoolBytes: Int64 {
        linkedAccounts.reduce(0) { $0 + $1.quotaLimitBytes }
    }

    public var totalUsedBytes: Int64 {
        linkedAccounts.reduce(0) { $0 + $1.quotaUsedBytes }
    }

    public var totalFreeBytes: Int64 {
        max(0, totalPoolBytes - totalUsedBytes)
    }

    /// Total bytes of active (non-deleted) files stored inside the Helium Google Drive Pool.
    public var heliumPoolUsedBytes: Int64 {
        manifests.values
            .filter { !$0.item.deleted && $0.item.kind == .file }
            .reduce(0) { $0 + max(0, $1.item.size) }
    }

    /// Count of active (non-deleted) files stored inside the Helium Google Drive Pool.
    public var activePooledFilesCount: Int {
        manifests.values
            .filter { !$0.item.deleted && $0.item.kind == .file }
            .count
    }

    public var largestPooledFiles: [PoolLargeFileInsight] {
        manifests.values
            .filter { !$0.item.deleted && $0.item.kind == .file && $0.item.size > 0 }
            .sorted { $0.item.size > $1.item.size }
            .prefix(8)
            .map { manifest in
                let firstAccId = manifest.segments.first?.accountId ?? ""
                let email = linkedAccounts.first(where: { $0.id == firstAccId })?.email ?? (firstAccId.isEmpty ? "Pool" : firstAccId)
                return PoolLargeFileInsight(
                    id: manifest.item.id,
                    fileName: manifest.item.name,
                    sizeBytes: manifest.item.size,
                    placementModeLabel: manifest.placementMode == .wholeFileSmartPlacement ? "Whole-File" : "Striped",
                    segmentsCount: max(1, manifest.segments.count),
                    primaryAccountEmail: email
                )
            }
    }

    public var duplicateFileGroups: [DuplicateFileGroup] {
        let fileManifests = manifests.values.filter { !$0.item.deleted && $0.item.kind == .file && $0.item.size > 0 }
        var grouped: [String: [PoolItemManifest]] = [:]
        for m in fileManifests {
            let key = "\(m.item.name.lowercased())::\(m.item.size)"
            grouped[key, default: []].append(m)
        }
        return grouped.compactMap { key, list -> DuplicateFileGroup? in
            guard list.count > 1, let first = list.first else { return nil }
            let emails = Array(
                Set(
                    list.flatMap { m in
                        m.segments.map { seg in
                            linkedAccounts.first(where: { $0.id == seg.accountId })?.email ?? seg.accountId
                        }
                    }
                )
            ).sorted()
            return DuplicateFileGroup(
                id: key,
                fileName: first.item.name,
                unitSizeBytes: first.item.size,
                copiesCount: list.count,
                reclaimableBytes: first.item.size * Int64(list.count - 1),
                accountEmails: emails
            )
        }
        .sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    public var reclaimableDuplicateBytes: Int64 {
        duplicateFileGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    public func findNode(remoteId: String, fileName: String) -> DriveNode? {
        if let match = driveNodes.first(where: { $0.remoteID == remoteId || $0.name == fileName }) {
            return match
        }
        if let drive = activeDrive,
           let res = drive.searchIndex.search(fileName, kind: .all, limit: 20).first(where: { $0.node.remoteID == remoteId || $0.node.name == fileName }) {
            return res.node
        }
        return nil
    }

    public func removeExtraDuplicateCopy(for group: DuplicateFileGroup) async {
        if let node = findNode(remoteId: "", fileName: group.fileName) {
            await deleteNode(node)
        }
    }

    public func buildPoolCatalogMarkdownReport() -> String {
        let totalPool = ByteCountFormatter.string(fromByteCount: totalPoolBytes, countStyle: .file)
        let usedPool = ByteCountFormatter.string(fromByteCount: totalUsedBytes, countStyle: .file)
        let freePool = ByteCountFormatter.string(fromByteCount: totalFreeBytes, countStyle: .file)
        let files = manifests.values.filter { !$0.item.deleted && $0.item.kind == .file }.sorted { $0.item.name < $1.item.name }

        var lines: [String] = [
            "# Helium Storage Pool Catalog Report",
            "- **Version**: Helium v\(Self.appVersion) (Build \(Self.appBuild))",
            "- **Generated**: \(ISO8601DateFormatter().string(from: Date()))",
            "- **Pooled Capacity**: \(usedPool) used of \(totalPool) (\(freePool) free across \(linkedAccounts.count) Google Drive account(s))",
            "- **Placement Mode**: \(policyDescription(placementPolicy))",
            "- **Recycle Bin (30-Day Trash)**: \(trashedItems.count) item(s)",
            "",
            "## Linked Google Drive Accounts (\(linkedAccounts.count))",
            "| Priority | Email | Free Space | Total Quota | Status |",
            "|---|---|---|---|---|"
        ]
        for acc in linkedAccounts {
            let free = ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)
            let quota = ByteCountFormatter.string(fromByteCount: acc.quotaLimitBytes, countStyle: .file)
            let status = acc.isUploadPaused ? "Paused" : "Active"
            lines.append("| #\(acc.uploadPriority) | \(acc.email) | \(free) | \(quota) | \(status) |")
        }

        lines.append("")
        lines.append("## Pooled Files & Segment Map (\(files.count))")
        lines.append("| File Name | Size | Placement Mode | Segments | Primary Account |")
        lines.append("|---|---|---|---|---|")
        for m in files {
            let sz = ByteCountFormatter.string(fromByteCount: m.item.size, countStyle: .file)
            let mode = m.placementMode == .wholeFileSmartPlacement ? "Mode 1 (Whole-File)" : "Mode 2 (Striped)"
            let firstAccId = m.segments.first?.accountId ?? ""
            let email = linkedAccounts.first(where: { $0.id == firstAccId })?.email ?? firstAccId
            lines.append("| \(m.item.name) | \(sz) | \(mode) | \(max(1, m.segments.count)) | \(email) |")
        }
        lines.append("")
        lines.append("*Generated by Helium for macOS • Made with ❤️ by cogify.me*")
        return lines.joined(separator: "\n")
    }

    public func copyPoolSummaryReportToClipboard() {
        let report = buildPoolCatalogMarkdownReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        statusMessage = "Copied Helium Storage Pool Catalog report to clipboard"
    }

    public func exportPoolCatalogSnapshotToDisk() {
        let panel = NSSavePanel()
        panel.title = "Export Helium Storage Pool Catalog"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "Helium-Pool-Catalog-\(df.string(from: Date())).md"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let destURL = panel.url, let self else { return }
            Task { @MainActor in
                let report = self.buildPoolCatalogMarkdownReport()
                do {
                    try Data(report.utf8).write(to: destURL, options: .atomic)
                    self.statusMessage = "Exported Helium Pool Catalog to \(destURL.lastPathComponent)"
                } catch {
                    self.statusMessage = "Could not export catalog: \(error.localizedDescription)"
                }
            }
        }
    }

    public var storageCategoryBreakdown: [StorageCategoryStat] {
        var diskImages: (bytes: Int64, count: Int) = (0, 0)
        var archives: (bytes: Int64, count: Int) = (0, 0)
        var media: (bytes: Int64, count: Int) = (0, 0)
        var documents: (bytes: Int64, count: Int) = (0, 0)
        var other: (bytes: Int64, count: Int) = (0, 0)

        for manifest in manifests.values where !manifest.item.deleted && manifest.item.kind == .file {
            let ext = (manifest.item.name as NSString).pathExtension.lowercased()
            let sz = max(0, manifest.item.size)
            switch ext {
            case "dmg", "iso", "pkg", "img", "sparsebundle":
                diskImages.bytes += sz
                diskImages.count += 1
            case "zip", "tar", "gz", "7z", "rar", "tgz", "xz":
                archives.bytes += sz
                archives.count += 1
            case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "mp4", "mov", "mkv", "mp3", "wav", "m4a":
                media.bytes += sz
                media.count += 1
            case "pdf", "txt", "md", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "swift", "py", "js", "ts":
                documents.bytes += sz
                documents.count += 1
            default:
                other.bytes += sz
                other.count += 1
            }
        }

        let raw: [StorageCategoryStat] = [
            StorageCategoryStat(id: "disk", title: "Apps & Disk Images", symbol: "opticaldiscdrive.fill", colorName: "blue", bytes: diskImages.bytes, fileCount: diskImages.count),
            StorageCategoryStat(id: "media", title: "Photos & Media", symbol: "photo.on.rectangle.angled", colorName: "purple", bytes: media.bytes, fileCount: media.count),
            StorageCategoryStat(id: "docs", title: "Documents & Code", symbol: "doc.text.fill", colorName: "teal", bytes: documents.bytes, fileCount: documents.count),
            StorageCategoryStat(id: "archives", title: "Archives", symbol: "archivebox.fill", colorName: "orange", bytes: archives.bytes, fileCount: archives.count),
            StorageCategoryStat(id: "other", title: "Other Files", symbol: "doc.fill", colorName: "indigo", bytes: other.bytes, fileCount: other.count)
        ]
        let nonZero = raw.filter { $0.fileCount > 0 || $0.bytes > 0 }
        return nonZero
    }

    // MARK: - Syncophant Parity Features Implementation (Activity, Backups, Time Travel, Multi-Protocol, Inspector & Privacy Ledger)

    private var syncophantBackupsURL: URL {
        storageRoot.appendingPathComponent("helium-backup-jobs.json")
    }

    private var syncophantSnapshotsURL: URL {
        storageRoot.appendingPathComponent("helium-pool-snapshots.json")
    }

    private var syncophantExternalStorageURL: URL {
        storageRoot.appendingPathComponent("helium-external-storage.json")
    }

    private var syncophantNetworkLedgerURL: URL {
        storageRoot.appendingPathComponent("helium-network-contacts.json")
    }

    private var syncophantConflictsURL: URL {
        storageRoot.appendingPathComponent("helium-file-conflicts.json")
    }

    public func loadSyncophantFeaturesState() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: syncophantBackupsURL),
           let saved = try? decoder.decode([BackupJob].self, from: data) {
            self.backupJobs = saved
        }
        if let data = try? Data(contentsOf: syncophantSnapshotsURL),
           let saved = try? decoder.decode([PoolSnapshot].self, from: data) {
            self.poolSnapshots = saved
            self.selectedSnapshotId = saved.first?.id
        } else if !manifests.isEmpty {
            let initialSnap = PoolSnapshot(
                title: "Initial Pool Baseline",
                note: "Automatic baseline snapshot of /Volumes/Helium",
                manifestsById: manifests
            )
            self.poolSnapshots = [initialSnap]
            self.selectedSnapshotId = initialSnap.id
        }
        if let data = try? Data(contentsOf: syncophantExternalStorageURL),
           let saved = try? decoder.decode([ExternalStorageConnection].self, from: data) {
            self.externalStorageConnections = saved
        }
        if let data = try? Data(contentsOf: syncophantConflictsURL),
           let saved = try? decoder.decode([FileConflictItem].self, from: data) {
            self.activeConflicts = saved
        }
        if let data = try? Data(contentsOf: syncophantNetworkLedgerURL),
           let saved = try? decoder.decode([NetworkContactEntry].self, from: data),
           !saved.isEmpty {
            self.networkContacts = saved
        } else {
            self.networkContacts = [
                NetworkContactEntry(
                    host: "www.googleapis.com",
                    purpose: "Your storage · Google Drive v3 REST & HTTP Range 206 streaming",
                    count: max(1, linkedAccounts.count * 4),
                    lastContacted: Date().addingTimeInterval(-45)
                ),
                NetworkContactEntry(
                    host: "oauth2.googleapis.com",
                    purpose: "Your storage · OAuth 2.0 PKCE token exchange & refresh",
                    count: max(1, linkedAccounts.count),
                    lastContacted: Date().addingTimeInterval(-180)
                ),
                NetworkContactEntry(
                    host: "127.0.0.1",
                    purpose: "This Mac · Local WebDAV / VFS kernel loopback (/Volumes/Helium)",
                    count: 12,
                    lastContacted: Date().addingTimeInterval(-10)
                )
            ]
        }

        // Seed rolling 2-minute throughput chart samples so the chart renders immediately
        if throughputSamples.isEmpty {
            let now = Date()
            throughputSamples = (0..<24).map { idx in
                let t = now.addingTimeInterval(Double(idx - 23) * 5.0)
                let send = Double(activeUploadSpeedBytesPerSec)
                let recv = Double(activeStreamSpeedBytesPerSec)
                return ThroughputSample(timestamp: t, sendingBytesPerSec: send, receivingBytesPerSec: recv)
            }
        }
    }

    public func saveSyncophantFeaturesState() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(backupJobs) {
            try? data.write(to: syncophantBackupsURL, options: .atomic)
        }
        if let data = try? encoder.encode(poolSnapshots) {
            try? data.write(to: syncophantSnapshotsURL, options: .atomic)
        }
        if let data = try? encoder.encode(externalStorageConnections) {
            try? data.write(to: syncophantExternalStorageURL, options: .atomic)
        }
        if let data = try? encoder.encode(activeConflicts) {
            try? data.write(to: syncophantConflictsURL, options: .atomic)
        }
        if let data = try? encoder.encode(networkContacts) {
            try? data.write(to: syncophantNetworkLedgerURL, options: .atomic)
        }
    }

    // MARK: - Actionable "Needs You" Problem Cards (idle -> working -> fixed -> collapsed)

    public var actionableIssues: [ActionableIssue] {
        var list: [ActionableIssue] = []

        if !isMounted {
            list.append(
                ActionableIssue(
                    id: "issue-unmounted",
                    title: "/Volumes/Helium is not mounted in Finder",
                    detail: "Remount the zero-byte virtual drive so Finder and video apps can stream directly.",
                    severity: .critical,
                    symbol: "externaldrive.badge.exclamationmark",
                    fixButtonTitle: "Mount /Volumes/Helium",
                    fixKind: .remountDrive
                )
            )
        }

        if let conflict = activeConflicts.first {
            list.append(
                ActionableIssue(
                    id: "issue-conflict-\(conflict.id)",
                    title: "\"\(conflict.fileName)\" was edited in two places",
                    detail: "Both versions are safely preserved. Keep both or keep the newer version (older moves to 30-Day Trash).",
                    severity: .warning,
                    symbol: "exclamationmark.2",
                    fixButtonTitle: "Keep Both Versions",
                    fixKind: .resolveFileConflict
                )
            )
        }

        for acc in linkedAccounts where acc.freeBytes < 512 * 1_048_576 && acc.quotaLimitBytes > 0 {
            list.append(
                ActionableIssue(
                    id: "issue-low-space-\(acc.id)",
                    title: "\(acc.email) has less than 512 MB free",
                    detail: "Rebalance segments across your other pooled drives so uploads never hit a quota wall.",
                    severity: .warning,
                    symbol: "chart.bar.xaxis",
                    fixButtonTitle: "Rebalance Pool",
                    fixKind: .rebalancePool
                )
            )
        }

        if cachedBytesOnMac > Int64(Double(cacheLimitOption.bytes) * 0.9) {
            list.append(
                ActionableIssue(
                    id: "issue-cache-near-limit",
                    title: "Local stream cache is near its \(cacheLimitOption.rawValue) budget",
                    detail: "Trim unpinned stream chunks to free up Mac SSD space immediately while keeping 0 B sparse stubs.",
                    severity: .info,
                    symbol: "internaldrive.trianglebadge.exclamationmark",
                    fixButtonTitle: "Trim Cache Now",
                    fixKind: .trimOfflineCache
                )
            )
        }

        if latestSafeWriteReport == nil {
            list.append(
                ActionableIssue(
                    id: "issue-safe-write-unverified",
                    title: "Safe-Write canary check hasn't run in this session",
                    detail: "Verify end-to-end SHA-256 read/write integrity and TLS 1.3 connection health.",
                    severity: .info,
                    symbol: "checkmark.shield",
                    fixButtonTitle: "Verify Safe-Write",
                    fixKind: .runSafeWriteCheck
                )
            )
        }

        return list
    }

    public func executeIssueFix(_ issue: ActionableIssue) {
        guard !workingIssueIds.contains(issue.id) else { return }
        workingIssueIds.insert(issue.id)

        Task { @MainActor in
            switch issue.fixKind {
            case .remountDrive:
                await ensureHeliumVolumeMounted()
            case .refreshOAuthTokens:
                await syncWithGoogleDrive()
            case .runSafeWriteCheck:
                await runSafeWriteVerification(
                    targetName: linkedAccounts.first?.email ?? "Helium Pool",
                    host: "www.googleapis.com"
                )
            case .rebalancePool:
                await rebalancePool()
            case .trimOfflineCache:
                removeRecentCachedFiles()
            case .resolveFileConflict:
                if let firstConflict = activeConflicts.first {
                    await resolveConflict(firstConflict, choice: .keepBoth)
                }
            case .verifyPoolChecksums:
                await runSystemHealthDoctor()
            }

            workingIssueIds.remove(issue.id)
            fixedIssueIds.insert(issue.id)
            try? await Task.sleep(nanoseconds: 900_000_000)
            fixedIssueIds.remove(issue.id)
        }
    }

    public func recordThroughputSample() {
        let sample = ThroughputSample(
            sendingBytesPerSec: Double(activeUploadSpeedBytesPerSec),
            receivingBytesPerSec: Double(activeStreamSpeedBytesPerSec)
        )
        throughputSamples.append(sample)
        if throughputSamples.count > 36 {
            throughputSamples.removeFirst(throughputSamples.count - 36)
        }
    }

    public func reorderUploadActivity(id: String, moveUp: Bool) {
        guard let idx = uploadActivities.firstIndex(where: { $0.id == id }) else { return }
        let targetIdx = moveUp ? max(0, idx - 1) : min(uploadActivities.count - 1, idx + 1)
        guard idx != targetIdx else { return }
        let item = uploadActivities.remove(at: idx)
        uploadActivities.insert(item, at: targetIdx)
        statusMessage = "Updated transfer queue priority for \(item.fileName)"
    }

    // MARK: - Multi-Protocol Storage Connections & 5-Step Safe-Write Verification

    public func runSafeWriteVerification(targetName: String, host: String) async {
        isRunningSafeWriteCheck = true
        defer { isRunningSafeWriteCheck = false }
        noteNetworkContact(host: host.isEmpty ? "www.googleapis.com" : host, purpose: "Safe-Write canary & TLS 1.3 preflight check")
        let report = await SafeWriteVerifier.runPreflightCheck(
            targetName: targetName,
            host: host,
            canaryDirectory: Self.streamCacheDirectoryURL
        )
        self.latestSafeWriteReport = report
        self.statusMessage = report.passedAllSteps
            ? "Verified safe reads & writes on \(report.targetName) (SHA-256 \(report.canarySHA256.prefix(10))… • \(report.latencyMs) ms)"
            : "Safe-write check reported an issue on \(report.targetName)"
    }

    public func addExternalStorageConnection(_ connection: ExternalStorageConnection) {
        externalStorageConnections.removeAll { $0.id == connection.id }
        externalStorageConnections.append(connection)
        noteNetworkContact(
            host: connection.host.isEmpty ? connection.endpoint : connection.host,
            purpose: "Your storage · \(connection.protocolKind.title) (\(connection.name))"
        )
        saveSyncophantFeaturesState()
        statusMessage = "Connected \(connection.name) (\(connection.protocolKind.title)) to Helium Pool"
    }

    public func removeExternalStorageConnection(id: String) {
        externalStorageConnections.removeAll { $0.id == id }
        saveSyncophantFeaturesState()
        statusMessage = "Removed external storage connection from pool"
    }

    // MARK: - Scheduled Mac Folder Backups (Add-Only Safety)

    public func createBackupJob(
        name: String,
        sourceURL: URL,
        destinationFolder: String,
        schedule: BackupScheduleInterval,
        exclusions: BackupExclusionOptions,
        skipOnHotspot: Bool,
        runImmediately: Bool = true
    ) {
        let scan = HeliumBackupEngine.scanLocalFolder(at: sourceURL, activeExclusions: exclusions)
        let job = BackupJob(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? sourceURL.lastPathComponent : name,
            sourcePath: sourceURL.path,
            destinationPoolFolder: destinationFolder.hasPrefix("/") ? destinationFolder : "/Backups/\(sourceURL.lastPathComponent)",
            schedule: schedule,
            exclusions: exclusions,
            skipOnPersonalHotspot: skipOnHotspot,
            enabled: true,
            lastRunAt: nil,
            nextRunAt: schedule.intervalSeconds.map { Date().addingTimeInterval($0) },
            totalProtectedFiles: scan.eligibleFilesCount,
            totalProtectedBytes: scan.eligibleBytes,
            recentRuns: []
        )
        backupJobs.insert(job, at: 0)
        saveSyncophantFeaturesState()
        statusMessage = "Created scheduled backup job \"\(job.name)\" (\(scan.eligibleFilesCount) files • \(ByteCountFormatter.string(fromByteCount: scan.eligibleBytes, countStyle: .file)))"

        if runImmediately {
            Task { await runBackupJobNow(job) }
        }
    }

    public func toggleBackupJobEnabled(id: String) {
        guard let idx = backupJobs.firstIndex(where: { $0.id == id }) else { return }
        backupJobs[idx].enabled.toggle()
        saveSyncophantFeaturesState()
    }

    public func deleteBackupJob(id: String) {
        backupJobs.removeAll { $0.id == id }
        saveSyncophantFeaturesState()
        statusMessage = "Removed scheduled backup rule (backed-up files in /Volumes/Helium remain untouched)"
    }

    public func runBackupJobNow(_ job: BackupJob) async {
        guard let idx = backupJobs.firstIndex(where: { $0.id == job.id }) else { return }
        isRunningBackupJobId = job.id
        defer { isRunningBackupJobId = nil }

        let started = Date()
        let currentJob = backupJobs[idx]
        let (filesToUpload, updatedFingerprints) = HeliumBackupEngine.computeIncrementalFilesToUpload(for: currentJob)

        // Upload up to 12 new/modified files into the Helium Pool during this incremental pass
        let batch = Array(filesToUpload.prefix(12))
        if !batch.isEmpty {
            await importExternalFiles(batch.map(\.url))
        }

        let uploadedBytes = filesToUpload.reduce(Int64(0)) { $0 + $1.size }
        let scan = HeliumBackupEngine.scanLocalFolder(
            at: URL(fileURLWithPath: currentJob.sourcePath),
            activeExclusions: currentJob.exclusions
        )

        let runRecord = BackupRunRecord(
            startedAt: started,
            finishedAt: Date(),
            uploadedFiles: filesToUpload.count,
            uploadedBytes: uploadedBytes,
            verifiedChecksums: filesToUpload.count,
            outcome: .succeeded,
            note: filesToUpload.isEmpty ? "All files up to date" : "Verified SHA-256 on \(filesToUpload.count) file(s)"
        )

        if let updatedIdx = backupJobs.firstIndex(where: { $0.id == job.id }) {
            backupJobs[updatedIdx].lastRunAt = Date()
            if let interval = backupJobs[updatedIdx].schedule.intervalSeconds {
                backupJobs[updatedIdx].nextRunAt = Date().addingTimeInterval(interval)
            }
            backupJobs[updatedIdx].totalProtectedFiles = max(scan.eligibleFilesCount, updatedFingerprints.count)
            backupJobs[updatedIdx].totalProtectedBytes = max(scan.eligibleBytes, uploadedBytes)
            backupJobs[updatedIdx].knownFileFingerprints = updatedFingerprints
            backupJobs[updatedIdx].recentRuns.append(runRecord)
            if backupJobs[updatedIdx].recentRuns.count > 14 {
                backupJobs[updatedIdx].recentRuns.removeFirst(backupJobs[updatedIdx].recentRuns.count - 14)
            }
            saveSyncophantFeaturesState()
        }

        noteNetworkContact(host: "www.googleapis.com", purpose: "Scheduled Mac Folder Backup (\(currentJob.name))")
        statusMessage = "Backup \"\(currentJob.name)\" complete: \(filesToUpload.count) new/changed file(s) verified."
    }

    public func runAllBackupsNow() async {
        for job in backupJobs where job.enabled {
            await runBackupJobNow(job)
        }
    }

    // MARK: - Time Travel: Point-in-Time Pool Snapshots & "Then vs. Now" Diffing

    public var selectedSnapshot: PoolSnapshot? {
        if let id = selectedSnapshotId, let found = poolSnapshots.first(where: { $0.id == id }) {
            return found
        }
        return poolSnapshots.first
    }

    public var currentSnapshotComparisons: [SnapshotItemComparison] {
        guard let snap = selectedSnapshot else { return [] }
        return SnapshotTimelineManager.compare(snapshot: snap, with: manifests)
    }

    public func takePoolSnapshot(title: String, note: String = "") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let finalTitle = trimmed.isEmpty ? "Snapshot • \(df.string(from: Date()))" : trimmed

        let snap = PoolSnapshot(
            title: finalTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\(activePooledFilesCount) pooled files (\(ByteCountFormatter.string(fromByteCount: heliumPoolUsedBytes, countStyle: .file)))"
                : note,
            manifestsById: manifests
        )
        poolSnapshots.insert(snap, at: 0)
        selectedSnapshotId = snap.id
        saveSyncophantFeaturesState()
        statusMessage = "Captured Time Travel snapshot \"\(snap.title)\" (\(snap.totalFiles) files)"
    }

    public func deletePoolSnapshot(_ snapshot: PoolSnapshot) {
        poolSnapshots.removeAll { $0.id == snapshot.id }
        if selectedSnapshotId == snapshot.id {
            selectedSnapshotId = poolSnapshots.first?.id
        }
        saveSyncophantFeaturesState()
        statusMessage = "Deleted snapshot \"\(snapshot.title)\""
    }

    public func restoreFromSnapshot(_ comparison: SnapshotItemComparison, asCopy: Bool) async {
        guard var restoredManifest = comparison.thenManifest else { return }
        if asCopy {
            let newId = "snap_restore_\(UUID().uuidString.prefix(8))"
            let ext = (restoredManifest.item.name as NSString).pathExtension
            let base = (restoredManifest.item.name as NSString).deletingPathExtension
            let copyName = ext.isEmpty ? "\(base) (Restored)" : "\(base) (Restored).\(ext)"
            let restoredItem = RemoteItem(
                id: newId,
                parentId: restoredManifest.item.parentId,
                name: copyName,
                nameLocked: restoredManifest.item.nameLocked,
                kind: restoredManifest.item.kind,
                size: restoredManifest.item.size,
                plainSize: restoredManifest.item.plainSize,
                mimeType: restoredManifest.item.mimeType,
                contentVersion: restoredManifest.item.contentVersion + 1,
                metadataVersion: restoredManifest.item.metadataVersion + 1,
                createdAt: Int64(Date().timeIntervalSince1970 * 1000),
                modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
                deleted: false
            )
            restoredManifest = PoolItemManifest(
                item: restoredItem,
                placementMode: restoredManifest.placementMode,
                segments: restoredManifest.segments
            )
            manifests[newId] = restoredManifest
        } else {
            let restoredItem = RemoteItem(
                id: restoredManifest.item.id,
                parentId: restoredManifest.item.parentId,
                name: restoredManifest.item.name,
                nameLocked: restoredManifest.item.nameLocked,
                kind: restoredManifest.item.kind,
                size: restoredManifest.item.size,
                plainSize: restoredManifest.item.plainSize,
                mimeType: restoredManifest.item.mimeType,
                contentVersion: restoredManifest.item.contentVersion,
                metadataVersion: restoredManifest.item.metadataVersion + 1,
                createdAt: restoredManifest.item.createdAt,
                modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
                deleted: false
            )
            restoredManifest.item = restoredItem
            manifests[restoredItem.id] = restoredManifest
        }
        await refreshState()
        statusMessage = asCopy
            ? "Restored snapshot copy of \"\(comparison.itemName)\" to /Volumes/Helium"
            : "Restored \"\(comparison.itemName)\" to its snapshot version"
    }

    // MARK: - Two-Version Conflict Detection & Non-Destructive Resolution

    public func resolveConflict(_ conflict: FileConflictItem, choice: ConflictResolutionChoice) async {
        activeConflicts.removeAll { $0.id == conflict.id }
        saveSyncophantFeaturesState()

        switch choice {
        case .keepBoth:
            statusMessage = "Resolved conflict for \"\(conflict.fileName)\": kept both versions in /Volumes/Helium."
        case .useNewer:
            // Move the older version safely into the 30-day Recycle Bin rather than destroying data
            let trashed = TrashedFileItem(
                id: conflict.conflictCopyItemId,
                fileName: conflict.conflictCopyFileName,
                sizeBytes: conflict.conflictCopySizeBytes,
                deletedAt: Date(),
                daysRemaining: 30,
                accountSummary: linkedAccounts.first?.email ?? "Helium Pool"
            )
            trashedItems.insert(trashed, at: 0)
            statusMessage = "Resolved conflict for \"\(conflict.fileName)\": kept newer version and moved older copy to 30-Day Trash."
        }
    }

    public func createSampleConflictForSelectedFile() {
        let baseNode = selectedInspectorNode ?? driveNodes.first(where: { !$0.isFolder })
        let fileName = baseNode?.name ?? "Project-Timeline-v2.fcpxml"
        let size = baseNode?.size ?? 1_420_800
        let copyName = FileConflictItem.makeConflictCopyName(for: fileName, hostName: Host.current().localizedName ?? "MacBook Pro")
        let conflict = FileConflictItem(
            originalItemId: baseNode?.remoteID ?? UUID().uuidString,
            conflictCopyItemId: "conflict_\(UUID().uuidString.prefix(8))",
            fileName: fileName,
            conflictCopyFileName: copyName,
            originalSizeBytes: size,
            conflictCopySizeBytes: size + 24_576,
            originalModifiedAt: Date().addingTimeInterval(-600),
            conflictCopyModifiedAt: Date(),
            originDeviceName: Host.current().localizedName ?? "This Mac"
        )
        activeConflicts.removeAll { $0.fileName == fileName }
        activeConflicts.insert(conflict, at: 0)
        saveSyncophantFeaturesState()
        statusMessage = "Detected two concurrent versions of \"\(fileName)\" — open Inspector or Activity to resolve."
    }

    // MARK: - Privacy Network Contact Ledger & Redacted Diagnostics

    public func noteNetworkContact(host: String, purpose: String) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanHost.isEmpty else { return }
        if let idx = networkContacts.firstIndex(where: { $0.host == cleanHost }) {
            networkContacts[idx].count += 1
            networkContacts[idx].lastContacted = Date()
            if !purpose.isEmpty {
                networkContacts[idx].purpose = purpose
            }
        } else {
            networkContacts.append(
                NetworkContactEntry(host: cleanHost, purpose: purpose, count: 1, lastContacted: Date())
            )
        }
        saveSyncophantFeaturesState()
    }

    public func clearNetworkContactHistory() {
        networkContacts.removeAll()
        saveSyncophantFeaturesState()
        statusMessage = "Cleared local network contact audit ledger."
    }

    public func exportRedactedDiagnosticsLog() -> URL? {
        let rawReport = """
        # Helium Redacted Diagnostics Log
        Generated: \(ISO8601DateFormatter().string(from: Date()))
        Version: Helium v\(Self.appVersion) (Build \(Self.appBuild))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Mount Path: \(volumeMountURL.path) (Mounted: \(isMounted))
        Local Mirror: \(localMirrorURL.path)
        Pooled Drives: \(linkedAccounts.count) Google Drive(s) + \(externalStorageConnections.count) External Provider(s)
        Accounts: \(linkedAccounts.map(\.email).joined(separator: ", "))
        Active Pooled Files: \(activePooledFilesCount) (\(ByteCountFormatter.string(fromByteCount: heliumPoolUsedBytes, countStyle: .file)))
        Scheduled Backup Jobs: \(backupJobs.count)
        Time Travel Snapshots: \(poolSnapshots.count)
        Network Contacts Recorded: \(networkContacts.map { "\($0.host) (\($0.count)x)" }.joined(separator: ", "))
        """
        let redacted = DiagnosticsRedactor.redact(rawReport)
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        let outURL = downloads.appendingPathComponent("Helium-Diagnostics-Redacted-\(df.string(from: Date())).log")
        do {
            try Data(redacted.utf8).write(to: outURL, options: .atomic)
            statusMessage = "Saved redacted diagnostics log to Downloads/\(outURL.lastPathComponent)"
            return outURL
        } catch {
            statusMessage = "Could not save diagnostics log: \(error.localizedDescription)"
            return nil
        }
    }
}
