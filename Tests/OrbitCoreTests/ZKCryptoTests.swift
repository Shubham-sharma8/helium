import XCTest
import CryptoKit
@testable import OrbitCore

final class ZKCryptoTests: XCTestCase {

    func testKeyDerivationAndKeyCheck() throws {
        let mk = ZK.random(32)
        XCTAssertEqual(mk.count, 32)

        let keys1 = ZK.deriveKeys(mk)
        let keys2 = ZK.deriveKeys(mk)

        // Deterministic derivation
        let hash1 = ZK.nameHash(keys1, "Project_Final.mov")
        let hash2 = ZK.nameHash(keys2, "Project_Final.mov")
        XCTAssertEqual(hash1, hash2)

        // Key check verification
        let check = try ZK.makeKeyCheck(keys1, nonce: nil)
        XCTAssertTrue(ZK.verifyKeyCheck(keys2, check))

        let wrongKeys = ZK.deriveKeys(ZK.random(32))
        XCTAssertFalse(ZK.verifyKeyCheck(wrongKeys, check))

        // Owner proof determinism
        let proof1 = ZK.ownerProof(mk)
        let proof2 = ZK.ownerProof(mk)
        XCTAssertEqual(proof1, proof2)
        XCTAssertNotEqual(proof1, ZK.ownerProof(ZK.random(32)))
    }

    func testRecoveryKeyEncodingAndWrapping() throws {
        let mk = ZK.random(32)
        let rk = ZK.random(32)

        let recoveryText = ZK.recoveryToText(rk)
        // 32 bytes in Base32 without padding = 52 characters
        XCTAssertEqual(recoveryText.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").count, 52)
        XCTAssertTrue(RecoveryKeyFile.looksLike(recoveryText))

        let decodedRK = try XCTUnwrap(ZK.recoveryFromText(recoveryText))
        XCTAssertEqual(decodedRK, rk)

        let wrappedMK = try ZK.wrapForRecovery(rk: rk, mk: mk, nonce: nil)
        let unwrappedMK = try ZK.unwrapWithRecovery(rk: decodedRK, wrappedMK)
        XCTAssertEqual(unwrappedMK, mk)

        // Wrong recovery key must fail
        XCTAssertThrowsError(try ZK.unwrapWithRecovery(rk: ZK.random(32), wrappedMK))
    }

    func testFilenameEncryptionAndUniquenessHash() throws {
        let keys = ZK.deriveKeys(ZK.random(32))
        let original = "2026 Budget & Roadmap (Final).xlsx"

        let wire1 = try WireName.locked(original, keys: keys)
        let wire2 = try WireName.locked(original, keys: keys)

        // Ciphertext differs due to random nonce, but HMAC hash is identical
        XCTAssertNotEqual(wire1.text, wire2.text)
        XCTAssertNotNil(wire1.hash)
        XCTAssertEqual(wire1.hash, wire2.hash)

        let unlocked = try ZK.unlockName(keys, wire1.text)
        XCTAssertEqual(unlocked, original)
    }

    func testPieceEncryptionAndTamperProtection() throws {
        let secrets = FileSecrets.new()
        let plain0 = Data((0..<(1024 * 64)).map { UInt8($0 & 0xFF) })
        let plain1 = Data((0..<(1024 * 32)).map { UInt8(($0 * 7) & 0xFF) })

        let cipher0 = try ZK.lockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 0, last: false, plain0)
        let cipher1 = try ZK.lockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 1, last: true, plain1)

        XCTAssertEqual(cipher0.count, plain0.count + ZK.tag)
        XCTAssertEqual(cipher1.count, plain1.count + ZK.tag)

