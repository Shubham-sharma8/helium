import Foundation
import CryptoKit

public struct GoogleDriveRemoteFile: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let size: Int64

    public init(id: String, name: String, mimeType: String, size: Int64) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.size = size
    }
}

public enum GoogleDriveTransportError: LocalizedError, Sendable {
    case missingAccessToken(email: String)
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingAccessToken(let email):
            return "Google Drive session expired for \(email). Please click 'Sign in with Google' to reconnect."
        case .httpError(let code, let msg):
            return "Google Drive API HTTP \(code): \(msg)"
        }
    }
}

/// Transport abstraction for Google Drive v3 API operations (`files.create`, `files.get?alt=media` with `Range`, `files.delete`, `about.get`).
public protocol GoogleDriveTransport: Sendable {
    func putSegment(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data
    ) async throws -> String

    func putSegmentWithProgress(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> String

    func fetchSegmentRange(
        account: LinkedGoogleAccount,
        driveFileId: String,
        offset: Int64,
        length: Int
    ) async throws -> Data

    func deleteSegment(
        account: LinkedGoogleAccount,
        driveFileId: String
    ) async throws

    func fetchQuota(
        account: LinkedGoogleAccount
    ) async throws -> (limit: Int64, used: Int64)
}

extension GoogleDriveTransport {
    public func putSegmentWithProgress(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> String {
        let id = try await putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
        progress?(Int64(data.count))
        return id
    }
}

/// Production `URLSession` transport speaking Google Drive REST API v3 (`www.googleapis.com/drive/v3` and `www.googleapis.com/upload/drive/v3`).
public final class URLSessionGoogleDriveTransport: GoogleDriveTransport, Sendable {
    private let session: URLSession
    private let timeoutInterval: TimeInterval
    private let resumableChunkSize: Int = 8 * 1_048_576 // 8 MiB chunks (multiple of 256 KiB)

    private static let allowedFileIdScalars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

    public init(session: URLSession = .shared, timeoutInterval: TimeInterval = 300.0) {
        self.session = session
        self.timeoutInterval = timeoutInterval
    }

    private func validatedDriveFileId(_ rawId: String) throws -> String {
        guard !rawId.isEmpty,
              rawId.unicodeScalars.allSatisfy({ Self.allowedFileIdScalars.contains($0) }) else {
            throw URLError(.badURL)
        }
        return rawId
    }

    private func makeDriveURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Exchanges a persisted OAuth 2.0 `refresh_token` for a fresh `access_token`.
    public func refreshAccessToken(refreshToken: String, clientId: String) async throws -> String {
        guard !refreshToken.isEmpty, !clientId.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "oauth2.googleapis.com"
        components.path = "/token"
        guard let tokenURL = components.url else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: tokenURL, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        req.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String, !newToken.isEmpty else {
            let msg = String(data: data, encoding: .utf8) ?? "Token refresh failed"
            throw GoogleDriveTransportError.httpError(
                statusCode: (resp as? HTTPURLResponse)?.statusCode ?? 401,
                message: msg
            )
        }
        return newToken
    }

    public func ensureHeliumVaultFolder(accessToken: String) async throws -> String {
        // 1. Search for an existing non-trashed "Helium Pool Vault" or legacy "Helium Pool Vault" folder
        let query = "(name = 'Helium Pool Vault' or name = 'Helium Pool Vault') and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        let searchURL = try makeDriveURL(
            path: "/drive/v3/files",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: "files(id,name)"),
                URLQueryItem(name: "pageSize", value: "5")
            ]
        )
        var searchReq = URLRequest(url: searchURL, timeoutInterval: 30)
        searchReq.httpMethod = "GET"
        searchReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let (searchData, searchResp) = try? await session.data(for: searchReq),
           let httpSearch = searchResp as? HTTPURLResponse,
           (200..<300).contains(httpSearch.statusCode),
           let json = try? JSONSerialization.jsonObject(with: searchData) as? [String: Any],
           let files = json["files"] as? [[String: Any]],
           let firstId = files.first?["id"] as? String, !firstId.isEmpty {
            return firstId
        }

        // 2. Otherwise create "Helium Pool Vault" in root
        let createURL = try makeDriveURL(path: "/drive/v3/files")
        var req = URLRequest(url: createURL, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let meta: [String: Any] = [
            "name": "Helium Pool Vault",
            "mimeType": "application/vnd.google-apps.folder"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: meta)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let folderId = json["id"] as? String, !folderId.isEmpty {
            return folderId
        }
        return "root"
    }

    public func renameFile(
        account: LinkedGoogleAccount,
        driveFileId: String,
        newName: String
    ) async throws {
        guard let token = account.accessToken, !token.isEmpty else { return }
        let safeFileId = try validatedDriveFileId(driveFileId)
        let url = try makeDriveURL(path: "/drive/v3/files/\(safeFileId)")
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": newName]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: req)
    }

    /// Finds or creates a subfolder named `name` inside `parentFolderId` on the given Google Drive account.
    public func ensureSubfolder(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String
    ) async throws -> String {
        guard let token = account.accessToken, !token.isEmpty else {
            throw GoogleDriveTransportError.missingAccessToken(email: account.email)
        }
        let targetParent: String
        if parentFolderId.isEmpty || parentFolderId == "root" || parentFolderId.hasPrefix("helium_root_") {
            targetParent = (try? await ensureHeliumVaultFolder(accessToken: token)) ?? "root"
        } else {
            targetParent = parentFolderId
        }
        let safeParent = try validatedDriveFileId(targetParent)
        let escapedName = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let query = "'\(safeParent)' in parents and name = '\(escapedName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        let searchURL = try makeDriveURL(
            path: "/drive/v3/files",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: "files(id,name)"),
                URLQueryItem(name: "pageSize", value: "5")
            ]
        )
        var searchReq = URLRequest(url: searchURL, timeoutInterval: 30)
        searchReq.httpMethod = "GET"
        searchReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let (searchData, searchResp) = try? await session.data(for: searchReq),
           let httpSearch = searchResp as? HTTPURLResponse,
           (200..<300).contains(httpSearch.statusCode),
           let json = try? JSONSerialization.jsonObject(with: searchData) as? [String: Any],
           let files = json["files"] as? [[String: Any]],
           let firstId = files.first?["id"] as? String, !firstId.isEmpty {
            return firstId
        }

        let createURL = try makeDriveURL(path: "/drive/v3/files")
        var req = URLRequest(url: createURL, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let meta: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [safeParent]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: meta)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let folderId = json["id"] as? String, !folderId.isEmpty {
            return folderId
        }
        return safeParent
    }

    /// Finds or creates the `Recycle Bin` folder inside the account's `Helium Pool Vault` folder on Google Drive.
    public func ensureRecycleBinFolder(account: LinkedGoogleAccount) async throws -> String {
        try await ensureSubfolder(
            account: account,
            name: "Recycle Bin",
            parentFolderId: account.rootFolderId
        )
    }

    /// Moves a Google Drive file between folders (e.g., into `Recycle Bin` when deleted, or back to `Helium Pool Vault` when restored).
    public func moveFileBetweenFolders(
        account: LinkedGoogleAccount,
        driveFileId: String,
        targetFolderId: String
    ) async throws {
        guard let token = account.accessToken, !token.isEmpty else { return }
        let safeFileId = try validatedDriveFileId(driveFileId)
        let safeTargetId = try validatedDriveFileId(targetFolderId)

        // Fetch current parents of the file first
        let getURL = try makeDriveURL(
            path: "/drive/v3/files/\(safeFileId)",
            queryItems: [URLQueryItem(name: "fields", value: "parents,trashed")]
        )
        var getReq = URLRequest(url: getURL, timeoutInterval: 30)
        getReq.httpMethod = "GET"
        getReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var existingParents: [String] = []
        if let (getData, getResp) = try? await session.data(for: getReq),
           let httpGet = getResp as? HTTPURLResponse,
           (200..<300).contains(httpGet.statusCode),
           let json = try? JSONSerialization.jsonObject(with: getData) as? [String: Any],
           let parents = json["parents"] as? [String] {
            existingParents = parents.filter { $0 != safeTargetId }
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "addParents", value: safeTargetId)
        ]
        if !existingParents.isEmpty {
            queryItems.append(URLQueryItem(name: "removeParents", value: existingParents.joined(separator: ",")))
        }
        let patchURL = try makeDriveURL(path: "/drive/v3/files/\(safeFileId)", queryItems: queryItems)
        var patchReq = URLRequest(url: patchURL, timeoutInterval: 30)
        patchReq.httpMethod = "PATCH"
        patchReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        patchReq.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        patchReq.httpBody = try JSONSerialization.data(withJSONObject: ["trashed": false])
        _ = try await session.data(for: patchReq)
    }

    public func listFilesInFolder(
        account: LinkedGoogleAccount,
        folderId: String
    ) async throws -> [GoogleDriveRemoteFile] {
        let all = try await listItemsInFolder(account: account, folderId: folderId)
        return all.filter { $0.mimeType != "application/vnd.google-apps.folder" }
    }

    /// Lists both regular files AND folders (`application/vnd.google-apps.folder`) inside `folderId` on Google Drive.
    public func listItemsInFolder(
        account: LinkedGoogleAccount,
        folderId: String
    ) async throws -> [GoogleDriveRemoteFile] {
        guard let token = account.accessToken, !token.isEmpty else {
            throw GoogleDriveTransportError.missingAccessToken(email: account.email)
        }
        let targetFolder = (folderId.isEmpty || folderId.hasPrefix("helium_root_")) ? "root" : folderId
        let safeFolder = try validatedDriveFileId(targetFolder)
        let query = "'\(safeFolder)' in parents and trashed = false"
        let url = try makeDriveURL(
            path: "/drive/v3/files",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size)"),
                URLQueryItem(name: "pageSize", value: "250")
            ]
        )
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "List folder failed"
            throw GoogleDriveTransportError.httpError(statusCode: http.statusCode, message: msg)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]] else {
            return []
        }
        return files.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            let mime = (dict["mimeType"] as? String) ?? "application/octet-stream"
            let sizeStr = dict["size"] as? String ?? "0"
            let size = Int64(sizeStr) ?? 0
            return GoogleDriveRemoteFile(id: id, name: name, mimeType: mime, size: size)
        }
    }

    /// Returns `true` ONLY when Google Drive API explicitly confirms the file/folder is HTTP 404 (not found) or has `"trashed": true`.
    public func checkFileTrashedOrMissing(
        account: LinkedGoogleAccount,
        driveFileId: String
    ) async -> Bool {
        guard let token = account.accessToken, !token.isEmpty,
              let safeFileId = try? validatedDriveFileId(driveFileId),
              let url = try? makeDriveURL(
                  path: "/drive/v3/files/\(safeFileId)",
                  queryItems: [URLQueryItem(name: "fields", value: "id,trashed")]
              ) else {
            return false
        }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        if http.statusCode == 404 {
            return true
        }
        if (200..<300).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let trashed = json["trashed"] as? Bool {
            return trashed
        }
        return false
    }

    public func putSegment(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data
    ) async throws -> String {
        try await putSegmentWithProgress(
            account: account,
            name: name,
            parentFolderId: parentFolderId,
            data: data,
            progress: nil
        )
    }

    public func putSegmentWithProgress(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> String {
        guard let token = account.accessToken, !token.isEmpty else {
            throw GoogleDriveTransportError.missingAccessToken(email: account.email)
        }

        // Resolve valid parentFolderId (avoiding any legacy mock folder IDs)
        let validParent: String?
        if parentFolderId.isEmpty || parentFolderId == "root" || parentFolderId.hasPrefix("helium_root_") {
            validParent = try? await ensureHeliumVaultFolder(accessToken: token)
        } else {
            validParent = parentFolderId
        }

        let uploadSessionURL: URL
        do {
            uploadSessionURL = try await initiateResumableSession(
                token: token,
                name: name,
                parentFolderId: validParent,
                totalBytes: data.count
            )
        } catch {
            // Fallback without explicit parent folder if the stored folder ID was deleted on Google Drive
            uploadSessionURL = try await initiateResumableSession(
                token: token,
                name: name,
                parentFolderId: nil,
                totalBytes: data.count
            )
        }

        // Step 2: Upload binary payload in resumable chunks (or single PUT for empty/small payloads)
        let total = data.count
        if total == 0 {
            var putReq = URLRequest(url: uploadSessionURL, timeoutInterval: timeoutInterval)
            putReq.httpMethod = "PUT"
            putReq.setValue("0", forHTTPHeaderField: "Content-Length")
            putReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            putReq.httpBody = Data()
            let (putData, putResp) = try await session.data(for: putReq)
            guard let httpPut = putResp as? HTTPURLResponse, (200..<300).contains(httpPut.statusCode) else {
                let errMsg = String(data: putData, encoding: .utf8) ?? "Empty upload failed"
                throw GoogleDriveTransportError.httpError(
                    statusCode: (putResp as? HTTPURLResponse)?.statusCode ?? 500,
                    message: errMsg
                )
            }
            let json = try JSONSerialization.jsonObject(with: putData) as? [String: Any]
            guard let fileId = json?["id"] as? String else {
                throw URLError(.cannotParseResponse)
            }
            return fileId
        }

        var offset = 0
        while offset < total {
            let chunkLen = min(resumableChunkSize, total - offset)
            let chunkEnd = offset + chunkLen - 1
            let chunkData = data.subdata(in: offset..<(offset + chunkLen))

            var putReq = URLRequest(url: uploadSessionURL, timeoutInterval: timeoutInterval)
            putReq.httpMethod = "PUT"
            putReq.setValue("\(chunkLen)", forHTTPHeaderField: "Content-Length")
            putReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            if chunkLen < total {
                putReq.setValue("bytes \(offset)-\(chunkEnd)/\(total)", forHTTPHeaderField: "Content-Range")
            }
            putReq.httpBody = chunkData

            let (putData, putResp) = try await session.data(for: putReq)
            guard let httpPut = putResp as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            offset += chunkLen
            progress?(Int64(offset))

            if httpPut.statusCode == 308 {
                // 308 Resume Incomplete: chunk accepted by Google Drive, continue to next chunk
                continue
            } else if (200..<300).contains(httpPut.statusCode) {
                let json = try JSONSerialization.jsonObject(with: putData) as? [String: Any]
                guard let fileId = json?["id"] as? String else {
                    throw URLError(.cannotParseResponse)
                }
                return fileId
            } else {
                let errBody = String(data: putData, encoding: .utf8) ?? "Upload chunk failed"
                throw GoogleDriveTransportError.httpError(statusCode: httpPut.statusCode, message: errBody)
            }
        }

        throw URLError(.cannotCreateFile)
    }

    private func initiateResumableSession(
        token: String,
        name: String,
        parentFolderId: String?,
        totalBytes: Int
    ) async throws -> URL {
        let initURL = try makeDriveURL(
            path: "/upload/drive/v3/files",
            queryItems: [URLQueryItem(name: "uploadType", value: "resumable")]
        )
        var initReq = URLRequest(url: initURL, timeoutInterval: timeoutInterval)
        initReq.httpMethod = "POST"
        initReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        initReq.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        initReq.setValue("\(totalBytes)", forHTTPHeaderField: "X-Upload-Content-Length")
        initReq.setValue("application/octet-stream", forHTTPHeaderField: "X-Upload-Content-Type")

        var meta: [String: Any] = ["name": name]
        if let parentFolderId, !parentFolderId.isEmpty, parentFolderId != "root" {
            meta["parents"] = [parentFolderId]
        }
        initReq.httpBody = try JSONSerialization.data(withJSONObject: meta)

        let (initData, initResp) = try await session.data(for: initReq)
        guard let httpInit = initResp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpInit.statusCode),
              let location = httpInit.value(forHTTPHeaderField: "Location"),
              let uploadURL = URL(string: location) else {
            let errBody = String(data: initData, encoding: .utf8) ?? "Resumable session initiation failed"
            throw GoogleDriveTransportError.httpError(statusCode: httpInit.statusCode, message: errBody)
        }
        return uploadURL
    }

    public func fetchSegmentRange(
        account: LinkedGoogleAccount,
        driveFileId: String,
        offset: Int64,
        length: Int
    ) async throws -> Data {
        guard length > 0 else { return Data() }
        guard let token = account.accessToken, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        let safeFileId = try validatedDriveFileId(driveFileId)
        let url = try makeDriveURL(
            path: "/drive/v3/files/\(safeFileId)",
            queryItems: [URLQueryItem(name: "alt", value: "media")]
        )
        let endByte = offset + Int64(length) - 1
        var req = URLRequest(url: url, timeoutInterval: max(timeoutInterval, 120))
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("bytes=\(offset)-\(endByte)", forHTTPHeaderField: "Range")

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw GoogleDriveTransportError.httpError(statusCode: 401, message: "Unauthorized (expired access token)")
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    public func deleteSegment(
        account: LinkedGoogleAccount,
        driveFileId: String
    ) async throws {
        guard let token = account.accessToken, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        let safeFileId = try validatedDriveFileId(driveFileId)
        let url = try makeDriveURL(path: "/drive/v3/files/\(safeFileId)")
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: req)
    }

    public func fetchQuota(
        account: LinkedGoogleAccount
    ) async throws -> (limit: Int64, used: Int64) {
        guard let token = account.accessToken, !token.isEmpty else {
            return (account.quotaLimitBytes, account.quotaUsedBytes)
        }
        let url = try makeDriveURL(
            path: "/drive/v3/about",
            queryItems: [URLQueryItem(name: "fields", value: "storageQuota")]
        )
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quota = root["storageQuota"] as? [String: Any] else {
            return (account.quotaLimitBytes, account.quotaUsedBytes)
        }
        let limit = Int64(quota["limit"] as? String ?? "") ?? account.quotaLimitBytes
        let usage = Int64(quota["usage"] as? String ?? "") ?? account.quotaUsedBytes
        return (limit, usage)
    }
}

