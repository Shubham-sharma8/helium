import Foundation

/// Represents a linked Google Drive account participating in the unified Helium storage pool.
public struct LinkedGoogleAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let email: String
    public let displayName: String
    public var refreshToken: String
    public var accessToken: String?
    public var tokenExpiry: Date?
    public var isPrimaryCatalogHost: Bool
    public var quotaLimitBytes: Int64
    public var quotaUsedBytes: Int64
    public var heliumUsedBytes: Int64
    public var rootFolderId: String
    /// Upload priority rank (`1` = highest priority `#1`, `2` = `#2`, etc.). Lower number = higher priority.
    public var uploadPriority: Int
    /// When `true`, new uploads skip this account (Read-Only / Drain mode) while existing segments remain readable.
    public var isUploadPaused: Bool

    public init(
        id: String,
        email: String,
        displayName: String,
        refreshToken: String,
        accessToken: String? = nil,
        tokenExpiry: Date? = nil,
        isPrimaryCatalogHost: Bool,
        quotaLimitBytes: Int64,
        quotaUsedBytes: Int64,
        heliumUsedBytes: Int64,
        rootFolderId: String,
        uploadPriority: Int = 1,
        isUploadPaused: Bool = false
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.tokenExpiry = tokenExpiry
        self.isPrimaryCatalogHost = isPrimaryCatalogHost
        self.quotaLimitBytes = quotaLimitBytes
        self.quotaUsedBytes = quotaUsedBytes
        self.heliumUsedBytes = heliumUsedBytes
        self.rootFolderId = rootFolderId
        self.uploadPriority = max(1, uploadPriority)
        self.isUploadPaused = isUploadPaused
    }

    private enum CodingKeys: String, CodingKey {
        case id, email, displayName, refreshToken, accessToken, tokenExpiry
        case isPrimaryCatalogHost, quotaLimitBytes, quotaUsedBytes, heliumUsedBytes, rootFolderId
        case uploadPriority, isUploadPaused
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.email = try c.decode(String.self, forKey: .email)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        self.accessToken = try c.decodeIfPresent(String.self, forKey: .accessToken)
        self.tokenExpiry = try c.decodeIfPresent(Date.self, forKey: .tokenExpiry)
        self.isPrimaryCatalogHost = try c.decodeIfPresent(Bool.self, forKey: .isPrimaryCatalogHost) ?? false
        self.quotaLimitBytes = try c.decodeIfPresent(Int64.self, forKey: .quotaLimitBytes) ?? 0
        self.quotaUsedBytes = try c.decodeIfPresent(Int64.self, forKey: .quotaUsedBytes) ?? 0
        self.heliumUsedBytes = try c.decodeIfPresent(Int64.self, forKey: .heliumUsedBytes) ?? 0
        self.rootFolderId = try c.decodeIfPresent(String.self, forKey: .rootFolderId) ?? "root"
        self.uploadPriority = max(1, try c.decodeIfPresent(Int.self, forKey: .uploadPriority) ?? 1)
        self.isUploadPaused = try c.decodeIfPresent(Bool.self, forKey: .isUploadPaused) ?? false
    }

    public var freeBytes: Int64 {
        max(0, quotaLimitBytes - quotaUsedBytes)
    }

    public func allocatableBytes(reserve: Int64) -> Int64 {
        max(0, freeBytes - reserve)
    }
}

public enum AccountRoutingStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case priorityOrder = "priority_order"
    case mostFreeSpace = "most_free_space"
    case pinnedAccount = "pinned_account"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .priorityOrder:
            return "Priority Order (Fill #1 First, Overflow to #2…)"
        case .mostFreeSpace:
            return "Most Free Space (Balance Headroom)"
        case .pinnedAccount:
            return "Preferred Target Account (Auto-Overflow)"
        }
    }
}

public enum PlacementMode: String, Codable, Equatable, Sendable {
    case wholeFileSmartPlacement = "whole_file"
    case crossAccountStriped = "striped"
}

public enum PlacementPolicy: String, Codable, CaseIterable, Sendable {
    case automatic = "automatic"
    case preferWholeFile = "prefer_whole_file"
    case alwaysStripe = "always_stripe"
}