        // Valid unlock
        let dec0 = try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 0, last: false, cipher0)
        let dec1 = try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 1, last: true, cipher1)
        XCTAssertEqual(dec0, plain0)
        XCTAssertEqual(dec1, plain1)

        // Reordering attack: unlocking chunk 0 at index 1 must fail
        XCTAssertThrowsError(try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 1, last: false, cipher0))

        // Truncation attack: unlocking non-final chunk 0 with last=true must fail
        XCTAssertThrowsError(try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 0, last: true, cipher0))
    }

    func testLockedSizeAndLockedBlobSource() throws {
        // 0-byte file still has 1 piece (16-byte tag)
        XCTAssertEqual(ZK.pieceCount(0), 1)
        XCTAssertEqual(ZK.lockedSize(0), 16)

        // Exact 1 MiB file -> 1 piece -> 1_048_576 + 16 = 1_048_592 bytes
        let oneMiB = Int64(ZK.piece)
        XCTAssertEqual(ZK.pieceCount(oneMiB), 1)
        XCTAssertEqual(ZK.lockedSize(oneMiB), oneMiB + 16)

        // 2.5 MiB file -> 3 pieces -> 2.5 MiB + 48 bytes
        let twoPointFiveMiB = oneMiB * 2 + 524_288
        XCTAssertEqual(ZK.pieceCount(twoPointFiveMiB), 3)
        XCTAssertEqual(ZK.lockedSize(twoPointFiveMiB), twoPointFiveMiB + 48)

        // Create temporary file of 1.5 MiB and read through LockedBlobSource
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let plainSize = Int(oneMiB) + 200_000
        var plainData = Data(count: plainSize)
        for i in 0..<plainSize {
            plainData[i] = UInt8((i * 31 + 17) & 0xFF)
        }
        try plainData.write(to: tempURL)

        let fileSource = try FileBlobSource(tempURL)
        let secrets = FileSecrets.new()
        let lockedSource = LockedBlobSource(plain: fileSource, secrets: secrets)

        XCTAssertEqual(lockedSource.size, ZK.lockedSize(Int64(plainSize)))

        // Read encrypted chunk 0 (1_048_592 bytes) and chunk 1 (200_016 bytes)
        let encChunk0 = try lockedSource.read(offset: 0, length: ZK.piece + ZK.tag)
        let encChunk1 = try lockedSource.read(offset: Int64(ZK.piece + ZK.tag), length: 200_000 + ZK.tag)

        let decChunk0 = try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 0, last: false, encChunk0)
        let decChunk1 = try ZK.unlockPiece(fk: secrets.key, fileNonce: secrets.nonce, index: 1, last: true, encChunk1)

        XCTAssertEqual(decChunk0 + decChunk1, plainData)
    }

    func testDeviceGrantAndDropSealingAndShares() throws {
        let mk = ZK.random(32)
        let keys = ZK.deriveKeys(mk)

        // 1. Device Pairing via P-256 ECDH
        let newDeviceKey = P256.KeyAgreement.PrivateKey()
        let macKey = P256.KeyAgreement.PrivateKey()
        let devicePubData = newDeviceKey.publicKey.rawRepresentation

        let code1 = ZK.matchCode(devicePubData)
        let code2 = ZK.matchCode(devicePubData)
        XCTAssertEqual(code1, code2)
        XCTAssertEqual(code1.count, 6)

        let grant = try ZK.grantForDevice(mk: mk, devicePublic: devicePubData, mac: macKey, nonce: nil)
        let recoveredMK = try ZK.openDeviceGrant(
            wrap: grant.wrap,
            macPublic: grant.macPublic,
            devicePrivateKey: newDeviceKey
        )
        XCTAssertEqual(recoveredMK, mk)

        // 2. Public File Drop Sealing (P-256 ephemeral ECDH)
        let dropKey = P256.KeyAgreement.PrivateKey()
        let dropPrivateWrap = try ZK.seal(keys.wrap, dropKey.rawRepresentation, label: "helium drop v1", nonce: nil)
        let fk = ZK.random(32)
        let eph = P256.KeyAgreement.PrivateKey()

        let sealed = try ZK.sealForDrop(
            dropPublic: dropKey.publicKey.rawRepresentation,
            fk: fk,
            name: "Client_Upload.pdf",
            eph: eph,
            fkNonce: nil,
            nameNonce: nil
        )
        let openedDrop = try ZK.openDrop(
            keys,
            dropPrivateWrap: dropPrivateWrap,
            sealPublic: sealed.sealPublic,
            fileKey: sealed.fileKey,
            name: sealed.name
        )
        XCTAssertEqual(openedDrop.fk, fk)
        XCTAssertEqual(openedDrop.name, "Client_Upload.pdf")

        // 3. Share Links
        let sk = ZK.random(ZK.shareKeyBytes)
        let share = try ZK.makeShare(keys, fk: fk, name: "Shared_Video.mp4", sk: sk, keyNonce: nil, wrapNonce: nil)
        let openedShare = try ZK.openShare(sk: share.sk, wrap: share.wrap)
        XCTAssertEqual(openedShare.fk, fk)
        XCTAssertEqual(openedShare.name, "Shared_Video.mp4")
    }
}
