import Foundation

/// Parses Firebase / Google Cloud OAuth configuration from `GoogleService-Info.plist` or environment variables.
public struct FirebaseConfig: Codable, Equatable, Sendable {
    public let projectId: String
    public let projectNumber: String
    public let apiKey: String
    public let bundleId: String
    public let storageBucket: String
    public let googleAppId: String
    public var clientId: String?
    public var reversedClientId: String?

    public init(
        projectId: String,
        projectNumber: String,
        apiKey: String,
        bundleId: String,
        storageBucket: String,
        googleAppId: String,
        clientId: String? = nil,
        reversedClientId: String? = nil
    ) {
        self.projectId = projectId
        self.projectNumber = projectNumber
        self.apiKey = apiKey
        self.bundleId = bundleId
        self.storageBucket = storageBucket
        self.googleAppId = googleAppId
        self.clientId = clientId
        self.reversedClientId = reversedClientId
    }

    private struct AndroidGoogleServicesJSON: Decodable {
        struct ProjectInfo: Decodable {
            let project_number: String?
            let project_id: String?
            let storage_bucket: String?
        }
        struct ClientEntry: Decodable {
            struct ClientInfo: Decodable {
                let mobilesdk_app_id: String?
            }
            struct OAuthClient: Decodable {
                let client_id: String?
                let client_type: Int?
            }
            struct APIKeyEntry: Decodable {
                let current_key: String?
            }
            let client_info: ClientInfo?
            let oauth_client: [OAuthClient]?
            let api_key: [APIKeyEntry]?
        }
        let project_info: ProjectInfo?
        let client: [ClientEntry]?
    }

    public static func load(plistURL: URL, jsonURL: URL? = nil) throws -> FirebaseConfig {
        let plistData = try Data(contentsOf: plistURL)
        let rawPlist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        guard let dict = rawPlist as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }

        var jsonModel: AndroidGoogleServicesJSON?
        if let jsonURL, let jsonData = try? Data(contentsOf: jsonURL) {
            jsonModel = try? JSONDecoder().decode(AndroidGoogleServicesJSON.self, from: jsonData)
        }

        let projectId = (dict["PROJECT_ID"] as? String)
            ?? jsonModel?.project_info?.project_id
            ?? "helium-cloud"
        let projectNumber = (dict["GCM_SENDER_ID"] as? String)
            ?? jsonModel?.project_info?.project_number
            ?? ""
        let apiKey = (dict["API_KEY"] as? String)
            ?? jsonModel?.client?.first?.api_key?.first?.current_key
            ?? ""
        let bundleId = (dict["BUNDLE_ID"] as? String) ?? "com.cogify.helium"
        let storageBucket = (dict["STORAGE_BUCKET"] as? String)
            ?? jsonModel?.project_info?.storage_bucket
            ?? ""
        let googleAppId = (dict["GOOGLE_APP_ID"] as? String)
            ?? jsonModel?.client?.first?.client_info?.mobilesdk_app_id
            ?? ""

        let envClientID = ProcessInfo.processInfo.environment["HELIUM_GOOGLE_CLIENT_ID"]
        let plistClientID = dict["CLIENT_ID"] as? String
        let jsonClientID = jsonModel?.client?.first?.oauth_client?.first?.client_id
        let resolvedClientID = plistClientID ?? jsonClientID ?? envClientID

        let reversed = (dict["REVERSED_CLIENT_ID"] as? String)
            ?? resolvedClientID.map { $0.components(separatedBy: ".").reversed().joined(separator: ".") }

        return FirebaseConfig(
            projectId: projectId,
            projectNumber: projectNumber,
            apiKey: apiKey,
            bundleId: bundleId,
            storageBucket: storageBucket,
            googleAppId: googleAppId,
            clientId: resolvedClientID,
            reversedClientId: reversed
        )
    }

    public static func loadDefault(workspaceFallback: URL? = nil) -> FirebaseConfig {
        if let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") {
            let jsonURL = Bundle.main.url(forResource: "google-services", withExtension: "json")
            if let loaded = try? load(plistURL: plistURL, jsonURL: jsonURL) {
                return loaded
            }
        }
        let containerDir = SharedContainer.directoryURL()
        let containerPlist = containerDir.appendingPathComponent("GoogleService-Info.plist")
        let containerJson = containerDir.appendingPathComponent("google-services.json")
        if let loaded = try? load(plistURL: containerPlist, jsonURL: containerJson) {
            return loaded
        }
        if let root = workspaceFallback {
            for relativePlist in ["GoogleService-Info.plist", ".local-credentials/GoogleService-Info.plist"] {
                let plistURL = root.appendingPathComponent(relativePlist)
                let jsonURL = plistURL.deletingLastPathComponent().appendingPathComponent("google-services.json")
                if let loaded = try? load(plistURL: plistURL, jsonURL: jsonURL) {
                    return loaded
                }
            }
        }
        return FirebaseConfig(
            projectId: ProcessInfo.processInfo.environment["HELIUM_FIREBASE_PROJECT_ID"] ?? "helium-cloud",
            projectNumber: ProcessInfo.processInfo.environment["HELIUM_GOOGLE_PROJECT_NUMBER"] ?? "",
            apiKey: ProcessInfo.processInfo.environment["HELIUM_FIREBASE_API_KEY"] ?? "",
            bundleId: "com.cogify.helium",
            storageBucket: "",
            googleAppId: "",
            clientId: ProcessInfo.processInfo.environment["HELIUM_GOOGLE_CLIENT_ID"]
        )
    }
}
