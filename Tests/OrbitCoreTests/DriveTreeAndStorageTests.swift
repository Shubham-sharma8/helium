import XCTest
@testable import OrbitCore

final class DriveTreeAndStorageTests: XCTestCase {

    func testDriveTreeInodeAssignmentAndChangeApplication() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-tree.json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let tree = DriveTree(file: tempFile)
        XCTAssertNotNil(tree.node(DriveNode.rootID))
        XCTAssertEqual(DriveNode.onDiskBytes, 0)

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let remoteFolder = RemoteItem(
            id: "rem_folder_1",
            parentId: RemoteItem.rootID,
            name: "Projects",
            kind: .folder,
            size: 0,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: now,
            modifiedAt: now,
            deleted: false
        )
        let remoteFile = RemoteItem(
            id: "rem_file_1",
            parentId: "rem_folder_1",
            name: "Timeline.drp",
            kind: .file,
            size: 4_194_304,
            contentVersion: 1,
            metadataVersion: 1,
            createdAt: now,
            modifiedAt: now,
            deleted: false
        )

        let applyResult = tree.apply([remoteFolder, remoteFile], seq: 10, complete: true)
        XCTAssertTrue(applyResult.changedFolders.contains(""))
        XCTAssertTrue(applyResult.changedFolders.contains("Projects"))

        let folderNode = try XCTUnwrap(tree.lookup("Projects", in: DriveNode.rootID))
        XCTAssertTrue(folderNode.isFolder)
        XCTAssertEqual(folderNode.remoteID, "rem_folder_1")

        let fileNode = try XCTUnwrap(tree.lookup("Timeline.drp", in: folderNode.id))
        XCTAssertEqual(fileNode.size, 4_194_304)
        XCTAssertEqual(tree.folderPath(of: fileNode.id), ["Projects", "Timeline.drp"])