public struct PoolSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public var accountId: String
    public var driveFileId: String
    public let logicalOffset: Int64
    public let byteLength: Int64
    public var sha256: String?

    public init(
        index: Int,
        accountId: String,
        driveFileId: String = "",
        logicalOffset: Int64,
        byteLength: Int64,
        sha256: String? = nil
    ) {
        self.index = index
        self.accountId = accountId
        self.driveFileId = driveFileId
        self.logicalOffset = logicalOffset
        self.byteLength = byteLength
        self.sha256 = sha256
    }
}

public struct AllocationPlan: Codable, Equatable, Sendable {
    public let mode: PlacementMode
    public let segments: [PoolSegment]

    public init(mode: PlacementMode, segments: [PoolSegment]) {
        self.mode = mode
        self.segments = segments
    }
}

public enum PoolAllocationError: Error, LocalizedError, Sendable {
    case noLinkedAccounts
    case insufficientPooledStorage(required: Int64, available: Int64)

    public var errorDescription: String? {
        switch self {
        case .noLinkedAccounts:
            return "No Google Drive accounts are linked to the storage pool."
        case let .insufficientPooledStorage(required, available):
            return "Insufficient pooled storage across linked Google Drives (required \(required) bytes, available \(available) bytes)."
        }
    }
}

/// Allocates files across multiple linked Google Drive accounts using BOTH Mode 1 (Whole-File Smart Placement) and Mode 2 (Cross-Account Segment Striping),
/// respecting per-account upload priority, pause/read-only state, and preferred target account routing.
public struct StoragePoolAllocator: Sendable {
    public let safetyReserveBytes: Int64
    public let segmentChunkCount: Int
    public let autoStripeAboveBytes: Int64
    public let policy: PlacementPolicy
    public let routingStrategy: AccountRoutingStrategy
    public let preferredAccountId: String?

    public init(
        safetyReserveBytes: Int64 = 100 * 1_048_576,
        segmentChunkCount: Int = 64,
        autoStripeAboveBytes: Int64 = 8 * 1_073_741_824,
        policy: PlacementPolicy = .automatic,
        routingStrategy: AccountRoutingStrategy = .priorityOrder,
        preferredAccountId: String? = nil
    ) {
        self.safetyReserveBytes = max(0, safetyReserveBytes)
        self.segmentChunkCount = max(1, segmentChunkCount)
        self.autoStripeAboveBytes = max(1, autoStripeAboveBytes)
        self.policy = policy
        self.routingStrategy = routingStrategy
        self.preferredAccountId = preferredAccountId
    }