/// Simulated multi-account Google Drive cloud storage backend for deterministic testing and offline verification.
public actor MockGoogleDriveCloud: GoogleDriveTransport {
    private var filesByAccount: [String: [String: Data]] = [:]

    public init() {}

    public func putSegment(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data
    ) async throws -> String {
        let fileId = "gdrive_\(account.id)_\(UUID().uuidString)"
        filesByAccount[account.id, default: [:]][fileId] = data
        return fileId
    }

    public func fetchSegmentRange(
        account: LinkedGoogleAccount,
        driveFileId: String,
        offset: Int64,
        length: Int
    ) async throws -> Data {
        guard let blob = filesByAccount[account.id]?[driveFileId] else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard offset < blob.count, length > 0 else { return Data() }
        let start = Int(max(0, offset))
        let end = min(blob.count, start + length)
        return blob.subdata(in: start..<end)
    }

    public func deleteSegment(
        account: LinkedGoogleAccount,
        driveFileId: String
    ) async throws {
        filesByAccount[account.id]?[driveFileId] = nil
    }

    public func fetchQuota(
        account: LinkedGoogleAccount
    ) async throws -> (limit: Int64, used: Int64) {
        let stored = filesByAccount[account.id]?.values.reduce(Int64(0)) { $0 + Int64($1.count) } ?? 0
        return (account.quotaLimitBytes, account.quotaUsedBytes + stored)
    }
}

/// Routes live OAuth-authenticated Google Drive accounts (with an `accessToken`) to `URLSessionGoogleDriveTransport`
/// while routing unit-test accounts (without an `accessToken`) to `MockGoogleDriveCloud`.
public final class HybridGoogleDriveTransport: GoogleDriveTransport, Sendable {
    public let live: URLSessionGoogleDriveTransport
    public let mock: MockGoogleDriveCloud

    public init(
        live: URLSessionGoogleDriveTransport = URLSessionGoogleDriveTransport(),
        mock: MockGoogleDriveCloud = MockGoogleDriveCloud()
    ) {
        self.live = live
        self.mock = mock
    }

    private func isLive(_ account: LinkedGoogleAccount) -> Bool {
        if let token = account.accessToken, !token.isEmpty {
            return true
        }
        return false
    }

    public func putSegment(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data
    ) async throws -> String {
        if isLive(account) {
            return try await live.putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
        }
        return try await mock.putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
    }

    public func putSegmentWithProgress(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String,
        data: Data,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> String {
        if isLive(account) {
            return try await live.putSegmentWithProgress(
                account: account,
                name: name,
                parentFolderId: parentFolderId,
                data: data,
                progress: progress
            )
        }
        let id = try await mock.putSegment(account: account, name: name, parentFolderId: parentFolderId, data: data)
        progress?(Int64(data.count))
        return id
    }

    public func fetchSegmentRange(
        account: LinkedGoogleAccount,
        driveFileId: String,
        offset: Int64,
        length: Int
    ) async throws -> Data {
        if isLive(account) {
            return try await live.fetchSegmentRange(account: account, driveFileId: driveFileId, offset: offset, length: length)
        }
        return try await mock.fetchSegmentRange(account: account, driveFileId: driveFileId, offset: offset, length: length)
    }

    public func deleteSegment(
        account: LinkedGoogleAccount,
        driveFileId: String
    ) async throws {
        if isLive(account) {
            try await live.deleteSegment(account: account, driveFileId: driveFileId)
        } else {
            try await mock.deleteSegment(account: account, driveFileId: driveFileId)
        }
    }

    public func fetchQuota(
        account: LinkedGoogleAccount
    ) async throws -> (limit: Int64, used: Int64) {
        if isLive(account) {
            return try await live.fetchQuota(account: account)
        }
        return try await mock.fetchQuota(account: account)
    }
}

/// Manages the set of linked Google Drive accounts, their quotas, and their persistence in the shared App Group container.
/// OAuth refresh/access tokens are stored in `SecretStore` and redacted from the JSON metadata file on disk.
public actor GoogleAccountPool {
    private var accountsById: [String: LinkedGoogleAccount] = [:]
    private var orderedIds: [String] = []
    public let transport: any GoogleDriveTransport
    private let persistenceURL: URL?
    private let secretStore: any SecretStore

    private static let legacySimulatedIds: Set<String> = [
        "gdrive_primary",
        "gdrive_secondary",
        "gdrive_tertiary"
    ]

    public init(
        accounts: [LinkedGoogleAccount] = [],
        transport: any GoogleDriveTransport = URLSessionGoogleDriveTransport(),
        persistenceURL: URL? = nil,
        secretStore: any SecretStore = MemorySecretStore()
    ) {
        self.transport = transport
        self.persistenceURL = persistenceURL
        self.secretStore = secretStore
        var loadedById: [String: LinkedGoogleAccount] = [:]
        var loadedOrder: [String] = []
        if let persistenceURL,
           let data = try? Data(contentsOf: persistenceURL),
           let saved = try? JSONDecoder().decode([LinkedGoogleAccount].self, from: data),
           !saved.isEmpty {
            var purgedAny = false
            for var acc in saved {
                // Purge any legacy simulated/demo accounts from earlier builds
                if Self.legacySimulatedIds.contains(acc.id) || acc.rootFolderId.hasPrefix("helium_root_") {
                    purgedAny = true
                    continue
                }
                if let rtData = secretStore.get("helium.oauth.rt.\(acc.id)"),
                   let rt = String(data: rtData, encoding: .utf8), !rt.isEmpty {
                    acc.refreshToken = rt
                } else if !acc.refreshToken.isEmpty {
                    try? secretStore.set(Data(acc.refreshToken.utf8), for: "helium.oauth.rt.\(acc.id)")
                }
                if let atData = secretStore.get("helium.oauth.at.\(acc.id)"),
                   let at = String(data: atData, encoding: .utf8), !at.isEmpty {
                    acc.accessToken = at
                } else if let at = acc.accessToken, !at.isEmpty {
                    try? secretStore.set(Data(at.utf8), for: "helium.oauth.at.\(acc.id)")
                }
                loadedById[acc.id] = acc
                loadedOrder.append(acc.id)
            }
            if purgedAny {
                if !loadedOrder.isEmpty, !loadedById.values.contains(where: \.isPrimaryCatalogHost) {
                    loadedById[loadedOrder[0]]?.isPrimaryCatalogHost = true
                }
                let persistedList: [LinkedGoogleAccount] = loadedOrder.compactMap { loadedById[$0] }
                if let data = try? JSONEncoder().encode(persistedList) {
                    try? data.write(to: persistenceURL, options: .atomic)
                    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: persistenceURL.path)
                }
            }
        } else {
            for acc in accounts {
                if !acc.refreshToken.isEmpty {
                    try? secretStore.set(Data(acc.refreshToken.utf8), for: "helium.oauth.rt.\(acc.id)")
                }
                if let at = acc.accessToken, !at.isEmpty {
                    try? secretStore.set(Data(at.utf8), for: "helium.oauth.at.\(acc.id)")
                }
                loadedById[acc.id] = acc
                loadedOrder.append(acc.id)
            }
        }
        self.accountsById = loadedById
        self.orderedIds = loadedOrder
    }