        // Persist and reload from disk
        tree.save()
        let reloaded = DriveTree(file: tempFile)
        let reloadedFile = try XCTUnwrap(reloaded.node(remoteID: "rem_file_1"))
        XCTAssertEqual(reloadedFile.id, fileNode.id)
        XCTAssertEqual(reloadedFile.name, "Timeline.drp")
    }

    func testSearchIndexFilteringAndRanking() throws {
        let tree = DriveTree(file: nil)
        let folder = try tree.add(name: "Footage", in: DriveNode.rootID, isFolder: true, remote: nil)
        _ = try tree.add(name: "B_Roll_Sunset_4K.mov", in: folder.id, isFolder: false, remote: nil)
        _ = try tree.add(name: "Podcast_Master.wav", in: folder.id, isFolder: false, remote: nil)
        _ = try tree.add(name: "Quarterly_Report.pdf", in: DriveNode.rootID, isFolder: false, remote: nil)
        _ = try tree.add(name: "Cover_Photo.png", in: DriveNode.rootID, isFolder: false, remote: nil)

        let index = SearchIndex(tree: tree)

        let videos = index.search("sunset", kind: .videos, limit: 10)
        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.node.name, "B_Roll_Sunset_4K.mov")
        XCTAssertEqual(videos.first?.folders, ["Footage"])

        let docs = index.search("report", kind: .documents, limit: 10)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs.first?.node.name, "Quarterly_Report.pdf")

        let audio = index.search("podcast", kind: .audio, limit: 10)
        XCTAssertEqual(audio.count, 1)
        XCTAssertEqual(audio.first?.node.name, "Podcast_Master.wav")

        let photos = index.search("cover", kind: .photos, limit: 10)
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.first?.node.name, "Cover_Photo.png")
    }

    func testStagingStreamSourceAndXattrStore() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let staging = Staging(root: tempRoot.appendingPathComponent("staging"))
        let xattrs = XattrStore(root: tempRoot.appendingPathComponent("xattrs"))

        let nodeID: UInt64 = 42
        try staging.create(nodeID)
        XCTAssertTrue(staging.exists(nodeID))

        let payload = Data("Hello Helium FSKit Streaming World!".utf8)
        try staging.write(nodeID, offset: 0, data: payload)
        XCTAssertEqual(staging.size(nodeID), Int64(payload.count))

        let readBack = try staging.read(nodeID, offset: 6, length: 6)
        XCTAssertEqual(String(data: readBack, encoding: .utf8), "Helium")

        // Extended attributes
        let finderInfo = Data(repeating: 0x04, count: 32)
        try xattrs.set(XattrStore.finderInfoName, to: finderInfo, of: nodeID, policy: .create)
        XCTAssertEqual(xattrs.names(of: nodeID), [XattrStore.finderInfoName])
        XCTAssertEqual(try xattrs.get(XattrStore.finderInfoName, of: nodeID), finderInfo)

        // Duplicate create should throw
        XCTAssertThrowsError(try xattrs.set(XattrStore.finderInfoName, to: finderInfo, of: nodeID, policy: .create))
        // Replace should succeed
        let updatedInfo = Data(repeating: 0x08, count: 32)
        try xattrs.set(XattrStore.finderInfoName, to: updatedInfo, of: nodeID, policy: .replace)
        XCTAssertEqual(try xattrs.get(XattrStore.finderInfoName, of: nodeID), updatedInfo)
    }

    func testUploadGovernorCongestionControl() {
        let gov = UploadGovernor()
        gov.record(rtt: 0.025, at: 1.0) // 25ms baseline RTT

        // Low RTT + good throughput -> rate increases or stays high
        let rate1 = gov.adjust(rtt: 0.028, throughput: 10_000_000, at: 2.0)
        XCTAssertNotNil(rate1)
        XCTAssertGreaterThan(rate1 ?? 0, 10_000_000)

        // Bufferbloat RTT spike (250ms vs 25ms baseline) -> rate throttles down
        let rate2 = gov.adjust(rtt: 0.250, throughput: 10_000_000, at: 3.5)
        XCTAssertNotNil(rate2)
        XCTAssertLessThan(rate2 ?? .infinity, 10_000_000)
        XCTAssertGreaterThanOrEqual(rate2 ?? 0, UploadGovernor.minRate)
    }

    func testAsyncPrimitivesKeepListAndOrbitDriveOperations() async throws {
        let asyncLock = AsyncLock()
        let val = await asyncLock.withLock { 42 }
        XCTAssertEqual(val, 42)

        let gate = AsyncGate(initiallyOpen: false)
        XCTAssertFalse(gate.isOpen)
        gate.open()
        await gate.wait()
        XCTAssertTrue(gate.isOpen)

        let sem = AsyncSemaphore(value: 2)
        let semResult = await sem.withPermit { "permit_ok" }
        XCTAssertEqual(semResult, "permit_ok")

        var failure = LastingFailure(window: 10.0)
        let t0 = Date()
        XCTAssertFalse(failure.recordFailure("net err", now: t0))
        XCTAssertTrue(failure.recordFailure("net err", now: t0.addingTimeInterval(12.0)))
        XCTAssertEqual(failure.message, "net err")
        failure.clear()
        XCTAssertNil(failure.message)

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let keepList = KeepList(fileURL: tempRoot.appendingPathComponent("keep.json"))
        keepList.setKept("item_1", kept: true)
        XCTAssertTrue(keepList.isKept("item_1"))
        XCTAssertEqual(keepList.all(), ["item_1"])
        keepList.setKept("item_1", kept: false)
        XCTAssertFalse(keepList.isKept("item_1"))

        let keyMgr = KeyManager(store: MemorySecretStore())
        let mk = ZK.random(32)
        try keyMgr.saveMasterKey(mk)
        XCTAssertEqual(keyMgr.masterKey(), mk)
        XCTAssertNotNil(keyMgr.accountKeys())

        // OrbitDrive local write -> staging -> flush -> overwrite -> remove
        let remote = InMemoryLockableRemote()
        let locked = LockedRemote(
            inner: remote,
            keys: try XCTUnwrap(keyMgr.accountKeys()),
            locksWrites: true,
            directory: tempRoot
        )
        let drive = OrbitDrive(
            remote: locked,
            configuration: .init(
                directory: tempRoot.appendingPathComponent("drive"),
                deviceName: "TestMac",
                cacheLimits: .defaults(diskCapacity: 10_000_000_000)
            )
        )
        try await drive.start()

        let folder = try await drive.createFolder(name: "Clips", in: DriveNode.rootID)
        XCTAssertTrue(folder.isFolder)

        let created = try drive.createFile(name: "Note.txt", in: folder.id)
        try drive.write(created.id, offset: 0, data: Data("First draft".utf8))
        let stagedRead = try await drive.read(created.id, offset: 0, length: 11)
        XCTAssertEqual(String(data: stagedRead, encoding: .utf8), "First draft")

        let flushed = try await drive.flushFile(created.id)
        XCTAssertNotNil(flushed.remoteID)
        XCTAssertFalse(flushed.dirtyContent)

        // Overwrite and flush again
        try drive.write(created.id, offset: 0, data: Data("Updated draft!".utf8))
        let reflushed = try await drive.flushFile(created.id)
        XCTAssertEqual(reflushed.contentVersion, 2)

        let cloudRead = try await drive.read(created.id, offset: 0, length: 14)
        XCTAssertEqual(String(data: cloudRead, encoding: .utf8), "Updated draft!")

        try await drive.remove(created.id)
        XCTAssertNil(drive.node(created.id))
    }
}
