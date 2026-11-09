import AppKit
import Darwin
import Foundation

final class HeliumOpenerDelegate: NSObject, NSApplicationDelegate {
    private var handledPaths = Set<String>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-") }
        if !args.isEmpty {
            let urls = args.map { URL(fileURLWithPath: $0) }
            handleOpen(urls: urls)
        }
        scheduleExit()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleOpen(urls: urls)
        scheduleExit()
    }

    private func scheduleExit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func isHydrated(_ fileURL: URL, expectedSize: Int64) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
              vals.isRegularFile == true else {
            return false
        }
        let logical = Int64(vals.fileSize ?? 0)
        if expectedSize > 0 && logical != expectedSize {
            return false
        }
        if logical == 0 { return true }
        let allocated = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0
        guard allocated > 0 else { return false }

        let fd = Darwin.open(fileURL.path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }
        var buf = [UInt8](repeating: 0, count: min(4096, Int(max(1, logical))))
        let n = Darwin.pread(fd, &buf, buf.count, 0)
        guard n > 0 else { return false }
        return buf.prefix(n).contains { $0 != 0 }
    }

    private func sanitizeHydratedFile(_ fileURL: URL) {
        _ = Darwin.removexattr(fileURL.path, "com.apple.LaunchServices.OpenWith", 0)
        _ = Darwin.removexattr(fileURL.path, "com.apple.quarantine", 0)
    }

    private func openInNativeDefaultApp(_ fileURL: URL) {
        sanitizeHydratedFile(fileURL)
        let workspace = NSWorkspace.shared

        let isHeliumApp: (URL) -> Bool = { appURL in
            let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? ""
            if bundleID.hasPrefix("com.cogify.helium") { return true }
            return appURL.lastPathComponent.localizedCaseInsensitiveContains("Helium")
        }

        if let defaultApp = workspace.urlForApplication(toOpen: fileURL),
           !isHeliumApp(defaultApp) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.open([fileURL], withApplicationAt: defaultApp, configuration: config, completionHandler: nil)
            return
        }

        let candidates = workspace.urlsForApplications(toOpen: fileURL).filter { !isHeliumApp($0) }
        if let best = candidates.first {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.open([fileURL], withApplicationAt: best, configuration: config, completionHandler: nil)
            return
        }

        workspace.activateFileViewerSelecting([fileURL])
    }

    private func handleOpen(urls: [URL]) {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Helium/OfflinePinned", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/Helium/OfflinePinned", isDirectory: true)
        let streamCacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("HeliumStreamCache", isDirectory: true)

        for url in urls where url.isFileURL {
            let stdPath = url.standardizedFileURL.path
            guard !handledPaths.contains(stdPath) else { continue }
            handledPaths.insert(stdPath)

            let fileName = url.lastPathComponent
            let expectedSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)

            let pinnedCandidate = cachesDir.appendingPathComponent(fileName)
            let streamCandidate = streamCacheDir.appendingPathComponent(fileName)

            if isHydrated(pinnedCandidate, expectedSize: expectedSize) {
                openInNativeDefaultApp(pinnedCandidate)
                DistributedNotificationCenter.default().postNotificationName(
                    Notification.Name("com.cogify.helium.opener.didOpenCached"),
                    object: url.path,
                    userInfo: nil,
                    deliverImmediately: true
                )
                continue
            }

            if isHydrated(streamCandidate, expectedSize: expectedSize) {
                openInNativeDefaultApp(streamCandidate)
                DistributedNotificationCenter.default().postNotificationName(
                    Notification.Name("com.cogify.helium.opener.didOpenCached"),
                    object: url.path,
                    userInfo: nil,
                    deliverImmediately: true
                )
                continue
            }

            if isHydrated(url, expectedSize: expectedSize) {
                try? FileManager.default.createDirectory(at: streamCacheDir, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: streamCandidate)
                try? FileManager.default.copyItem(at: url, to: streamCandidate)
                openInNativeDefaultApp(streamCandidate)
                continue
            }

            // Not yet cached locally -> ask running Helium.app to stream and open in background without activating Helium's window
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("com.cogify.helium.opener.streamAndOpen"),
                object: url.path,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = HeliumOpenerDelegate()
app.delegate = delegate
app.run()