    private func persist() {
        for id in orderedIds {
            guard let acc = accountsById[id] else { continue }
            if !acc.refreshToken.isEmpty {
                try? secretStore.set(Data(acc.refreshToken.utf8), for: "helium.oauth.rt.\(acc.id)")
            }
            if let at = acc.accessToken, !at.isEmpty {
                try? secretStore.set(Data(at.utf8), for: "helium.oauth.at.\(acc.id)")
            }
        }
        guard let persistenceURL else { return }
        let persistedList: [LinkedGoogleAccount] = orderedIds.compactMap { accountsById[$0] }
        if let data = try? JSONEncoder().encode(persistedList) {
            try? data.write(to: persistenceURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: persistenceURL.path)
        }
    }

    public func accounts() -> [LinkedGoogleAccount] {
        orderedIds.compactMap { accountsById[$0] }
    }

    public func account(id: String) -> LinkedGoogleAccount? {
        accountsById[id]
    }

    public func addAccount(_ account: LinkedGoogleAccount) {
        var unlinked = Set(UserDefaults.standard.stringArray(forKey: "helium.unlinkedAccountIds") ?? [])
        if unlinked.remove(account.id) != nil {
            UserDefaults.standard.set(Array(unlinked), forKey: "helium.unlinkedAccountIds")
        }
        // Deduplicate by email if the same Google account is signed in again
        if let existingId = orderedIds.first(where: { accountsById[$0]?.email.lowercased() == account.email.lowercased() && $0 != account.id }) {
            accountsById.removeValue(forKey: existingId)
            orderedIds.removeAll { $0 == existingId }
        }
        if accountsById[account.id] == nil {
            orderedIds.append(account.id)
        }
        var updated = account
        if let prev = accountsById[account.id], updated.refreshToken.isEmpty, !prev.refreshToken.isEmpty {
            updated.refreshToken = prev.refreshToken
        }
        if orderedIds.count == 1 {
            updated.isPrimaryCatalogHost = true
        }
        accountsById[account.id] = updated
        persist()
    }

    public func updateAccountTokens(
        id: String,
        accessToken: String,
        refreshToken: String? = nil,
        rootFolderId: String? = nil
    ) {
        guard var acc = accountsById[id] else { return }
        acc.accessToken = accessToken
        if let refreshToken, !refreshToken.isEmpty {
            acc.refreshToken = refreshToken
        }
        if let rootFolderId, !rootFolderId.isEmpty {
            acc.rootFolderId = rootFolderId
        }
        accountsById[id] = acc
        persist()
    }

    /// Refreshes OAuth access tokens (when a refresh token is stored) and syncs real storage quotas from Google Drive API v3.
    public func refreshTokensAndQuotas(clientId: String?) async {
        let liveTransport = URLSessionGoogleDriveTransport()
        let resolvedClientId = clientId ?? FirebaseConfig.loadDefault().clientId ?? ""

        // Recover any previously signed-in accounts whose refresh tokens exist in PersistentSecretStore
        if let persistentStore = secretStore as? PersistentSecretStore, !resolvedClientId.isEmpty {
            let unlinkedIds = Set(UserDefaults.standard.stringArray(forKey: "helium.unlinkedAccountIds") ?? [])
            let rtPrefix = "helium.oauth.rt."
            for key in persistentStore.allKeys().sorted() where key.hasPrefix(rtPrefix) {
                let candidateId = String(key.dropFirst(rtPrefix.count))
                guard candidateId.hasPrefix("gdrive_"),
                      !Self.legacySimulatedIds.contains(candidateId),
                      !unlinkedIds.contains(candidateId),
                      accountsById[candidateId] == nil,
                      let rtData = persistentStore.get(key),
                      let rt = String(data: rtData, encoding: .utf8),
                      !rt.isEmpty,
                      !rt.hasPrefix("rt_") else {
                    continue
                }
                if let freshToken = try? await liveTransport.refreshAccessToken(refreshToken: rt, clientId: resolvedClientId),
                   let aboutURL = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user,storageQuota") {
                    var req = URLRequest(url: aboutURL, timeoutInterval: 20)
                    req.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                    if let (aboutData, aboutResp) = try? await URLSession.shared.data(for: req),
                       let http = aboutResp as? HTTPURLResponse,
                       (200..<300).contains(http.statusCode),
                       let json = try? JSONSerialization.jsonObject(with: aboutData) as? [String: Any],
                       let userDict = json["user"] as? [String: Any],
                       let email = userDict["emailAddress"] as? String, !email.isEmpty {
                        if orderedIds.contains(where: { accountsById[$0]?.email.lowercased() == email.lowercased() }) {
                            continue
                        }
                        let displayName = (userDict["displayName"] as? String) ?? email
                        let quotaDict = json["storageQuota"] as? [String: Any]
                        let limitBytes = Int64(quotaDict?["limit"] as? String ?? "") ?? (15 * 1_073_741_824)
                        let usageBytes = Int64(quotaDict?["usage"] as? String ?? "") ?? 0
                        let rootFolderId = (try? await liveTransport.ensureHeliumVaultFolder(accessToken: freshToken)) ?? "root"
                        let recovered = LinkedGoogleAccount(
                            id: candidateId,
                            email: email,
                            displayName: displayName,
                            refreshToken: rt,
                            accessToken: freshToken,
                            isPrimaryCatalogHost: orderedIds.isEmpty,
                            quotaLimitBytes: limitBytes,
                            quotaUsedBytes: usageBytes,
                            heliumUsedBytes: 0,
                            rootFolderId: rootFolderId,
                            uploadPriority: orderedIds.count + 1
                        )
                        accountsById[candidateId] = recovered
                        orderedIds.append(candidateId)
                    }
                }
            }
        }

        for id in orderedIds {
            guard var acc = accountsById[id] else { continue }
            if !acc.refreshToken.isEmpty, !resolvedClientId.isEmpty, !acc.refreshToken.hasPrefix("rt_") {
                if let freshToken = try? await liveTransport.refreshAccessToken(
                    refreshToken: acc.refreshToken,
                    clientId: resolvedClientId
                ) {
                    acc.accessToken = freshToken
                }
            }
            if let token = acc.accessToken, !token.isEmpty {
                if acc.rootFolderId.isEmpty || acc.rootFolderId == "root" || acc.rootFolderId.hasPrefix("helium_root_") {
                    if let folderId = try? await liveTransport.ensureHeliumVaultFolder(accessToken: token) {
                        acc.rootFolderId = folderId
                    }
                }
                if let quota = try? await transport.fetchQuota(account: acc) {
                    acc.quotaLimitBytes = quota.limit
                    acc.quotaUsedBytes = quota.used
                }
            }
            accountsById[id] = acc
        }
        persist()
    }

    public func removeAccount(id: String) {
        accountsById.removeValue(forKey: id)
        orderedIds.removeAll { $0 == id }
        var unlinked = Set(UserDefaults.standard.stringArray(forKey: "helium.unlinkedAccountIds") ?? [])
        unlinked.insert(id)
        UserDefaults.standard.set(Array(unlinked), forKey: "helium.unlinkedAccountIds")
        secretStore.delete("helium.oauth.rt.\(id)")
        secretStore.delete("helium.oauth.at.\(id)")
        if !orderedIds.isEmpty, !accountsById.values.contains(where: \.isPrimaryCatalogHost) {
            let firstId = orderedIds[0]
            accountsById[firstId]?.isPrimaryCatalogHost = true
        }
        persist()
    }

    public func recordUsageDelta(accountId: String, deltaBytes: Int64) {
        guard var acc = accountsById[accountId] else { return }
        acc.quotaUsedBytes = max(0, acc.quotaUsedBytes + deltaBytes)
        acc.heliumUsedBytes = max(0, acc.heliumUsedBytes + deltaBytes)
        accountsById[accountId] = acc
        persist()
    }

    /// Reconciles each account's `heliumUsedBytes` (and adjusts `quotaUsedBytes` by the delta) to match the exact sum of active, non-deleted segments in the Helium pool.
    public func reconcileHeliumUsage(activeBytesByAccount: [String: Int64]) {
        var changed = false
        for id in orderedIds {
            guard var acc = accountsById[id] else { continue }
            let newHeliumBytes = max(0, activeBytesByAccount[id] ?? 0)
            let delta = newHeliumBytes - acc.heliumUsedBytes
            if delta != 0 {
                acc.heliumUsedBytes = newHeliumBytes
                acc.quotaUsedBytes = max(newHeliumBytes, acc.quotaUsedBytes + delta)
                accountsById[id] = acc
                changed = true
            }
        }
        if changed {
            persist()
        }
    }

    /// Promotes `id` to `#1` upload priority (`isPrimaryCatalogHost = true`, `uploadPriority = 1`) and normalizes all other accounts sequentially (`2, 3, ...`).
    public func prioritiseAccountFirst(id: String) {
        guard accountsById[id] != nil else { return }
        orderedIds.removeAll { $0 == id }
        orderedIds.insert(id, at: 0)
        for (idx, accId) in orderedIds.enumerated() {
            accountsById[accId]?.uploadPriority = idx + 1
            accountsById[accId]?.isPrimaryCatalogHost = (idx == 0)
        }
        persist()
    }

    /// Moves an account up (`delta < 0`) or down (`delta > 0`) in the upload priority order and normalizes `uploadPriority` ranks (`1...N`).
    public func moveAccountPriority(id: String, delta: Int) {
        guard let currentIndex = orderedIds.firstIndex(of: id) else { return }
        let targetIndex = max(0, min(orderedIds.count - 1, currentIndex + delta))
        guard targetIndex != currentIndex else { return }
        orderedIds.remove(at: currentIndex)
        orderedIds.insert(id, at: targetIndex)
        for (idx, accId) in orderedIds.enumerated() {
            accountsById[accId]?.uploadPriority = idx + 1
            accountsById[accId]?.isPrimaryCatalogHost = (idx == 0)
        }
        persist()
    }

    /// Explicitly sets the numerical `uploadPriority` (`1` = highest) for an account.
    public func setAccountPriority(id: String, priority: Int) {
        guard var acc = accountsById[id] else { return }
        acc.uploadPriority = max(1, priority)
        accountsById[id] = acc
        orderedIds.sort { lhs, rhs in
            let lp = accountsById[lhs]?.uploadPriority ?? 1
            let rp = accountsById[rhs]?.uploadPriority ?? 1
            if lp != rp { return lp < rp }
            return lhs < rhs
        }
        persist()
    }

    /// Pauses or resumes new uploads to `id` (Read-Only / Drain mode when `paused == true`).
    public func setAccountUploadPaused(id: String, paused: Bool) {
        guard var acc = accountsById[id] else { return }
        acc.isUploadPaused = paused
        accountsById[id] = acc
        persist()
    }

    public func combinedQuota() -> (usedBytes: Int64, quotaBytes: Int64, heliumBytes: Int64) {
        var used: Int64 = 0
        var limit: Int64 = 0
        var helium: Int64 = 0
        for id in orderedIds {
            if let acc = accountsById[id] {
                used += acc.quotaUsedBytes
                limit += acc.quotaLimitBytes
                helium += acc.heliumUsedBytes
            }
        }
        return (used, limit, helium)
    }
}

