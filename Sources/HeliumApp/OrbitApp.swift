import AppKit
import OrbitCore
import SwiftUI

@MainActor
final class HeliumAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for window in NSApplication.shared.windows where window.title.contains("Helium") {
                window.minSize = NSSize(width: 740, height: 520)
                if window.frame.width < 1040 || window.frame.height < 680 {
                    var frame = window.frame
                    frame.size = NSSize(width: 1120, height: 740)
                    window.setFrame(frame, display: true, animate: true)
                    window.center()
                }
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        if !fileURLs.isEmpty {
            if let model = AppModel.shared {
                model.handleOpenFinderFileURLs(fileURLs)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AppModel.shared?.handleOpenFinderFileURLs(fileURLs)
                }
            }
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if let model = AppModel.shared {
            model.handleOpenFinderFileURLs([url])
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppModel.shared?.handleOpenFinderFileURLs([url])
            }
        }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        if let model = AppModel.shared {
            model.handleOpenFinderFileURLs(urls)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppModel.shared?.handleOpenFinderFileURLs(urls)
            }
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppModel.shared?.navigateToMainWindow(destination: .home)
        }
        return true
    }
}

@main
@MainActor
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(HeliumAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    init() {
        if CommandLine.arguments.contains("--version") {
            print("Helium macOS App v0.0.1 (Build 1 — Multi-Google-Drive Pool Edition)")
            exit(0)
        }
        DispatchQueue.main.async {
            if let iconURL = Bundle.main.url(forResource: "HeliumIcon", withExtension: "png")
                ?? Bundle.main.url(forResource: "Orbit", withExtension: "icns"),
               let icon = NSImage(contentsOf: iconURL) {
                NSApplication.shared.applicationIconImage = icon
            }
        }
    }

    var body: some Scene {
        WindowGroup("Helium") {
            MainDashboardView(model: model)
                .frame(minWidth: 740, idealWidth: 1120, minHeight: 520, idealHeight: 740)
                .onOpenURL { url in
                    if url.isFileURL {
                        model.handleOpenFinderFileURLs([url])
                    }
                }
        }
        .defaultSize(width: 1120, height: 740)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            CommandGroup(replacing: .help) {
                Button("Helium Help Center") {
                    NSApp.activate(ignoringOtherApps: true)
                    model.showHelpSheet = true
                }
                .keyboardShortcut("?", modifiers: [.command])

                Button("Storage Pool Placement Engine Guide…") {
                    NSApp.activate(ignoringOtherApps: true)
                    model.showHelpSheet = true
                }

                Divider()

                Button("Send Feedback / Write Email (connect@cogify.me)…") {
                    NSApp.activate(ignoringOtherApps: true)
                    model.showFeedbackSheet = true
                }

                Button("Open Mail to connect@cogify.me") {
                    model.composeSupportEmail(template: .support)
                }

                Divider()

                Button("Made with ❤️ by cogify.me") {
                    if let url = URL(string: "https://cogify.me") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            CommandMenu("Helium Drive") {
                Button("Open Helium in Finder") {
                    model.openInFinder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Paste Clipboard into Helium Drive") {
                    model.uploadClipboardToHelium()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Export Storage Pool Catalog (.md)…") {
                    model.exportPoolCatalogSnapshotToDisk()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Sync with Google Drive Pool") {
                    Task { await model.syncWithGoogleDrive() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Undo Last Delete from Recycle Bin") {
                    model.undoLastDelete()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(model.trashedItems.isEmpty)

                Button("Open Recycle Bin (30-Day Trash)…") {
                    model.navigateToMainWindow(destination: .home)
                    model.showTrashSheet = true
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Rebalance Storage Pool") {
                    Task { await model.rebalancePool() }
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Sign in with Google (+Add Drive to Pool)…") {
                    model.startBrowserOAuthFlow()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button("Global Spotlight Search…") {
                    model.navigateToMainWindow(destination: .search)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Helium Settings…") {
                    model.navigateToMainWindow(destination: .settings)
                }
                .keyboardShortcut(",", modifiers: [.command])

                Divider()

                Toggle(
                    "Start Helium on Bootup",
                    isOn: Binding(
                        get: { model.openAtLogin },
                        set: { model.setOpenAtLogin($0) }
                    )
                )

                Toggle(
                    "Run in Taskbar (Menu Bar) Only",
                    isOn: Binding(
                        get: { model.runInTaskbarOnly },
                        set: { model.setRunInTaskbarOnly($0, closeWindowImmediately: $0) }
                    )
                )

                Button("Ask Startup & Taskbar Preferences…") {
                    model.navigateToMainWindow(destination: .home)
                    model.askStartupPreferencesAgain()
                }

                Divider()

                Button("Save Recovery Key…") {
                    model.saveRecoveryKeyToDisk()
                }
            }
        }

        Settings {
            OriginalFiveTabSettingsView(model: model)
                .frame(width: 640, height: 520)
        }

        MenuBarExtra {
            MenuBarPopoverView(model: model)
        } label: {
            if let img = HeliumAsset.nsImage(model.isUploadsPaused ? "MenuBarIconSleepy" : "MenuBarIconHappy") {
                Image(nsImage: img)
            } else {
                Image(systemName: "externaldrive.fill.badge.icloud")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
