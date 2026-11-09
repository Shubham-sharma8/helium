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
}