/// Metadata manifest describing a virtual file or folder in the pooled Google Drive catalog, including its segment map across accounts.
public struct PoolItemManifest: Codable, Equatable, Sendable {
    public var item: RemoteItem
    public var placementMode: PlacementMode
    public var segments: [PoolSegment]

    public init(item: RemoteItem, placementMode: PlacementMode, segments: [PoolSegment]) {
        self.item = item
        self.placementMode = placementMode
        self.segments = segments
    }
}

/// Unified multi-account Google Drive implementation of `LockableRemote`, `DriveRemote`, `KeysRemote`, and `ShareRemote`.
/// Supports BOTH Mode 1 (Whole-File Smart Placement) and Mode 2 (Cross-Account Segment Striping) and plugs directly into `LockedRemote` and `OrbitDrive`.
public actor PooledGoogleDriveRemote: LockableRemote, KeysRemote, ShareRemote {
    public let pool: GoogleAccountPool
    public var allocator: StoragePoolAllocator
    private var manifestsById: [String: PoolItemManifest] = [:]
    private var seqCounter: Int64 = 0
    private let manifestsPersistenceURL: URL?
    private var serverKeysState = ServerKeys(
        mode: "off",
        keyCheck: nil,
        recoveryWrap: nil,
        dropPublicKey: nil,
        dropPrivateWrap: nil
    )
    private var sharedLinks: [String: SharedLink] = [:]
    private var fileRequests: [String: FileRequest] = [:]

    public init(
        pool: GoogleAccountPool,
        allocator: StoragePoolAllocator = StoragePoolAllocator(),
        manifestsPersistenceURL: URL? = nil
    ) {
        self.pool = pool
        self.allocator = allocator
        self.manifestsPersistenceURL = manifestsPersistenceURL
        if let manifestsPersistenceURL,
           let data = try? Data(contentsOf: manifestsPersistenceURL),
           let saved = try? JSONDecoder().decode([String: PoolItemManifest].self, from: data) {
            let cleaned = saved.filter { _, manifest in
                let name = manifest.item.name
                return !name.hasPrefix("pool_file_") && !name.hasSuffix(".blob")
            }
            self.manifestsById = cleaned
            self.seqCounter = cleaned.values.map(\.item.metadataVersion).max() ?? 0
            if cleaned.count != saved.count,
               let cleanedData = try? JSONEncoder().encode(cleaned) {
                try? cleanedData.write(to: manifestsPersistenceURL, options: .atomic)
            }
        }
    }

    private func persistManifests() {
        guard let manifestsPersistenceURL else { return }
        if let data = try? JSONEncoder().encode(manifestsById) {
            try? data.write(to: manifestsPersistenceURL, options: .atomic)
        }
    }

    public func clearAllManifests() {
        manifestsById = [:]
        seqCounter = 0
        persistManifests()
    }

    public func setAllocator(_ newAllocator: StoragePoolAllocator) {
        self.allocator = newAllocator
    }

    public func manifest(for itemId: String) throws -> PoolItemManifest {
        guard let manifest = manifestsById[itemId] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return manifest
    }

    public func allManifests() -> [PoolItemManifest] {
        Array(manifestsById.values)
    }

    /// Ensures `account` has a valid, non-empty OAuth access token (refreshing via `refreshToken` if missing or when `forceRefresh == true`).
    private func ensureValidToken(
        for account: LinkedGoogleAccount,
        forceRefresh: Bool = false
    ) async -> LinkedGoogleAccount {
        if pool.transport is MockGoogleDriveCloud {
            return account
        }
        var current = account
        let needsRefresh = forceRefresh || current.accessToken == nil || current.accessToken?.isEmpty == true
        guard needsRefresh,
              current.refreshToken.count >= 12,
              !current.refreshToken.hasPrefix("rt_") else {
            return current
        }
        let oauthClientId = FirebaseConfig.loadDefault().clientId ?? ""
        guard !oauthClientId.isEmpty else { return current }
        if let freshToken = try? await URLSessionGoogleDriveTransport().refreshAccessToken(
            refreshToken: current.refreshToken,
            clientId: oauthClientId
        ) {
            await pool.updateAccountTokens(id: current.id, accessToken: freshToken)
            current.accessToken = freshToken
        }
        return current
    }

    /// Resolves (or creates on-demand) the Google Drive folder ID on `account` corresponding to `virtualFolderId` (`RemoteItem.rootID` or a `pool_folder_*` ID).
    private func resolveGoogleDriveFolderId(
        for account: LinkedGoogleAccount,
        virtualFolderId: String
    ) async -> String {
        if virtualFolderId.isEmpty || virtualFolderId == RemoteItem.rootID {
            return account.rootFolderId
        }
        guard var folderManifest = manifestsById[virtualFolderId], folderManifest.item.kind == .folder else {
            return account.rootFolderId
        }
        if let existingSeg = folderManifest.segments.first(where: { $0.accountId == account.id && !$0.driveFileId.isEmpty }) {
            return existingSeg.driveFileId
        }
        let validAcc = await ensureValidToken(for: account)
        let parentDriveFolderId = await resolveGoogleDriveFolderId(
            for: validAcc,
            virtualFolderId: folderManifest.item.parentId ?? RemoteItem.rootID
        )
        guard let token = validAcc.accessToken, !token.isEmpty else {
            return parentDriveFolderId
        }
        let liveTransport = URLSessionGoogleDriveTransport()
        if let createdFolderId = try? await liveTransport.ensureSubfolder(
            account: validAcc,
            name: folderManifest.item.name,
            parentFolderId: parentDriveFolderId
        ) {
            let newSeg = PoolSegment(
                index: folderManifest.segments.count,
                accountId: validAcc.id,
                driveFileId: createdFolderId,
                logicalOffset: 0,
                byteLength: 0,
                sha256: ""
            )
            folderManifest.segments.append(newSeg)
            manifestsById[virtualFolderId] = folderManifest
            persistManifests()
            return createdFolderId
        }
        return parentDriveFolderId
    }

    /// Recomputes each linked Google account's active Helium usage (`heliumUsedBytes` and `quotaUsedBytes` delta) from all non-deleted file manifests.
    public func reconcileAccountPoolUsage() async {
        var activeBytesByAccount: [String: Int64] = [:]
        for manifest in manifestsById.values where !manifest.item.deleted && manifest.item.kind == .file {
            for seg in manifest.segments {
                activeBytesByAccount[seg.accountId, default: 0] += max(0, seg.byteLength)
            }
        }
        await pool.reconcileHeliumUsage(activeBytesByAccount: activeBytesByAccount)
    }

    /// Bi-directionally synchronizes folders, files, and the `Recycle Bin` across all linked Google Drive accounts (`Helium Pool Vault`).
    /// - Merges folders with the same path across 2+ linked Google Drives into a single unified folder tree in Helium and `/Volumes/Helium`.
    /// - Never re-imports files that are in Helium's 30-Day Recycle Bin (`item.deleted == true`).
    /// - Syncs renames, folder moves, and deletions/trashed items between Google Drive Web and Helium.
    @discardableResult
    public func syncExistingVaultFiles() async -> Int {
        let liveTransport = URLSessionGoogleDriveTransport()
        let accounts = await pool.accounts()
        // Include ALL manifests (both active AND deleted/trashed) so trashed files are never re-imported as new active files!
        var knownDriveFileIds = Set(
            manifestsById.values
                .flatMap { $0.segments.map(\.driveFileId) }
                .filter { !$0.isEmpty }
        )
        var importedCount = 0
        var changedAny = false
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        for rawAcc in accounts {
            var acc = await ensureValidToken(for: rawAcc)
            guard let token = acc.accessToken, !token.isEmpty else { continue }
            var seenActiveDriveFileIdsOnAccount = Set<String>()
            var seenRecycleBinDriveFileIdsOnAccount = Set<String>()
            var rootListingSucceeded = false
            var allFolderListingsSucceeded = true

            // Recursive helper to walk `Helium Pool Vault` and its subfolders (up to 6 levels deep)
            func syncDriveFolder(
                driveFolderId: String,
                virtualParentId: String,
                depth: Int
            ) async {
                guard depth <= 6 else { return }
                let items: [GoogleDriveRemoteFile]
                if let fetched = try? await liveTransport.listItemsInFolder(account: acc, folderId: driveFolderId) {
                    items = fetched
                } else {
                    let refreshed = await ensureValidToken(for: acc, forceRefresh: true)
                    acc = refreshed
                    guard let retried = try? await liveTransport.listItemsInFolder(account: acc, folderId: driveFolderId) else {
                        allFolderListingsSucceeded = false
                        return
                    }
                    items = retried
                }
                if depth == 0 {
                    rootListingSucceeded = true
                }

                for rf in items {
                    let isFolder = (rf.mimeType == "application/vnd.google-apps.folder")
                    let canonicalName = rf.name.precomposedStringWithCanonicalMapping

                    // 1. Handle the special "Recycle Bin" / "Helium Recycle Bin" folder on Google Drive
                    if isFolder && (canonicalName.caseInsensitiveCompare("Recycle Bin") == .orderedSame
                                    || canonicalName.caseInsensitiveCompare("Helium Recycle Bin") == .orderedSame) {
                        if let trashedFiles = try? await liveTransport.listFilesInFolder(account: acc, folderId: rf.id) {
                            for tf in trashedFiles {
                                seenRecycleBinDriveFileIdsOnAccount.insert(tf.id)
                                if let matchedPair = manifestsById.first(where: { _, m in
                                    m.segments.contains(where: { $0.driveFileId == tf.id })
                                }) {
                                    let existingId = matchedPair.key
                                    var existingManifest = matchedPair.value
                                    if !existingManifest.item.deleted {
                                        seqCounter += 1
                                        let old = existingManifest.item
                                        existingManifest.item = RemoteItem(
                                            id: old.id,
                                            parentId: old.parentId,
                                            name: old.name,
                                            nameLocked: old.nameLocked,
                                            kind: old.kind,
                                            size: old.size,
                                            plainSize: old.plainSize,
                                            mimeType: old.mimeType,
                                            contentVersion: old.contentVersion,
                                            metadataVersion: seqCounter,
                                            createdAt: old.createdAt,
                                            modifiedAt: now,
                                            deleted: true
                                        )
                                        manifestsById[existingId] = existingManifest
                                        changedAny = true
                                    }
                                } else if !knownDriveFileIds.contains(tf.id) {
                                    knownDriveFileIds.insert(tf.id)
                                    seqCounter += 1
                                    let itemId = "pool_file_\(tf.id)"
                                    let trashedItem = RemoteItem(
                                        id: itemId,
                                        parentId: RemoteItem.rootID,
                                        name: tf.name,
                                        nameLocked: false,
                                        kind: .file,
                                        size: tf.size,
                                        plainSize: tf.size,
                                        mimeType: tf.mimeType,
                                        contentVersion: 1,
                                        metadataVersion: seqCounter,
                                        createdAt: now,
                                        modifiedAt: now,
                                        deleted: true
                                    )
                                    let seg = PoolSegment(
                                        index: 0,
                                        accountId: acc.id,
                                        driveFileId: tf.id,
                                        logicalOffset: 0,
                                        byteLength: tf.size,
                                        sha256: ""
                                    )
                                    manifestsById[itemId] = PoolItemManifest(
                                        item: trashedItem,
                                        placementMode: .wholeFileSmartPlacement,
                                        segments: [seg]
                                    )
                                    changedAny = true
                                }
                            }
                        }
                        continue
                    }

                    // 2. Handle Subfolders (Union Merge across all linked Google Drives)
                    if isFolder {
                        seenActiveDriveFileIdsOnAccount.insert(rf.id)
                        let existingFolderEntry = manifestsById.first { _, m in
                            m.item.kind == .folder
                                && !m.item.deleted
                                && (m.item.parentId ?? RemoteItem.rootID) == virtualParentId
                                && m.item.name.precomposedStringWithCanonicalMapping.caseInsensitiveCompare(canonicalName) == .orderedSame
                        }
                        let virtualFolderId: String
                        if let matchedFolder = existingFolderEntry {
                            let existingId = matchedFolder.key
                            var folderManifest = matchedFolder.value
                            virtualFolderId = existingId
                            if !folderManifest.segments.contains(where: { $0.accountId == acc.id && $0.driveFileId == rf.id }) {
                                folderManifest.segments.append(
                                    PoolSegment(
                                        index: folderManifest.segments.count,
                                        accountId: acc.id,
                                        driveFileId: rf.id,
                                        logicalOffset: 0,
                                        byteLength: 0,
                                        sha256: ""
                                    )
                                )
                                manifestsById[existingId] = folderManifest
                                changedAny = true
                            }
                        } else {
                            seqCounter += 1
                            let newFolderId = "pool_folder_\(rf.id)"
                            let folderItem = RemoteItem(
                                id: newFolderId,
                                parentId: virtualParentId,
                                name: rf.name,
                                nameLocked: false,
                                kind: .folder,
                                size: 0,
                                contentVersion: 1,
                                metadataVersion: seqCounter,
                                createdAt: now,
                                modifiedAt: now,
                                deleted: false
                            )
                            let seg = PoolSegment(
                                index: 0,
                                accountId: acc.id,
                                driveFileId: rf.id,
                                logicalOffset: 0,
                                byteLength: 0,
                                sha256: ""
                            )
                            manifestsById[newFolderId] = PoolItemManifest(
                                item: folderItem,
                                placementMode: .wholeFileSmartPlacement,
                                segments: [seg]
                            )
                            virtualFolderId = newFolderId
                            importedCount += 1
                            changedAny = true
                        }
                        knownDriveFileIds.insert(rf.id)
                        await syncDriveFolder(
                            driveFolderId: rf.id,
                            virtualParentId: virtualFolderId,
                            depth: depth + 1
                        )
                        continue
                    }

                    // 3. Regular File inside `Helium Pool Vault` or a subfolder
                    seenActiveDriveFileIdsOnAccount.insert(rf.id)
                    if knownDriveFileIds.contains(rf.id) {
                        if let matchedPair = manifestsById.first(where: { _, m in
                            m.segments.contains(where: { $0.driveFileId == rf.id })
                        }) {
                            let existingId = matchedPair.key
                            var existingManifest = matchedPair.value
                            if existingManifest.item.deleted {
                                // Move any locally-trashed file still sitting in active Google Drive into Google Drive's Recycle Bin
                                if let seg = existingManifest.segments.first(where: { $0.driveFileId == rf.id }),
                                   seg.accountId == acc.id,
                                   let binFolderId = try? await liveTransport.ensureRecycleBinFolder(account: acc) {
                                    try? await liveTransport.moveFileBetweenFolders(
                                        account: acc,
                                        driveFileId: rf.id,
                                        targetFolderId: binFolderId
                                    )
                                    seenActiveDriveFileIdsOnAccount.remove(rf.id)
                                    seenRecycleBinDriveFileIdsOnAccount.insert(rf.id)
                                }
                            } else if !existingManifest.item.nameLocked && existingManifest.segments.count == 1 {
                                // Sync any rename or folder move made directly in Google Drive Web back to Helium
                                let currentParent = existingManifest.item.parentId ?? RemoteItem.rootID
                                if existingManifest.item.name != rf.name || currentParent != virtualParentId {
                                    seqCounter += 1
                                    let old = existingManifest.item
                                    existingManifest.item = RemoteItem(
                                        id: old.id,
                                        parentId: virtualParentId,
                                        name: rf.name,
                                        nameLocked: old.nameLocked,
                                        kind: old.kind,
                                        size: rf.size > 0 ? rf.size : old.size,
                                        plainSize: rf.size > 0 ? rf.size : old.plainSize,
                                        mimeType: rf.mimeType,
                                        contentVersion: old.contentVersion,
                                        metadataVersion: seqCounter,
                                        createdAt: old.createdAt,
                                        modifiedAt: now,
                                        deleted: false,
                                        shared: old.shared,
                                        shareUrl: old.shareUrl,
                                        encryption: old.encryption,
                                        wrappedKey: old.wrappedKey,
                                        nonce: old.nonce,
                                        sealPublicKey: old.sealPublicKey
                                    )
                                    manifestsById[existingId] = existingManifest
                                    changedAny = true
                                }
                            }
                        }
                        continue
                    }

                    // Clean up orphaned internal segment/blob files no longer referenced by any manifest, and skip part fragments from standalone import
                    if rf.name.hasPrefix("pool_file_") && (rf.name.contains(".seg_") || rf.name.hasSuffix(".blob")) {
                        seenActiveDriveFileIdsOnAccount.remove(rf.id)
                        try? await liveTransport.deleteSegment(account: acc, driveFileId: rf.id)
                        continue
                    }
                    if rf.name.contains(".seg_") || rf.name.contains(".part") || rf.name.hasPrefix("pool_file_") || rf.name.hasSuffix(".blob") {
                        continue
                    }
                    knownDriveFileIds.insert(rf.id)
                    seqCounter += 1
                    let itemId = "pool_file_\(rf.id)"
                    let remoteItem = RemoteItem(
                        id: itemId,
                        parentId: virtualParentId,
                        name: rf.name,
                        nameLocked: false,
                        kind: .file,
                        size: rf.size,
                        plainSize: rf.size,
                        mimeType: rf.mimeType,
                        contentVersion: 1,
                        metadataVersion: seqCounter,
                        createdAt: now,
                        modifiedAt: now,
                        deleted: false
                    )
                    let seg = PoolSegment(
                        index: 0,
                        accountId: acc.id,
                        driveFileId: rf.id,
                        logicalOffset: 0,
                        byteLength: rf.size,
                        sha256: ""
                    )
                    manifestsById[itemId] = PoolItemManifest(
                        item: remoteItem,
                        placementMode: .wholeFileSmartPlacement,
                        segments: [seg]
                    )
                    importedCount += 1
                    changedAny = true
                }
            }

            await syncDriveFolder(
                driveFolderId: acc.rootFolderId,
                virtualParentId: RemoteItem.rootID,
                depth: 0
            )

            // 4. Cloud-to-Mac Deletion Sync:
            //    - If an active file/folder on this account is no longer in `Helium Pool Vault` on Google Drive Web, mark it deleted (and if it wasn't moved into `Recycle Bin`, purge its segments so deleted Drive files never linger).
            //    - If a Recycle Bin item was deleted from `Recycle Bin` on Google Drive Web, purge its segments so it disappears from Helium's Recycle Bin too.
            if rootListingSucceeded {
                for (itemId, var manifest) in manifestsById {
                    let accountSegments = manifest.segments.filter {
                        $0.accountId == acc.id && !$0.driveFileId.isEmpty && !$0.driveFileId.hasPrefix("gdrive_") && !$0.driveFileId.hasPrefix("gfile_")
                    }
                    guard !accountSegments.isEmpty else { continue }

                    if !manifest.item.deleted {
                        // Grace period of 15 seconds for brand-new uploads
                        if now - manifest.item.createdAt < 15_000 { continue }
                        var missingFromActiveVault = false
                        var movedToCloudRecycleBin = false
                        for seg in accountSegments where !seenActiveDriveFileIdsOnAccount.contains(seg.driveFileId) {
                            if seenRecycleBinDriveFileIdsOnAccount.contains(seg.driveFileId) {
                                missingFromActiveVault = true
                                movedToCloudRecycleBin = true
                            } else if allFolderListingsSucceeded {
                                missingFromActiveVault = true
                            } else {
                                let confirmedTrashed = await liveTransport.checkFileTrashedOrMissing(
                                    account: acc,
                                    driveFileId: seg.driveFileId
                                )
                                if confirmedTrashed {
                                    missingFromActiveVault = true
                                }
                            }
                        }

                        if missingFromActiveVault {
                            seqCounter += 1
                            let old = manifest.item
                            manifest.item = RemoteItem(
                                id: old.id,
                                parentId: old.parentId,
                                name: old.name,
                                nameLocked: old.nameLocked,
                                kind: old.kind,
                                size: old.size,
                                plainSize: old.plainSize,
                                mimeType: old.mimeType,
                                contentVersion: old.contentVersion,
                                metadataVersion: seqCounter,
                                createdAt: old.createdAt,
                                modifiedAt: now,
                                deleted: true,
                                shared: old.shared,
                                shareUrl: old.shareUrl,
                                encryption: old.encryption,
                                wrappedKey: old.wrappedKey,
                                nonce: old.nonce,
                                sealPublicKey: old.sealPublicKey
                            )
                            if !movedToCloudRecycleBin {
                                // Deleted directly in Google Drive Web (not in Helium Recycle Bin) -> clear segments so it is purged
                                manifest.segments.removeAll { $0.accountId == acc.id && !seenRecycleBinDriveFileIdsOnAccount.contains($0.driveFileId) }
                            }
                            manifestsById[itemId] = manifest
                            changedAny = true
                        }
                    } else if allFolderListingsSucceeded {
                        // Item is in Helium's Recycle Bin (`deleted == true`); if user also deleted it from Google Drive's `Recycle Bin`, remove its segments
                        let beforeCount = manifest.segments.count
                        manifest.segments.removeAll { seg in
                            guard seg.accountId == acc.id,
                                  !seg.driveFileId.isEmpty,
                                  !seg.driveFileId.hasPrefix("gdrive_"),
                                  !seg.driveFileId.hasPrefix("gfile_") else {
                                return false
                            }
                            return !seenRecycleBinDriveFileIdsOnAccount.contains(seg.driveFileId)
                                && !seenActiveDriveFileIdsOnAccount.contains(seg.driveFileId)
                        }
                        if manifest.segments.count != beforeCount {
                            manifestsById[itemId] = manifest
                            changedAny = true
                        }
                    }
                }
            }
        }
        if changedAny || importedCount > 0 {
            persistManifests()
        }
        await reconcileAccountPoolUsage()
        return importedCount
    }

    // MARK: - DriveRemote & LockableRemote

    public func account() async throws -> Account {
        let list = await pool.accounts()
        let totals = await pool.combinedQuota()
        let primaryEmail = list.first(where: \.isPrimaryCatalogHost)?.email ?? list.first?.email ?? "unlinked@gmail.com"
        let displayName = list.count > 1
            ? "\(list.count) Linked Google Drives"
            : (list.first?.displayName ?? "Google Drive Pool")
        return Account(
            email: primaryEmail,
            name: displayName,
            usedBytes: totals.usedBytes,
            quotaBytes: totals.quotaBytes,
            plan: "Google Drive Pool (\(list.count) \(list.count == 1 ? "Account" : "Accounts"))"
        )
    }

    public func listChanges(since seq: Int64) async throws -> ChangePage {
        let changed = manifestsById.values
            .map(\.item)
            .filter { $0.metadataVersion > seq || $0.deleted || seq > seqCounter }
            .sorted { $0.metadataVersion < $1.metadataVersion }
        return ChangePage(items: changed, seq: seqCounter, hasMore: false)
    }

    public func listChildren(folderId: String, cursor: String?) async throws -> ChildrenPage {
        let children = manifestsById.values
            .map(\.item)
            .filter { !$0.deleted && ($0.parentId ?? RemoteItem.rootID) == folderId }
        return ChildrenPage(items: children, nextCursor: nil)
    }

    public func fetchRange(id: String, offset: Int64, length: Int) async throws -> Data {
        guard length > 0 else { return Data() }
        guard let manifest = manifestsById[id], !manifest.item.deleted else {
            throw CocoaError(.fileNoSuchFile)
        }
        let totalSize = manifest.item.size
        guard offset < totalSize else { return Data() }
        let clampedEnd = min(totalSize, offset + Int64(length))

        var output = Data(capacity: Int(clampedEnd - offset))
        for seg in manifest.segments {
            let segStart = seg.logicalOffset
            let segEnd = segStart + seg.byteLength
            guard segEnd > offset, segStart < clampedEnd else { continue }

            guard let account = await pool.account(id: seg.accountId) else {
                throw PoolAllocationError.noLinkedAccounts
            }
            let readStartInSeg = max(0, offset - segStart)
            let readEndInSeg = min(seg.byteLength, clampedEnd - segStart)
            let readLen = Int(readEndInSeg - readStartInSeg)
            let slice = try await fetchSegmentRangeWithAutoRefresh(
                account: account,
                driveFileId: seg.driveFileId,
                offset: readStartInSeg,
                length: readLen
            )
            output.append(slice)
        }
        return output
    }

    private func fetchSegmentRangeWithAutoRefresh(
        account: LinkedGoogleAccount,
        driveFileId: String,
        offset: Int64,
        length: Int
    ) async throws -> Data {
        guard length > 0 else { return Data() }
        var currentAccount = account
        let oauthClientId = FirebaseConfig.loadDefault().clientId ?? ""
        if !(pool.transport is MockGoogleDriveCloud),
           (currentAccount.accessToken == nil || currentAccount.accessToken?.isEmpty == true),
           currentAccount.refreshToken.count >= 12,
           !currentAccount.refreshToken.hasPrefix("rt_"),
           !oauthClientId.isEmpty {
            let freshToken = try await URLSessionGoogleDriveTransport().refreshAccessToken(
                refreshToken: currentAccount.refreshToken,
                clientId: oauthClientId
            )
            await pool.updateAccountTokens(id: currentAccount.id, accessToken: freshToken)
            currentAccount.accessToken = freshToken
        }

        let maxSliceBytes = 16 * 1024 * 1024
        var result = Data(capacity: length)
        var cursorOffset = offset
        var remaining = length

        while remaining > 0 {
            let chunkLen = min(remaining, maxSliceBytes)
            let chunkData: Data
            do {
                chunkData = try await pool.transport.fetchSegmentRange(
                    account: currentAccount,
                    driveFileId: driveFileId,
                    offset: cursorOffset,
                    length: chunkLen
                )
            } catch {
                guard !currentAccount.refreshToken.isEmpty,
                      !currentAccount.refreshToken.hasPrefix("rt_"),
                      !oauthClientId.isEmpty else {
                    throw error
                }
                let freshToken = try await URLSessionGoogleDriveTransport().refreshAccessToken(
                    refreshToken: currentAccount.refreshToken,
                    clientId: oauthClientId
                )
                await pool.updateAccountTokens(id: currentAccount.id, accessToken: freshToken)
                currentAccount.accessToken = freshToken
                chunkData = try await pool.transport.fetchSegmentRange(
                    account: currentAccount,
                    driveFileId: driveFileId,
                    offset: cursorOffset,
                    length: chunkLen
                )
            }
            result.append(chunkData)
            if chunkData.isEmpty { break }
            cursorOffset += Int64(chunkData.count)
            remaining -= chunkData.count
        }
        return result
    }

    public func createFolder(name: String, parentId: String) async throws -> RemoteItem {
        try await createFolder(name: .plain(name), parentId: parentId)
    }

    public func createFolder(name: WireName, parentId: String) async throws -> RemoteItem {
        // Union merge: if a non-deleted folder with the same name and parent already exists, return it
        if let existing = manifestsById.values.first(where: {
            !$0.item.deleted &&
            $0.item.kind == .folder &&
            ($0.item.parentId ?? RemoteItem.rootID) == parentId &&
            $0.item.name.caseInsensitiveCompare(name.text) == .orderedSame
        }) {
            return existing.item
        }

        let id = "pool_folder_\(UUID().uuidString)"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        seqCounter += 1
        let item = RemoteItem(
            id: id,
            parentId: parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: .folder,
            size: 0,
            contentVersion: 1,
            metadataVersion: seqCounter,
            createdAt: now,
            modifiedAt: now
        )
        manifestsById[id] = PoolItemManifest(item: item, placementMode: .wholeFileSmartPlacement, segments: [])
        persistManifests()

        // Create corresponding folder in the primary Google Drive account's Helium Pool Vault
        if !name.locked {
            let accounts = await pool.accounts()
            if let primary = accounts.first(where: { !$0.refreshToken.isEmpty && !$0.refreshToken.hasPrefix("rt_") }) {
                _ = await resolveGoogleDriveFolderId(for: primary, virtualFolderId: id)
            }
        }
        return item
    }

    public func rename(id: String, newName: String) async throws -> RemoteItem {
        try await rename(id: id, name: .plain(newName))
    }

    public func rename(id: String, name: WireName) async throws -> RemoteItem {
        guard var manifest = manifestsById[id] else { throw CocoaError(.fileNoSuchFile) }
        if !name.locked, manifest.segments.count == 1, let seg = manifest.segments.first,
           let rawAcc = await pool.account(id: seg.accountId), !seg.driveFileId.isEmpty,
           !seg.driveFileId.hasPrefix("gdrive_") {
            let acc = await ensureValidToken(for: rawAcc)
            try? await URLSessionGoogleDriveTransport().renameFile(
                account: acc,
                driveFileId: seg.driveFileId,
                newName: name.text
            )
        }
        seqCounter += 1
        let old = manifest.item
        let updated = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: old.deleted,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        manifest.item = updated
        manifestsById[id] = manifest
        persistManifests()
        return updated
    }

    public func move(id: String, toParent parentId: String, newName: String?) async throws -> RemoteItem {
        try await move(id: id, toParent: parentId, name: newName.map(WireName.plain))
    }

    public func move(id: String, toParent parentId: String, name: WireName?) async throws -> RemoteItem {
        guard var manifest = manifestsById[id] else { throw CocoaError(.fileNoSuchFile) }
        let old = manifest.item
        let newNameText = name?.text ?? old.name
        let newNameLocked = name?.locked ?? old.nameLocked
        seqCounter += 1
        let updated = RemoteItem(
            id: old.id,
            parentId: parentId,
            name: newNameText,
            nameLocked: newNameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: old.deleted,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        manifest.item = updated
        manifestsById[id] = manifest
        persistManifests()

        // Cross-sync folder move (and optional rename) to Google Drive
        let transport = URLSessionGoogleDriveTransport()
        for seg in manifest.segments where !seg.driveFileId.isEmpty && !seg.driveFileId.hasPrefix("gdrive_") {
            if let rawAcc = await pool.account(id: seg.accountId),
               !rawAcc.refreshToken.isEmpty,
               !rawAcc.refreshToken.hasPrefix("rt_") {
                let acc = await ensureValidToken(for: rawAcc)
                if (old.parentId ?? RemoteItem.rootID) != parentId {
                    let targetFolderId = await resolveGoogleDriveFolderId(for: acc, virtualFolderId: parentId)
                    try? await transport.moveFileBetweenFolders(
                        account: acc,
                        driveFileId: seg.driveFileId,
                        targetFolderId: targetFolderId
                    )
                }
                if !newNameLocked && manifest.segments.count == 1 && newNameText != old.name {
                    try? await transport.renameFile(
                        account: acc,
                        driveFileId: seg.driveFileId,
                        newName: newNameText
                    )
                }
            }
        }
        return updated
    }

    public func delete(id: String) async throws {
        guard var manifest = manifestsById[id] else { return }
        for seg in manifest.segments {
            if let rawAcc = await pool.account(id: seg.accountId), !seg.driveFileId.isEmpty {
                let acc = await ensureValidToken(for: rawAcc)
                try? await pool.transport.deleteSegment(account: acc, driveFileId: seg.driveFileId)
                await pool.recordUsageDelta(accountId: acc.id, deltaBytes: -seg.byteLength)
            }
        }
        seqCounter += 1
        let old = manifest.item
        manifest.item = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: old.name,
            nameLocked: old.nameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: true
        )
        manifest.segments = []
        manifestsById[id] = manifest
        persistManifests()
        await reconcileAccountPoolUsage()
    }

    /// Moves an item to the 30-day Trash without deleting its underlying Google Drive segments, enabling 1-click Undo Delete for 30 days.
    /// Also moves the file into the `Helium Pool Vault / Recycle Bin` folder on Google Drive.
    @discardableResult
    public func moveToTrash(id: String) async -> PoolItemManifest? {
        guard var manifest = manifestsById[id] else { return nil }
        seqCounter += 1
        let old = manifest.item
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        manifest.item = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: old.name,
            nameLocked: old.nameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: nowMs,
            deleted: true,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        manifestsById[id] = manifest

        var segmentsToRecycle = manifest.segments
        // Also mark any duplicate active manifests with the same parent and canonical name as deleted
        let targetParentId = old.parentId ?? RemoteItem.rootID
        let targetCanonicalName = old.name.precomposedStringWithCanonicalMapping.lowercased()
        for (otherId, var otherManifest) in manifestsById where otherId != id && !otherManifest.item.deleted {
            let otherParentId = otherManifest.item.parentId ?? RemoteItem.rootID
            if otherParentId == targetParentId &&
               otherManifest.item.kind == old.kind &&
               otherManifest.item.name.precomposedStringWithCanonicalMapping.lowercased() == targetCanonicalName {
                seqCounter += 1
                let otherOld = otherManifest.item
                otherManifest.item = RemoteItem(
                    id: otherOld.id,
                    parentId: otherOld.parentId,
                    name: otherOld.name,
                    nameLocked: otherOld.nameLocked,
                    kind: otherOld.kind,
                    size: otherOld.size,
                    plainSize: otherOld.plainSize,
                    mimeType: otherOld.mimeType,
                    contentVersion: otherOld.contentVersion,
                    metadataVersion: seqCounter,
                    createdAt: otherOld.createdAt,
                    modifiedAt: nowMs,
                    deleted: true,
                    shared: otherOld.shared,
                    shareUrl: otherOld.shareUrl,
                    encryption: otherOld.encryption,
                    wrappedKey: otherOld.wrappedKey,
                    nonce: otherOld.nonce,
                    sealPublicKey: otherOld.sealPublicKey
                )
                manifestsById[otherId] = otherManifest
                segmentsToRecycle.append(contentsOf: otherManifest.segments)
            }
        }
        persistManifests()
        await reconcileAccountPoolUsage()

        // Move underlying Google Drive segments into the `Helium Pool Vault / Recycle Bin` folder
        let transport = URLSessionGoogleDriveTransport()
        for seg in segmentsToRecycle where !seg.driveFileId.isEmpty && !seg.driveFileId.hasPrefix("gdrive_") {
            if let rawAcc = await pool.account(id: seg.accountId),
               !rawAcc.refreshToken.isEmpty,
               !rawAcc.refreshToken.hasPrefix("rt_") {
                let acc = await ensureValidToken(for: rawAcc)
                if let recycleBinId = try? await transport.ensureRecycleBinFolder(account: acc) {
                    try? await transport.moveFileBetweenFolders(
                        account: acc,
                        driveFileId: seg.driveFileId,
                        targetFolderId: recycleBinId
                    )
                }
            }
        }
        return manifest
    }

    /// Restores a soft-deleted item from the 30-day Trash back into the active pool catalog
    /// and moves its Google Drive files out of `Recycle Bin` back into the active `Helium Pool Vault` folder.
    @discardableResult
    public func restoreFromTrash(id: String) async -> PoolItemManifest? {
        guard var manifest = manifestsById[id] else { return nil }
        seqCounter += 1
        let old = manifest.item
        manifest.item = RemoteItem(
            id: old.id,
            parentId: old.parentId,
            name: old.name,
            nameLocked: old.nameLocked,
            kind: old.kind,
            size: old.size,
            plainSize: old.plainSize,
            mimeType: old.mimeType,
            contentVersion: old.contentVersion,
            metadataVersion: seqCounter,
            createdAt: old.createdAt,
            modifiedAt: Int64(Date().timeIntervalSince1970 * 1000),
            deleted: false,
            shared: old.shared,
            shareUrl: old.shareUrl,
            encryption: old.encryption,
            wrappedKey: old.wrappedKey,
            nonce: old.nonce,
            sealPublicKey: old.sealPublicKey
        )
        manifestsById[id] = manifest
        persistManifests()
        await reconcileAccountPoolUsage()

        // Move underlying Google Drive segments out of `Recycle Bin` back into their target folder
        let transport = URLSessionGoogleDriveTransport()
        for seg in manifest.segments where !seg.driveFileId.isEmpty && !seg.driveFileId.hasPrefix("gdrive_") {
            if let rawAcc = await pool.account(id: seg.accountId),
               !rawAcc.refreshToken.isEmpty,
               !rawAcc.refreshToken.hasPrefix("rt_") {
                let acc = await ensureValidToken(for: rawAcc)
                let targetFolderId = await resolveGoogleDriveFolderId(
                    for: acc,
                    virtualFolderId: manifest.item.parentId ?? RemoteItem.rootID
                )
                try? await transport.moveFileBetweenFolders(
                    account: acc,
                    driveFileId: seg.driveFileId,
                    targetFolderId: targetFolderId
                )
            }
        }
        return manifest
    }

    /// Returns all items currently in the 30-day Trash.
    public func trashedManifests() -> [PoolItemManifest] {
        manifestsById.values
            .filter { $0.item.deleted && (!$0.segments.isEmpty || $0.item.kind == .folder) }
            .sorted { $0.item.modifiedAt > $1.item.modifiedAt }
    }

    public func uploadNewFile(
        from fileURL: URL,
        name: String,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        let source = try FileBlobSource(fileURL)
        let saved = try await putBlob(
            source: source,
            plainSize: source.size,
            secrets: nil,
            name: .plain(name),
            parentId: parentId,
            clientId: clientId,
            modifiedAt: modifiedAt,
            link: link,
            progress: progress
        )
        return saved.item
    }

    public func uploadOverwrite(
        id: String,
        from fileURL: URL,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        let source = try FileBlobSource(fileURL)
        return try await replaceBlob(
            id: id,
            source: source,
            plainSize: source.size,
            secrets: nil,
            expectedVersion: expectedVersion,
            modifiedAt: modifiedAt,
            progress: progress
        )
    }

    private func uploadSegmentWithAutoRefresh(
        account: LinkedGoogleAccount,
        name: String,
        parentFolderId: String? = nil,
        data: Data,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> String {
        var currentAccount = account
        let oauthClientId = FirebaseConfig.loadDefault().clientId ?? ""
        if !(pool.transport is MockGoogleDriveCloud),
           (currentAccount.accessToken == nil || currentAccount.accessToken?.isEmpty == true),
           currentAccount.refreshToken.count >= 12,
           !currentAccount.refreshToken.hasPrefix("rt_"),
           !oauthClientId.isEmpty {
            let freshToken = try await URLSessionGoogleDriveTransport().refreshAccessToken(
                refreshToken: currentAccount.refreshToken,
                clientId: oauthClientId
            )
            await pool.updateAccountTokens(id: currentAccount.id, accessToken: freshToken)
            currentAccount.accessToken = freshToken
        }

        let effectiveFolderId = parentFolderId ?? currentAccount.rootFolderId
        do {
            return try await pool.transport.putSegmentWithProgress(
                account: currentAccount,
                name: name,
                parentFolderId: effectiveFolderId,
                data: data,
                progress: progress
            )
        } catch let GoogleDriveTransportError.httpError(statusCode, _) where statusCode == 401 {
            guard !currentAccount.refreshToken.isEmpty,
                  !currentAccount.refreshToken.hasPrefix("rt_"),
                  !oauthClientId.isEmpty else {
                throw GoogleDriveTransportError.missingAccessToken(email: currentAccount.email)
            }
            let freshToken = try await URLSessionGoogleDriveTransport().refreshAccessToken(
                refreshToken: currentAccount.refreshToken,
                clientId: oauthClientId
            )
            await pool.updateAccountTokens(id: currentAccount.id, accessToken: freshToken)
            currentAccount.accessToken = freshToken
            return try await pool.transport.putSegmentWithProgress(
                account: currentAccount,
                name: name,
                parentFolderId: effectiveFolderId,
                data: data,
                progress: progress
            )
        }
    }

    public func putBlob(
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        name: WireName,
        parentId: String,
        clientId: String,
        modifiedAt: Date,
        link: Bool,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> SaveResult {
        let accounts = await pool.accounts()
        let isEncrypted = (secrets?.wrapped != nil)
        let plan = try allocator.allocate(totalBytes: source.size, encrypted: isEncrypted, accounts: accounts)

        let itemId = "pool_file_\(UUID().uuidString)"
        var uploadedSegments: [PoolSegment] = []
        var completedSegmentsBytes: Int64 = 0

        let readableBaseName = name.locked ? itemId : name.text

        for var seg in plan.segments {
            guard let targetAccount = await pool.account(id: seg.accountId) else {
                throw PoolAllocationError.noLinkedAccounts
            }
            let segBytes = seg.byteLength > 0
                ? try source.read(offset: seg.logicalOffset, length: Int(seg.byteLength))
                : Data()
            let segFilename: String
            if plan.mode == .wholeFileSmartPlacement {
                segFilename = name.locked ? "\(itemId).blob" : readableBaseName
            } else {
                segFilename = "\(readableBaseName).part\(String(format: "%04d", seg.index + 1))"
            }
            let targetFolderId = await resolveGoogleDriveFolderId(for: targetAccount, virtualFolderId: parentId)
            let baseCompleted = completedSegmentsBytes
            let driveFileId = try await uploadSegmentWithAutoRefresh(
                account: targetAccount,
                name: segFilename,
                parentFolderId: targetFolderId,
                data: segBytes
            ) { chunkBytesSent in
                progress?(baseCompleted + chunkBytesSent)
            }
            let digest = SHA256.hash(data: segBytes)
            seg.driveFileId = driveFileId
            seg.sha256 = ZK.b64(Data(digest))
            uploadedSegments.append(seg)

            await pool.recordUsageDelta(accountId: targetAccount.id, deltaBytes: seg.byteLength)
            completedSegmentsBytes += seg.byteLength
            progress?(completedSegmentsBytes)
        }

        let now = Int64(modifiedAt.timeIntervalSince1970 * 1000)
        seqCounter += 1
        let shareURL = link ? "https://cogify.me/helium/s/\(itemId)" : nil
        let remoteItem = RemoteItem(
            id: itemId,
            parentId: parentId,
            name: name.text,
            nameLocked: name.locked,
            kind: .file,
            size: source.size,
            plainSize: plainSize,
            contentVersion: 1,
            metadataVersion: seqCounter,
            createdAt: now,
            modifiedAt: now,
            deleted: false,
            shared: link,
            shareUrl: shareURL,
            encryption: isEncrypted ? "zk-v1" : nil,
            wrappedKey: secrets?.wrapped?.key,
            nonce: secrets?.wrapped?.nonce,
            sealPublicKey: secrets?.sealPublic
        )
        manifestsById[itemId] = PoolItemManifest(
            item: remoteItem,
            placementMode: plan.mode,
            segments: uploadedSegments
        )
        persistManifests()
        await reconcileAccountPoolUsage()
        return SaveResult(item: remoteItem, shareUrl: shareURL)
    }

    public func replaceBlob(
        id: String,
        source: any BlobSource,
        plainSize: Int64,
        secrets: WireSecrets?,
        expectedVersion: Int64,
        modifiedAt: Date,
        progress: (@Sendable (Int64) -> Void)?
    ) async throws -> RemoteItem {
        guard let existing = manifestsById[id] else {
            throw CocoaError(.fileNoSuchFile)
        }
        // Reclaim old segments first
        for oldSeg in existing.segments {
            if let acc = await pool.account(id: oldSeg.accountId), !oldSeg.driveFileId.isEmpty {
                try? await pool.transport.deleteSegment(account: acc, driveFileId: oldSeg.driveFileId)
                await pool.recordUsageDelta(accountId: acc.id, deltaBytes: -oldSeg.byteLength)
            }
        }

        let accounts = await pool.accounts()
        let isEncrypted = (secrets?.wrapped != nil)
        let plan = try allocator.allocate(totalBytes: source.size, encrypted: isEncrypted, accounts: accounts)

        var uploadedSegments: [PoolSegment] = []
        var completedSegmentsBytes: Int64 = 0
        for var seg in plan.segments {
            guard let targetAccount = await pool.account(id: seg.accountId) else {
                throw PoolAllocationError.noLinkedAccounts
            }
            let segBytes = seg.byteLength > 0
                ? try source.read(offset: seg.logicalOffset, length: Int(seg.byteLength))
                : Data()
            let segFilename = plan.mode == .wholeFileSmartPlacement
                ? existing.item.name
                : "\(existing.item.name).part\(String(format: "%04d", seg.index + 1))"
            let baseCompleted = completedSegmentsBytes
            let driveFileId = try await uploadSegmentWithAutoRefresh(
                account: targetAccount,
                name: segFilename,
                data: segBytes
            ) { chunkBytesSent in
                progress?(baseCompleted + chunkBytesSent)
            }
            seg.driveFileId = driveFileId
            uploadedSegments.append(seg)
            await pool.recordUsageDelta(accountId: targetAccount.id, deltaBytes: seg.byteLength)
            completedSegmentsBytes += seg.byteLength
            progress?(completedSegmentsBytes)
        }

        seqCounter += 1
        let updatedItem = RemoteItem(
            id: existing.item.id,
            parentId: existing.item.parentId,
            name: existing.item.name,
            nameLocked: existing.item.nameLocked,
            kind: .file,
            size: source.size,
            plainSize: plainSize,
            mimeType: existing.item.mimeType,
            contentVersion: existing.item.contentVersion + 1,
            metadataVersion: seqCounter,
            createdAt: existing.item.createdAt,
            modifiedAt: Int64(modifiedAt.timeIntervalSince1970 * 1000),
            deleted: false,
            shared: existing.item.shared,
            shareUrl: existing.item.shareUrl,
            encryption: isEncrypted ? "zk-v1" : nil,
            wrappedKey: secrets?.wrapped?.key,
            nonce: secrets?.wrapped?.nonce,
            sealPublicKey: secrets?.sealPublic
        )
        manifestsById[id] = PoolItemManifest(
            item: updatedItem,
            placementMode: plan.mode,
            segments: uploadedSegments
        )
        persistManifests()
        await reconcileAccountPoolUsage()
        return updatedItem
    }

    // MARK: - Account Evacuation & Unlinking

    /// Gracefully migrates all segments stored on `accountId` onto the remaining linked Google Drive accounts before unlinking it.
    public func drainAndUnlinkAccount(id accountId: String) async throws {
        guard let drainingAccount = await pool.account(id: accountId) else { return }
        let remainingAccounts = await pool.accounts().filter { $0.id != accountId }
        guard !remainingAccounts.isEmpty else {
            throw PoolAllocationError.noLinkedAccounts
        }

        for (itemId, var manifest) in manifestsById where !manifest.item.deleted {
            var changed = false
            for idx in manifest.segments.indices {
                let seg = manifest.segments[idx]
                guard seg.accountId == accountId else { continue }

                // Read segment bytes from the account being drained
                let segData = try await pool.transport.fetchSegmentRange(
                    account: drainingAccount,
                    driveFileId: seg.driveFileId,
                    offset: 0,
                    length: Int(seg.byteLength)
                )

                // Pick target account with highest headroom among remaining accounts
                let currentRemaining = await pool.accounts().filter { $0.id != accountId }
                let singlePlan = try allocator.allocate(
                    totalBytes: seg.byteLength,
                    encrypted: manifest.item.encryption != nil,
                    accounts: currentRemaining
                )
                guard let targetSeg = singlePlan.segments.first,
                      let targetAccount = await pool.account(id: targetSeg.accountId) else {
                    throw PoolAllocationError.noLinkedAccounts
                }

                let newDriveFileId = try await uploadSegmentWithAutoRefresh(
                    account: targetAccount,
                    name: manifest.segments.count == 1 ? manifest.item.name : "\(manifest.item.name).part\(String(format: "%04d", seg.index + 1))",
                    data: segData,
                    progress: nil
                )
                await pool.recordUsageDelta(accountId: targetAccount.id, deltaBytes: seg.byteLength)
                do {
                    try await pool.transport.deleteSegment(account: drainingAccount, driveFileId: seg.driveFileId)
                    await pool.recordUsageDelta(accountId: drainingAccount.id, deltaBytes: -seg.byteLength)
                } catch {
                    // Retain drainingAccount usage accounting if old segment deletion fails, while still completing migration to targetAccount.
                }

                manifest.segments[idx].accountId = targetAccount.id
                manifest.segments[idx].driveFileId = newDriveFileId
                changed = true
            }
            if changed {
                manifestsById[itemId] = manifest
            }
        }

        persistManifests()
        await pool.removeAccount(id: accountId)
    }

    /// Rebalances whole-file items from heavily-used Google Drive accounts onto accounts with the most available free space.
    public func rebalanceWholeFiles() async throws -> Int {
        let initialAccounts = await pool.accounts()
        guard initialAccounts.count >= 2 else { return 0 }

        var migratedCount = 0
        let candidateIds = manifestsById.values
            .filter { !$0.item.deleted && $0.item.kind == .file && $0.placementMode == .wholeFileSmartPlacement && $0.segments.count == 1 }
            .sorted { $0.item.size > $1.item.size }
            .map(\.item.id)

        for itemId in candidateIds {
            if migratedCount >= 5 { break }
            guard var manifest = manifestsById[itemId],
                  let seg = manifest.segments.first,
                  seg.byteLength > 0 else { continue }

            let currentAccounts = await pool.accounts()
            guard let sourceAccount = currentAccounts.first(where: { $0.id == seg.accountId }),
                  let freestAccount = currentAccounts.max(by: { $0.freeBytes < $1.freeBytes }),
                  freestAccount.id != sourceAccount.id else { continue }

            // Migrate if the freest account has significantly more headroom than the source account
            guard freestAccount.freeBytes - sourceAccount.freeBytes > max(seg.byteLength * 2, 1_048_576) else {
                continue
            }

            let segData = try await pool.transport.fetchSegmentRange(
                account: sourceAccount,
                driveFileId: seg.driveFileId,
                offset: 0,
                length: Int(seg.byteLength)
            )
            let newDriveFileId = try await uploadSegmentWithAutoRefresh(
                account: freestAccount,
                name: manifest.item.name,
                data: segData,
                progress: nil
            )
            await pool.recordUsageDelta(accountId: freestAccount.id, deltaBytes: seg.byteLength)
            do {
                try await pool.transport.deleteSegment(account: sourceAccount, driveFileId: seg.driveFileId)
                await pool.recordUsageDelta(accountId: sourceAccount.id, deltaBytes: -seg.byteLength)
            } catch {
                // Keep source accounting if old segment cleanup fails
            }

            manifest.segments[0].accountId = freestAccount.id
            manifest.segments[0].driveFileId = newDriveFileId
            manifestsById[itemId] = manifest
            migratedCount += 1
        }

        if migratedCount > 0 {
            persistManifests()
            await reconcileAccountPoolUsage()
        }
        return migratedCount
    }

    /// Audits the active manifest table and returns pool health metrics.
    public func verifyPoolIntegrity() async -> (verifiedFiles: Int, healthySegments: Int, totalSegments: Int) {
        let knownAccountIds = Set(await pool.accounts().map(\.id))
        var verifiedFiles = 0
        var healthySegments = 0
        var totalSegments = 0

        for manifest in manifestsById.values where !manifest.item.deleted && manifest.item.kind == .file {
            var fileHealthy = true
            for seg in manifest.segments {
                totalSegments += 1
                if knownAccountIds.contains(seg.accountId) && !seg.driveFileId.isEmpty {
                    healthySegments += 1
                } else {
                    fileHealthy = false
                }
            }
            if fileHealthy {
                verifiedFiles += 1
            }
        }
        return (verifiedFiles, healthySegments, totalSegments)
    }

    /// Moves an existing pooled file (`itemId`) directly onto a user-specified Google Drive account (`targetAccountId`).
    @discardableResult
    public func moveFileToAccount(id itemId: String, targetAccountId: String) async throws -> PoolItemManifest {
        guard var manifest = manifestsById[itemId], !manifest.item.deleted, manifest.item.kind == .file else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard let targetAccount = await pool.account(id: targetAccountId) else {
            throw PoolAllocationError.noLinkedAccounts
        }
        if manifest.segments.count == 1, manifest.segments[0].accountId == targetAccountId {
            return manifest
        }
        let totalSize = manifest.item.size
        guard targetAccount.freeBytes >= totalSize else {
            throw PoolAllocationError.insufficientPooledStorage(required: totalSize, available: targetAccount.freeBytes)
        }

        let payload = totalSize > 0
            ? try await fetchRange(id: itemId, offset: 0, length: Int(totalSize))
            : Data()
        let filename = manifest.item.nameLocked ? "\(itemId).blob" : manifest.item.name
        let newDriveFileId = try await uploadSegmentWithAutoRefresh(
            account: targetAccount,
            name: filename,
            data: payload,
            progress: nil
        )
        await pool.recordUsageDelta(accountId: targetAccount.id, deltaBytes: totalSize)

        let oldSegments = manifest.segments
        for oldSeg in oldSegments {
            if let oldAcc = await pool.account(id: oldSeg.accountId), !oldSeg.driveFileId.isEmpty {
                do {
                    try await pool.transport.deleteSegment(account: oldAcc, driveFileId: oldSeg.driveFileId)
                    await pool.recordUsageDelta(accountId: oldAcc.id, deltaBytes: -oldSeg.byteLength)
                } catch {
                    // Retain old account usage if remote delete fails
                }
            }
        }

        let digest = SHA256.hash(data: payload)
        manifest.placementMode = .wholeFileSmartPlacement
        manifest.segments = [
            PoolSegment(
                index: 0,
                accountId: targetAccount.id,
                driveFileId: newDriveFileId,
                logicalOffset: 0,
                byteLength: totalSize,
                sha256: ZK.b64(Data(digest))
            )
        ]
        manifestsById[itemId] = manifest
        persistManifests()
        return manifest
    }

    // MARK: - KeysRemote & ShareRemote

    public func fetchServerKeys() async throws -> ServerKeys {
        serverKeysState
    }

    public func enableZeroKnowledge(
        keyCheck: String,
        recoveryWrap: String,
        dropPublicKey: String,
        dropPrivateWrap: String,
        ownerProof: String
    ) async throws {
        serverKeysState = ServerKeys(
            mode: "zero_knowledge",
            keyCheck: keyCheck,
            recoveryWrap: recoveryWrap,
            dropPublicKey: dropPublicKey,
            dropPrivateWrap: dropPrivateWrap
        )
    }

    public func listShares() async throws -> [SharedLink] {
        Array(sharedLinks.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func createShare(itemId: String, keyWrap: String?, wrap: String?) async throws -> SharedLink {
        guard let manifest = manifestsById[itemId] else { throw CocoaError(.fileNoSuchFile) }
        let shareId = "shr_\(UUID().uuidString.prefix(8))"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let link = SharedLink(
            id: shareId,
            itemId: itemId,
            name: manifest.item.name,
            kind: manifest.item.kind.rawValue,
            size: manifest.item.plainSize ?? manifest.item.size,
            url: "https://cogify.me/helium/s/\(shareId)",
            createdAt: now
        )
        sharedLinks[shareId] = link
        return link
    }

    public func revokeShare(id: String) async throws {
        sharedLinks.removeValue(forKey: id)
    }

    public func listFileRequests() async throws -> [FileRequest] {
        Array(fileRequests.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func createFileRequest(folderId: String, title: String, note: String?) async throws -> FileRequest {
        let reqId = "req_\(UUID().uuidString.prefix(8))"
        let folderName = manifestsById[folderId]?.item.name ?? "Helium"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let req = FileRequest(
            id: reqId,
            folderId: folderId,
            folderName: folderName,
            title: title,
            note: note,
            url: "https://cogify.me/helium/r/\(reqId)",
            createdAt: now
        )
        fileRequests[reqId] = req
        return req
    }

    public func closeFileRequest(id: String) async throws {
        if let existing = fileRequests[id] {
            fileRequests[id] = FileRequest(
                id: existing.id,
                folderId: existing.folderId,
                folderName: existing.folderName,
                title: existing.title,
                note: existing.note,
                url: existing.url,
                createdAt: existing.createdAt,
                expiresAt: existing.expiresAt,
                open: false,
                uploads: existing.uploads
            )
        }
    }
}
