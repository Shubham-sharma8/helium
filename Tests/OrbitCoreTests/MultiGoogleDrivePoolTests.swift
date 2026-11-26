import XCTest
@testable import OrbitCore

final class MultiGoogleDrivePoolTests: XCTestCase {

    func testFirebaseConfigParsesWorkspacePlistAndJson() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plistURL = tempDir.appendingPathComponent("GoogleService-Info.plist")
        let jsonURL = tempDir.appendingPathComponent("google-services.json")

        let samplePlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CLIENT_ID</key>
            <string>123456789000-exampleclientid.apps.googleusercontent.com</string>
            <key>REVERSED_CLIENT_ID</key>
            <string>com.googleusercontent.apps.123456789000-exampleclientid</string>
            <key>API_KEY</key>
            <string>TEST_API_KEY_PLACEHOLDER</string>
            <key>GCM_SENDER_ID</key>
            <string>123456789000</string>
            <key>BUNDLE_ID</key>
            <string>com.cogify.helium</string>
            <key>PROJECT_ID</key>
            <string>helium-test-project</string>
            <key>STORAGE_BUCKET</key>
            <string>helium-test-project.firebasestorage.app</string>
            <key>GOOGLE_APP_ID</key>
            <string>1:123456789000:ios:abcdef1234567890</string>
        </dict>
        </plist>
        """
        try Data(samplePlist.utf8).write(to: plistURL)

        let config = try FirebaseConfig.load(plistURL: plistURL, jsonURL: jsonURL)
        XCTAssertEqual(config.projectId, "helium-test-project")
        XCTAssertEqual(config.projectNumber, "123456789000")
        XCTAssertEqual(config.bundleId, "com.cogify.helium")
        XCTAssertEqual(config.storageBucket, "helium-test-project.firebasestorage.app")
        XCTAssertFalse(config.apiKey.isEmpty)
        XCTAssertEqual(
            config.clientId,
            "123456789000-exampleclientid.apps.googleusercontent.com"
        )
        XCTAssertEqual(
            config.reversedClientId,
            "com.googleusercontent.apps.123456789000-exampleclientid"
        )
    }

    func testStoragePoolAllocatorSmartPlacementAndCrossAccountStriping() throws {
        let gb: Int64 = 1_073_741_824
        let mib: Int64 = 1_048_576

        // Three free 15 GB Google Drive accounts with varying usage:
        // Account 1: 12 GB used / 15 GB (3 GB free)
        // Account 2: 5 GB used  / 15 GB (10 GB free)
        // Account 3: 8 GB used  / 15 GB (7 GB free)
        // Total Pool: 25 GB used / 45 GB total (20 GB combined free!)
        let acc1 = LinkedGoogleAccount(
            id: "acc_1",
            email: "drive1@gmail.com",
            displayName: "Drive 1",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 12 * gb,
            heliumUsedBytes: 2 * gb,
            rootFolderId: "root_1"
        )
        let acc2 = LinkedGoogleAccount(
            id: "acc_2",
            email: "drive2@gmail.com",
            displayName: "Drive 2",
            refreshToken: "rt_2",
            isPrimaryCatalogHost: false,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 5 * gb,
            heliumUsedBytes: 1 * gb,
            rootFolderId: "root_2"
        )
        let acc3 = LinkedGoogleAccount(
            id: "acc_3",
            email: "drive3@gmail.com",
            displayName: "Drive 3",
            refreshToken: "rt_3",
            isPrimaryCatalogHost: false,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 8 * gb,
            heliumUsedBytes: 3 * gb,
            rootFolderId: "root_3"
        )

        let allocator = StoragePoolAllocator(
            safetyReserveBytes: 100 * mib,
            segmentChunkCount: 64, // 64 MiB segments
            autoStripeAboveBytes: 8 * gb
        )

        // MODE 1: Whole-File Smart Placement
        // A 2 GB file fits comfortably on a single drive -> should route to Account 2 (which has 10 GB free, the most headroom)
        let planSmall = try allocator.allocate(
            totalBytes: 2 * gb,
            encrypted: false,
            accounts: [acc1, acc2, acc3]
        )
        XCTAssertEqual(planSmall.mode, .wholeFileSmartPlacement)
        XCTAssertEqual(planSmall.segments.count, 1)
        XCTAssertEqual(planSmall.segments[0].accountId, "acc_2")
        XCTAssertEqual(planSmall.segments[0].logicalOffset, 0)
        XCTAssertEqual(planSmall.segments[0].byteLength, 2 * gb)

        // MODE 2: Cross-Account Segment Striping
        // A 14 GB 4K ProRes movie is LARGER than any single account's free space (max single free is 10 GB on acc_2),
        // yet fits inside the 20 GB combined free pool across acc_1 + acc_2 + acc_3!
        let fourteenGB = 14 * gb
        let planStriped = try allocator.allocate(
            totalBytes: fourteenGB,
            encrypted: false,
            accounts: [acc1, acc2, acc3]
        )
        XCTAssertEqual(planStriped.mode, .crossAccountStriped)
        XCTAssertGreaterThan(planStriped.segments.count, 1)

        // Verify contiguous byte coverage and that all 3 accounts participate without any account exceeding its free space
        var expectedOffset: Int64 = 0
        var bytesPerAccount: [String: Int64] = [:]
        for seg in planStriped.segments {
            XCTAssertEqual(seg.logicalOffset, expectedOffset)
            // Every segment (except possibly the last) is an exact multiple of 1 MiB chunk size
            if seg.index < planStriped.segments.count - 1 {
                XCTAssertEqual(seg.byteLength % mib, 0)
            }
            expectedOffset += seg.byteLength
            bytesPerAccount[seg.accountId, default: 0] += seg.byteLength
        }
        XCTAssertEqual(expectedOffset, fourteenGB)
        XCTAssertGreaterThanOrEqual(bytesPerAccount.keys.count, 2, "Must stripe across multiple Google Drive accounts")
        XCTAssertLessThanOrEqual(bytesPerAccount["acc_1"] ?? 0, acc1.allocatableBytes(reserve: 100 * mib))
        XCTAssertLessThanOrEqual(bytesPerAccount["acc_2"] ?? 0, acc2.allocatableBytes(reserve: 100 * mib))
        XCTAssertLessThanOrEqual(bytesPerAccount["acc_3"] ?? 0, acc3.allocatableBytes(reserve: 100 * mib))
    }

    func testPooledGoogleDriveRemoteEndToEndWithLockedRemoteAndOrbitDrive() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let mib: Int64 = 1_048_576
        // Set up 3 simulated Google Drive accounts with 3 MiB free each (total 9 MiB pooled free space)
        let mockCloud = MockGoogleDriveCloud()
        let pool = GoogleAccountPool(
            accounts: [
                LinkedGoogleAccount(
                    id: "gd_1", email: "user1@gmail.com", displayName: "User 1", refreshToken: "rt1",
                    isPrimaryCatalogHost: true, quotaLimitBytes: 5 * mib, quotaUsedBytes: 2 * mib,
                    heliumUsedBytes: 0, rootFolderId: "folder_1"
                ),
                LinkedGoogleAccount(
                    id: "gd_2", email: "user2@gmail.com", displayName: "User 2", refreshToken: "rt2",
                    isPrimaryCatalogHost: false, quotaLimitBytes: 5 * mib, quotaUsedBytes: 2 * mib,
                    heliumUsedBytes: 0, rootFolderId: "folder_2"
                ),
                LinkedGoogleAccount(
                    id: "gd_3", email: "user3@gmail.com", displayName: "User 3", refreshToken: "rt3",
                    isPrimaryCatalogHost: false, quotaLimitBytes: 5 * mib, quotaUsedBytes: 2 * mib,
                    heliumUsedBytes: 0, rootFolderId: "folder_3"
                )
            ],
            transport: mockCloud
        )

        // Configure allocator with 1-chunk segments and 0 safety reserve so a 4.2 MiB file stripes across all 3 accounts
        let allocator = StoragePoolAllocator(
            safetyReserveBytes: 0,
            segmentChunkCount: 1,
            autoStripeAboveBytes: 2 * mib
        )
        let pooledRemote = PooledGoogleDriveRemote(pool: pool, allocator: allocator)

        // Verify combined quota aggregation: 3 * 5 MiB = 15 MiB total, 3 * 2 MiB = 6 MiB used
        let pooledAccount = try await pooledRemote.account()
        XCTAssertEqual(pooledAccount.quotaBytes, 15 * mib)
        XCTAssertEqual(pooledAccount.usedBytes, 6 * mib)

        // Wrap PooledGoogleDriveRemote inside LockedRemote (Zero-Knowledge AES-256-GCM encryption!)
        let masterKey = ZK.random(32)
        let accountKeys = ZK.deriveKeys(masterKey)
        let lockedRemote = LockedRemote(
            inner: pooledRemote,
            keys: accountKeys,
            locksWrites: true,
            directory: tempDir
        )

        // Create a 3.5 MiB file (larger than any single account's 3 MiB free space!)
        let plainSize = Int(3 * mib + 524_288)
        var largeVideoData = Data(count: plainSize)
        for i in 0..<plainSize {
            largeVideoData[i] = UInt8((i * 19 + 3) & 0xFF)
        }
        let localSourceURL = tempDir.appendingPathComponent("4K_Edit.mov")
        try largeVideoData.write(to: localSourceURL)

        // Upload through LockedRemote -> PooledGoogleDriveRemote (automatically encrypted in 1 MiB pieces AND striped across gd_1, gd_2, gd_3!)
        let uploadedItem = try await lockedRemote.uploadNewFile(
            from: localSourceURL,
            name: "4K_Edit.mov",
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )
        XCTAssertEqual(uploadedItem.name, "4K_Edit.mov")
        XCTAssertEqual(uploadedItem.size, Int64(plainSize))

        // Verify that the file was striped across multiple Google Drive accounts in MockGoogleDriveCloud
        let manifest = try await pooledRemote.manifest(for: uploadedItem.id)
        XCTAssertEqual(manifest.placementMode, .crossAccountStriped)
        XCTAssertEqual(manifest.segments.count, 4) // 4 encrypted chunks (3 * 1 MiB + 0.5 MiB)
        let accountsUsed = Set(manifest.segments.map(\.accountId))
        XCTAssertGreaterThanOrEqual(accountsUsed.count, 2, "3.5 MiB file must span at least 2 of the 3 MiB-free Google Drive accounts")

        // Now mount OrbitDrive on top of LockedRemote and read arbitrary byte ranges via ContentReader!
        let driveDir = tempDir.appendingPathComponent("drive")
        let config = OrbitDrive.Configuration(
            directory: driveDir,
            deviceName: "TestMac",
            cacheLimits: ChunkStore.Limits.defaults(diskCapacity: 50_000_000_000)
        )
        let drive = OrbitDrive(remote: lockedRemote, configuration: config)
        try await drive.start()

        let node = try XCTUnwrap(drive.lookup("4K_Edit.mov", in: DriveNode.rootID))
        XCTAssertEqual(node.size, Int64(plainSize))

        // Scrub across chunk 1 and chunk 2 (stored on different Google Drive accounts!)
        let scrubOffset = Int64(mib * 2 - 4096)
        let scrubLength = 16_384
        let scrubbedBytes = try await drive.read(node.id, offset: scrubOffset, length: scrubLength)
        let expectedBytes = largeVideoData.subdata(in: Int(scrubOffset)..<Int(scrubOffset) + scrubLength)
        XCTAssertEqual(scrubbedBytes, expectedBytes)

        // Test graceful account draining (evacuating gd_3 onto a newly added 20 MiB gd_4 account)
        await pool.addAccount(LinkedGoogleAccount(
            id: "gd_4", email: "bigdrive@gmail.com", displayName: "Big Drive", refreshToken: "rt4",
            isPrimaryCatalogHost: false, quotaLimitBytes: 20 * mib, quotaUsedBytes: 0,
            heliumUsedBytes: 0, rootFolderId: "folder_4"
        ))
        try await pooledRemote.drainAndUnlinkAccount(id: "gd_3")

        // Reading the entire file after unlinking gd_3 must still succeed 100%!
        let endOffset = Int64(plainSize - 50_000)
        let tailBytes = try await drive.read(node.id, offset: endOffset, length: 50_000)
        XCTAssertEqual(tailBytes, largeVideoData.subdata(in: Int(endOffset)..<plainSize))

        // Verify pool integrity diagnostics
        let diag = await pooledRemote.verifyPoolIntegrity()
        XCTAssertEqual(diag.verifiedFiles, 1)
        XCTAssertEqual(diag.healthySegments, 4)

        // Test live file rename propagation across OrbitDrive -> LockedRemote -> PooledGoogleDriveRemote
        let renamedNode = try await drive.rename(node.id, newName: "4K_Final_Cut.mov")
        XCTAssertEqual(renamedNode.name, "4K_Final_Cut.mov")
        XCTAssertNotNil(drive.lookup("4K_Final_Cut.mov", in: DriveNode.rootID))

        // Test remote file deletion and quota reclamation across the Google Drive pool
        let usedBeforeDelete = try await pooledRemote.account().usedBytes
        try await drive.remove(node.id)
        let usedAfterDelete = try await pooledRemote.account().usedBytes
        XCTAssertLessThan(usedAfterDelete, usedBeforeDelete)
    }

    func testAccountUploadPriorityAndMigration() async throws {
        let gb: Int64 = 1_073_741_824
        let mib: Int64 = 1_048_576

        // Account 1 has LESS free space (4 GB free), but is Priority #1.
        // Account 2 has MORE free space (12 GB free), but is Priority #2.
        // Account 3 has 8 GB free, Priority #3.
        let acc1 = LinkedGoogleAccount(
            id: "acc_1",
            email: "priority1@gmail.com",
            displayName: "Priority 1 Drive",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 11 * gb,
            heliumUsedBytes: 1 * gb,
            rootFolderId: "root_1",
            uploadPriority: 1,
            isUploadPaused: false
        )
        let acc2 = LinkedGoogleAccount(
            id: "acc_2",
            email: "priority2@gmail.com",
            displayName: "Priority 2 Drive",
            refreshToken: "rt_2",
            isPrimaryCatalogHost: false,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 3 * gb,
            heliumUsedBytes: 0,
            rootFolderId: "root_2",
            uploadPriority: 2,
            isUploadPaused: false
        )
        let acc3 = LinkedGoogleAccount(
            id: "acc_3",
            email: "priority3@gmail.com",
            displayName: "Priority 3 Drive",
            refreshToken: "rt_3",
            isPrimaryCatalogHost: false,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 7 * gb,
            heliumUsedBytes: 0,
            rootFolderId: "root_3",
            uploadPriority: 3,
            isUploadPaused: false
        )

        // 1. Priority Order strategy: 2 GB file fits on acc_1 (4 GB free), so acc_1 MUST be chosen even though acc_2 has 12 GB free
        let priorityAllocator = StoragePoolAllocator(
            safetyReserveBytes: 100 * mib,
            segmentChunkCount: 64,
            autoStripeAboveBytes: 8 * gb,
            routingStrategy: .priorityOrder,
            preferredAccountId: nil
        )
        let planPriority = try priorityAllocator.allocate(
            totalBytes: 2 * gb,
            encrypted: false,
            accounts: [acc2, acc3, acc1]
        )
        XCTAssertEqual(planPriority.segments.count, 1)
        XCTAssertEqual(planPriority.segments[0].accountId, "acc_1", "Priority #1 account should receive upload first when it has space")

        // 2. If file is 6 GB (larger than Priority #1's 4 GB free space), Priority Order falls back to Priority #2 (acc_2, 12 GB free)
        let planFallback = try priorityAllocator.allocate(
            totalBytes: 6 * gb,
            encrypted: false,
            accounts: [acc1, acc2, acc3]
        )
        XCTAssertEqual(planFallback.segments.count, 1)
        XCTAssertEqual(planFallback.segments[0].accountId, "acc_2", "Should overflow to Priority #2 when Priority #1 lacks space")

        // 3. Most Free Space strategy: 2 GB file routes to acc_2 (12 GB free) regardless of priority #1 on acc_1
        let freeSpaceAllocator = StoragePoolAllocator(
            safetyReserveBytes: 100 * mib,
            segmentChunkCount: 64,
            autoStripeAboveBytes: 8 * gb,
            routingStrategy: .mostFreeSpace,
            preferredAccountId: nil
        )
        let planMostFree = try freeSpaceAllocator.allocate(
            totalBytes: 2 * gb,
            encrypted: false,
            accounts: [acc1, acc2, acc3]
        )
        XCTAssertEqual(planMostFree.segments[0].accountId, "acc_2")

        // 4. Pinned Account override: pinning acc_3 routes directly to acc_3
        let pinnedAllocator = StoragePoolAllocator(
            safetyReserveBytes: 100 * mib,
            segmentChunkCount: 64,
            autoStripeAboveBytes: 8 * gb,
            routingStrategy: .pinnedAccount,
            preferredAccountId: "acc_3"
        )
        let planPinned = try pinnedAllocator.allocate(
            totalBytes: 2 * gb,
            encrypted: false,
            accounts: [acc1, acc2, acc3]
        )
        XCTAssertEqual(planPinned.segments[0].accountId, "acc_3")

        // 5. Pausing uploads on Priority #1 account skips acc_1 and routes to Priority #2 (acc_2)
        var pausedAcc1 = acc1
        pausedAcc1.isUploadPaused = true
        let planPaused = try priorityAllocator.allocate(
            totalBytes: 2 * gb,
            encrypted: false,
            accounts: [pausedAcc1, acc2, acc3]
        )
        XCTAssertEqual(planPaused.segments[0].accountId, "acc_2")

        // 6. Test GoogleAccountPool priority reordering & PooledGoogleDriveRemote.moveFileToAccount
        let mockCloud = MockGoogleDriveCloud()
        let pool = GoogleAccountPool(accounts: [acc1, acc2, acc3], transport: mockCloud)
        await pool.prioritiseAccountFirst(id: "acc_3")
        let reordered = await pool.accounts()
        XCTAssertEqual(reordered.first(where: { $0.id == "acc_3" })?.uploadPriority, 1)
        XCTAssertEqual(reordered.first(where: { $0.id == "acc_1" })?.uploadPriority, 2)

        // Upload a small file (lands on acc_3 since it is now #1) and then migrate it to acc_2
        let pooledRemote = PooledGoogleDriveRemote(pool: pool, allocator: priorityAllocator)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("priority_test_\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let sampleData = Data("Helium Priority & Account Migration Test".utf8)
        try sampleData.write(to: tempURL)

        let uploaded = try await pooledRemote.uploadNewFile(
            from: tempURL,
            name: "priority_doc.txt",
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )
        let initialManifest = try await pooledRemote.manifest(for: uploaded.id)
        XCTAssertEqual(initialManifest.segments.first?.accountId, "acc_3")

        let migratedManifest = try await pooledRemote.moveFileToAccount(id: uploaded.id, targetAccountId: "acc_2")
        XCTAssertEqual(migratedManifest.segments.count, 1)
        XCTAssertEqual(migratedManifest.segments.first?.accountId, "acc_2")
        let downloaded = try await pooledRemote.fetchRange(id: uploaded.id, offset: 0, length: sampleData.count)
        XCTAssertEqual(downloaded, sampleData)
    }

    func testCrossSyncRecycleBinFolderUnionAndMove() async throws {
        let mockCloud = MockGoogleDriveCloud()
        let gb: Int64 = 1024 * 1024 * 1024
        let acc1 = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 1 * gb,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1",
            uploadPriority: 1,
            isUploadPaused: false
        )
        let pool = GoogleAccountPool(accounts: [acc1], transport: mockCloud)
        let pooledRemote = PooledGoogleDriveRemote(pool: pool)

        // 1. Folder union deduplication: creating "Projects" twice at root returns the same unified folder ID
        let folderA = try await pooledRemote.createFolder(name: "Projects", parentId: RemoteItem.rootID)
        let folderB = try await pooledRemote.createFolder(name: "projects", parentId: RemoteItem.rootID)
        XCTAssertEqual(folderA.id, folderB.id, "Folders with same case-insensitive name and parent should union to one ID")

        // 2. Upload a file into root, then move/rename it into "Projects"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("trash_move_test_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try Data("Cross sync test payload".utf8).write(to: tempURL)

        let uploaded = try await pooledRemote.uploadNewFile(
            from: tempURL,
            name: "draft.txt",
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )

        let moved = try await pooledRemote.move(id: uploaded.id, toParent: folderA.id, newName: "final.txt")
        XCTAssertEqual(moved.parentId, folderA.id)
        XCTAssertEqual(moved.name, "final.txt")

        // 3. Soft-delete to Recycle Bin (moveToTrash) and verify allManifests reflects deleted == true
        let trashed = await pooledRemote.moveToTrash(id: uploaded.id)
        XCTAssertEqual(trashed?.item.deleted, true)
        let allAfterTrash = await pooledRemote.allManifests()
        XCTAssertEqual(allAfterTrash.first(where: { $0.item.id == uploaded.id })?.item.deleted, true)

        // 4. Restore from Recycle Bin (restoreFromTrash) and verify deleted == false
        let restored = await pooledRemote.restoreFromTrash(id: uploaded.id)
        XCTAssertEqual(restored?.item.deleted, false)
        let allAfterRestore = await pooledRemote.allManifests()
        XCTAssertEqual(allAfterRestore.first(where: { $0.item.id == uploaded.id })?.item.deleted, false)
    }

    func testRestoreFromTrashFailsWithoutMarkingItemActiveWhenSegmentMoveCannotRun() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("pool-manifests.json")
        let itemId = "pool_file_real_123"
        let trashedItem = RemoteItem(
            id: itemId,
            parentId: RemoteItem.rootID,
            name: "important.pdf",
            nameLocked: false,
            kind: .file,
            size: 1024,
            plainSize: 1024,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: 1_700_000_000_000,
            modifiedAt: 1_700_000_000_000,
            deleted: true
        )
        let manifest = PoolItemManifest(
            item: trashedItem,
            placementMode: .wholeFileSmartPlacement,
            segments: [
                PoolSegment(
                    index: 0,
                    accountId: "acc_real",
                    driveFileId: "drive_file_in_recycle_bin",
                    logicalOffset: 0,
                    byteLength: 1024,
                    sha256: ""
                )
            ]
        )
        let encoded = try JSONEncoder().encode([itemId: manifest])
        try encoded.write(to: manifestURL, options: .atomic)

        // Account has no access token and a short non-mock refresh token, so moveFileBetweenFolders fails immediately.
        let acc = LinkedGoogleAccount(
            id: "acc_real",
            email: "real@gmail.com",
            displayName: "Real Drive",
            refreshToken: "expired",
            accessToken: nil,
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * 1024 * 1024 * 1024,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_real"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: MockGoogleDriveCloud())
        let pooledRemote = PooledGoogleDriveRemote(pool: pool, manifestsPersistenceURL: manifestURL)

        let restored = await pooledRemote.restoreFromTrash(id: itemId)
        XCTAssertNil(restored, "restoreFromTrash must return nil when moving a segment out of Drive Recycle Bin fails")

        let stored = try await pooledRemote.manifest(for: itemId)
        XCTAssertTrue(stored.item.deleted, "Item must remain marked deleted in memory when restore fails")

        let persistedData = try Data(contentsOf: manifestURL)
        let persisted = try JSONDecoder().decode([String: PoolItemManifest].self, from: persistedData)
        XCTAssertEqual(persisted[itemId]?.item.deleted, true, "Persisted manifest must remain deleted when restore fails")
    }

    func testShouldSkipRecycleBinSyncRespectsRestoreGraceWindow() async throws {
        let mockCloud = MockGoogleDriveCloud()
        let gb: Int64 = 1024 * 1024 * 1024
        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 1 * gb,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: mockCloud)
        let pooledRemote = PooledGoogleDriveRemote(pool: pool)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("grace_test_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try Data("Grace window payload".utf8).write(to: tempURL)

        let uploaded = try await pooledRemote.uploadNewFile(
            from: tempURL,
            name: "grace.txt",
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )
        _ = await pooledRemote.moveToTrash(id: uploaded.id)
        let restored = await pooledRemote.restoreFromTrash(id: uploaded.id)
        XCTAssertEqual(restored?.item.deleted, false)

        let restoreCompletedAt = Date()
        let skipInsideWindow = await pooledRemote.shouldSkipRecycleBinSync(
            for: uploaded.id,
            now: restoreCompletedAt.addingTimeInterval(60)
        )
        XCTAssertTrue(skipInsideWindow)

        let skipUnrelated = await pooledRemote.shouldSkipRecycleBinSync(
            for: "unrelated_item_id",
            now: restoreCompletedAt.addingTimeInterval(60)
        )
        XCTAssertFalse(skipUnrelated)

        let skipAfterWindow = await pooledRemote.shouldSkipRecycleBinSync(
            for: uploaded.id,
            now: restoreCompletedAt.addingTimeInterval(121)
        )
        XCTAssertFalse(skipAfterWindow)
    }

    func testParseDriveFileListPageHandlesPaginationAndThrowsOnInvalidJSON() throws {
        let page1JSON = """
        {
          "nextPageToken": "tok_page_2",
          "files": [
            {"id": "f1", "name": "alpha.mov", "mimeType": "video/quicktime", "size": "1024"},
            {"id": "f2", "name": "Subfolder", "mimeType": "application/vnd.google-apps.folder"}
          ]
        }
        """
        let page1 = try URLSessionGoogleDriveTransport.parseDriveFileListPage(from: Data(page1JSON.utf8))
        XCTAssertEqual(page1.nextPageToken, "tok_page_2")
        XCTAssertEqual(page1.files.count, 2)
        XCTAssertEqual(page1.files[0].size, 1024)
        XCTAssertEqual(page1.files[1].mimeType, "application/vnd.google-apps.folder")

        let page2JSON = """
        {
          "files": [
            {"id": "f3", "name": "omega.pdf", "mimeType": "application/pdf", "size": "2048"}
          ]
        }
        """
        let page2 = try URLSessionGoogleDriveTransport.parseDriveFileListPage(from: Data(page2JSON.utf8))
        XCTAssertNil(page2.nextPageToken)
        XCTAssertEqual(page2.files.map(\.id), ["f3"])

        XCTAssertThrowsError(try URLSessionGoogleDriveTransport.parseDriveFileListPage(from: Data("not-json".utf8)))
        XCTAssertThrowsError(try URLSessionGoogleDriveTransport.parseDriveFileListPage(from: Data("{\"unexpected\":true}".utf8)))
    }

    func testShouldAbortMassDeleteThresholds() {
        XCTAssertFalse(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 0, totalActiveCount: 0))
        XCTAssertFalse(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 2, totalActiveCount: 10))
        XCTAssertTrue(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 3, totalActiveCount: 10))
        XCTAssertFalse(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 10, totalActiveCount: 100))
        XCTAssertTrue(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 11, totalActiveCount: 100))
        XCTAssertTrue(PooledGoogleDriveRemote.shouldAbortMassDelete(candidateCount: 1, totalActiveCount: 1))
    }

    func testRestoreWithHierarchyRestoresFolderChildrenAndParentChain() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("pool-manifests.json")
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        let parentFolder = PoolItemManifest(
            item: RemoteItem(
                id: "folder_parent",
                parentId: RemoteItem.rootID,
                name: "Projects",
                kind: .folder,
                size: 0,
                contentVersion: 1,
                metadataVersion: 1,
                createdAt: nowMs - 500_000,
                modifiedAt: nowMs,
                deleted: true
            ),
            placementMode: .wholeFileSmartPlacement,
            segments: []
        )
        let childFolder = PoolItemManifest(
            item: RemoteItem(
                id: "folder_child",
                parentId: "folder_parent",
                name: "2026",
                kind: .folder,
                size: 0,
                contentVersion: 1,
                metadataVersion: 2,
                createdAt: nowMs - 500_000,
                modifiedAt: nowMs + 500,
                deleted: true
            ),
            placementMode: .wholeFileSmartPlacement,
            segments: []
        )
        let grandChildFile = PoolItemManifest(
            item: RemoteItem(
                id: "file_grandchild",
                parentId: "folder_child",
                name: "cut.mov",
                kind: .file,
                size: 512,
                contentVersion: 1,
                metadataVersion: 3,
                createdAt: nowMs - 500_000,
                modifiedAt: nowMs + 900,
                deleted: true
            ),
            placementMode: .wholeFileSmartPlacement,
            segments: [
                PoolSegment(index: 0, accountId: "acc_1", driveFileId: "gdrive_acc_1_cut", logicalOffset: 0, byteLength: 512, sha256: "")
            ]
        )
        let olderTrashedChild = PoolItemManifest(
            item: RemoteItem(
                id: "file_older_trash",
                parentId: "folder_parent",
                name: "old_draft.txt",
                kind: .file,
                size: 128,
                contentVersion: 1,
                metadataVersion: 4,
                createdAt: nowMs - 500_000,
                modifiedAt: nowMs - 120_000,
                deleted: true
            ),
            placementMode: .wholeFileSmartPlacement,
            segments: [
                PoolSegment(index: 0, accountId: "acc_1", driveFileId: "gdrive_acc_1_old", logicalOffset: 0, byteLength: 128, sha256: "")
            ]
        )

        let encoded = try JSONEncoder().encode([
            parentFolder.item.id: parentFolder,
            childFolder.item.id: childFolder,
            grandChildFile.item.id: grandChildFile,
            olderTrashedChild.item.id: olderTrashedChild
        ])
        try encoded.write(to: manifestURL, options: .atomic)

        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * 1024 * 1024 * 1024,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: MockGoogleDriveCloud())
        let pooledRemote = PooledGoogleDriveRemote(pool: pool, manifestsPersistenceURL: manifestURL)

        // 1. Restoring folder restores co-trashed children (within 60s), leaving older trashed child in the bin
        let restoredFromFolder = await pooledRemote.restoreWithHierarchy(id: "folder_parent")
        XCTAssertEqual(Set(restoredFromFolder.map(\.item.id)), ["folder_parent", "folder_child", "file_grandchild"])
        let olderAfterFolderRestore = try await pooledRemote.manifest(for: "file_older_trash")
        XCTAssertTrue(olderAfterFolderRestore.item.deleted)

        // 2. Trash parent + grandchild again, then restore only grandchild: parent chain must be restored first
        _ = await pooledRemote.moveToTrash(id: "folder_parent")
        _ = await pooledRemote.moveToTrash(id: "folder_child")
        _ = await pooledRemote.moveToTrash(id: "file_grandchild")
        let restoredFromLeaf = await pooledRemote.restoreWithHierarchy(id: "file_grandchild")
        XCTAssertEqual(restoredFromLeaf.map(\.item.id), ["folder_parent", "folder_child", "file_grandchild"])
        let leafAfter = try await pooledRemote.manifest(for: "file_grandchild")
        XCTAssertFalse(leafAfter.item.deleted)
        XCTAssertEqual(leafAfter.item.parentId, "folder_child")
    }

    func testUnresolvedMissingIdsForDeletionSkipsDescendantsOfMovedFolders() {
        let parentById: [String: String?] = [
            "folder_a": RemoteItem.rootID,
            "folder_b": "folder_a",
            "file_in_b": "folder_b",
            "file_in_a": "folder_a",
            "unrelated_file": RemoteItem.rootID,
            "moved_root_file": RemoteItem.rootID
        ]
        let missing = ["folder_a", "folder_b", "file_in_b", "file_in_a", "moved_root_file", "unrelated_file"]
        let unresolved = PooledGoogleDriveRemote.unresolvedMissingIdsForDeletion(
            missingItemIds: missing,
            movedItemIds: ["folder_a", "moved_root_file"],
            movedFolderIds: ["folder_a"],
            parentById: parentById
        )
        XCTAssertEqual(unresolved, ["unrelated_file"])
    }

    func testMoveToTrashMatchesExactCanonicalCaseAndPreservesDifferentCase() async throws {
        let mockCloud = MockGoogleDriveCloud()
        let gb: Int64 = 1024 * 1024 * 1024
        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 15 * gb,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: mockCloud)
        let pooledRemote = PooledGoogleDriveRemote(pool: pool)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let upper1 = tempDir.appendingPathComponent("upper1.pdf")
        let upper2 = tempDir.appendingPathComponent("upper2.pdf")
        let lower = tempDir.appendingPathComponent("lower.pdf")
        try Data("Upper 1".utf8).write(to: upper1)
        try Data("Upper 2".utf8).write(to: upper2)
        try Data("Lower".utf8).write(to: lower)

        let itemUpper1 = try await pooledRemote.uploadNewFile(
            from: upper1, name: "Report.pdf", parentId: RemoteItem.rootID,
            clientId: UUID().uuidString, modifiedAt: Date(), link: false, progress: nil
        )
        let itemUpper2 = try await pooledRemote.uploadNewFile(
            from: upper2, name: "Report.pdf", parentId: RemoteItem.rootID,
            clientId: UUID().uuidString, modifiedAt: Date(), link: false, progress: nil
        )
        let itemLower = try await pooledRemote.uploadNewFile(
            from: lower, name: "report.pdf", parentId: RemoteItem.rootID,
            clientId: UUID().uuidString, modifiedAt: Date(), link: false, progress: nil
        )

        _ = await pooledRemote.moveToTrash(id: itemUpper1.id)

        let upper1After = try await pooledRemote.manifest(for: itemUpper1.id)
        let upper2After = try await pooledRemote.manifest(for: itemUpper2.id)
        let lowerAfter = try await pooledRemote.manifest(for: itemLower.id)
        XCTAssertTrue(upper1After.item.deleted)
        XCTAssertTrue(upper2After.item.deleted)
        XCTAssertFalse(lowerAfter.item.deleted)
    }

    func testReplaceBlobFailurePreservesOldContentAndManifest() async throws {
        actor FailingPutMockTransport: GoogleDriveTransport {
            let inner = MockGoogleDriveCloud()
            var failPutAfterCount: Int?
            var putCount = 0

            func setFailPutAfterCount(_ count: Int?) {
                failPutAfterCount = count
            }

            func putSegment(account: LinkedGoogleAccount, name: String, parentFolderId: String, data: Data) async throws -> String {
                putCount += 1
                if let limit = failPutAfterCount, putCount > limit {
                    throw GoogleDriveTransportError.httpError(statusCode: 500, message: "Injected upload failure")
                }
                return try await inner.putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
            }

            func fetchSegmentRange(account: LinkedGoogleAccount, driveFileId: String, offset: Int64, length: Int) async throws -> Data {
                try await inner.fetchSegmentRange(account: account, driveFileId: driveFileId, offset: offset, length: length)
            }

            func deleteSegment(account: LinkedGoogleAccount, driveFileId: String) async throws {
                try await inner.deleteSegment(account: account, driveFileId: driveFileId)
            }

            func fetchQuota(account: LinkedGoogleAccount) async throws -> (limit: Int64, used: Int64) {
                try await inner.fetchQuota(account: account)
            }
        }

        let transport = FailingPutMockTransport()
        let mib: Int64 = 1_048_576
        // 3 MiB quota with 0 reserve; initial 2 MiB file leaves 1 MiB free so replacement also exercises reclaimable quota accounting.
        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 3 * mib,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: transport)
        let allocator = StoragePoolAllocator(safetyReserveBytes: 0, segmentChunkCount: 1, autoStripeAboveBytes: 1 * mib)
        let pooledRemote = PooledGoogleDriveRemote(pool: pool, allocator: allocator)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let originalData = Data(repeating: 0xAA, count: Int(2 * mib))
        let originalURL = tempDir.appendingPathComponent("video.bin")
        try originalData.write(to: originalURL)

        let uploaded = try await pooledRemote.uploadNewFile(
            from: originalURL, name: "video.bin", parentId: RemoteItem.rootID,
            clientId: UUID().uuidString, modifiedAt: Date(), link: false, progress: nil
        )
        let originalManifest = try await pooledRemote.manifest(for: uploaded.id)

        // Allow 1st segment of replacement (put #3) to upload, fail on 2nd segment (put #4)
        await transport.setFailPutAfterCount(3)

        let replacementData = Data(repeating: 0xBB, count: Int(2 * mib))
        let replacementURL = tempDir.appendingPathComponent("video_new.bin")
        try replacementData.write(to: replacementURL)

        do {
            _ = try await pooledRemote.uploadOverwrite(
                id: uploaded.id,
                from: replacementURL,
                expectedVersion: originalManifest.item.contentVersion,
                modifiedAt: Date(),
                progress: nil
            )
            XCTFail("Expected uploadOverwrite to throw when replacement segment upload fails")
        } catch {
            // Expected
        }

        let afterManifest = try await pooledRemote.manifest(for: uploaded.id)
        XCTAssertEqual(afterManifest, originalManifest, "Manifest must stay unchanged when replacement fails")

        let readBack = try await pooledRemote.fetchRange(id: uploaded.id, offset: 0, length: originalData.count)
        XCTAssertEqual(readBack, originalData, "Original content must remain readable after failed replacement")
    }

    func testClassifyLocalHydratedFileThreeWayBaselineAndNoBaselineCases() throws {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let baseline = LocalSyncBaseline(
            contentVersion: 3,
            localSize: 1024,
            localModifiedAt: baseDate.timeIntervalSince1970
        )

        // 1. Baseline exists: not local, not cloud -> .unchanged (within 0.001s mtime tolerance)
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: 1024,
                localModifiedAt: baseDate.addingTimeInterval(0.0005),
                cloudSize: 1024,
                cloudContentVersion: 3,
                baseline: baseline
            ),
            .unchanged
        )

        // 1b. Baseline exists: 0.5s mtime drift with identical size exceeds 0.001s -> .overwriteCloud
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: 1024,
                localModifiedAt: baseDate.addingTimeInterval(0.5),
                cloudSize: 1024,
                cloudContentVersion: 3,
                baseline: baseline
            ),
            .overwriteCloud
        )

        // 2. Baseline exists: local only changed -> .overwriteCloud
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: 2048,
                localModifiedAt: baseDate.addingTimeInterval(5.0),
                cloudSize: 1024,
                cloudContentVersion: 3,
                baseline: baseline
            ),
            .overwriteCloud
        )

        // 3. Baseline exists: cloud only changed -> .refreshFromCloud
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: 1024,
                localModifiedAt: baseDate,
                cloudSize: 4096,
                cloudContentVersion: 4,
                baseline: baseline
            ),
            .refreshFromCloud
        )

        // 4. Baseline exists: both local and cloud changed -> .conflict
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: 2048,
                localModifiedAt: baseDate.addingTimeInterval(5.0),
                cloudSize: 4096,
                cloudContentVersion: 4,
                baseline: baseline
            ),
            .conflict
        )

        // 5. No baseline: local size and SHA-256 match cloud -> .unchanged
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let payload = Data("Helium sync baseline payload".utf8)
        let localFileURL = tempDir.appendingPathComponent("sample.bin")
        try payload.write(to: localFileURL)
        let localHash = PooledGoogleDriveRemote.computeFileSHA256ZKBase64(at: localFileURL)

        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: Int64(payload.count),
                localModifiedAt: Date(),
                localSHA256Base64: localHash,
                cloudSize: Int64(payload.count),
                cloudContentVersion: 2,
                cloudSHA256Base64: localHash,
                baseline: nil
            ),
            .unchanged
        )

        // 6. No baseline: size or hash mismatch -> .conflict
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: Int64(payload.count),
                localModifiedAt: Date(),
                localSHA256Base64: localHash,
                cloudSize: Int64(payload.count),
                cloudContentVersion: 2,
                cloudSHA256Base64: "different_hash",
                baseline: nil
            ),
            .conflict
        )
        XCTAssertEqual(
            PooledGoogleDriveRemote.classifyLocalHydratedFile(
                localSize: Int64(payload.count + 10),
                localModifiedAt: Date(),
                localSHA256Base64: localHash,
                cloudSize: Int64(payload.count),
                cloudContentVersion: 2,
                cloudSHA256Base64: localHash,
                baseline: nil
            ),
            .conflict
        )
    }

    func testLocalSyncBaselineStoreRoundTripAndRemove() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storeURL = tempDir.appendingPathComponent("local-sync-baselines.json")

        let writer = LocalSyncBaselineStore(fileURL: storeURL)
        let entry = LocalSyncBaseline(contentVersion: 5, localSize: 4096, localModifiedAt: 1_700_000_123.5)
        writer.setBaseline(entry, for: "item_1")

        let reader = LocalSyncBaselineStore(fileURL: storeURL)
        XCTAssertEqual(reader.baseline(for: "item_1"), entry)

        reader.removeBaseline(for: "item_1")
        let readerAfterRemove = LocalSyncBaselineStore(fileURL: storeURL)
        XCTAssertNil(readerAfterRemove.baseline(for: "item_1"))
    }

    func testIsCloudContentEditedDetectsChecksumAndSizeChanges() {
        // Matching MD5 and matching size -> not edited
        XCTAssertFalse(
            PooledGoogleDriveRemote.isCloudContentEdited(
                storedMD5: "abc123",
                storedSize: 1024,
                listedMD5: "abc123",
                listedSize: 1024
            )
        )
        // Different MD5 with identical byte size -> edited (same-size Drive Web replace)
        XCTAssertTrue(
            PooledGoogleDriveRemote.isCloudContentEdited(
                storedMD5: "abc123",
                storedSize: 1024,
                listedMD5: "def456",
                listedSize: 1024
            )
        )
        // Missing stored MD5 and matching size -> not edited (first listing backfills MD5)
        XCTAssertFalse(
            PooledGoogleDriveRemote.isCloudContentEdited(
                storedMD5: nil,
                storedSize: 1024,
                listedMD5: "abc123",
                listedSize: 1024
            )
        )
        // Different listed size (> 0), even without stored MD5 -> edited
        XCTAssertTrue(
            PooledGoogleDriveRemote.isCloudContentEdited(
                storedMD5: nil,
                storedSize: 1024,
                listedMD5: "abc123",
                listedSize: 2048
            )
        )
        // Different listed size (> 0) with missing listed MD5 -> edited
        XCTAssertTrue(
            PooledGoogleDriveRemote.isCloudContentEdited(
                storedMD5: "abc123",
                storedSize: 1024,
                listedMD5: nil,
                listedSize: 512
            )
        )
    }

    func testLegacyManifestJSONDecodesWithoutMD5Checksum() throws {
        let legacyJSON = """
        {
          "pool_file_legacy": {
            "item": {
              "id": "pool_file_legacy",
              "name": "legacy.txt",
              "nameLocked": false,
              "kind": "file",
              "size": 128,
              "contentVersion": 1,
              "metadataVersion": 1,
              "createdAt": 1700000000000,
              "modifiedAt": 1700000000000,
              "deleted": false,
              "shared": false
            },
            "placementMode": "whole_file",
            "segments": [
              {
                "index": 0,
                "accountId": "acc_1",
                "driveFileId": "drive_legacy_1",
                "logicalOffset": 0,
                "byteLength": 128,
                "sha256": "abc"
              }
            ]
          }
        }
        """
        let decoded = try JSONDecoder().decode(
            [String: PoolItemManifest].self,
            from: Data(legacyJSON.utf8)
        )
        let manifest = try XCTUnwrap(decoded["pool_file_legacy"])
        XCTAssertEqual(manifest.segments.count, 1)
        XCTAssertNil(manifest.segments[0].md5Checksum)
        XCTAssertEqual(manifest.segments[0].byteLength, 128)
    }

    func testParseDriveFileListPageReadsMD5AndModifiedTime() throws {
        let pageJSON = """
        {
          "files": [
            {
              "id": "drive_1",
              "name": "doc.txt",
              "mimeType": "text/plain",
              "size": "42",
              "md5Checksum": "9e107d9d372bb6826bd81d3542a419d6",
              "modifiedTime": "2026-11-26T09:15:30.123Z"
            }
          ]
        }
        """
        let parsed = try URLSessionGoogleDriveTransport.parseDriveFileListPage(from: Data(pageJSON.utf8))
        XCTAssertEqual(parsed.files.count, 1)
        XCTAssertEqual(parsed.files[0].id, "drive_1")
        XCTAssertEqual(parsed.files[0].size, 42)
        XCTAssertEqual(parsed.files[0].md5Checksum, "9e107d9d372bb6826bd81d3542a419d6")
        XCTAssertEqual(parsed.files[0].modifiedTime, "2026-11-26T09:15:30.123Z")
    }

    func testDecideBeforeOverwriteCoversAllCloudPrecheckCases() {
        // 1. Same md5Checksum and size -> overwrite
        XCTAssertEqual(
            PooledGoogleDriveRemote.decideBeforeOverwrite(
                storedMD5: "abc123",
                storedSize: 1024,
                fetchResult: .found(GoogleDriveLiveFileMetadata(md5Checksum: "abc123", size: 1024, trashed: false))
            ),
            .overwrite
        )

        // 2. MD5 differs (even with same size) -> conflict with cloud refresh
        let md5Diff = PooledGoogleDriveRemote.decideBeforeOverwrite(
            storedMD5: "abc123",
            storedSize: 1024,
            fetchResult: .found(GoogleDriveLiveFileMetadata(md5Checksum: "def456", size: 1024, trashed: false))
        )
        XCTAssertEqual(md5Diff, .conflictRefreshFromCloud)
        XCTAssertTrue(md5Diff.isConflict)

        // 3. Size differs -> conflict with cloud refresh
        let sizeDiff = PooledGoogleDriveRemote.decideBeforeOverwrite(
            storedMD5: "abc123",
            storedSize: 1024,
            fetchResult: .found(GoogleDriveLiveFileMetadata(md5Checksum: "abc123", size: 2048, trashed: false))
        )
        XCTAssertEqual(sizeDiff, .conflictRefreshFromCloud)
        XCTAssertTrue(sizeDiff.isConflict)

        // 4a. Missing (404) -> conflict leaving original as-is
        let missing = PooledGoogleDriveRemote.decideBeforeOverwrite(
            storedMD5: "abc123",
            storedSize: 1024,
            fetchResult: .missingOrTrashed
        )
        XCTAssertEqual(missing, .conflictLeaveOriginal)
        XCTAssertTrue(missing.isConflict)

        // 4b. Explicitly trashed -> conflict leaving original as-is
        let trashed = PooledGoogleDriveRemote.decideBeforeOverwrite(
            storedMD5: "abc123",
            storedSize: 1024,
            fetchResult: .found(GoogleDriveLiveFileMetadata(md5Checksum: "abc123", size: 1024, trashed: true))
        )
        XCTAssertEqual(trashed, .conflictLeaveOriginal)
        XCTAssertTrue(trashed.isConflict)

        // 5. Fetch failed (network / 5xx) -> skip overwrite this round
        XCTAssertEqual(
            PooledGoogleDriveRemote.decideBeforeOverwrite(
                storedMD5: "abc123",
                storedSize: 1024,
                fetchResult: .failed
            ),
            .skip
        )
    }

    func testParseDriveLiveFileMetadataResponseHandlesActiveTrashedMissingAndErrors() throws {
        let activeJSON = Data(#"{"md5Checksum":"deadbeef","size":"512","trashed":false}"#.utf8)
        let active = try URLSessionGoogleDriveTransport.parseDriveLiveFileMetadataResponse(data: activeJSON, statusCode: 200)
        XCTAssertEqual(active, .found(GoogleDriveLiveFileMetadata(md5Checksum: "deadbeef", size: 512, trashed: false)))

        let trashedJSON = Data(#"{"md5Checksum":"deadbeef","size":"512","trashed":true}"#.utf8)
        let trashed = try URLSessionGoogleDriveTransport.parseDriveLiveFileMetadataResponse(data: trashedJSON, statusCode: 200)
        XCTAssertEqual(trashed, .missingOrTrashed)

        let notFound = try URLSessionGoogleDriveTransport.parseDriveLiveFileMetadataResponse(data: Data(), statusCode: 404)
        XCTAssertEqual(notFound, .missingOrTrashed)

        let serverErr = try URLSessionGoogleDriveTransport.parseDriveLiveFileMetadataResponse(data: Data(), statusCode: 503)
        XCTAssertEqual(serverErr, .failed)

        XCTAssertThrowsError(
            try URLSessionGoogleDriveTransport.parseDriveLiveFileMetadataResponse(data: Data(), statusCode: 401)
        )
    }

    func testReplaceBlobStaleExpectedVersionThrowsWithoutUploadingOrMutating() async throws {
        actor CountingMockTransport: GoogleDriveTransport {
            let inner = MockGoogleDriveCloud()
            var putCount = 0
            var deleteCount = 0

            func resetCounts() {
                putCount = 0
                deleteCount = 0
            }

            func putSegment(account: LinkedGoogleAccount, name: String, parentFolderId: String, data: Data) async throws -> String {
                putCount += 1
                return try await inner.putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
            }

            func fetchSegmentRange(account: LinkedGoogleAccount, driveFileId: String, offset: Int64, length: Int) async throws -> Data {
                try await inner.fetchSegmentRange(account: account, driveFileId: driveFileId, offset: offset, length: length)
            }

            func deleteSegment(account: LinkedGoogleAccount, driveFileId: String) async throws {
                deleteCount += 1
                try await inner.deleteSegment(account: account, driveFileId: driveFileId)
            }

            func fetchQuota(account: LinkedGoogleAccount) async throws -> (limit: Int64, used: Int64) {
                try await inner.fetchQuota(account: account)
            }
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let transport = CountingMockTransport()
        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 1024 * 1_048_576,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: transport, secretStore: MemorySecretStore())
        let remote = PooledGoogleDriveRemote(pool: pool)

        let v1Payload = Data("version-one".utf8)
        let v1URL = tempDir.appendingPathComponent("v1.txt")
        try v1Payload.write(to: v1URL)
        let saved = try await remote.putBlob(
            source: try FileBlobSource(v1URL),
            plainSize: Int64(v1Payload.count),
            secrets: nil,
            name: .plain("notes.txt"),
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )
        XCTAssertEqual(saved.item.contentVersion, 1)

        // Advance cloud to v2 with a valid matching expectedVersion
        let v2Payload = Data("version-two".utf8)
        let v2URL = tempDir.appendingPathComponent("v2.txt")
        try v2Payload.write(to: v2URL)
        let updatedV2 = try await remote.replaceBlob(
            id: saved.item.id,
            source: try FileBlobSource(v2URL),
            plainSize: Int64(v2Payload.count),
            secrets: nil,
            expectedVersion: 1,
            modifiedAt: Date(),
            progress: nil
        )
        XCTAssertEqual(updatedV2.contentVersion, 2)

        let manifestBeforeStale = try await remote.manifest(for: saved.item.id)
        await transport.resetCounts()

        // Attempt overwrite with stale expectedVersion: 1
        let stalePayload = Data("stale-local-overwrite".utf8)
        let staleURL = tempDir.appendingPathComponent("stale.txt")
        try stalePayload.write(to: staleURL)
        do {
            _ = try await remote.replaceBlob(
                id: saved.item.id,
                source: try FileBlobSource(staleURL),
                plainSize: Int64(stalePayload.count),
                secrets: nil,
                expectedVersion: 1,
                modifiedAt: Date(),
                progress: nil
            )
            XCTFail("Expected PoolConflictError.versionMismatch when expectedVersion is stale")
        } catch let error as PoolConflictError {
            XCTAssertEqual(error, .versionMismatch(expected: 1, actual: 2))
        }

        let putsAfterStale = await transport.putCount
        let deletesAfterStale = await transport.deleteCount
        XCTAssertEqual(putsAfterStale, 0)
        XCTAssertEqual(deletesAfterStale, 0)

        let manifestAfterStale = try await remote.manifest(for: saved.item.id)
        XCTAssertEqual(manifestAfterStale, manifestBeforeStale)
        let fetchedData = try await remote.fetchRange(id: saved.item.id, offset: 0, length: v2Payload.count)
        XCTAssertEqual(fetchedData, v2Payload)
    }

    func testOrbitDriveFlushFileSavesConflictCopyAndPreservesStagingOnVersionMismatch() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let acc = LinkedGoogleAccount(
            id: "acc_1",
            email: "one@gmail.com",
            displayName: "Account One",
            refreshToken: "rt_1",
            isPrimaryCatalogHost: true,
            quotaLimitBytes: 1024 * 1_048_576,
            quotaUsedBytes: 0,
            heliumUsedBytes: 0,
            rootFolderId: "vault_1"
        )
        let pool = GoogleAccountPool(accounts: [acc], transport: MockGoogleDriveCloud(), secretStore: MemorySecretStore())
        let remote = PooledGoogleDriveRemote(pool: pool)

        let v1Data = Data("cloud-v1".utf8)
        let v1URL = tempDir.appendingPathComponent("doc_v1.txt")
        try v1Data.write(to: v1URL)
        let saved = try await remote.putBlob(
            source: try FileBlobSource(v1URL),
            plainSize: Int64(v1Data.count),
            secrets: nil,
            name: .plain("doc.txt"),
            parentId: RemoteItem.rootID,
            clientId: UUID().uuidString,
            modifiedAt: Date(),
            link: false,
            progress: nil
        )

        let drive = OrbitDrive(
            remote: remote,
            configuration: OrbitDrive.Configuration(
                directory: tempDir.appendingPathComponent("orbit"),
                deviceName: "TestMac",
                cacheLimits: ChunkStore.Limits.defaults(diskCapacity: 50_000_000_000)
            )
        )
        try await drive.sync()

        guard let node = drive.lookup("doc.txt", in: DriveNode.rootID) else {
            return XCTFail("Expected doc.txt in OrbitDrive tree")
        }
        XCTAssertEqual(node.contentVersion, 1)

        // Stage a local edit in OrbitDrive while based on v1
        let localEditData = Data("local-dirty-edit".utf8)
        try drive.write(node.id, offset: 0, data: localEditData)

        // Advance cloud to v2 externally, then run sync() to ensure dirtyContent preserves local base version 1
        let v2Data = Data("cloud-v2-newer".utf8)
        let v2URL = tempDir.appendingPathComponent("doc_v2.txt")
        try v2Data.write(to: v2URL)
        _ = try await remote.replaceBlob(
            id: saved.item.id,
            source: try FileBlobSource(v2URL),
            plainSize: Int64(v2Data.count),
            secrets: nil,
            expectedVersion: 1,
            modifiedAt: Date(),
            progress: nil
        )
        try await drive.sync()
        XCTAssertEqual(drive.node(node.id)?.contentVersion, 1)

        // Flushing should detect versionMismatch, keep the staging file, and save a Conflict copy
        _ = try await drive.flushFile(node.id)

        XCTAssertTrue(drive.staging.exists(node.id))
        let stagedReadback = try drive.staging.read(node.id, offset: 0, length: localEditData.count)
        XCTAssertEqual(stagedReadback, localEditData)

        let originalManifest = try await remote.manifest(for: saved.item.id)
        XCTAssertEqual(originalManifest.item.contentVersion, 2)
        let originalCloudData = try await remote.fetchRange(id: saved.item.id, offset: 0, length: v2Data.count)
        XCTAssertEqual(originalCloudData, v2Data)

        let allManifests = await remote.allManifests()
        let conflictManifest = allManifests.first { m in
            m.item.id != saved.item.id && m.item.name.hasPrefix("doc (Conflict copy ") && m.item.name.hasSuffix(").txt")
        }
        let conflictItem = try XCTUnwrap(conflictManifest)
        let conflictCloudData = try await remote.fetchRange(id: conflictItem.item.id, offset: 0, length: localEditData.count)
        XCTAssertEqual(conflictCloudData, localEditData)
    }
}
