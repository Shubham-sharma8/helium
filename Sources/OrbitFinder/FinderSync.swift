import Cocoa
import FinderSync
import OrbitCore

@objc(FinderSync)
public final class FinderSync: FIFinderSync {
    private let mountURL = URL(fileURLWithPath: SharedContainer.mountPointPath, isDirectory: true)
    private let mirrorURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Helium", isDirectory: true)
    private let keepList = KeepList()

    public override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [mountURL, mirrorURL]
        setupBadges()
    }

    private func setupBadges() {
        let controller = FIFinderSyncController.default()
        if let keptImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Kept on this Mac") {
            controller.setBadgeImage(keptImage, label: "Kept on this Mac", forBadgeIdentifier: "kept")
        }
        if let cloudImage = NSImage(systemSymbolName: "icloud", accessibilityDescription: "Cloud Only (0 B on disk)") {
            controller.setBadgeImage(cloudImage, label: "Zero bytes on disk", forBadgeIdentifier: "cloud")
        }
        if let syncingImage = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.icloud.fill", accessibilityDescription: "Syncing") {
            controller.setBadgeImage(syncingImage, label: "Syncing", forBadgeIdentifier: "syncing")
        }
        if let sharedImage = NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: "Shared") {
            controller.setBadgeImage(sharedImage, label: "Shared", forBadgeIdentifier: "shared")
        }
    }

    public override func requestBadgeIdentifier(for url: URL) {
        let name = url.lastPathComponent
        guard !name.isEmpty, url.standardizedFileURL != mountURL.standardizedFileURL, url.standardizedFileURL != mirrorURL.standardizedFileURL else { return }

        if keepList.isKept(name) {
            FIFinderSyncController.default().setBadgeIdentifier("kept", for: url)
        } else {
            FIFinderSyncController.default().setBadgeIdentifier("cloud", for: url)
        }
    }

    public override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Helium")
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        let firstKept = selected.first.map { keepList.isKept($0.lastPathComponent) } ?? false

        let shareItem = NSMenuItem(
            title: "Copy Helium Link",
            action: #selector(copyHeliumLink(_:)),
            keyEquivalent: ""
        )
        shareItem.target = self
        menu.addItem(shareItem)

        let requestItem = NSMenuItem(
            title: "Request Files…",
            action: #selector(requestFiles(_:)),
            keyEquivalent: ""
        )
        requestItem.target = self
        menu.addItem(requestItem)

        menu.addItem(.separator())

        let keepItem = NSMenuItem(
            title: firstKept ? "Free up space (0 B on disk)" : "Keep on this Mac",
            action: #selector(toggleKeepOnMac(_:)),
            keyEquivalent: ""
        )
        keepItem.target = self
        menu.addItem(keepItem)

        return menu
    }

    private func selectedPathPayload() -> String {
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        if !selected.isEmpty {
            return selected.map(\.path).joined(separator: "\n")
        }
        if let target = FIFinderSyncController.default().targetedURL() {
            return target.path
        }
        return ""
    }

    @objc private func toggleKeepOnMac(_ sender: AnyObject?) {
        let items = FIFinderSyncController.default().selectedItemURLs() ?? []
        for url in items {
            let key = url.lastPathComponent
            let currentlyKept = keepList.isKept(key)
            keepList.setKept(key, kept: !currentlyKept)
            requestBadgeIdentifier(for: url)
        }
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.cogify.helium.finder.keepOffline"),
            object: selectedPathPayload(),
            userInfo: nil,
            deliverImmediately: true
        )
    }

    @objc private func copyHeliumLink(_ sender: AnyObject?) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.cogify.helium.finder.copyLink"),
            object: selectedPathPayload(),
            userInfo: nil,
            deliverImmediately: true
        )
        SharedContainer.postDarwinNotification("com.cogify.helium.share.requested")
    }

    @objc private func requestFiles(_ sender: AnyObject?) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.cogify.helium.finder.requestFiles"),
            object: selectedPathPayload(),
            userInfo: nil,
            deliverImmediately: true
        )
        SharedContainer.postDarwinNotification("com.cogify.helium.filerequest.requested")
    }
}

let args = CommandLine.arguments
if args.contains("--version") {
    print("OrbitFinder FinderSync Extension Ready")
    exit(0)
}
