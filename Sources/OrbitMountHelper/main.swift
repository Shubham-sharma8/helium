import Foundation
import Security
import OrbitCore

public final class Helper: NSObject, NSXPCListenerDelegate, MountHelperProtocol, @unchecked Sendable {
    public static let helperVersion: Int = 42
    private static let allowedMountPoint = SharedContainer.mountPointPath

    public override init() {
        super.init()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isAuthorizedClient(newConnection) else {
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: MountHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    private func isAuthorizedClient(_ connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else { return false }
        let attrs: [CFString: Any] = [kSecGuestAttributePid: pid]
        var guestCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs as CFDictionary, [], &guestCode) == errSecSuccess,
              let code = guestCode else {
            return false
        }
        var requirement: SecRequirement?
        let reqString = "identifier \"com.cogify.helium\" or identifier \"com.cogify.helium.OrbitFS\"" as CFString
        guard SecRequirementCreateWithString(reqString, [], &requirement) == errSecSuccess,
              let req = requirement else {
            return false
        }
        return SecCodeCheckValidity(code, [], req) == errSecSuccess
    }

    private func isAllowedMountPoint(_ mountPoint: String) -> Bool {
        let standardized = URL(fileURLWithPath: mountPoint).standardizedFileURL.path
        return standardized == Self.allowedMountPoint
    }

    public func mount(mountPoint: String, ready: @escaping @Sendable (String?) -> Void) {
        guard isAllowedMountPoint(mountPoint) else {
            ready("Rejected disallowed mount point: \(mountPoint)")
            return
        }
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: Self.allowedMountPoint) {
                try fm.createDirectory(atPath: Self.allowedMountPoint, withIntermediateDirectories: false)
            }
            ready(nil)
        } catch {
            ready(error.localizedDescription)
        }
    }

    public func unmount(mountPoint: String, force: Bool, reply: @escaping @Sendable (String?) -> Void) {
        guard isAllowedMountPoint(mountPoint) else {
            reply("Rejected disallowed mount point: \(mountPoint)")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = force
            ? ["unmount", "force", Self.allowedMountPoint]
            : ["unmount", Self.allowedMountPoint]
        do {
            try process.run()
            process.waitUntilExit()
            reply(nil)
        } catch {
            reply(error.localizedDescription)
        }
    }

    public func version(reply: @escaping @Sendable (Int) -> Void) {
        reply(Self.helperVersion)
    }
}

let args = CommandLine.arguments
if args.contains("--version") {
    print("OrbitMountHelper version \(Helper.helperVersion)")
    exit(0)
}

let helper = Helper()
let listener = NSXPCListener(machServiceName: SharedContainer.mountHelperMachServiceName)
listener.delegate = helper
listener.resume()
RunLoop.current.run()
