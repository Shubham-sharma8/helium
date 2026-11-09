import Foundation
import CryptoKit
import Security

/// Zero-Knowledge End-to-End Encryption (E2EE) cryptographic engine for Helium (`OrbitCore.ZK`).
public enum ZK: Sendable {
    /// 1 MiB plaintext piece size (`1_048_576` bytes).
    public static let piece: Int = 1_048_576
    /// 16-byte AES-GCM authentication tag.
    public static let tag: Int = 16
    /// 32-byte share key length.
    public static let shareKeyBytes: Int = 32

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case badBase64
        case badKeySize
        case shortCiphertext
        case badCiphertext
        case badPlaintext
        case badPublicKey
        case badRecoveryKey

        public var errorDescription: String? {
            switch self {
            case .badBase64: return "Invalid Base64URL encoding."
            case .badKeySize: return "Invalid cryptographic key size."
            case .shortCiphertext: return "Ciphertext is shorter than nonce + tag."
            case .badCiphertext: return "Failed to authenticate or decrypt ciphertext."
            case .badPlaintext: return "Decrypted plaintext is malformed."
            case .badPublicKey: return "Invalid P-256 public key representation."
            case .badRecoveryKey: return "Invalid 52-character recovery key."
            }
        }
    }

    /// Subkeys deterministically derived via HKDF-SHA256 from the 32-byte Master Key (`mk`).
    public struct AccountKeys: Sendable {
        public let wrap: SymmetricKey
        public let nameEnc: SymmetricKey
        public let nameMAC: SymmetricKey
        public let check: SymmetricKey
        public let shareWrap: SymmetricKey

        public init(
            wrap: SymmetricKey,
            nameEnc: SymmetricKey,
            nameMAC: SymmetricKey,
            check: SymmetricKey,
            shareWrap: SymmetricKey
        ) {
            self.wrap = wrap
            self.nameEnc = nameEnc
            self.nameMAC = nameMAC
            self.check = check
            self.shareWrap = shareWrap
        }
    }

    /// Wrapped file key and file nonce stored in encrypted item metadata.
    public struct WrappedFile: Codable, Equatable, Sendable {
        public let key: String
        public let nonce: String

        public init(key: String, nonce: String) {
            self.key = key
            self.nonce = nonce
        }
    }

    /// Generates cryptographically secure random bytes.
    public static func random(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: max(0, count))
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Base64URL encoding without padding.
    public static func b64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Base64URL decoding (accepts standard or URL-safe Base64 with or without padding).
    public static func unb64(_ string: String) throws -> Data {
        var normalized = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: normalized) else {
            throw Error.badBase64
        }
        return data
    }

    /// Derives 5 domain-separated 256-bit subkeys from the 32-byte Master Key (`mk`).
    public static func deriveKeys(_ mk: Data) -> AccountKeys {
        let master = SymmetricKey(data: mk)
        let wrap = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            info: Data("helium wrap v1".utf8),
            outputByteCount: 32
        )
        let nameEnc = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            info: Data("helium name enc v1".utf8),
            outputByteCount: 32
        )
        let nameMAC = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            info: Data("helium name mac v1".utf8),
            outputByteCount: 32
        )
        let check = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            info: Data("helium keycheck v1".utf8),
            outputByteCount: 32
        )
        let shareWrap = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            info: Data("helium share wrap v1".utf8),
            outputByteCount: 32
        )
        return AccountKeys(wrap: wrap, nameEnc: nameEnc, nameMAC: nameMAC, check: check, shareWrap: shareWrap)
    }

    /// Low-level AES-256-GCM seal with AAD label, returning Base64URL(nonce || ciphertext || tag).
    public static func seal(_ key: SymmetricKey, _ plaintext: Data, label: String, nonce: Data? = nil) throws -> String {
        let aesNonce: AES.GCM.Nonce
        if let nonce {
            aesNonce = try AES.GCM.Nonce(data: nonce)
        } else {
            aesNonce = AES.GCM.Nonce()
        }
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: aesNonce, authenticating: Data(label.utf8))
        guard let combined = sealed.combined else {
            throw Error.badCiphertext
        }
        return b64(combined)
    }

    /// Low-level AES-256-GCM open with AAD label from Base64URL(nonce || ciphertext || tag).
    public static func open(_ key: SymmetricKey, _ encoded: String, label: String) throws -> Data {
        let combined = try unb64(encoded)
        guard combined.count >= 12 + tag else {
            throw Error.shortCiphertext
        }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key, authenticating: Data(label.utf8))
        } catch {
            throw Error.badCiphertext
        }
    }

    private static let keyCheckCanary = Data("helium-keycheck-v1".utf8)

    public static func makeKeyCheck(_ keys: AccountKeys, nonce: Data? = nil) throws -> String {
        try seal(keys.check, keyCheckCanary, label: "helium keycheck v1", nonce: nonce)
    }

    public static func verifyKeyCheck(_ keys: AccountKeys, _ check: String) -> Bool {
        guard let opened = try? open(keys.check, check, label: "helium keycheck v1") else {
            return false
        }
        return opened == keyCheckCanary
    }

    public static func ownerProof(_ mk: Data) -> String {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: mk),
            info: Data("helium owner proof v1".utf8),
            outputByteCount: 32
        )
        let mac = HMAC<SHA256>.authenticationCode(for: Data("helium-owner-v1".utf8), using: key)
        return b64(Data(mac))
    }

    // MARK: - RFC 4648 Base32 Recovery Key (52 chars for 32 bytes)

    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    public static func recoveryToText(_ rk: Data) -> String {
        var output = ""
        var buffer = 0
        var bitsLeft = 0
        for byte in rk {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                let index = (buffer >> (bitsLeft - 5)) & 0x1F
                output.append(base32Alphabet[index])
                bitsLeft -= 5
            }
        }
        if bitsLeft > 0 {
            let index = (buffer << (5 - bitsLeft)) & 0x1F
            output.append(base32Alphabet[index])
        }
        // Group into chunks of 4 separated by dashes for human readability
        var grouped: [String] = []
        var idx = output.startIndex
        while idx < output.endIndex {
            let end = output.index(idx, offsetBy: 4, limitedBy: output.endIndex) ?? output.endIndex
            grouped.append(String(output[idx..<end]))
            idx = end
        }
        return grouped.joined(separator: "-")
    }

    public static func recoveryFromText(_ text: String) -> Data? {
        let cleaned = text.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == 52 else { return nil }
        var lookup: [Character: Int] = [:]
        for (i, ch) in base32Alphabet.enumerated() {
            lookup[ch] = i
        }
        var buffer = 0
        var bitsLeft = 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32)
        for ch in cleaned {
            guard let val = lookup[ch] else { return nil }
            buffer = (buffer << 5) | val
            bitsLeft += 5
            if bitsLeft >= 8 {
                let byte = UInt8((buffer >> (bitsLeft - 8)) & 0xFF)
                bytes.append(byte)
                bitsLeft -= 8
            }
        }
        guard bytes.count == 32 else { return nil }
        return Data(bytes)
    }

    public static func wrapForRecovery(rk: Data, mk: Data, nonce: Data? = nil) throws -> String {
        guard rk.count == 32, mk.count == 32 else { throw Error.badKeySize }
        let wrapKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: rk),
            info: Data("helium recovery wrap v1".utf8),
            outputByteCount: 32
        )
        return try seal(wrapKey, mk, label: "helium recovery wrap v1", nonce: nonce)
    }

    public static func unwrapWithRecovery(rk: Data, _ wrapped: String) throws -> Data {
        guard rk.count == 32 else { throw Error.badKeySize }
        let wrapKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: rk),
            info: Data("helium recovery wrap v1".utf8),
            outputByteCount: 32
        )
        return try open(wrapKey, wrapped, label: "helium recovery wrap v1")
    }

    // MARK: - Filename Encryption & HMAC Collision Detection

    public static func lockName(_ keys: AccountKeys, _ name: String, nonce: Data? = nil) throws -> String {
        try seal(keys.nameEnc, Data(name.utf8), label: "helium name v1", nonce: nonce)
    }

    public static func unlockName(_ keys: AccountKeys, _ locked: String) throws -> String {
        let data = try open(keys.nameEnc, locked, label: "helium name v1")
        guard let str = String(data: data, encoding: .utf8) else {
            throw Error.badPlaintext
        }
        return str
    }

    public static func nameHash(_ keys: AccountKeys, _ name: String) -> String {
        let normalized = name.precomposedStringWithCanonicalMapping.lowercased()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(normalized.utf8), using: keys.nameMAC)
        return b64(Data(mac))
    }

    // MARK: - Per-File Key Wrapping & 1 MiB Piece Encryption

    public static func wrapFileKey(_ keys: AccountKeys, fk: Data, fileNonce: Data, wrapNonce: Data? = nil) throws -> WrappedFile {
        guard fk.count == 32, fileNonce.count == 12 else { throw Error.badKeySize }
        let wrappedKey = try seal(keys.wrap, fk, label: "helium file key v1", nonce: wrapNonce)
        return WrappedFile(key: wrappedKey, nonce: b64(fileNonce))
    }

    public static func unwrapFileKey(_ keys: AccountKeys, _ wrapped: WrappedFile) throws -> (fk: Data, fileNonce: Data) {
        let fk = try open(keys.wrap, wrapped.key, label: "helium file key v1")
        let fn = try unb64(wrapped.nonce)
        guard fk.count == 32, fn.count == 12 else { throw Error.badKeySize }
        return (fk, fn)
    }

    /// Derives the 12-byte chunk nonce by XORing the last 8 bytes of `fileNonce` with big-endian `index`.
    private static func chunkNonce(fileNonce: Data, index: UInt64) throws -> AES.GCM.Nonce {
        guard fileNonce.count == 12 else { throw Error.badKeySize }
        var bytes = [UInt8](fileNonce)
        var beIndex = index.bigEndian
        withUnsafeBytes(of: &beIndex) { idxBytes in
            for i in 0..<8 {
                bytes[4 + i] ^= idxBytes[i]
            }
        }
        return try AES.GCM.Nonce(data: Data(bytes))
    }

    private static func chunkAAD(index: UInt64, last: Bool) -> Data {
        var aad = Data("helium piece v1:".utf8)
        var beIndex = index.bigEndian
        withUnsafeBytes(of: &beIndex) { aad.append(contentsOf: $0) }
        aad.append(last ? 1 : 0)
        return aad
    }

    /// Encrypts a single 1 MiB piece, returning `ciphertext || 16-byte tag` (no nonce prefix needed because nonce is deterministic).
    public static func lockPiece(fk: Data, fileNonce: Data, index: UInt64, last: Bool, _ plain: Data) throws -> Data {
        guard fk.count == 32 else { throw Error.badKeySize }
        let nonce = try chunkNonce(fileNonce: fileNonce, index: index)
        let aad = chunkAAD(index: index, last: last)
        let box = try AES.GCM.seal(plain, using: SymmetricKey(data: fk), nonce: nonce, authenticating: aad)
        var out = Data(capacity: box.ciphertext.count + tag)
        out.append(box.ciphertext)
        out.append(box.tag)
        return out
    }

    /// Decrypts and authenticates a single 1 MiB piece (`ciphertext || 16-byte tag`), preventing chunk reordering and truncation.
    public static func unlockPiece(fk: Data, fileNonce: Data, index: UInt64, last: Bool, _ cipherAndTag: Data) throws -> Data {
        guard fk.count == 32 else { throw Error.badKeySize }
        guard cipherAndTag.count >= tag else { throw Error.shortCiphertext }
        let nonce = try chunkNonce(fileNonce: fileNonce, index: index)
        let aad = chunkAAD(index: index, last: last)
        let cipherLen = cipherAndTag.count - tag
        let ciphertext = cipherAndTag.prefix(cipherLen)
        let tagData = cipherAndTag.suffix(tag)
        do {
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tagData)
            return try AES.GCM.open(box, using: SymmetricKey(data: fk), authenticating: aad)
        } catch {
            throw Error.badCiphertext
        }
    }

    public static func pieceCount(_ plainSize: Int64) -> Int64 {
        if plainSize <= 0 { return 1 }
        let p = Int64(piece)
        return (plainSize + p - 1) / p
    }

    public static func lockedSize(_ plainSize: Int64) -> Int64 {
        let count = pieceCount(plainSize)
        return max(0, plainSize) + count * Int64(tag)
    }

    // MARK: - P-256 ECDH Device Pairing, File Drops, and Share Links

    public static func matchCode(_ devicePublic: Data) -> String {
        let digest = SHA256.hash(data: Data("helium-match-v1:".utf8) + devicePublic)
        let bytes = Array(digest)
        let value = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        return String(format: "%06d", value % 1_000_000)
    }

    public static func grantForDevice(
        mk: Data,
        devicePublic: Data,
        mac: P256.KeyAgreement.PrivateKey = P256.KeyAgreement.PrivateKey(),
        nonce: Data? = nil
    ) throws -> (wrap: String, macPublic: String) {
        let peerPub: P256.KeyAgreement.PublicKey
        do {
            peerPub = try P256.KeyAgreement.PublicKey(rawRepresentation: devicePublic)
        } catch {
            throw Error.badPublicKey
        }
        let macPubRaw = mac.publicKey.rawRepresentation
        let shared = try mac.sharedSecretFromKeyAgreement(with: peerPub)
        let symKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("helium device grant v1:".utf8) + macPubRaw + peerPub.rawRepresentation,
            outputByteCount: 32
        )
        let wrapped = try seal(symKey, mk, label: "helium device grant v1", nonce: nonce)
        return (wrapped, b64(macPubRaw))
    }

    public static func openDeviceGrant(
        wrap: String,
        macPublic: String,
        devicePrivateKey: P256.KeyAgreement.PrivateKey
    ) throws -> Data {
        let macPubData = try unb64(macPublic)
        let peerPub = try P256.KeyAgreement.PublicKey(rawRepresentation: macPubData)
        let shared = try devicePrivateKey.sharedSecretFromKeyAgreement(with: peerPub)
        let symKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("helium device grant v1:".utf8) + peerPub.rawRepresentation + devicePrivateKey.publicKey.rawRepresentation,
            outputByteCount: 32
        )
        return try open(symKey, wrap, label: "helium device grant v1")
    }

    private struct DropPayload: Codable {
        let fk: String
        let name: String
    }

    public static func sealForDrop(
        dropPublic: Data,
        fk: Data,
        name: String,
        eph: P256.KeyAgreement.PrivateKey = P256.KeyAgreement.PrivateKey(),
        fkNonce: Data? = nil,
        nameNonce: Data? = nil
    ) throws -> (sealPublic: String, fileKey: String, name: String) {
        let recipientPub: P256.KeyAgreement.PublicKey
        do {
            recipientPub = try P256.KeyAgreement.PublicKey(rawRepresentation: dropPublic)
        } catch {
            throw Error.badPublicKey
        }
        let ephPubRaw = eph.publicKey.rawRepresentation
        let shared = try eph.sharedSecretFromKeyAgreement(with: recipientPub)
        let dropKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("helium drop seal v1:".utf8) + ephPubRaw + recipientPub.rawRepresentation,
            outputByteCount: 32
        )
        let sealedFK = try seal(dropKey, fk, label: "helium drop fk v1", nonce: fkNonce)
        let sealedName = try seal(dropKey, Data(name.utf8), label: "helium drop name v1", nonce: nameNonce)
        return (b64(ephPubRaw), sealedFK, sealedName)
    }

    public static func openDrop(
        _ keys: AccountKeys,
        dropPrivateWrap: String,
        sealPublic: String,
        fileKey: String,
        name: String
    ) throws -> (fk: Data, name: String) {
        let dropPrivRaw = try open(keys.wrap, dropPrivateWrap, label: "helium drop v1")
        let dropPriv = try P256.KeyAgreement.PrivateKey(rawRepresentation: dropPrivRaw)
        let ephPubRaw = try unb64(sealPublic)
        let ephPub = try P256.KeyAgreement.PublicKey(rawRepresentation: ephPubRaw)
        let shared = try dropPriv.sharedSecretFromKeyAgreement(with: ephPub)
        let dropKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("helium drop seal v1:".utf8) + ephPub.rawRepresentation + dropPriv.publicKey.rawRepresentation,
            outputByteCount: 32
        )
        let fk = try open(dropKey, fileKey, label: "helium drop fk v1")
        let nameData = try open(dropKey, name, label: "helium drop name v1")
        guard let nameStr = String(data: nameData, encoding: .utf8) else {
            throw Error.badPlaintext
        }
        return (fk, nameStr)
    }

    private struct SharePayload: Codable {
        let fk: String
        let name: String
    }

    public static func shareKey(_ sk: Data) throws -> SymmetricKey {
        guard sk.count == shareKeyBytes else { throw Error.badKeySize }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: sk),
            info: Data("helium share link v1".utf8),
            outputByteCount: 32
        )
    }

    public static func makeShare(
        _ keys: AccountKeys,
        fk: Data,
        name: String,
        sk: Data? = nil,
        keyNonce: Data? = nil,
        wrapNonce: Data? = nil
    ) throws -> (sk: Data, keyWrap: String, wrap: String) {
        let actualSK = sk ?? random(shareKeyBytes)
        let sKey = try shareKey(actualSK)
        let payload = SharePayload(fk: b64(fk), name: name)
        let payloadBytes = try JSONEncoder().encode(payload)
        let wrap = try seal(sKey, payloadBytes, label: "helium share payload v1", nonce: wrapNonce)
        let keyWrap = try seal(keys.shareWrap, actualSK, label: "helium share key v1", nonce: keyNonce)
        return (actualSK, keyWrap, wrap)
    }

    public static func openShare(sk: Data, wrap: String) throws -> (fk: Data, name: String) {
        let sKey = try shareKey(sk)
        let payloadBytes = try open(sKey, wrap, label: "helium share payload v1")
        let payload = try JSONDecoder().decode(SharePayload.self, from: payloadBytes)
        let fk = try unb64(payload.fk)
        return (fk, payload.name)
    }

    public static func rewrapShare(_ keys: AccountKeys, keyWrap: String, fk: Data, name: String) throws -> String {
        let sk = try open(keys.shareWrap, keyWrap, label: "helium share key v1")
        let sKey = try shareKey(sk)
        let payload = SharePayload(fk: b64(fk), name: name)
        let payloadBytes = try JSONEncoder().encode(payload)
        return try seal(sKey, payloadBytes, label: "helium share payload v1")
    }
}

/// Recovery Key File reader/writer (`Helium Recovery Key.txt`).
public enum RecoveryKeyFile: Sendable {
    public static let defaultFilename = "Helium Recovery Key.txt"

    public static func format(email: String, recoveryKeyText: String, createdAt: Date = Date()) -> String {
        let iso = ISO8601DateFormatter().string(from: createdAt)
        return """
        HELIUM ZERO-KNOWLEDGE RECOVERY KEY
        Account: \(email)
        Created: \(iso)

        \(recoveryKeyText)

        Keep this recovery key in a safe place. Helium cannot recover encrypted files without it.
        """
    }

    public static func looksLike(_ text: String) -> Bool {
        if let _ = ZK.recoveryFromText(text) {
            return true
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if ZK.recoveryFromText(trimmed) != nil {
                return true
            }
        }
        return false
    }

    public static func extractKey(from text: String) -> Data? {
        if let direct = ZK.recoveryFromText(text) {
            return direct
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let key = ZK.recoveryFromText(trimmed) {
                return key
            }
        }
        return nil
    }
}