    public func allocate(
        totalBytes: Int64,
        encrypted: Bool,
        accounts: [LinkedGoogleAccount]
    ) throws -> AllocationPlan {
        guard !accounts.isEmpty else {
            throw PoolAllocationError.noLinkedAccounts
        }

        // Filter out accounts whose uploads are paused unless all accounts are paused
        let unpaused = accounts.filter { !$0.isUploadPaused }
        let candidatePool = unpaused.isEmpty ? accounts : unpaused

        // Sort accounts according to routingStrategy, preferredAccountId, uploadPriority, and available headroom
        let sorted = candidatePool.sorted { lhs, rhs in
            if let pref = preferredAccountId, !pref.isEmpty {
                let lIsPref = (lhs.id == pref) && lhs.allocatableBytes(reserve: safetyReserveBytes) > 0
                let rIsPref = (rhs.id == pref) && rhs.allocatableBytes(reserve: safetyReserveBytes) > 0
                if lIsPref != rIsPref { return lIsPref }
            }

            let lFree = lhs.allocatableBytes(reserve: safetyReserveBytes)
            let rFree = rhs.allocatableBytes(reserve: safetyReserveBytes)

            switch routingStrategy {
            case .priorityOrder, .pinnedAccount:
                if lhs.uploadPriority != rhs.uploadPriority {
                    return lhs.uploadPriority < rhs.uploadPriority
                }
                if lFree != rFree { return lFree > rFree }
                return lhs.id < rhs.id
            case .mostFreeSpace:
                if lFree != rFree { return lFree > rFree }
                if lhs.uploadPriority != rhs.uploadPriority {
                    return lhs.uploadPriority < rhs.uploadPriority
                }
                return lhs.id < rhs.id
            }
        }

        if totalBytes <= 0 {
            let best = sorted[0]
            return AllocationPlan(
                mode: .wholeFileSmartPlacement,
                segments: [PoolSegment(index: 0, accountId: best.id, logicalOffset: 0, byteLength: 0)]
            )
        }

        let totalPooledFree = sorted.reduce(Int64(0)) { $0 + $1.allocatableBytes(reserve: safetyReserveBytes) }
        guard totalPooledFree >= totalBytes else {
            throw PoolAllocationError.insufficientPooledStorage(required: totalBytes, available: totalPooledFree)
        }

        // Find the first account in priority/sorted order that can accommodate the entire file
        let firstFittingAccount = sorted.first { $0.allocatableBytes(reserve: safetyReserveBytes) >= totalBytes }
        let canFitWholeOnSingleAccount = (firstFittingAccount != nil)
        let shouldUseWholeFile: Bool
        switch policy {
        case .alwaysStripe:
            shouldUseWholeFile = sorted.count == 1 && canFitWholeOnSingleAccount
        case .preferWholeFile:
            shouldUseWholeFile = canFitWholeOnSingleAccount
        case .automatic:
            shouldUseWholeFile = (totalBytes <= autoStripeAboveBytes) && canFitWholeOnSingleAccount
        }

        // MODE 1: Whole-File Smart Placement (respecting priority order!)
        if shouldUseWholeFile, let target = firstFittingAccount {
            return AllocationPlan(
                mode: .wholeFileSmartPlacement,
                segments: [
                    PoolSegment(
                        index: 0,
                        accountId: target.id,
                        logicalOffset: 0,
                        byteLength: totalBytes
                    )
                ]
            )
        }

        // MODE 2: Cross-Account Segment Striping
        // Align every non-final segment to an exact multiple of 1 MiB (plain) or 1 MiB + 16B (ZK encrypted piece).
        let chunkUnit: Int64 = encrypted ? Int64(ZK.piece + ZK.tag) : Int64(ZK.piece)
        let targetSegmentBytes = Int64(segmentChunkCount) * chunkUnit

        var remainingByAccount: [String: Int64] = [:]
        for acct in sorted {
            remainingByAccount[acct.id] = acct.allocatableBytes(reserve: safetyReserveBytes)
        }

        var segments: [PoolSegment] = []
        var offset: Int64 = 0
        var segmentIndex = 0
        var cursor = 0

        while offset < totalBytes {
            let remainingFileBytes = totalBytes - offset
            let desiredBytes = min(targetSegmentBytes, remainingFileBytes)
            let isFinalPiece = remainingFileBytes <= chunkUnit

            var chosenAccountID: String?
            var chosenLength: Int64 = 0

            // Round-robin across accounts that can accommodate at least one chunkUnit (or the final tail)
            for attempt in 0..<sorted.count {
                let candidate = sorted[(cursor + attempt) % sorted.count]
                let avail = remainingByAccount[candidate.id] ?? 0
                if avail >= desiredBytes {
                    chosenAccountID = candidate.id
                    chosenLength = desiredBytes
                    cursor = (cursor + attempt + 1) % sorted.count
                    break
                } else if avail >= chunkUnit {
                    let alignedAvail = (avail / chunkUnit) * chunkUnit
                    if alignedAvail > 0 {
                        chosenAccountID = candidate.id
                        chosenLength = min(remainingFileBytes, alignedAvail)
                        cursor = (cursor + attempt + 1) % sorted.count
                        break
                    }
                } else if isFinalPiece && avail >= remainingFileBytes {
                    chosenAccountID = candidate.id
                    chosenLength = remainingFileBytes
                    cursor = (cursor + attempt + 1) % sorted.count
                    break
                }
            }

            // Fallback if remaining capacity is fragmented below chunkUnit
            if chosenAccountID == nil {
                if let fallback = sorted.max(by: { (remainingByAccount[$0.id] ?? 0) < (remainingByAccount[$1.id] ?? 0) }),
                   let avail = remainingByAccount[fallback.id], avail > 0 {
                    chosenAccountID = fallback.id
                    chosenLength = min(remainingFileBytes, avail)
                }
            }

            guard let accountId = chosenAccountID, chosenLength > 0 else {
                throw PoolAllocationError.insufficientPooledStorage(
                    required: remainingFileBytes,
                    available: remainingByAccount.values.reduce(0, +)
                )
            }

            segments.append(
                PoolSegment(
                    index: segmentIndex,
                    accountId: accountId,
                    logicalOffset: offset,
                    byteLength: chosenLength
                )
            )
            remainingByAccount[accountId] = max(0, (remainingByAccount[accountId] ?? 0) - chosenLength)
            offset += chosenLength
            segmentIndex += 1
        }

        return AllocationPlan(mode: .crossAccountStriped, segments: segments)
    }
}
