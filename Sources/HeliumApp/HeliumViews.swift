import AppKit
import AVKit
import OrbitCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root Main Window View
public struct MainDashboardView: View {
    @ObservedObject var model: AppModel
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var isSidebarVisible: Bool = true

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if model.phase == .welcomeSignIn && model.linkedAccounts.isEmpty {
                OriginalWelcomeAndSignInView(model: model)
            } else {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        sidebarContent
                            .frame(width: 224)
                            .background(Color(nsColor: .windowBackgroundColor))
                        Divider()
                    }
                    VStack(spacing: 0) {
                        detailContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if !model.statusMessage.isEmpty || !model.trashedItems.isEmpty || model.isSyncingPool {
                            Divider()
                            HStack(spacing: 10) {
                                if model.isSyncingPool {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Circle()
                                        .fill(model.isMounted ? Color.green : Color.orange)
                                        .frame(width: 7, height: 7)
                                }
                                Text(model.statusMessage.isEmpty ? "Mounted at /Volumes/Helium • Zero bytes on disk" : model.statusMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 8)
                                if !model.trashedItems.isEmpty {
                                    Button {
                                        model.showTrashSheet = true
                                    } label: {
                                        Label("Recycle Bin (\(model.trashedItems.count))", systemImage: "arrow.uturn.backward.circle")
                                            .font(.caption2.bold())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.orange)
                                }
                                Button {
                                    Task { await model.syncWithGoogleDrive() }
                                } label: {
                                    Label(model.isSyncingPool ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2.bold())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                                .disabled(model.isSyncingPool)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(HeliumSpring.snappy) {
                                isSidebarVisible.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showStartupPreferencesPrompt) {
            StartupTaskbarPromptSheet(model: model)
        }
        .sheet(isPresented: $model.showRecoveryKeySheet) {
            RecoveryKeyModalSheet(model: model)
        }
        .sheet(isPresented: $model.showUnlockSheet) {
            UnlockVaultModalSheet(model: model)
        }
        .sheet(isPresented: $model.showFeedbackSheet) {
            FeedbackModalSheet(model: model)
        }
        .sheet(isPresented: $model.showHelpSheet) {
            HeliumHelpCenterSheet(model: model)
        }
        .sheet(isPresented: $model.showTrashSheet) {
            ThirtyDayTrashModalSheet(model: model)
        }
        .sheet(isPresented: $model.showCrossDeviceSheet) {
            CrossDeviceAccessModalSheet(model: model)
        }
        .sheet(isPresented: $model.showRealtimeVideoStreamerSheet) {
            RealtimeChunkStreamerSheet(model: model, initialNode: model.streamingInspectorNode)
        }
        .sheet(isPresented: $model.showFileRequestsSheet) {
            FileRequestsManagerSheet(model: model)
        }
        .sheet(item: $model.inspectedNode) { inspected in
            NodeInspectorModalSheet(model: model, node: inspected)
        }
        .alert("New Folder in Helium", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let folder = newFolderName
                newFolderName = ""
                Task { await model.createNewFolder(name: folder) }
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Create a folder inside /Volumes/Helium (\(model.breadcrumbs.last?.name ?? "Root")).")
        }
    }

    private func sidebarNavButton(_ item: SidebarDestination, badgeText: String? = nil, badgeTinted: Bool = false) -> some View {
        let isSelected = model.selectedSidebarDestination == item
        return Button {
            withAnimation(HeliumSpring.snappy) {
                model.selectedSidebarDestination = item
            }
        } label: {
            HStack(spacing: 8) {
                HeliumAsset.icon(item.assetIcon, size: 15, tint: isSelected ? .white : .primary)
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badgeText {
                    Text(badgeText)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? Color.white.opacity(0.24)
                                    : (badgeTinted ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.14))
                            )
                        )
                        .foregroundStyle(isSelected ? .white : (badgeTinted ? .blue : .secondary))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header with Animated Helium Mascot
            HStack(spacing: 10) {
                HeliumAnimatedMascot(
                    name: model.isUploadsPaused ? "HeliumSleepy" : (model.activeUploadSpeedBytesPerSec > 0 ? "HeliumBusy" : "HeliumHappy"),
                    size: 38,
                    showAura: true
                )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("Helium")
                            .font(.headline.bold())
                        Text("POOL")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    Text(model.isMounted ? "/Volumes/Helium" : "Drive Disconnected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Drive")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                        sidebarNavButton(
                            .home,
                            badgeText: model.driveNodes.isEmpty ? nil : "\(model.driveNodes.count)"
                        )
                        sidebarNavButton(
                            .pool,
                            badgeText: "\(model.linkedAccounts.count)",
                            badgeTinted: true
                        )
                        sidebarNavButton(.search)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Preferences & Tour")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                        sidebarNavButton(.settings)
                        sidebarNavButton(.welcome)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            Divider()

            // Persistent Sidebar Google Account Pool Card & Sign-In Button
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("POOLED STORAGE")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.linkedAccounts.count) Drive\(model.linkedAccounts.count == 1 ? "" : "s")")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                }

                MultiAccountSegmentedBar(accounts: model.linkedAccounts, totalCapacity: model.totalPoolBytes)
                    .frame(height: 8)

                HStack {
                    Text("\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Pool")
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                SignInWithGoogleButton(
                    title: model.hasRealGoogleAccount ? "+ Link Google Drive" : "Sign in with Google",
                    style: .standard,
                    isLoading: model.isSigningInWithGoogle
                ) {
                    model.startBrowserOAuthFlow()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    CogifyBrandingView(compact: true)
                    Spacer()
                    Button {
                        model.showHelpSheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "questionmark.circle")
                            Text("Help")
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Open Helium Help Center")
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .frame(width: 224)
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            switch model.selectedSidebarDestination {
            case .home:
                OriginalHeliumHomeWorkspaceView(
                    model: model,
                    onNavigateToPool: {
                        withAnimation(HeliumSpring.fluid) { model.selectedSidebarDestination = .pool }
                    },
                    onNavigateToSettings: { tab in
                        model.selectedSettingsTab = tab
                        withAnimation(HeliumSpring.fluid) { model.selectedSidebarDestination = .settings }
                    },
                    onNavigateToSearch: {
                        withAnimation(HeliumSpring.fluid) { model.selectedSidebarDestination = .search }
                    }
                )
                .transition(.opacity)
            case .pool:
                GoogleDrivePoolWorkspaceView(model: model)
                    .transition(.opacity)
            case .search:
                OriginalSpotlightSearchView(model: model)
                    .transition(.opacity)
            case .settings:
                OriginalFiveTabSettingsView(model: model)
                    .transition(.opacity)
            case .welcome:
                OriginalWelcomeAndSignInView(model: model, allowDismissToHome: true) {
                    withAnimation(HeliumSpring.fluid) { model.selectedSidebarDestination = .home }
                }
                .transition(.opacity)
            }
        }
        .animation(HeliumSpring.fluid, value: model.selectedSidebarDestination)
    }
}

// MARK: - 1. More / Welcome & Sign-In Screen (SignInView + WelcomeView + Quick Action Buttons)
public struct OriginalWelcomeAndSignInView: View {
    @ObservedObject var model: AppModel
    public var allowDismissToHome: Bool = false
    public var onContinueToHome: (() -> Void)?

    public init(
        model: AppModel,
        allowDismissToHome: Bool = false,
        onContinueToHome: (() -> Void)? = nil
    ) {
        self.model = model
        self.allowDismissToHome = allowDismissToHome
        self.onContinueToHome = onContinueToHome
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Mascot & Headline
                VStack(spacing: 12) {
                    HeliumAnimatedMascot(name: "HeliumHappy", size: 96, showAura: true)

                    Text("Welcome to Helium")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("More space for your Mac, without buying a new Mac.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Three Signature Helium Feature Cards
                HeliumGlassCard(cornerRadius: 16, padding: 20, interactiveHover: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        WelcomeFeatureRow(
                            iconName: "folder-cloud",
                            title: "A drive called Helium",
                            subtitle: "It sits in Finder at /Volumes/Helium next to your Mac's own disk. Move files in like anywhere else."
                        )
                        WelcomeFeatureRow(
                            iconName: "flash",
                            title: "Takes no space on your Mac",
                            subtitle: "Your files live safely across your pooled Google Drives. Finder shows them all, using zero local disk bytes."
                        )
                        WelcomeFeatureRow(
                            iconName: "download",
                            title: "Still opens instantly",
                            subtitle: "Double-click any file, even a huge 4K video, and it streams right away with smart caching and optional AES-256-GCM encryption."
                        )
                    }
                    .frame(maxWidth: 520)
                }

                // Primary Google Sign-In Placement Card
                HeliumGlassCard(cornerRadius: 16, padding: 22, interactiveHover: true, accentTint: .blue) {
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            GoogleLogoBadge(size: 20)
                            Text("Combine Multiple Google Drives into One Unified Volume")
                                .font(.headline)
                        }

                        Text("Sign in with one or more Google accounts. Helium pools their free storage together and automatically uses Smart Whole-File Placement and Cross-Account Striping.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 480)

                        HStack(spacing: 14) {
                            SignInWithGoogleButton(
                                title: model.hasRealGoogleAccount ? "Link Another Google Account" : "Sign in with Google",
                                subtitle: "Connect your Google Drive storage",
                                style: .hero,
                                isLoading: model.isSigningInWithGoogle
                            ) {
                                model.startBrowserOAuthFlow()
                            }

                            if !model.linkedAccounts.isEmpty {
                                Button {
                                    withAnimation(HeliumSpring.fluid) {
                                        model.phase = .active
                                    }
                                    onContinueToHome?()
                                } label: {
                                    Label("Open Helium Drive (\(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file)))", systemImage: "arrow.right.circle.fill")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                        }

                        // Show currently linked Google accounts right on the sign-in card
                        if !model.linkedAccounts.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Connected Google Drives (\(model.linkedAccounts.count))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Total Pool: \(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file))")
                                        .font(.caption.bold())
                                }

                                ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(HeliumAsset.colorForAccount(at: idx))
                                            .frame(width: 8, height: 8)
                                        Text(acc.email)
                                            .font(.caption.bold())
                                        Text("Connected")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.2))
                                            .clipShape(Capsule())
                                        Spacer()
                                        Text("\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: 480)
                        }
                    }
                }

                // Clean Action Buttons Grid in More
                HeliumGlassCard(cornerRadius: 16, padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            Button {
                                model.openInFinder()
                            } label: {
                                Label("Open in Finder", systemImage: "folder.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                model.openGoogleDriveVaultInBrowser()
                            } label: {
                                Label("Google Drive Web", systemImage: "safari.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                model.showTrashSheet = true
                            } label: {
                                Label("30-Day Trash (\(model.trashedItems.count))", systemImage: "arrow.uturn.backward.circle.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                model.showCrossDeviceSheet = true
                            } label: {
                                Label("Open on Any Device", systemImage: "laptopcomputer.and.iphone")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                model.showStartupPreferencesPrompt = true
                            } label: {
                                Label("Bootup & Taskbar", systemImage: "menubar.rectangle")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                model.showFeedbackSheet = true
                            } label: {
                                Label("Email Support", systemImage: "envelope.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: 520)
                }

                HStack(spacing: 16) {
                    CogifyBrandingView()
                    Text("•")
                        .foregroundStyle(.secondary)
                    Button("Helium Help Center") {
                        model.showHelpSheet = true
                    }
                    .buttonStyle(.link)
                    .font(.caption.bold())
                }
                .padding(.top, 4)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
    }
}

struct WelcomeFeatureRow: View {
    let iconName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                HeliumAsset.icon(iconName, size: 20, tint: .blue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 2. Helium Home Workspace (HomeView Card + Live Drive Explorer)
struct OriginalHeliumHomeWorkspaceView: View {
    @ObservedObject var model: AppModel
    var onNavigateToPool: () -> Void
    var onNavigateToSettings: (SettingsTab) -> Void
    var onNavigateToSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Google Sign-In & Multi-Drive Pool Banner (Prominent Placement)
                GooglePoolTopBanner(
                    model: model,
                    onManagePool: onNavigateToPool
                )

                // Helium-Style Offline Keep Download Progress Card ("Downloading X of Y — To keep on this Mac, as you chose.")
                if model.isDownloadingOfflineKeep {
                    OfflineKeepDownloadProgressBanner(model: model)
                }

                // Conditional Helium Alert Rows
                if model.isAlmostFull {
                    OriginalAlertBannerRow(
                        icon: "HeliumWorried",
                        title: "Helium is almost full",
                        subtitle: "Less than 10% of your combined Google Drive pool is left. Link another Google account to add +15 GB immediately.",
                        tint: .orange,
                        buttonTitle: "+ Sign in with Google",
                        action: { model.startBrowserOAuthFlow() }
                    )
                }

                if model.recoveryKeyInsideDriveWarning {
                    OriginalAlertBannerRow(
                        icon: "key",
                        title: "Your recovery key is inside Helium",
                        subtitle: "Move it onto this Mac or into Passwords so you still have it if you're ever locked out.",
                        tint: .red,
                        buttonTitle: "Save Outside Helium…",
                        action: { model.saveRecoveryKeyToDisk() }
                    )
                } else if !model.recoveryKeySavedConfirmation {
                    OriginalAlertBannerRow(
                        icon: "key",
                        title: "Save your recovery key",
                        subtitle: "Your way back to your files if you ever lose this Mac.",
                        tint: .blue,
                        buttonTitle: "View & Save Key",
                        action: { model.showRecoveryKeySheet = true }
                    )
                }

                if model.showAllowDevicePrompt {
                    AllowDeviceVerificationCard(model: model)
                }

                // Responsive Workspace Layout: Side-by-Side when wide, Stacked when narrower
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        OriginalHeliumHomeCard(
                            model: model,
                            onOpenSearch: onNavigateToSearch,
                            onOpenSettings: { onNavigateToSettings(.general) }
                        )
                        .frame(width: 294)

                        LiveVolumeFilesAndSegmentsCard(
                            model: model,
                            onManagePool: onNavigateToPool
                        )
                        .frame(minWidth: 460, maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        OriginalHeliumHomeCard(
                            model: model,
                            onOpenSearch: onNavigateToSearch,
                            onOpenSettings: { onNavigateToSettings(.general) }
                        )
                        .frame(maxWidth: .infinity)

                        LiveVolumeFilesAndSegmentsCard(
                            model: model,
                            onManagePool: onNavigateToPool
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct OfflineKeepDownloadProgressBanner: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let downloadedStr = ByteCountFormatter.string(fromByteCount: model.offlineKeepDownloadedBytes, countStyle: .file)
        let totalStr = ByteCountFormatter.string(fromByteCount: model.offlineKeepTotalBytes, countStyle: .file)
        let fraction = model.offlineKeepTotalBytes > 0
            ? min(1.0, max(0.02, Double(model.offlineKeepDownloadedBytes) / Double(model.offlineKeepTotalBytes)))
            : 0.0

        HeliumGlassCard(cornerRadius: 14, padding: 14, accentTint: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.88))
                            .frame(width: 30, height: 30)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Downloading \(downloadedStr) of \(totalStr)")
                            .font(.subheadline.bold())
                        Text("To keep on this Mac, as you chose.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Free Up Space") {
                        model.unpinAllInCurrentFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.20))
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: max(8, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

struct GooglePoolTopBanner: View {
    @ObservedObject var model: AppModel
    var onManagePool: () -> Void

    var body: some View {
        HeliumGlassCard(cornerRadius: 14, padding: 14, interactiveHover: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    HeliumAnimatedMascot(
                        name: model.hasRealGoogleAccount ? "HeliumLove" : "HeliumHappy",
                        size: 46,
                        showAura: true
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Unified Google Drive Storage Pool")
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(model.linkedAccounts.count) Drive\(model.linkedAccounts.count == 1 ? "" : "s") Linked")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                                .fixedSize()
                            if model.zeroKnowledgeEnabled {
                                Label("Zero-Knowledge E2EE", systemImage: "lock.shield.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .fixedSize()
                            } else {
                                Label("Direct Vault Mode", systemImage: "externaldrive.fill.badge.icloud")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                    .fixedSize()
                            }
                        }

                        MultiAccountSegmentedBar(accounts: model.linkedAccounts, totalCapacity: model.totalPoolBytes)
                            .frame(height: 8)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 5) {
                        SignInWithGoogleButton(
                            title: model.hasRealGoogleAccount ? "+ Add Google Drive" : "Sign in with Google",
                            style: .standard,
                            isLoading: model.isSigningInWithGoogle
                        ) {
                            model.startBrowserOAuthFlow()
                        }

                        HStack(spacing: 10) {
                            Button("View in Google Drive") {
                                model.openGoogleDriveVaultInBrowser()
                            }
                            .buttonStyle(.link)
                            .font(.caption)

                            Button("Manage Pool →") {
                                onManagePool()
                            }
                            .buttonStyle(.link)
                            .font(.caption.bold())
                        }
                    }
                    .fixedSize()
                }

                HStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                                Button {
                                    model.openGoogleDriveVaultInBrowser(for: acc)
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(HeliumAsset.colorForAccount(at: idx))
                                            .frame(width: 7, height: 7)
                                        Text(acc.email)
                                            .font(.caption2.bold())
                                            .fixedSize()
                                        Text("(\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize()
                                    }
                                }
                                .buttonStyle(.plain)
                                .help("Click to open \(acc.email)'s Helium Pool Vault in Google Drive")
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    Text("\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Helium (\(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file))) • 0 B on Mac")
                        .font(.caption.monospacedDigit().bold())
                        .fixedSize()
                }
            }
        }
    }
}

struct MultiAccountSegmentedBar: View {
    let accounts: [LinkedGoogleAccount]
    let totalCapacity: Int64

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))

                HStack(spacing: 2) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, acc in
                        let effectiveUsed = max(acc.heliumUsedBytes, acc.quotaUsedBytes)
                        if effectiveUsed > 0 {
                            let fraction = totalCapacity > 0
                                ? max(0.012, Double(effectiveUsed) / Double(totalCapacity))
                                : 0
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            HeliumAsset.colorForAccount(at: idx),
                                            HeliumAsset.colorForAccount(at: idx).opacity(0.82)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: max(4, geo.size.width * fraction))
                                .help("\(acc.email): \(ByteCountFormatter.string(fromByteCount: acc.heliumUsedBytes, countStyle: .file)) in Helium Pool (\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: acc.quotaLimitBytes, countStyle: .file)))")
                        }
                    }
                }
                .clipShape(Capsule())
                .animation(HeliumSpring.fluid, value: accounts.map(\.heliumUsedBytes))
                .animation(HeliumSpring.fluid, value: accounts.map(\.quotaUsedBytes))
            }
        }
    }
}

struct OriginalAlertBannerRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HeliumAsset.icon(icon, size: 22, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

struct AllowDeviceVerificationCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            HeliumAsset.icon("lock", size: 28, tint: .blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Allow this device?")
                    .font(.headline)
                Text("Another Mac is signing in to your Helium Google Drive pool. Do these numbers match the ones on that device?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.allowDeviceCode)
                .font(.system(.title3, design: .monospaced).bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("Allow") {
                model.showAllowDevicePrompt = false
                model.statusMessage = "Approved new device and shared zero-knowledge vault key via P-256 ECDH."
            }
            .buttonStyle(.borderedProminent)
            Button("Don't Allow") {
                model.showAllowDevicePrompt = false
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct HeaderActionIconButton: View {
    let iconName: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.blue.opacity(0.16) : Color.primary.opacity(0.05))
                HeliumAsset.icon(iconName, size: 15, tint: isHovered ? .blue : nil)
            }
            .frame(width: 30, height: 30)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(HeliumPressableButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help(tooltip)
    }
}

// MARK: - Simpler & Unique Helium Magnetic Levitation Drop Portal Card
struct OriginalHeliumHomeCard: View {
    @ObservedObject var model: AppModel
    var onOpenSearch: () -> Void
    var onOpenSettings: () -> Void
    @State private var isDropTargeted: Bool = false
    @State private var isPortalHovered: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showRoutingOptions: Bool = false
    @State private var orbitPulse: Bool = false

    private var activeDestinationName: String {
        if model.selectedFolderId == RemoteItem.rootID {
            return "/Volumes/Helium"
        }
        return model.foldersInDrive.first(where: { ($0.remoteID ?? $0.name) == model.selectedFolderId })?.name ?? "/Volumes/Helium"
    }

    var body: some View {
        HeliumGlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Clean Header Bar
                HStack(spacing: 8) {
                    HeliumAsset.icon(
                        model.isUploadsPaused ? "MenuBarIconSleepy" : "MenuBarIconHappy",
                        size: 22
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Helium")
                            .font(.headline.bold())
                        Text("\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Pool • \(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free • 0 B on Mac")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HeaderActionIconButton(
                        iconName: "folder",
                        tooltip: "Open /Volumes/Helium in Finder"
                    ) {
                        model.openInFinder()
                    }

                    HeaderActionIconButton(
                        iconName: "search",
                        tooltip: "Search files in Helium (⇧⌘F)"
                    ) {
                        onOpenSearch()
                    }

                    HeaderActionIconButton(
                        iconName: "settings",
                        tooltip: "Open Helium Settings"
                    ) {
                        onOpenSettings()
                    }
                }

                // Unique Magnetic Levitation Drop Portal
                ZStack {
                    // Ambient Radial Levitation Glow
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isDropTargeted
                                    ? [Color.blue.opacity(0.24), Color.indigo.opacity(0.18)]
                                    : (isPortalHovered
                                        ? [Color.blue.opacity(0.11), Color.cyan.opacity(0.06)]
                                        : [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Concentric Orbital Levitation Rings
                    ZStack {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(isDropTargeted ? 0.55 : 0.16),
                                        Color.cyan.opacity(isDropTargeted ? 0.35 : 0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.0 : 1.0, dash: [8, 6])
                            )
                            .frame(width: isDropTargeted ? 168 : 148, height: isDropTargeted ? 168 : 148)
                            .scaleEffect(orbitPulse ? 1.04 : 0.96)

                        Circle()
                            .strokeBorder(
                                Color.blue.opacity(isDropTargeted ? 0.40 : 0.10),
                                lineWidth: 1.2
                            )
                            .frame(width: isDropTargeted ? 116 : 104, height: isDropTargeted ? 116 : 104)
                    }
                    .offset(y: -14)
                    .allowsHitTesting(false)

                    VStack(spacing: 12) {
                        // Top Destination & Finder Status Pill inside Portal
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Menu {
                                Button("Helium Root (/Volumes/Helium)") {
                                    model.selectedFolderId = RemoteItem.rootID
                                }
                                if !model.foldersInDrive.isEmpty {
                                    Divider()
                                    ForEach(model.foldersInDrive) { folder in
                                        Button("Folder: /\(folder.name)") {
                                            model.selectedFolderId = folder.remoteID ?? folder.name
                                        }
                                    }
                                }
                                Divider()
                                Button("Open /Volumes/Helium in Finder") {
                                    model.openInFinder()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Into \(activeDestinationName)")
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))

                        // Floating Helium Mascot Core
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.blue.opacity(isDropTargeted ? 0.35 : 0.16),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 44
                                    )
                                )
                                .frame(width: 82, height: 82)

                            HeliumAnimatedMascot(
                                name: isDropTargeted ? "HeliumSurprised" : "HeliumHappy",
                                size: isDropTargeted ? 62 : 54,
                                showAura: true
                            )
                        }
                        .onTapGesture {
                            showFileImporter = true
                        }

                        VStack(spacing: 3) {
                            Text(isDropTargeted ? "Release to Levitate into Helium" : "Drop Anything into Helium")
                                .font(.system(.subheadline, design: .rounded).bold())
                            Text("Takes 0 B on your Mac • Opens instantly in any app")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        // Simple 2-Pill Action Bar
                        HStack(spacing: 8) {
                            Button {
                                showFileImporter = true
                            } label: {
                                Label("Add Files", systemImage: "plus.circle.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .clipShape(Capsule())

                            Button {
                                model.uploadClipboardToHelium()
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .clipShape(Capsule())
                            .help("Paste copied files, screenshots, or text from clipboard (⇧⌘V)")

                            Button {
                                model.openInFinder()
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .clipShape(Capsule())
                            .help("Open /Volumes/Helium in Finder")
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isDropTargeted
                                ? Color.blue
                                : (isPortalHovered ? Color.blue.opacity(0.45) : Color.blue.opacity(0.20)),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2.2 : 1.2, dash: isDropTargeted ? [] : [7, 5])
                        )
                )
                .scaleEffect(isDropTargeted ? 1.02 : 1.0)
                .animation(HeliumSpring.bouncy, value: isDropTargeted)
                .onHover { hovering in
                    withAnimation(HeliumSpring.snappy) {
                        isPortalHovered = hovering
                        orbitPulse = hovering
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDroppedProviders(providers)
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: true
                ) { result in
                    if case .success(let urls) = result {
                        Task { await model.importExternalFiles(urls, targetFolderId: model.selectedFolderId) }
                    }
                }

                // Compact Single-Row Smart Routing Pill (Collapsible for Simplicity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Menu {
                            Section("Upload Priority Target") {
                                Button {
                                    Task { await model.setPreferredUploadAccount(nil) }
                                    Task { await model.setAccountRoutingStrategy(.priorityOrder) }
                                } label: {
                                    Label("Priority Order (#1 → #2 → …)", systemImage: "list.number")
                                }
                                Button {
                                    Task { await model.setPreferredUploadAccount(nil) }
                                    Task { await model.setAccountRoutingStrategy(.mostFreeSpace) }
                                } label: {
                                    Label("Most Free Space First", systemImage: "chart.bar.fill")
                                }
                                ForEach(model.linkedAccounts) { acc in
                                    Button {
                                        Task {
                                            await model.prioritiseAccountFirst(acc.id)
                                            await model.setPreferredUploadAccount(acc.id)
                                        }
                                    } label: {
                                        Text("Pin #1: \(acc.email) (\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free)")
                                    }
                                }
                            }
                            Section("Storage Pool Placement Engine") {
                                Button("Both (Smart Whole-File + Auto Striping)") {
                                    Task { await model.updateAllocatorPolicy(.automatic) }
                                }
                                Button("Mode 1: Whole-File Smart Placement") {
                                    Task { await model.updateAllocatorPolicy(.preferWholeFile) }
                                }
                                Button("Mode 2: Always Cross-Account Striping") {
                                    Task { await model.updateAllocatorPolicy(.alwaysStripe) }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("Target: \(model.primaryUploadTargetAccount?.email ?? "Auto Pool")")
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(model.placementPolicy == .automatic ? "Smart Pool" : (model.placementPolicy == .preferWholeFile ? "Whole-File" : "Striped"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)

                        FeatureHelpPopoverButton(topic: .placementEngine) {
                            model.showHelpSheet = true
                        }
                    }

                    // 30-Day Undo Delete Quick Pill when trashed items exist
                    if let latestTrashed = model.trashedItems.first {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Deleted '\(latestTrashed.fileName)' (\(latestTrashed.daysRemaining)d left)")
                                .font(.caption2.bold())
                                .lineLimit(1)
                            Spacer()
                            Button("Undo") {
                                model.undoLastDelete()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.mini)

                            Button("Trash (\(model.trashedItems.count))") {
                                model.showTrashSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }
                }

                // Original UploadCard / Activity List
                if !model.uploadActivities.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent Transfers")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            if model.activeUploadSpeedBytesPerSec > 0 {
                                Text("\(ByteCountFormatter.string(fromByteCount: model.activeUploadSpeedBytesPerSec, countStyle: .file))/s")
                                    .font(.caption2.monospacedDigit().bold())
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            if model.uploadActivities.contains(where: \.isCompleted) {
                                Button("Clear") {
                                    model.clearCompletedUploads()
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                            Button(model.isUploadsPaused ? "Resume" : "Pause") {
                                model.isUploadsPaused.toggle()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }

                        ForEach(model.uploadActivities.prefix(4)) { act in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    HeliumAsset.icon(
                                        act.errorText != nil ? "warning" : (act.isCompleted ? "check-circle" : "upload"),
                                        size: 13,
                                        tint: act.errorText != nil ? .orange : (act.isCompleted ? .green : .blue)
                                    )
                                    Text(act.fileName)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Spacer()
                                    if act.errorText != nil {
                                        Button("Retry") {
                                            Task { await model.retryUpload(act) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                    Text(act.byteProgressLabel)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                if !act.isCompleted && act.errorText == nil {
                                    ProgressView(value: act.fractionCompleted)
                                        .controlSize(.small)
                                }
                                Text("\(act.placementSummary) • \(act.timeRemainingLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(act.errorText != nil ? .orange : .secondary)
                            }
                            .padding(8)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else {
                    resolvedURL = nil
                }
                if let fileURL = resolvedURL {
                    Task { @MainActor in
                        await model.importExternalFiles([fileURL], targetFolderId: model.selectedFolderId)
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Finder-Style Files Manager Card (/Volumes/Helium)
struct LiveVolumeFilesAndSegmentsCard: View {
    @ObservedObject var model: AppModel
    var onManagePool: () -> Void
    @State private var showFileRequestSheet: Bool = false
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showEmptyFileImporter: Bool = false
    @State private var fileRequestFolderName: String = "Shared Drops"
    @State private var fileRequestTitle: String = ""
    @State private var nodePendingRename: DriveNode?
    @State private var renameInputText: String = ""
    @State private var showQuickNoteAlert: Bool = false
    @State private var quickNoteTitle: String = ""
    @State private var quickNoteBody: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var selectedAccountFilterId: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredNodes: [DriveNode] {
        let base = model.displayedNodes
        guard !selectedAccountFilterId.isEmpty else { return base }
        return base.filter { node in
            if node.isFolder { return true }
            guard let remID = node.remoteID, let manifest = model.manifests[remID] else { return true }
            return manifest.segments.contains(where: { $0.accountId == selectedAccountFilterId })
        }
    }

    var body: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Finder Header & Primary Action Bar (With Search Button + Inline Search Field)
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "externaldrive.fill.badge.icloud")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("Files Manager")
                        .font(.headline)
                        .fixedSize()

                    Text("0 B on Mac")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                        .fixedSize()

                    Spacer(minLength: 6)

                    // Inline Finder Search Bar + Search Button
                    HStack(spacing: 5) {
                        Button {
                            if model.localFolderFilterQuery.isEmpty && !isSearchFieldFocused {
                                isSearchFieldFocused = true
                            } else {
                                model.selectedSidebarDestination = .search
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Search files in folder or open Spotlight Search (⌃⌥O)")

                        TextField("Search files…", text: $model.localFolderFilterQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .focused($isSearchFieldFocused)
                            .frame(minWidth: 95, maxWidth: 150)

                        if !model.localFolderFilterQuery.isEmpty {
                            Button {
                                model.localFolderFilterQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(isSearchFieldFocused ? Color.blue.opacity(0.55) : Color.secondary.opacity(0.18), lineWidth: 1)
                    )

                    Button {
                        model.selectedSidebarDestination = .search
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                    .help("Open Global Pool Search (⌃⌥O)")
                }

                // Finder Toolbar: Breadcrumbs on Left, Folder Actions & View Controls on Right
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if model.breadcrumbs.count > 1 {
                            Button {
                                model.navigateUpFolder()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Back to parent folder")
                        }

                        // Folder Breadcrumb Path
                        HStack(spacing: 4) {
                            ForEach(Array(model.breadcrumbs.enumerated()), id: \.element.id) { idx, crumb in
                                if idx > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    model.navigateToBreadcrumb(crumb)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: idx == 0 ? "externaldrive.fill" : "folder.fill")
                                            .font(.caption2)
                                        Text(crumb.name)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        idx == model.breadcrumbs.count - 1
                                            ? Color.blue.opacity(0.16)
                                            : Color(nsColor: .windowBackgroundColor)
                                    )
                                    .foregroundStyle(idx == model.breadcrumbs.count - 1 ? .blue : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 8)

                        Button {
                            showNewFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        .controlSize(.small)
                        .fixedSize()

                        Button {
                            showEmptyFileImporter = true
                        } label: {
                            Label("Add Files", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .fixedSize()

                        Button {
                            Task { await model.syncWithGoogleDrive() }
                        } label: {
                            Label(model.isSyncingPool ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .controlSize(.small)
                        .disabled(model.isSyncingPool)
                        .fixedSize()

                        Button {
                            model.openInFinder()
                        } label: {
                            Label("Finder", systemImage: "folder")
                        }
                        .controlSize(.small)
                        .fixedSize()
                        .help("Open /Volumes/Helium in macOS Finder")

                        // Sort Menu
                        Menu {
                            ForEach(FileSortOrder.allCases) { order in
                                Button {
                                    model.setFileSortOrder(order)
                                } label: {
                                    HStack {
                                        Text("Sort by \(order.rawValue)")
                                        if model.fileSortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(model.fileSortOrder.rawValue, systemImage: "arrow.up.arrow.down")
                                .font(.caption)
                        }
                        .controlSize(.small)
                        .fixedSize()

                        // List vs Grid Layout Toggle
                        Picker("", selection: Binding(
                            get: { model.fileViewLayout },
                            set: { model.setFileViewLayout($0) }
                        )) {
                            Image(systemName: "list.bullet").tag(FileViewLayout.list)
                            Image(systemName: "square.grid.2x2").tag(FileViewLayout.grid)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 62)
                        .controlSize(.small)

                        // More Actions (⋯) Menu
                        Menu {
                            Section("Offline Access (Keep on this Mac)") {
                                Button {
                                    model.pinAllInCurrentFolder()
                                } label: {
                                    Label("Keep Folder on this Mac", systemImage: "arrow.down.circle.fill")
                                }

                                Button {
                                    model.unpinAllInCurrentFolder()
                                } label: {
                                    Label("Free Up Space (0 B on Disk)", systemImage: "icloud.slash")
                                }
                            }

                            Section("Cloud & Sharing") {
                                Button {
                                    model.openGoogleDriveVaultInBrowser()
                                } label: {
                                    Label("Open in Google Drive Web", systemImage: "safari")
                                }

                                Button {
                                    showFileRequestSheet = true
                                } label: {
                                    Label("Request Files into This Folder…", systemImage: "tray.and.arrow.down.fill")
                                }

                                Button {
                                    model.showTrashSheet = true
                                } label: {
                                    Label(
                                        model.trashedItems.isEmpty ? "30-Day Undo Trash…" : "30-Day Undo Trash (\(model.trashedItems.count))…",
                                        systemImage: "arrow.uturn.backward.circle"
                                    )
                                }
                            }

                            Section("Quick Create & Clipboard") {
                                Button {
                                    model.uploadClipboardToHelium()
                                } label: {
                                    Label("Paste Clipboard into Helium (⇧⌘V)", systemImage: "doc.on.clipboard")
                                }

                                Button {
                                    quickNoteTitle = ""
                                    quickNoteBody = ""
                                    showQuickNoteAlert = true
                                } label: {
                                    Label("New Quick Markdown Note…", systemImage: "note.text.badge.plus")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .controlSize(.small)
                        .fixedSize()
                        .help("More Folder Actions")
                    }
                }

                // Filter Pills Row (Type Filters + Account Filter when multiple drives are linked)
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(FileFilterMode.allCases) { mode in
                                Button {
                                    withAnimation(HeliumSpring.snappy) {
                                        model.fileFilterMode = mode
                                    }
                                } label: {
                                    Text(mode.rawValue)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            model.fileFilterMode == mode
                                                ? Color.blue
                                                : Color(nsColor: .windowBackgroundColor)
                                        )
                                        .foregroundStyle(model.fileFilterMode == mode ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(HeliumPressableButtonStyle())
                                .fixedSize(horizontal: true, vertical: false)
                            }

                            if model.linkedAccounts.count > 1 {
                                Divider()
                                    .frame(height: 14)

                                Button {
                                    withAnimation(HeliumSpring.snappy) {
                                        selectedAccountFilterId = ""
                                    }
                                } label: {
                                    Text("All Drives")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(
                                            selectedAccountFilterId.isEmpty
                                                ? Color.indigo.opacity(0.18)
                                                : Color(nsColor: .windowBackgroundColor)
                                        )
                                        .foregroundStyle(selectedAccountFilterId.isEmpty ? .indigo : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                                    let isSelected = selectedAccountFilterId == acc.id
                                    let shortEmail = acc.email.components(separatedBy: "@").first ?? acc.email
                                    Button {
                                        withAnimation(HeliumSpring.snappy) {
                                            selectedAccountFilterId = isSelected ? "" : acc.id
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(HeliumAsset.colorForAccount(at: idx))
                                                .frame(width: 6, height: 6)
                                            Text(shortEmail)
                                                .font(.caption2.bold())
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(
                                            isSelected
                                                ? HeliumAsset.colorForAccount(at: idx).opacity(0.20)
                                                : Color(nsColor: .windowBackgroundColor)
                                        )
                                        .foregroundStyle(isSelected ? .primary : .secondary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    Text("\(filteredNodes.count) item\(filteredNodes.count == 1 ? "" : "s")")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                if filteredNodes.isEmpty {
                    VStack(spacing: 12) {
                        HeliumAnimatedMascot(name: "HeliumWink", size: 64)
                        Text(model.driveNodes.isEmpty ? "Your Helium Drive is Ready" : "No Matching Items")
                            .font(.headline)
                        Text(model.driveNodes.isEmpty
                             ? "Drag and drop files here or directly into Helium in Finder. Every file you add is automatically uploaded to your linked Google Drive storage pool."
                             : "Try clearing your search or filter pills above, or drop new files into this folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)

                        HStack(spacing: 10) {
                            if model.fileFilterMode != .all || !model.localFolderFilterQuery.isEmpty || !selectedAccountFilterId.isEmpty {
                                Button("Show All Items") {
                                    withAnimation(HeliumSpring.snappy) {
                                        model.fileFilterMode = .all
                                        model.localFolderFilterQuery = ""
                                        selectedAccountFilterId = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Add Files…") {
                                    showEmptyFileImporter = true
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Open in Finder") {
                                    model.openInFinder()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if model.fileViewLayout == .list {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredNodes) { node in
                            DriveNodeRowView(
                                model: model,
                                node: node,
                                onRequestRename: { target in
                                    nodePendingRename = target
                                    renameInputText = target.name
                                }
                            )
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 195), spacing: 10)], spacing: 10) {
                        ForEach(filteredNodes) { node in
                            DriveNodeGridCardView(
                                model: model,
                                node: node,
                                onRequestRename: { target in
                                    nodePendingRename = target
                                    renameInputText = target.name
                                }
                            )
                        }
                    }
                }

                // Active Share Links & File Requests Section
                if !model.shareLinks.isEmpty || !model.fileRequests.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Share Links & Encrypted File Requests")
                            .font(.subheadline.bold())

                        ForEach(model.shareLinks) { share in
                            HStack {
                                HeliumAsset.icon("external", size: 14, tint: .blue)
                                Text(share.itemName)
                                    .font(.caption.bold())
                                Text(share.urlString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button("Copy Link") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(share.urlString, forType: .string)
                                    model.statusMessage = "Copied share link to clipboard"
                                }
                                .controlSize(.mini)
                                Button("Turn Off Link") {
                                    model.revokeShareLink(id: share.id)
                                }
                                .controlSize(.mini)
                            }
                        }

                        ForEach(model.fileRequests) { req in
                            HStack {
                                HeliumAsset.icon("folder-add", size: 14, tint: .purple)
                                Text("\(req.title) → /\(req.folderName)")
                                    .font(.caption.bold())
                                Text("\(req.urlString) (P-256 key: \(req.publicKeyHex)…)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button("Copy Request Link") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(req.urlString, forType: .string)
                                }
                                .controlSize(.mini)
                                Button("Close") {
                                    model.closeFileRequest(id: req.id)
                                }
                                .controlSize(.mini)
                            }
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard !providers.isEmpty else { return false }
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let resolvedURL: URL?
                    if let data = item as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        resolvedURL = url
                    } else {
                        resolvedURL = nil
                    }
                    if let fileURL = resolvedURL {
                        Task { @MainActor in
                            await model.importExternalFiles([fileURL], targetFolderId: model.selectedFolderId)
                        }
                    }
                }
            }
            return true
        }
        .fileImporter(
            isPresented: $showEmptyFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await model.importExternalFiles(urls, targetFolderId: model.selectedFolderId) }
            }
        }
        .alert("Request Files into Helium", isPresented: $showFileRequestSheet) {
            TextField("Folder name", text: $fileRequestFolderName)
            TextField("Request title (optional)", text: $fileRequestTitle)
            Button("Create & Copy Link") {
                model.createFileRequest(folderName: fileRequestFolderName, title: fileRequestTitle)
                fileRequestTitle = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone with the link can upload files directly into this folder, encrypted with an ephemeral P-256 public key.")
        }
        .alert(
            "Rename Item",
            isPresented: Binding(
                get: { nodePendingRename != nil },
                set: { if !$0 { nodePendingRename = nil } }
            )
        ) {
            TextField("New name", text: $renameInputText)
            Button("Rename") {
                if let target = nodePendingRename {
                    let newName = renameInputText
                    nodePendingRename = nil
                    Task { await model.renameNode(target, newName: newName) }
                }
            }
            Button("Cancel", role: .cancel) {
                nodePendingRename = nil
            }
        } message: {
            Text("Renames the item in Helium, your local Finder volume, and your linked Google Drive.")
        }
        .alert("New Folder in Helium", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let folder = newFolderName
                newFolderName = ""
                Task { await model.createNewFolder(name: folder) }
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Create a folder inside /Volumes/Helium (\(model.breadcrumbs.last?.name ?? "Root")).")
        }
        .alert("New Quick Markdown Note", isPresented: $showQuickNoteAlert) {
            TextField("File name (e.g. Project Ideas.md)", text: $quickNoteTitle)
            TextField("Note content", text: $quickNoteBody)
            Button("Create & Upload") {
                let name = quickNoteTitle
                let body = quickNoteBody.isEmpty ? "# \(name.isEmpty ? "Quick Note" : name)\n\nCreated in Helium Drive." : quickNoteBody
                quickNoteTitle = ""
                quickNoteBody = ""
                Task { await model.createQuickTextFile(name: name, content: body) }
            }
            Button("Cancel", role: .cancel) {
                quickNoteTitle = ""
                quickNoteBody = ""
            }
        } message: {
            Text("Creates a Markdown file inside /Volumes/Helium (\(model.breadcrumbs.last?.name ?? "Root")) and syncs it to your Google Drive pool.")
        }
    }
}

struct DriveNodeRowView: View {
    @ObservedObject var model: AppModel
    let node: DriveNode
    var onRequestRename: (DriveNode) -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        let iconSpec = HeliumAsset.fileIconAndColor(for: node.name, isFolder: node.isFolder)
        let isPinned = model.isNodePinned(node)
        let isStarred = model.isNodeStarred(node)
        let canonical = node.name.precomposedStringWithCanonicalMapping
        let pinnedProgressBytes = model.offlinePinProgressByName[canonical]
        let currentAccountId: String? = {
            guard let remID = node.remoteID, let manifest = model.manifests[remID], manifest.segments.count == 1 else {
                return nil
            }
            return manifest.segments.first?.accountId
        }()
        let hostAccountEmail: String? = {
            guard let accId = currentAccountId else { return nil }
            return model.linkedAccounts.first(where: { $0.id == accId })?.email
        }()

        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconSpec.color.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: iconSpec.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconSpec.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(node.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if isStarred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if isPinned {
                        Label("Kept on Mac", systemImage: "checkmark.circle.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.teal.opacity(0.18))
                            .foregroundStyle(.teal)
                            .clipShape(Capsule())
                            .fixedSize()
                    } else if !node.isFolder {
                        Text("0 B on disk")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.14))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }
                if node.isFolder {
                    Text("Folder • Double-click to browse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if isPinned, let dl = pinnedProgressBytes, dl < node.size {
                    Text("\(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file)) • Downloading \(ByteCountFormatter.string(fromByteCount: dl, countStyle: .file)) to keep on Mac…")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 5) {
                        Text("\(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file)) • \(isPinned ? "Kept on this Mac" : "Zero bytes on disk")")
                        if let hostAccountEmail {
                            Text("• \(hostAccountEmail)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .frame(minWidth: 90, alignment: .leading)

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                if node.isFolder {
                    Button("Open") {
                        model.openFolder(node)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize()
                } else {
                    Button("Open") {
                        model.openNodeOnMac(node)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                }

                Button {
                    model.toggleStarNode(node)
                } label: {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .foregroundStyle(isStarred ? .yellow : .primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help(isStarred ? "Remove from ★ Starred" : "Add to ★ Starred")

                Button {
                    model.togglePinNode(node)
                } label: {
                    Image(systemName: isPinned ? "pin.slash.fill" : "pin")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help(isPinned ? "Free up space (0 B on disk)" : "Keep on this Mac (use without Wi-Fi)")

                Menu {
                    nodeActionMenuItems(isPinned: isPinned, currentAccountId: currentAccountId)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                            .frame(width: 28, height: 24)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 28, height: 24)
                .help("More Actions")
            }
            .fixedSize()
            .layoutPriority(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.blue.opacity(0.06) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color.blue.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(HeliumSpring.snappy) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            model.openNodeOnMac(node)
        }
        .contextMenu {
            nodeActionMenuItems(isPinned: isPinned, currentAccountId: currentAccountId)
        }
    }

    @ViewBuilder
    private func nodeActionMenuItems(isPinned: Bool, currentAccountId: String?) -> some View {
        Button(node.isFolder ? "Open Folder" : "Open on Mac") {
            model.openNodeOnMac(node)
        }
        Button("Reveal in Finder") {
            model.revealNodeInFinder(node)
        }
        Button("Open in Google Drive") {
            model.openNodeInGoogleDrive(node)
        }
        if !node.isFolder {
            Menu("Edit / Stream in Video & Creative Apps") {
                ForEach([ProExternalApp.finalCutPro, .davinciResolve, .capCut, .quickTime]) { app in
                    Button {
                        model.openNodeInExternalApp(node, app: app)
                    } label: {
                        Label("Open in \(app.rawValue) (0 B on Mac)", systemImage: app.symbol)
                    }
                }
            }
            Menu("Use with AI Apps (Claude, ChatGPT, Cursor)") {
                ForEach([ProExternalApp.claude, .chatGPT, .cursor, .vsCode]) { app in
                    Button {
                        model.openNodeInExternalApp(node, app: app)
                    } label: {
                        Label("Open & Copy Context for \(app.rawValue)", systemImage: app.symbol)
                    }
                }
                Divider()
                Button("Copy AI Prompt & /Volumes/Helium Path") {
                    model.copyNodeContextForAI(node)
                }
            }
            Button("Inspect File & Segments…") {
                model.inspectedNode = node
            }
            Button("Save Copy to Mac…") {
                model.exportNodeToMac(node)
            }
            if !model.linkedAccounts.isEmpty {
                Menu("Move to Google Account") {
                    ForEach(model.linkedAccounts) { acc in
                        Button {
                            Task { await model.moveNodeToGoogleAccount(node, targetAccountId: acc.id) }
                        } label: {
                            HStack {
                                Text("#\(acc.uploadPriority) \(acc.email) (\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free)")
                                if currentAccountId == acc.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(currentAccountId == acc.id)
                    }
                }
            }
        }
        Divider()
        if !model.allFoldersInDrive.isEmpty || node.parentID != DriveNode.rootID {
            Menu("Move to Folder") {
                if node.parentID != DriveNode.rootID {
                    Button {
                        Task { await model.moveNodeToFolder(node, targetFolderId: RemoteItem.rootID) }
                    } label: {
                        Label("Helium Drive (Root)", systemImage: "externaldrive.fill")
                    }
                }
                ForEach(model.allFoldersInDrive.filter { $0.id != node.id && $0.id != node.parentID }) { folder in
                    if let folderRemoteId = folder.remoteID {
                        Button {
                            Task { await model.moveNodeToFolder(node, targetFolderId: folderRemoteId) }
                        } label: {
                            Label(folder.name, systemImage: "folder.fill")
                        }
                    }
                }
            }
        }
        Button(model.isNodeStarred(node) ? "Remove from ★ Starred" : "Add to ★ Starred") {
            model.toggleStarNode(node)
        }
        Button(isPinned ? "Remove Offline Pin" : "Keep Offline on This Mac") {
            model.togglePinNode(node)
        }
        Button("Copy Helium Share Link") {
            model.createAndCopyShareLink(for: node)
        }
        Button("Rename…") {
            onRequestRename(node)
        }
        Divider()
        Button("Delete (30 Days to Undo)", role: .destructive) {
            Task { await model.deleteNode(node) }
        }
    }
}

struct DriveNodeGridCardView: View {
    @ObservedObject var model: AppModel
    let node: DriveNode
    var onRequestRename: (DriveNode) -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        let iconSpec = HeliumAsset.fileIconAndColor(for: node.name, isFolder: node.isFolder)
        let isPinned = model.isNodePinned(node)
        let isStarred = model.isNodeStarred(node)
        let currentAccountId: String? = {
            guard let remID = node.remoteID, let manifest = model.manifests[remID], manifest.segments.count == 1 else {
                return nil
            }
            return manifest.segments.first?.accountId
        }()

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconSpec.color.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconSpec.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconSpec.color)
                }
                Spacer()
                Button {
                    model.toggleStarNode(node)
                } label: {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(isStarred ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(isStarred ? "Remove from ★ Starred" : "Add to ★ Starred")
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
                Menu {
                    Button(node.isFolder ? "Open Folder" : "Open on Mac") {
                        model.openNodeOnMac(node)
                    }
                    Button("Reveal in Finder") {
                        model.revealNodeInFinder(node)
                    }
                    Button("Open in Google Drive") {
                        model.openNodeInGoogleDrive(node)
                    }
                    if !node.isFolder {
                        Button("Inspect File & Segments…") {
                            model.inspectedNode = node
                        }
                        Button("Save Copy to Mac…") {
                            model.exportNodeToMac(node)
                        }
                        if !model.linkedAccounts.isEmpty {
                            Menu("Move to Google Account") {
                                ForEach(model.linkedAccounts) { acc in
                                    Button {
                                        Task { await model.moveNodeToGoogleAccount(node, targetAccountId: acc.id) }
                                    } label: {
                                        HStack {
                                            Text("#\(acc.uploadPriority) \(acc.email) (\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free)")
                                            if currentAccountId == acc.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .disabled(currentAccountId == acc.id)
                                }
                            }
                        }
                    }
                    Divider()
                    if !model.allFoldersInDrive.isEmpty || node.parentID != DriveNode.rootID {
                        Menu("Move to Folder") {
                            if node.parentID != DriveNode.rootID {
                                Button {
                                    Task { await model.moveNodeToFolder(node, targetFolderId: RemoteItem.rootID) }
                                } label: {
                                    Label("Helium Drive (Root)", systemImage: "externaldrive.fill")
                                }
                            }
                            ForEach(model.allFoldersInDrive.filter { $0.id != node.id && $0.id != node.parentID }) { folder in
                                if let folderRemoteId = folder.remoteID {
                                    Button {
                                        Task { await model.moveNodeToFolder(node, targetFolderId: folderRemoteId) }
                                    } label: {
                                        Label(folder.name, systemImage: "folder.fill")
                                    }
                                }
                            }
                        }
                    }
                    Button(isStarred ? "Remove from ★ Starred" : "Add to ★ Starred") {
                        model.toggleStarNode(node)
                    }
                    Button(isPinned ? "Remove Offline Pin" : "Keep Offline on This Mac") {
                        model.togglePinNode(node)
                    }
                    Button("Copy Helium Share Link") {
                        model.createAndCopyShareLink(for: node)
                    }
                    Button("Rename…") {
                        onRequestRename(node)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        Task { await model.deleteNode(node) }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                            .frame(width: 26, height: 24)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 26, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(node.isFolder
                     ? "Folder"
                     : ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let remID = node.remoteID, let manifest = model.manifests[remID] {
                let hostEmail = manifest.segments.first.flatMap { seg in
                    model.linkedAccounts.first(where: { $0.id == seg.accountId })?.email
                }
                HStack(spacing: 4) {
                    Text(manifest.placementMode == .wholeFileSmartPlacement
                         ? "Smart Whole-File"
                         : "Striped (\(manifest.segments.count) segs)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            manifest.placementMode == .wholeFileSmartPlacement
                                ? Color.green.opacity(0.18)
                                : Color.purple.opacity(0.18)
                        )
                        .clipShape(Capsule())
                    if let hostEmail {
                        Text(hostEmail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.blue.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovered ? Color.blue.opacity(0.28) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(HeliumSpring.snappy, value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            model.openNodeOnMac(node)
        }
    }
}

// MARK: - 3. Google Drive Pool Workspace View (Storage Breakdowns + Finder-Style Files Manager with Search)
struct GoogleDrivePoolWorkspaceView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Pooled Google Drive Storage Breakdown Card (With Search & Pool Settings Buttons)
                HeliumGlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 12) {
                            HeliumAnimatedMascot(name: "HeliumHappy", size: 42, showAura: false)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text("Google Drive Pool")
                                        .font(.title3.bold())
                                    Text("\(model.linkedAccounts.count) Drive\(model.linkedAccounts.count == 1 ? "" : "s") Linked")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.16))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                                Text("\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Helium Pool (\(model.activePooledFilesCount) file\(model.activePooledFilesCount == 1 ? "" : "s")) • \(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Button {
                                Task { await model.syncWithGoogleDrive() }
                            } label: {
                                Label(model.isSyncingPool ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .fixedSize()
                            .disabled(model.isSyncingPool)
                            .help("Sync files, folders, deletions, and storage pool sizes across all linked Google Drives")

                            Button {
                                model.selectedSidebarDestination = .search
                            } label: {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .fixedSize()
                            .help("Search files across all pooled Google Drives (⌃⌥O)")

                            Button {
                                model.selectedSettingsTab = .account
                                model.selectedSidebarDestination = .settings
                            } label: {
                                Label("Pool Settings", systemImage: "gearshape")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .fixedSize()
                            .help("Configure Placement Engine, Upload Priority & Rebalancer in Settings")

                            SignInWithGoogleButton(
                                title: "+ Add Google Drive",
                                style: .standard,
                                isLoading: model.isSigningInWithGoogle
                            ) {
                                model.startBrowserOAuthFlow()
                            }
                            .fixedSize()
                        }

                        // Unified Multi-Account Segmented Storage Bar
                        MultiAccountSegmentedBar(accounts: model.linkedAccounts, totalCapacity: model.totalPoolBytes)
                            .frame(height: 10)

                        // Per-Account Storage Breakdown Rows
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                                let isTopTarget = (model.primaryUploadTargetAccount?.id == acc.id)
                                let storedCount = model.filesCountForAccount(acc.id)
                                let heliumBytes = model.heliumUsedBytesForAccount(acc.id)

                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(HeliumAsset.colorForAccount(at: idx))
                                        .frame(width: 9, height: 9)

                                    Text(acc.email)
                                        .font(.caption.bold())
                                        .lineLimit(1)

                                    if isTopTarget && !acc.isUploadPaused {
                                        Text("#1 Primary")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.16))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }

                                    Text("• \(storedCount) file\(storedCount == 1 ? "" : "s") (\(ByteCountFormatter.string(fromByteCount: heliumBytes, countStyle: .file)) in Helium)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Spacer(minLength: 8)

                                    ProgressView(value: Double(acc.quotaUsedBytes), total: Double(max(1, acc.quotaLimitBytes)))
                                        .tint(HeliumAsset.colorForAccount(at: idx))
                                        .frame(width: 140)

                                    Text("\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: acc.quotaLimitBytes, countStyle: .file))")
                                        .font(.caption.monospacedDigit().bold())
                                        .fixedSize()

                                    Button {
                                        model.openGoogleDriveVaultInBrowser(for: acc)
                                    } label: {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .help("Open \(acc.email) in Google Drive Web")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                            }
                        }
                    }
                }

                // 2. Pooled Storage Breakdown by File Category
                StorageCategoryBreakdownCard(model: model)

                // 3. Finder-Style Files Manager (With Search Button, Inline Filter, Breadcrumbs, List/Grid & Drag-and-Drop)
                LiveVolumeFilesAndSegmentsCard(model: model) {
                    model.selectedSettingsTab = .account
                    model.selectedSidebarDestination = .settings
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 4. Original Spotlight-Style Global Search View (SearchPanel / SearchView)
struct OriginalSpotlightSearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                HeliumAsset.icon("search", size: 22, tint: .blue)
                TextField("Search Helium across all pooled Google Drives…", text: Binding(
                    get: { model.searchQuery },
                    set: { model.updateSearch(query: $0, kind: model.searchKind) }
                ))
                .textFieldStyle(.plain)
                .font(.title3)

                if !model.searchQuery.isEmpty {
                    Button {
                        model.updateSearch(query: "", kind: model.searchKind)
                    } label: {
                        HeliumAsset.icon("cancel", size: 16, tint: .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // SearchKind Filter Pills (All, Documents, Photos, Videos, Audio, Folders)
            HStack(spacing: 8) {
                ForEach(SearchKind.allCases, id: \.self) { kind in
                    Button {
                        withAnimation(HeliumSpring.snappy) {
                            model.updateSearch(query: model.searchQuery, kind: kind)
                        }
                    } label: {
                        Text(kind.rawValue.capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                model.searchKind == kind
                                    ? Color.blue
                                    : Color(nsColor: .controlBackgroundColor)
                            )
                            .foregroundStyle(model.searchKind == kind ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(HeliumPressableButtonStyle())
                }
                Spacer()
                Text("\(model.searchResults.count) result\(model.searchResults.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.searchResults.isEmpty {
                VStack(spacing: 10) {
                    HeliumAnimatedMascot(name: "HeliumHappy", size: 58)
                    Text(model.searchQuery.isEmpty ? "Type to search your Helium drive instantly" : "No matching files in Helium")
                        .font(.headline)
                    Text("Helium indexes decrypted filenames in memory on your Mac — Google never sees your plaintext filenames when Zero-Knowledge encryption is active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.searchResults) { res in
                    let iconSpec = HeliumAsset.fileIconAndColor(for: res.node.name, isFolder: res.node.isFolder)
                    HStack(spacing: 12) {
                        Image(systemName: iconSpec.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconSpec.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(res.node.name)
                                .font(.body.bold())
                            Text("/Volumes/Helium/" + (res.folders + [res.node.name]).joined(separator: "/"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(res.node.isFolder ? "Folder" : ByteCountFormatter.string(fromByteCount: res.node.size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(res.node.isFolder ? "Open Folder" : "Open") {
                            if res.node.isFolder {
                                model.selectedSidebarDestination = .home
                                model.openFolder(res.node)
                            } else {
                                model.openNodeOnMac(res.node)
                            }
                        }
                        .controlSize(.small)
                        if !res.node.isFolder {
                            Button("Inspect") {
                                model.inspectedNode = res.node
                            }
                            .controlSize(.small)
                            Button("Google Drive") {
                                model.openNodeInGoogleDrive(res.node)
                            }
                            .controlSize(.small)
                        }
                        Button("Reveal in Finder") {
                            model.revealNodeInFinder(res.node)
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }
}

// MARK: - 5. Original 5-Tab Settings View (General, Account, Privacy, Storage, Updates)
public struct OriginalFiveTabSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var showSignOutConfirmation: Bool = false
    @State private var showMakeNewKeyConfirmation: Bool = false
    @State private var showClearRecentFilesConfirmation: Bool = false
    @State private var hoveredSettingsTab: SettingsTab? = nil

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Original 5-Tab Segmented Header (Full clickable blue pill area for every tab)
            HStack(spacing: 10) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = model.selectedSettingsTab == tab
                    let isHovered = hoveredSettingsTab == tab
                    Button {
                        withAnimation(HeliumSpring.snappy) {
                            model.selectedSettingsTab = tab
                        }
                    } label: {
                        VStack(spacing: 5) {
                            HeliumAsset.icon(
                                tab.iconName,
                                size: 18,
                                tint: (isSelected || isHovered) ? .blue : .secondary
                            )
                            Text(tab.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(isSelected ? .blue : (isHovered ? .blue : .primary))
                        }
                        .frame(width: 92, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(isSelected ? Color.blue.opacity(0.15) : (isHovered ? Color.blue.opacity(0.08) : Color.blue.opacity(0.001)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(isSelected ? Color.blue.opacity(0.28) : (isHovered ? Color.blue.opacity(0.18) : Color.clear), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .onHover { hovering in
                        withAnimation(HeliumSpring.snappy) {
                            hoveredSettingsTab = hovering ? tab : (hoveredSettingsTab == tab ? nil : hoveredSettingsTab)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.selectedSettingsTab {
                    case .general:
                        generalTabContent
                    case .account:
                        accountTabContent
                    case .privacy:
                        privacyTabContent
                    case .storage:
                        storageTabContent
                    case .updates:
                        updatesTabContent
                    }

                    Divider()
                        .padding(.top, 4)

                    HStack {
                        CogifyBrandingView()
                        Spacer()
                        Button {
                            model.showHelpSheet = true
                        } label: {
                            Label("Open Helium Help Center", systemImage: "questionmark.circle")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .confirmationDialog(
            "Sign out of Helium on this Mac?",
            isPresented: $showSignOutConfirmation
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await model.signOutOfThisMac() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Helium drive will be removed from this Mac. Your files stay safe in the cloud.")
        }
        .confirmationDialog(
            "Make a new recovery key?",
            isPresented: $showMakeNewKeyConfirmation
        ) {
            Button("Make New Key", role: .destructive) {
                model.makeNewRecoveryKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your old recovery key will stop working.")
        }
        .confirmationDialog(
            "Remove recent files from this Mac?",
            isPresented: $showClearRecentFilesConfirmation
        ) {
            Button("Remove Recent Files", role: .destructive) {
                model.removeRecentCachedFiles()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your files stay in Helium. They stream from the cloud again when you open them.")
        }
    }

    // Tab 1: General
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("General")
                    .font(.title3.bold())
                Spacer()
                Button {
                    model.askStartupPreferencesAgain()
                } label: {
                    Label("Startup & Taskbar Prompt…", systemImage: "menubar.rectangle")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            "Start Helium on bootup (Open when you log in)",
                            isOn: Binding(
                                get: { model.openAtLogin },
                                set: { model.setOpenAtLogin($0) }
                            )
                        )
                        Text("Automatically launches Helium and mounts /Volumes/Helium whenever your Mac starts up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            "Run in taskbar (menu bar) only",
                            isOn: Binding(
                                get: { model.runInTaskbarOnly },
                                set: { model.setRunInTaskbarOnly($0, closeWindowImmediately: false) }
                            )
                        )
                        Text("Keep Helium in the top macOS menu bar only and hide the Dock icon. You can still open the full dashboard window anytime from the menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Turn on Finder actions", isOn: $model.finderActionsEnabled)
                        Text("Right-click in Helium to copy share links, request files, and keep files on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Search from anywhere")
                                .font(.body.weight(.medium))
                            Text("Press ⌃⌥O anywhere on your Mac to search files across your pooled Google Drives.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("⌃⌥O")
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Send error reports", isOn: $model.sendErrorReports)
                        Text("When something goes wrong, Helium sends a short technical report so we can fix it. It never includes your files or their names.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
        }
    }

    // Tab 2: Account & Multi-Google-Drive Pool
    private var accountTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Account & Google Drive Pool")
                        .font(.title3.bold())
                    Text("\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Helium Pool (\(model.activePooledFilesCount) file\(model.activePooledFilesCount == 1 ? "" : "s")) • \(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file)) across \(model.linkedAccounts.count) Google Drive\(model.linkedAccounts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SignInWithGoogleButton(
                    title: "+ Sign in with Google",
                    style: .standard,
                    isLoading: model.isSigningInWithGoogle
                ) {
                    model.startBrowserOAuthFlow()
                }
            }

            // Pool Health, Rebalancer & Cloud Sync (Moved from Google Drive Pool to Settings)
            GroupBox("Pool Health, Rebalancer & Cloud Sync") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("Rebalance whole files to the Google Drive with the most free space or verify segment integrity across all accounts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await model.syncWithGoogleDrive() }
                        } label: {
                            Label(model.isSyncingPool ? "Syncing…" : "Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isSyncingPool)

                        Button {
                            Task { await model.verifyPoolHealth() }
                        } label: {
                            Label("Verify Integrity", systemImage: "checkmark.shield.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isSyncingPool)

                        Button {
                            Task { await model.rebalancePool() }
                        } label: {
                            Label(model.isRebalancingPool ? "Rebalancing…" : "Rebalance Pool", systemImage: "arrow.left.arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(model.isRebalancingPool || model.linkedAccounts.count < 2)
                    }

                    if !model.poolHealthSummary.isEmpty {
                        HStack(spacing: 8) {
                            HeliumAsset.icon("check-circle", size: 14, tint: .green)
                            Text(model.poolHealthSummary)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(8)
            }

            // Storage Placement Engine & Google Account Upload Priority (Moved from Google Drive Pool to Settings)
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Text("Storage Placement Engine & Google Account Upload Priority")
                            .font(.subheadline.bold())
                        FeatureHelpPopoverButton(topic: .placementEngine) {
                            model.showHelpSheet = true
                        }
                        Spacer()
                    }

                    Picker("Placement Mode:", selection: Binding(
                        get: { model.placementPolicy },
                        set: { policy in Task { await model.updateAllocatorPolicy(policy) } }
                    )) {
                        Text("Both (Smart Whole-File + Auto Striping)").tag(PlacementPolicy.automatic)
                        Text("Mode 1: Whole-File Smart Placement (Single Account First)").tag(PlacementPolicy.preferWholeFile)
                        Text("Mode 2: Always Cross-Account Striping Across All Drives").tag(PlacementPolicy.alwaysStripe)
                    }
                    .pickerStyle(.radioGroup)

                    Divider()

                    HStack(alignment: .center, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Account Upload Routing:")
                                    .font(.caption.bold())
                                FeatureHelpPopoverButton(topic: .uploadPriority) {
                                    model.showHelpSheet = true
                                }
                            }
                            Picker("", selection: Binding(
                                get: { model.accountRoutingStrategy },
                                set: { strategy in Task { await model.setAccountRoutingStrategy(strategy) } }
                            )) {
                                ForEach(AccountRoutingStrategy.allCases) { strat in
                                    Text(strat.displayTitle).tag(strat)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 240)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preferred Target Google Account:")
                                .font(.caption.bold())
                            Picker("", selection: Binding(
                                get: { model.preferredUploadAccountId ?? "" },
                                set: { val in
                                    Task { await model.setPreferredUploadAccount(val.isEmpty ? nil : val) }
                                }
                            )) {
                                Text("Automatic (#1 Priority Account)").tag("")
                                ForEach(model.linkedAccounts) { acc in
                                    Text("#\(acc.uploadPriority) \(acc.email) (\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free)").tag(acc.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 250)
                        }
                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Stripe Threshold: \(String(format: "%.1f", model.autoStripeAboveGB)) GB")
                                .font(.caption.bold())
                            Slider(
                                value: Binding(
                                    get: { model.autoStripeAboveGB },
                                    set: { gb in Task { await model.updateAutoStripeThresholdGB(gb) } }
                                ),
                                in: 0.5...32.0,
                                step: 0.5
                            )
                            .frame(width: 220)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stripe Segment Size: \(model.segmentSizeMiB) MiB")
                                .font(.caption.bold())
                            Picker("", selection: Binding(
                                get: { model.segmentSizeMiB },
                                set: { mib in Task { await model.updateSegmentSizeMiB(mib) } }
                            )) {
                                Text("16 MiB").tag(16)
                                Text("64 MiB").tag(64)
                                Text("128 MiB").tag(128)
                                Text("256 MiB").tag(256)
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            }

            GroupBox("Linked Google Accounts & Upload Priority") {
                VStack(alignment: .leading, spacing: 10) {
                    MultiAccountSegmentedBar(accounts: model.linkedAccounts, totalCapacity: model.totalPoolBytes)
                        .frame(height: 8)

                    ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                        let isTopTarget = (model.primaryUploadTargetAccount?.id == acc.id)
                        HStack {
                            Text("#\(acc.uploadPriority)")
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isTopTarget ? Color.blue : HeliumAsset.colorForAccount(at: idx).opacity(0.22))
                                .foregroundStyle(isTopTarget ? .white : .primary)
                                .clipShape(Capsule())

                            if model.linkedAccounts.count > 1 {
                                HStack(spacing: 2) {
                                    Button {
                                        Task { await model.moveAccountPriority(acc.id, delta: -1) }
                                    } label: {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .disabled(idx == 0)
                                    .help("Move Priority Up")

                                    Button {
                                        Task { await model.moveAccountPriority(acc.id, delta: 1) }
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .disabled(idx == model.linkedAccounts.count - 1)
                                    .help("Move Priority Down")
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(acc.email)
                                        .font(.subheadline.bold())
                                    if isTopTarget && !acc.isUploadPaused {
                                        Text("Primary Upload Target")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.18))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                    if acc.isUploadPaused {
                                        Text("Uploads Paused")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.20))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: acc.quotaLimitBytes, countStyle: .file)) • \(model.filesCountForAccount(acc.id)) files (\(ByteCountFormatter.string(fromByteCount: model.heliumUsedBytesForAccount(acc.id), countStyle: .file)) in Helium)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if !isTopTarget || acc.uploadPriority > 1 {
                                Button("Prioritise #1") {
                                    Task {
                                        await model.prioritiseAccountFirst(acc.id)
                                        await model.setPreferredUploadAccount(acc.id)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            Button(acc.isUploadPaused ? "Resume" : "Pause Uploads") {
                                Task { await model.toggleAccountUploadPaused(acc.id) }
                            }
                            .controlSize(.small)

                            Button("Open in Google Drive") {
                                model.openGoogleDriveVaultInBrowser(for: acc)
                            }
                            .controlSize(.small)

                            if model.linkedAccounts.count > 1 {
                                Button("Drain & Unlink") {
                                    Task { await model.drainAndUnlink(accountId: acc.id) }
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(8)
            }

            HStack {
                Button("Sign Out of This Mac…", role: .destructive) {
                    showSignOutConfirmation = true
                }
                Spacer()
            }
        }
    }

    // Tab 3: Privacy
    private var privacyTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Privacy")
                .font(.title3.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("End-to-end encryption")
                                    .font(.headline)
                                FeatureHelpPopoverButton(topic: .zeroKnowledge) {
                                    model.showHelpSheet = true
                                }
                            }
                            Text("Only your devices hold the key. Helium stores your files encrypted in Google Drive when enabled.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { model.zeroKnowledgeEnabled },
                            set: { model.setZeroKnowledgeEnabled($0) }
                        ))
                        .labelsHidden()
                    }

                    Divider()

                    WelcomeFeatureRow(
                        iconName: "lock",
                        title: "Encrypted on your Mac",
                        subtitle: "Files and names are locked with AES-256-GCM before they leave this Mac."
                    )
                    WelcomeFeatureRow(
                        iconName: "flash",
                        title: "Still opens instantly",
                        subtitle: "Everything in Finder works the way it always does."
                    )
                    WelcomeFeatureRow(
                        iconName: "key",
                        title: "One key, only yours",
                        subtitle: "Your recovery key is the only way back in if you lose your devices."
                    )
                }
                .padding(10)
            }

            GroupBox("Your Recovery Key (52-Character Base32)") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.formattedRecoveryKey)
                        .font(.system(.callout, design: .monospaced).bold())
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 10) {
                        Button("Copy Key") {
                            model.copyRecoveryKeyToClipboard()
                        }
                        Button("Save Recovery Key File…") {
                            model.saveRecoveryKeyToDisk()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Save in Passwords") {
                            model.openApplePasswordsApp()
                        }
                        Spacer()
                        Button("Make a New Key…") {
                            showMakeNewKeyConfirmation = true
                        }
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Button("Unlock Vault with Key…") {
                            model.showUnlockSheet = true
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
            }
        }
    }

    // Tab 4: Storage
    private var storageTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Storage")
                .font(.title3.bold())

            GroupBox("Space for recent files") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Files in Helium take no space on this Mac. To open them instantly, Helium keeps the parts you used recently, up to the size you choose. It always gives space back when your Mac runs low.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Keep recent files up to:", selection: $model.cacheLimitOption) {
                        ForEach(CacheLimitOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .frame(maxWidth: 320)

                    HStack {
                        Text("Currently cached on this Mac: \(ByteCountFormatter.string(fromByteCount: model.cachedBytesOnMac, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Remove Recent Files…") {
                            showClearRecentFilesConfirmation = true
                        }
                    }
                }
                .padding(10)
            }

            GroupBox("Upload speed") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Limit uploads so video calls and browsing stay smooth. Opening files is never slowed down.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Upload speed limit:", selection: $model.uploadSpeedOption) {
                        ForEach(UploadSpeedOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .frame(maxWidth: 320)

                    Toggle("Pause all background uploads", isOn: $model.isUploadsPaused)
                }
                .padding(10)
            }

            StorageCategoryBreakdownCard(model: model)

            StoragePoolOptimizerCard(model: model)
        }
    }

    // Tab 5: Updates & Feedback
    private var updatesTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Updates & Support")
                .font(.title3.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        HeliumAnimatedMascot(name: "HeliumHappy", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Helium v0.0.1 (Build 1)")
                                .font(.headline)
                            Text(model.lastUpdateCheckText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Check for Updates…") {
                            model.checkForUpdates()
                        }
                    }

                    Divider()

                    Toggle("Install updates automatically", isOn: $model.installUpdatesAutomatically)
                }
                .padding(10)
            }

            GroupBox("Support & Feedback (connect@cogify.me)") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Found a problem, need help, or have an idea? Write to us.")
                                .font(.subheadline.bold())
                            Text("Direct engineering & support email: connect@cogify.me")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            model.copySupportEmailAddress()
                        } label: {
                            Label("Copy Email", systemImage: "doc.on.doc")
                        }
                        .controlSize(.small)

                        Button {
                            model.showFeedbackSheet = true
                        } label: {
                            Label("Write Email to connect@cogify.me…", systemImage: "envelope.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(10)
            }
        }
    }
}

// MARK: - Modal Sheets (Recovery Key, Unlock Vault, Feedback)
struct RecoveryKeyModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                HeliumAsset.icon("key", size: 26, tint: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save your recovery key")
                        .font(.title3.bold())
                    Text("Keep a copy in Passwords or somewhere safe outside Helium.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(model.formattedRecoveryKey)
                .font(.system(.body, design: .monospaced).bold())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Copy Key") {
                    model.copyRecoveryKeyToClipboard()
                }
                Button("Save Key File…") {
                    model.saveRecoveryKeyToDisk()
                }
                .buttonStyle(.borderedProminent)
                Button("Open Passwords") {
                    model.openApplePasswordsApp()
                }
                Spacer()
                Button("I Saved It") {
                    model.recoveryKeySavedConfirmation = true
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

struct UnlockVaultModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock your files on this Mac")
                .font(.title3.bold())
            Text("Enter your 52-character recovery key, or approve this Mac from another device signed in to Helium.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("XXXX-XXXX-XXXX-...", text: $model.unlockKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Unlock") {
                    if model.verifyAndUnlockWithInputKey() {
                        dismiss()
                    } else {
                        errorMessage = "That recovery key doesn't look right."
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

struct FeedbackModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write Email to connect@cogify.me")
                        .font(.headline.bold())
                    Text("Pick a template or write your own note — opens in Mail or copies to clipboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    model.copySupportEmailAddress()
                } label: {
                    Label("Copy connect@cogify.me", systemImage: "doc.on.doc")
                        .font(.caption2.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 2x2 Template Selector Grid (fits cleanly inside modal width with zero horizontal overflow)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(SupportEmailTemplate.allCases) { tmpl in
                    let isSelected = model.selectedEmailTemplate == tmpl
                    Button {
                        model.selectedEmailTemplate = tmpl
                        model.feedbackText = tmpl.defaultPromptPlaceholder
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tmpl.symbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(tmpl.rawValue)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.blue.opacity(0.18) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSelected ? Color.blue.opacity(0.45) : Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? .blue : .primary)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextEditor(
                text: Binding(
                    get: {
                        model.feedbackText.isEmpty
                            ? model.selectedEmailTemplate.defaultPromptPlaceholder
                            : model.feedbackText
                    },
                    set: { model.feedbackText = $0 }
                )
            )
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
            )

            Toggle("Include Helium v0.0.1 technical & pool diagnostics", isOn: $model.feedbackIncludeDiagnostics)
                .font(.caption)

            HStack(spacing: 10) {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button {
                    model.copySupportEmailDraft(
                        template: model.selectedEmailTemplate,
                        customNotes: model.feedbackText,
                        includeDiagnostics: model.feedbackIncludeDiagnostics
                    )
                } label: {
                    Label("Copy Draft", systemImage: "doc.on.clipboard")
                }
                Button {
                    model.composeSupportEmail(
                        template: model.selectedEmailTemplate,
                        customNotes: model.feedbackText,
                        includeDiagnostics: model.feedbackIncludeDiagnostics
                    )
                    dismiss()
                } label: {
                    Label("Write Email (connect@cogify.me)", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 560)
    }
}

// MARK: - Storage Category Breakdown Card
struct StorageCategoryBreakdownCard: View {
    @ObservedObject var model: AppModel

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .gray
        }
    }

    var body: some View {
        let stats = model.storageCategoryBreakdown
        let rawTotalBytes = stats.reduce(Int64(0)) { $0 + $1.bytes }
        let totalFilesBytes = max(1, rawTotalBytes)
        let totalPooledFileCount = stats.reduce(0) { $0 + $1.fileCount }

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Pooled Storage Breakdown by File Type", systemImage: "chart.bar.xaxis")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(totalPooledFileCount) pooled file\(totalPooledFileCount == 1 ? "" : "s") • \(ByteCountFormatter.string(fromByteCount: rawTotalBytes, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if stats.isEmpty {
                    Text("Upload files to see a visual breakdown by category across your pooled Google Drives.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(stats) { stat in
                                let fraction = max(0.03, Double(stat.bytes) / Double(totalFilesBytes))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForName(stat.colorName).gradient)
                                    .frame(width: max(8, geo.size.width * fraction))
                            }
                        }
                    }
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 8) {
                        ForEach(stats) { stat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForName(stat.colorName))
                                    .frame(width: 9, height: 9)
                                Image(systemName: stat.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(colorForName(stat.colorName))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stat.title)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Text("\(stat.fileCount) file\(stat.fileCount == 1 ? "" : "s") • \(ByteCountFormatter.string(fromByteCount: stat.bytes, countStyle: .file))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                            )
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}

// MARK: - File Placement & Cryptographic Inspector Sheet
struct NodeInspectorModalSheet: View {
    @ObservedObject var model: AppModel
    let node: DriveNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let iconSpec = HeliumAsset.fileIconAndColor(for: node.name, isFolder: node.isFolder)
        let isPinned = model.isNodePinned(node)
        let manifest: PoolItemManifest? = node.remoteID.flatMap { model.manifests[$0] }
        let segments = manifest?.segments ?? []
        let isStriped = manifest?.placementMode == .crossAccountStriped || segments.count > 1

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconSpec.color.opacity(0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: iconSpec.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconSpec.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.name)
                        .font(.title3.bold())
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(node.isFolder ? "Folder" : ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                        Text("•")
                        Text("Inode #\(node.id)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            GroupBox("Encryption & Virtual Disk Metadata") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Storage Security")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(model.zeroKnowledgeEnabled ? "AES-256-GCM Zero-Knowledge E2EE" : "Direct Google Drive File Mode")
                            .font(.system(.caption, design: .monospaced).bold())
                    }
                    HStack {
                        Text("Placement Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isStriped ? "Mode 2: Cross-Account Striped (\(segments.count) segments)" : "Mode 1: Whole-File Smart Placement")
                            .font(.caption.bold())
                            .foregroundStyle(isStriped ? .purple : .blue)
                    }
                    HStack {
                        Text("Offline Pin State")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isPinned ? "Pinned on Mac SSD" : "On-Demand Streaming (0 B on Mac)")
                            .font(.caption.bold())
                            .foregroundStyle(isPinned ? .teal : .secondary)
                    }
                    if let remoteID = node.remoteID {
                        HStack {
                            Text("Catalog Item ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(remoteID)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Segment Distribution Across Google Drives (\(segments.count))") {
                if segments.isEmpty {
                    Text(node.isFolder
                         ? "Directory container — metadata indexed in Helium virtual file table."
                         : "Single-file virtual entry indexed in Helium Drive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(segments, id: \.index) { seg in
                                let accountEmail = model.linkedAccounts.first(where: { $0.id == seg.accountId })?.email ?? seg.accountId
                                HStack(spacing: 10) {
                                    Text("#\(seg.index + 1)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.blue)
                                        .frame(width: 28, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(accountEmail)
                                            .font(.caption.bold())
                                        Text("Google Drive File ID: \(seg.driveFileId)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(ByteCountFormatter.string(fromByteCount: seg.byteLength, countStyle: .file))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 160)
                }
            }

            if !node.isFolder && !model.linkedAccounts.isEmpty {
                GroupBox("Move File to Another Google Account") {
                    HStack(spacing: 8) {
                        Text("Migrate this file onto:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ForEach(model.linkedAccounts) { account in
                            let isCurrentOwner = segments.count == 1 && segments.first?.accountId == account.id
                            Button {
                                Task {
                                    await model.moveNodeToGoogleAccount(node, targetAccountId: account.id)
                                    if let refreshed = model.driveNodes.first(where: { $0.id == node.id }) {
                                        model.inspectedNode = refreshed
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isCurrentOwner ? "checkmark.circle.fill" : "arrow.right.circle")
                                    Text(account.email.components(separatedBy: "@").first ?? account.email)
                                }
                                .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .tint(isCurrentOwner ? .green : .blue)
                            .controlSize(.small)
                            .disabled(isCurrentOwner)
                        }
                    }
                    .padding(6)
                }
            }

            HStack {
                if !node.isFolder {
                    Button {
                        model.openNodeInGoogleDrive(node)
                    } label: {
                        Label("Open in Google Drive", systemImage: "arrow.up.right.square")
                    }
                }
                Button {
                    model.revealNodeInFinder(node)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 540)
    }
}

// MARK: - Startup & Taskbar Preferences Prompt Sheet ("Ask: Start on bootup, run in taskbar only")
public struct StartupTaskbarPromptSheet: View {
    @ObservedObject var model: AppModel
    @State private var draftStartOnBootup: Bool = true
    @State private var draftRunInTaskbarOnly: Bool = false
    @State private var draftDontAskAgain: Bool = false
    @State private var userToggledDontAsk: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                HeliumAnimatedMascot(name: "HeliumHappy", size: 52, showAura: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("How should Helium run on your Mac?")
                        .font(.title3.bold())
                    Text("Choose whether Helium starts automatically on bootup and whether it runs quietly in the taskbar (menu bar) only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Option 1: Start on bootup
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        draftStartOnBootup.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 38, height: 38)
                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start on bootup")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Launch Helium automatically and mount /Volumes/Helium whenever your Mac boots up or logs in.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $draftStartOnBootup)
                            .labelsHidden()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(draftStartOnBootup ? Color.blue.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(draftStartOnBootup ? Color.blue.opacity(0.40) : Color.secondary.opacity(0.20), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                // Option 2: Run in taskbar only
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        draftRunInTaskbarOnly.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.purple.opacity(0.14))
                                .frame(width: 38, height: 38)
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Run in taskbar only")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Keep Helium in the top macOS menu bar (taskbar) only and hide the Dock icon. You can still open the full dashboard anytime from the menu bar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $draftRunInTaskbarOnly)
                            .labelsHidden()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(draftRunInTaskbarOnly ? Color.purple.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(draftRunInTaskbarOnly ? Color.purple.opacity(0.40) : Color.secondary.opacity(0.20), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                // Don't ask me again checkbox row
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        draftDontAskAgain.toggle()
                        userToggledDontAsk = true
                        model.setDontAskStartupPreferencesAgain(draftDontAskAgain)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Toggle(
                            "Don't ask me again",
                            isOn: Binding(
                                get: { draftDontAskAgain },
                                set: { newValue in
                                    draftDontAskAgain = newValue
                                    userToggledDontAsk = true
                                    model.setDontAskStartupPreferencesAgain(newValue)
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                        Text("— Remember my choice and don't show this prompt on launch")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(draftDontAskAgain ? Color.blue.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(draftDontAskAgain ? Color.blue.opacity(0.35) : Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 10) {
                Button(draftDontAskAgain ? "Close" : "Ask Me Later") {
                    if draftDontAskAgain {
                        model.saveStartupPreferences(
                            startOnBootup: draftStartOnBootup,
                            taskbarOnly: draftRunInTaskbarOnly,
                            dontAskAgain: true
                        )
                    } else {
                        model.showStartupPreferencesPrompt = false
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start on Bootup + Taskbar Only") {
                    let finalDontAsk = userToggledDontAsk ? draftDontAskAgain : true
                    model.saveStartupPreferences(
                        startOnBootup: true,
                        taskbarOnly: true,
                        dontAskAgain: finalDontAsk
                    )
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button("Save Preferences") {
                    let finalDontAsk = userToggledDontAsk ? draftDontAskAgain : true
                    model.saveStartupPreferences(
                        startOnBootup: draftStartOnBootup,
                        taskbarOnly: draftRunInTaskbarOnly,
                        dontAskAgain: finalDontAsk
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                CogifyBrandingView(compact: true)
                Spacer()
                Text("You can change this anytime in Settings → General or the Menu Bar.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(width: 540)
        .onAppear {
            draftStartOnBootup = model.openAtLogin
            draftRunInTaskbarOnly = model.runInTaskbarOnly
            draftDontAskAgain = model.hasAskedStartupPreferences
            userToggledDontAsk = false
        }
    }
}

// MARK: - Menu Bar Popover (Original Helium MenuBarExtra Experience with Inline Search & Settings)
public struct MenuBarPopoverView: View {
    public enum PopoverPage: String, Equatable {
        case home
        case search
        case settings
    }

    @ObservedObject var model: AppModel
    @State private var activePage: PopoverPage = .home

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // If user hasn't answered Startup & Taskbar question yet, ask right in the popover too
            if !model.hasAskedStartupPreferences && activePage == .home {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                        Text("How should Helium run on your Mac?")
                            .font(.caption.bold())
                        Spacer()
                    }
                    Toggle(
                        "Start on bootup",
                        isOn: Binding(
                            get: { model.openAtLogin },
                            set: { model.setOpenAtLogin($0) }
                        )
                    )
                    .font(.caption)
                    .controlSize(.small)

                    Toggle(
                        "Run in taskbar only (hide Dock icon)",
                        isOn: Binding(
                            get: { model.runInTaskbarOnly },
                            set: { model.setRunInTaskbarOnly($0, closeWindowImmediately: $0) }
                        )
                    )
                    .font(.caption)
                    .controlSize(.small)

                    Toggle(
                        "Don't ask me again",
                        isOn: Binding(
                            get: { model.hasAskedStartupPreferences },
                            set: { model.setDontAskStartupPreferencesAgain($0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption.bold())
                    .controlSize(.small)

                    HStack(spacing: 8) {
                        Button("Enable Both") {
                            model.saveStartupPreferences(startOnBootup: true, taskbarOnly: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Save Current") {
                            model.saveStartupPreferences(startOnBootup: model.openAtLogin, taskbarOnly: model.runInTaskbarOnly)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.28), lineWidth: 1)
                )
            }

            switch activePage {
            case .home:
                // Helium-Style Offline Keep Download Card ("Downloading X of Y — To keep on this Mac, as you chose.")
                if model.isDownloadingOfflineKeep || !model.pinnedFilenames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.90))
                                    .frame(width: 28, height: 28)
                                Image(systemName: model.isDownloadingOfflineKeep ? "arrow.down" : "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if model.isDownloadingOfflineKeep {
                                    Text("Downloading \(ByteCountFormatter.string(fromByteCount: model.offlineKeepDownloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: model.offlineKeepTotalBytes, countStyle: .file))")
                                        .font(.subheadline.bold())
                                } else {
                                    Text("Kept \(ByteCountFormatter.string(fromByteCount: model.cachedBytesOnMac, countStyle: .file)) on this Mac")
                                        .font(.subheadline.bold())
                                }
                                Text("To keep on this Mac, as you chose.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Free Space") {
                                model.unpinAllInCurrentFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        let frac: Double = {
                            guard model.isDownloadingOfflineKeep, model.offlineKeepTotalBytes > 0 else { return 1.0 }
                            return min(1.0, max(0.05, Double(model.offlineKeepDownloadedBytes) / Double(model.offlineKeepTotalBytes)))
                        }()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.20))
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(width: max(8, geo.size.width * frac))
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                OriginalHeliumHomeCard(
                    model: model,
                    onOpenSearch: {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .search
                        }
                    },
                    onOpenSettings: {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .settings
                        }
                    }
                )

                // Helium-Style Quick Menu Rows (Search Helium ⌃⌥O, Open in Finder, Your Account ↗, Send Feedback, Settings ⌘,)
                VStack(spacing: 2) {
                    menuBarQuickActionRow(icon: "magnifyingglass", title: "Search Helium", trailingText: "⌃⌥O") {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .search
                        }
                    }
                    menuBarQuickActionRow(icon: "folder", title: "Open in Finder", trailingText: nil) {
                        model.openInFinder()
                    }
                    menuBarQuickActionRow(icon: "arrow.up.forward.app", title: "Your Account", trailingText: "↗") {
                        model.openGoogleDriveVaultInBrowser()
                    }
                    menuBarQuickActionRow(icon: "envelope", title: "Send Feedback", trailingText: nil) {
                        model.navigateToMainWindow(destination: .home)
                        model.showFeedbackSheet = true
                    }
                    menuBarQuickActionRow(icon: "gearshape", title: "Settings", trailingText: "⌘,") {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .settings
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                )
            case .search:
                menuBarInlineSearchView
            case .settings:
                menuBarInlineSettingsView
            }

            // Quick Taskbar & Bootup Toggles + Google Pool Footer inside Menu Bar Popover
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Toggle(
                        "Start on bootup",
                        isOn: Binding(
                            get: { model.openAtLogin },
                            set: {
                                model.hasAskedStartupPreferences = true
                                UserDefaults.standard.set(true, forKey: "helium.hasAskedStartupPreferences")
                                model.setOpenAtLogin($0)
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption2.bold())

                    Spacer()

                    Toggle(
                        "Run in taskbar only",
                        isOn: Binding(
                            get: { model.runInTaskbarOnly },
                            set: {
                                model.hasAskedStartupPreferences = true
                                UserDefaults.standard.set(true, forKey: "helium.hasAskedStartupPreferences")
                                model.setRunInTaskbarOnly($0, closeWindowImmediately: $0)
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

                HStack {
                    Text("\(model.linkedAccounts.count) Google Drive\(model.linkedAccounts.count == 1 ? "" : "s") Pooled")
                        .font(.caption.bold())
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }

                MultiAccountSegmentedBar(accounts: model.linkedAccounts, totalCapacity: model.totalPoolBytes)
                    .frame(height: 6)

                HStack {
                    SignInWithGoogleButton(
                        title: model.hasRealGoogleAccount ? "+ Add Google Drive" : "Sign in with Google",
                        style: .compact,
                        isLoading: model.isSigningInWithGoogle
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                        model.startBrowserOAuthFlow()
                    }

                    Spacer()

                    Button("Open Window") {
                        model.navigateToMainWindow(destination: .home)
                    }
                    .buttonStyle(.link)
                    .font(.caption.bold())

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Help") {
                        model.navigateToMainWindow(destination: .home)
                        model.showHelpSheet = true
                    }
                    .buttonStyle(.link)
                    .font(.caption.bold())

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Quit Helium") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    CogifyBrandingView(compact: true)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(8)
        .frame(width: 372)
    }

    private func menuBarQuickActionRow(
        icon: String,
        title: String,
        trailingText: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline Search Page in Menu Bar Popover
    private var menuBarInlineSearchView: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .home
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    Text("Search Helium Pool")
                        .font(.subheadline.bold())

                    Spacer()

                    Button {
                        model.navigateToMainWindow(destination: .search)
                    } label: {
                        Label("Full Window", systemImage: "macwindow")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        "Search files across pooled Google Drives…",
                        text: Binding(
                            get: { model.searchQuery },
                            set: { model.updateSearch(query: $0, kind: model.searchKind) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.caption)
                    if !model.searchQuery.isEmpty {
                        Button {
                            model.updateSearch(query: "", kind: model.searchKind)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )

                // Kind filter pills so menu bar search filters across all pooled folders by category
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(SearchKind.allCases, id: \.self) { kind in
                            let selected = model.searchKind == kind
                            Button {
                                model.updateSearch(query: model.searchQuery, kind: kind)
                            } label: {
                                Text(kind.rawValue)
                                    .font(.system(size: 10, weight: selected ? .bold : .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(selected ? Color.blue.opacity(0.18) : Color.primary.opacity(0.05))
                                    )
                                    .foregroundStyle(selected ? .blue : .secondary)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                let matchingNodes: [DriveNode] = {
                    if !model.searchResults.isEmpty || !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.searchKind != .all {
                        return model.searchResults.map(\.node)
                    }
                    return model.driveNodes
                }()

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if matchingNodes.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text(model.searchQuery.isEmpty ? "No matching items in Helium pool" : "No files matching \"\(model.searchQuery)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(matchingNodes.prefix(25)) { node in
                                let spec = HeliumAsset.fileIconAndColor(for: node.name, isFolder: node.isFolder)
                                HStack(spacing: 8) {
                                    Image(systemName: spec.symbol)
                                        .foregroundStyle(spec.color)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(node.name)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Text(node.isFolder ? "Folder" : ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()

                                    Button {
                                        model.revealNodeInFinder(node)
                                    } label: {
                                        Image(systemName: "folder")
                                            .font(.caption)
                                            .padding(5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                                            .contentShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reveal in Finder")

                                    if !node.isFolder {
                                        Button {
                                            model.openNodeInGoogleDrive(node)
                                        } label: {
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.caption)
                                                .padding(5)
                                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.12)))
                                                .foregroundStyle(.blue)
                                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Open in Google Drive")
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                                )
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }

    // MARK: - Inline Settings Page in Menu Bar Popover
    private var menuBarInlineSettingsView: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(HeliumSpring.snappy) {
                            activePage = .home
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    Text("Helium Settings")
                        .font(.subheadline.bold())

                    Spacer()

                    Button {
                        model.navigateToMainWindow(destination: .settings, settingsTab: model.selectedSettingsTab)
                    } label: {
                        Label("Full Settings", systemImage: "macwindow")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                // Compact 5-tab selector with full blue hit area
                HStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        let isSelected = model.selectedSettingsTab == tab
                        Button {
                            withAnimation(HeliumSpring.snappy) {
                                model.selectedSettingsTab = tab
                            }
                        } label: {
                            VStack(spacing: 3) {
                                HeliumAsset.icon(tab.iconName, size: 13, tint: isSelected ? .blue : .secondary)
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .blue : .primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.blue.opacity(0.14) : Color.primary.opacity(0.02))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch model.selectedSettingsTab {
                        case .general:
                            Toggle(
                                "Start Helium on bootup",
                                isOn: Binding(
                                    get: { model.openAtLogin },
                                    set: { model.setOpenAtLogin($0) }
                                )
                            )
                            .font(.caption.bold())

                            Text("Automatically launch Helium and mount /Volumes/Helium when your Mac starts up.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Divider()

                            Toggle(
                                "Run in taskbar (menu bar) only",
                                isOn: Binding(
                                    get: { model.runInTaskbarOnly },
                                    set: { model.setRunInTaskbarOnly($0, closeWindowImmediately: $0) }
                                )
                            )
                            .font(.caption.bold())

                            Text("Hide the Dock icon and keep Helium in the top macOS menu bar only.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Divider()

                            Toggle("Turn on Finder actions", isOn: $model.finderActionsEnabled)
                                .font(.caption)

                            Toggle("Send error reports", isOn: $model.sendErrorReports)
                                .font(.caption)

                        case .account:
                            HStack(spacing: 4) {
                                Text("Storage Pool Placement Engine")
                                    .font(.caption.bold())
                                FeatureHelpPopoverButton(topic: .placementEngine) {
                                    model.navigateToMainWindow(destination: .home)
                                    model.showHelpSheet = true
                                }
                            }
                            Picker("", selection: Binding(
                                get: { model.placementPolicy },
                                set: { policy in Task { await model.updateAllocatorPolicy(policy) } }
                            )) {
                                Text("Both (Smart Whole-File + Auto Striping)").tag(PlacementPolicy.automatic)
                                Text("Mode 1: Whole-File Smart Placement").tag(PlacementPolicy.preferWholeFile)
                                Text("Mode 2: Always Cross-Account Striping").tag(PlacementPolicy.alwaysStripe)
                            }
                            .labelsHidden()
                            .controlSize(.small)

                            Divider()

                            ForEach(model.linkedAccounts) { acc in
                                HStack {
                                    Text("#\(acc.uploadPriority)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                                    Text(acc.email)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    if acc.uploadPriority > 1 {
                                        Button("Make #1") {
                                            Task {
                                                await model.prioritiseAccountFirst(acc.id)
                                                await model.setPreferredUploadAccount(acc.id)
                                            }
                                        }
                                        .controlSize(.mini)
                                    }
                                }
                            }

                        case .privacy:
                            HStack(spacing: 6) {
                                Toggle(
                                    "End-to-end encryption (AES-256-GCM)",
                                    isOn: Binding(
                                        get: { model.zeroKnowledgeEnabled },
                                        set: { model.setZeroKnowledgeEnabled($0) }
                                    )
                                )
                                .font(.caption.bold())
                                FeatureHelpPopoverButton(topic: .zeroKnowledge) {
                                    model.navigateToMainWindow(destination: .home)
                                    model.showHelpSheet = true
                                }
                            }
                            HStack(spacing: 8) {
                                Button("Copy Recovery Key") {
                                    model.copyRecoveryKeyToClipboard()
                                }
                                .controlSize(.small)
                                Button("Save Key…") {
                                    model.saveRecoveryKeyToDisk()
                                }
                                .controlSize(.small)
                            }

                        case .storage:
                            Picker("Local Cache Limit", selection: $model.cacheLimitOption) {
                                ForEach(CacheLimitOption.allCases) { opt in
                                    Text(opt.rawValue).tag(opt)
                                }
                            }
                            .font(.caption)
                            .controlSize(.small)

                            Picker("Upload Speed", selection: $model.uploadSpeedOption) {
                                ForEach(UploadSpeedOption.allCases) { opt in
                                    Text(opt.rawValue).tag(opt)
                                }
                            }
                            .font(.caption)
                            .controlSize(.small)

                            Button("Clear Local Cache") {
                                model.removeRecentCachedFiles()
                            }
                            .controlSize(.small)

                        case .updates:
                            Toggle("Install updates automatically", isOn: $model.installUpdatesAutomatically)
                                .font(.caption.bold())
                            Text(model.lastUpdateCheckText)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Button("Check for Updates") {
                                model.checkForUpdates()
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 195)
            }
        }
    }
}

// MARK: - Storage Pool Optimizer, Duplicate Finder & Largest Files Inspector Card
struct StoragePoolOptimizerCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HeliumGlassCard(cornerRadius: 14, padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .foregroundStyle(.blue)
                            Text("Storage Pool Optimizer, Duplicate Finder & Catalog Export")
                                .font(.headline)
                        }
                        Text("Inspect your largest pooled files, reclaim wasted space from duplicates across folders, or export a full Markdown snapshot of your pool.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        model.copyPoolSummaryReportToClipboard()
                    } label: {
                        Label("Copy Report", systemImage: "list.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        model.exportPoolCatalogSnapshotToDisk()
                    } label: {
                        Label("Export Catalog (.md)…", systemImage: "doc.badge.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                HStack(alignment: .top, spacing: 14) {
                    // Column 1: Largest Pooled Files
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Largest Files in Pool", systemImage: "arrow.up.right.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("Top \(min(5, model.largestPooledFiles.count))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        if model.largestPooledFiles.isEmpty {
                            Text("No files in pool yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(model.largestPooledFiles.prefix(5)) { item in
                                HStack(spacing: 8) {
                                    let spec = HeliumAsset.fileIconAndColor(for: item.fileName, isFolder: false)
                                    Image(systemName: spec.symbol)
                                        .font(.caption.bold())
                                        .foregroundStyle(spec.color)
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.fileName)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text("\(item.primaryAccountEmail) • \(item.segmentsCount) seg\(item.segmentsCount == 1 ? "" : "s")")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                                        .font(.caption2.monospacedDigit().bold())

                                    if let node = model.findNode(remoteId: item.id, fileName: item.fileName) {
                                        Button("Inspect") {
                                            model.inspectedNode = node
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Column 2: Duplicate File Detector
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Duplicate File Detector", systemImage: "doc.on.doc.fill")
                                .font(.caption.bold())
                                .foregroundStyle(model.duplicateFileGroups.isEmpty ? .green : .orange)
                            Spacer()
                            if model.reclaimableDuplicateBytes > 0 {
                                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: model.reclaimableDuplicateBytes, countStyle: .file))")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                                    .foregroundStyle(.orange)
                            } else {
                                Text("0 duplicates")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            }
                        }

                        if model.duplicateFileGroups.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Clean pool — no duplicate files with identical names and byte sizes were detected across your folders.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.green.opacity(0.08))
                            )
                        } else {
                            ForEach(model.duplicateFileGroups.prefix(4)) { group in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.fileName)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Text("\(group.copiesCount) copies • \(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file)) wasted")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                    }
                                    Spacer()
                                    if let node = model.findNode(remoteId: "", fileName: group.fileName) {
                                        Button("Inspect") {
                                            model.inspectedNode = node
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }

                                    Button("Remove Copy") {
                                        Task { await model.removeExtraDuplicateCopy(for: group) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.mini)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - 30 Days to Undo a Delete Modal Sheet
struct ThirtyDayTrashModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("30 Days to Undo a Delete")
                        .font(.title3.bold())
                    Text("Deleted files stay safely recoverable in your Helium Pool Vault for 30 days while taking 0 bytes on your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !model.trashedItems.isEmpty {
                    Button("Restore Latest") {
                        model.undoLastDelete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Empty Trash", role: .destructive) {
                        Task { await model.emptyTrash() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            if model.trashedItems.isEmpty {
                VStack(spacing: 10) {
                    HeliumAnimatedMascot(name: "HeliumHappy", size: 58)
                    Text("Your 30-Day Trash is Empty")
                        .font(.headline)
                    Text("Whenever you delete a file in Helium, it appears here for 30 days so you can restore it in one click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.trashedItems) { item in
                            HStack(spacing: 12) {
                                let spec = HeliumAsset.fileIconAndColor(for: item.fileName, isFolder: false)
                                Image(systemName: spec.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(spec.color)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .font(.subheadline.bold())
                                    Text("\(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)) • \(item.accountSummary) • \(item.daysRemaining) day\(item.daysRemaining == 1 ? "" : "s") left to undo")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    Task { await model.restoreTrashedItem(item) }
                                } label: {
                                    Label("Undo Delete", systemImage: "arrow.uturn.backward")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    Task { await model.permanentlyDeleteTrashedItem(item) }
                                } label: {
                                    Text("Delete Forever")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(22)
        .frame(width: 620)
    }
}

// MARK: - Open Your Files on Any Device (Mac, Android, Windows, iOS) Modal Sheet
struct CrossDeviceAccessModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Your Files on Mac, Android, Windows & iPhone")
                        .font(.title3.bold())
                    Text("Your Helium files live inside your pooled Google Drive Vault folders and encrypted share links — accessible on every platform.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            HStack(spacing: 12) {
                platformCard(
                    symbol: "macbook",
                    title: "macOS Finder",
                    subtitle: "Mounted natively at /Volumes/Helium with 0 B on disk.",
                    buttonTitle: "Open in Finder"
                ) {
                    model.openInFinder()
                }

                platformCard(
                    symbol: "smartphone",
                    title: "Android & iPhone",
                    subtitle: "Open your Helium Pool Vault directly in the Google Drive mobile app or browser.",
                    buttonTitle: "Copy Mobile Vault Link"
                ) {
                    let target = model.linkedAccounts.first
                    let folderId = target?.rootFolderId ?? "root"
                    let urlStr = (folderId != "root" && !folderId.isEmpty)
                        ? "https://drive.google.com/drive/folders/\(folderId)"
                        : "https://drive.google.com/drive/my-drive"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(urlStr, forType: .string)
                    model.statusMessage = "Copied Helium Pool Vault URL for Android / iPhone / Windows"
                }

                platformCard(
                    symbol: "pc",
                    title: "Windows & Web",
                    subtitle: "Access whole-file items in any browser or unlock encrypted files with your 52-char Recovery Key.",
                    buttonTitle: "Open Web Vault"
                ) {
                    model.openGoogleDriveVaultInBrowser()
                }
            }

            HStack {
                CogifyBrandingView()
                Spacer()
                Button("View Recovery Key…") {
                    dismiss()
                    model.showRecoveryKeySheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(22)
        .frame(width: 640)
    }

    private func platformCard(
        symbol: String,
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(title)
                .font(.subheadline.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Native AVPlayerView Wrapper for Instant Real-Time Chunk Video Streaming
struct NativeAVPlayerWrapper: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

// MARK: - Real-Time 1 MiB Chunk & Video Streamer Modal Sheet ("helium only grabs the part your app needs, right when it needs it")
struct RealtimeChunkStreamerSheet: View {
    @ObservedObject var model: AppModel
    var initialNode: DriveNode?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedNode: DriveNode?
    @State private var player: AVPlayer?
    @State private var isStreamingChunk: Bool = false
    @State private var selectedChunkPreviewIndex: Int = 0
    @State private var chunkHexPreview: String = ""

    private var fileNodes: [DriveNode] {
        model.driveNodes.filter { !$0.isFolder }
    }

    private var activeNode: DriveNode? {
        selectedNode ?? initialNode ?? fileNodes.first
    }

    private func isPlayableMedia(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mp3", "m4a", "wav", "flac"].contains(ext)
    }

    private func cachedChunksSet(for node: DriveNode) -> Set<Int> {
        guard let remID = node.remoteID else { return [] }
        let total = max(1, Int((max(1, node.size) + Int64(HeliumRealtimeVFSServer.chunkSizeBytes) - 1) / Int64(HeliumRealtimeVFSServer.chunkSizeBytes)))
        return HeliumRealtimeVFSServer.shared.cachedChunkIndices(forRemoteID: remID, totalChunks: min(128, total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "bolt.horizontal.icloud.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Real-Time 1 MiB Chunk & Video Streamer")
                        .font(.title3.bold())
                    Text("Helium only grabs the exact 1 MiB chunk your app needs, right when it needs it — while keeping Zero bytes on disk in /Volumes/Helium.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    player?.pause()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            if fileNodes.isEmpty {
                VStack(spacing: 10) {
                    HeliumAnimatedMascot(name: "HeliumWink", size: 56)
                    Text("No Files in Current Folder")
                        .font(.headline)
                    Text("Drop a video, disk image, or document into Helium to inspect and stream its 1 MiB chunks in real time from Google Drive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // File Picker & Instant Actions
                HStack(spacing: 10) {
                    Picker("File in /Volumes/Helium:", selection: Binding(
                        get: { activeNode?.id ?? 0 },
                        set: { newID in
                            if let found = fileNodes.first(where: { $0.id == newID }) {
                                selectedNode = found
                                configureMediaPlayerIfNeeded(for: found)
                            }
                        }
                    )) {
                        ForEach(fileNodes) { f in
                            Text("\(f.name) (\(ByteCountFormatter.string(fromByteCount: f.size, countStyle: .file)))")
                                .tag(f.id)
                        }
                    }
                    .frame(maxWidth: 380)

                    Spacer()

                    if let node = activeNode {
                        Button {
                            model.openNodeOnMac(node)
                        } label: {
                            Label("Open in Default App", systemImage: "arrow.up.forward.app")
                        }
                        .controlSize(.small)

                        Button {
                            model.revealNodeInFinder(node)
                        } label: {
                            Label("Show in /Volumes/Helium", systemImage: "folder")
                        }
                        .controlSize(.small)
                    }
                }

                if let node = activeNode {
                    let totalChunks = max(1, Int((max(1, node.size) + Int64(HeliumRealtimeVFSServer.chunkSizeBytes) - 1) / Int64(HeliumRealtimeVFSServer.chunkSizeBytes)))
                    let displayLimit = min(64, totalChunks)
                    let cachedSet = cachedChunksSet(for: node)

                    // Native AVPlayerView when the selected file is a video or audio file
                    if isPlayableMedia(node.name), let player {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Live Video/Audio Stream from /Volumes/Helium/\(node.name)", systemImage: "play.rectangle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.indigo)
                                Spacer()
                                Text("Starts on Chunk #1 • Skip ahead to fetch any chunk on demand")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            NativeAVPlayerWrapper(player: player)
                                .frame(height: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    // Interactive 1 MiB Chunk Map Grid
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Interactive 1 MiB Chunk Map (\(totalChunks) total chunk\(totalChunks == 1 ? "" : "s"))", systemImage: "square.grid.3x3.fill")
                                    .font(.caption.bold())
                                Spacer()
                                HStack(spacing: 10) {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.green).frame(width: 7, height: 7)
                                        Text("Streamed (\(cachedSet.count))").font(.caption2)
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
                                        Text("Cloud Only (0 B on disk)").font(.caption2)
                                    }
                                }
                            }

                            Text("Click any 1 MiB chunk below to stream that exact byte range from your Google Drive pool in real time (just like skipping ahead in a video or opening a large project file).")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], spacing: 6) {
                                ForEach(0..<displayLimit, id: \.self) { idx in
                                    let isCached = cachedSet.contains(idx)
                                    let offsetMB = idx
                                    Button {
                                        streamSpecificChunk(node: node, chunkIndex: idx, totalChunks: totalChunks)
                                    } label: {
                                        VStack(spacing: 2) {
                                            HStack(spacing: 3) {
                                                Image(systemName: isCached ? "bolt.fill" : "icloud.and.arrow.down")
                                                    .font(.system(size: 9, weight: .bold))
                                                Text("#\(idx + 1)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            }
                                            Text("\(offsetMB)–\(offsetMB + 1) MB")
                                                .font(.system(size: 9))
                                                .opacity(0.85)
                                        }
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isCached ? Color.green.opacity(0.22) : Color.primary.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .strokeBorder(
                                                    selectedChunkPreviewIndex == idx
                                                        ? Color.indigo
                                                        : (isCached ? Color.green.opacity(0.55) : Color.secondary.opacity(0.18)),
                                                    lineWidth: selectedChunkPreviewIndex == idx ? 1.5 : 1
                                                )
                                        )
                                        .foregroundStyle(isCached ? .green : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if !chunkHexPreview.isEmpty {
                                HStack {
                                    Text("Chunk #\(selectedChunkPreviewIndex + 1) Header Preview:")
                                        .font(.caption2.bold())
                                    Text(chunkHexPreview)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(6)
                    }

                    // Live Chunk Read Events Log
                    GroupBox("Live Real-Time Chunk Stream Log") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if model.recentChunkEvents.isEmpty {
                                    Text("Click any chunk above or open a file in /Volumes/Helium to see real-time 1 MiB range reads.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(model.recentChunkEvents.prefix(12)) { ev in
                                        HStack(spacing: 8) {
                                            Image(systemName: ev.fromCache ? "memorychip" : "cloud.bolt.fill")
                                                .font(.caption2)
                                                .foregroundStyle(ev.fromCache ? .green : .indigo)
                                            Text(ev.fileName)
                                                .font(.caption.bold())
                                                .lineLimit(1)
                                            Text("Chunk #\(ev.chunkIndex + 1)/\(ev.totalChunks)")
                                                .font(.caption2.monospaced())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                                            Text("\(max(1, ev.bytesRead / 1024)) KB")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(ev.fromCache ? "Instant Cache (0 B on disk)" : "Google Drive HTTP Range 206")
                                                .font(.caption2)
                                                .foregroundStyle(ev.fromCache ? .green : .indigo)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 95)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 680)
        .onAppear {
            selectedNode = initialNode ?? fileNodes.first
            if let node = activeNode {
                configureMediaPlayerIfNeeded(for: node)
            }
        }
    }

    private func configureMediaPlayerIfNeeded(for node: DriveNode) {
        guard isPlayableMedia(node.name) else {
            player?.pause()
            player = nil
            return
        }
        if let remID = node.remoteID,
           let httpStreamURL = HeliumRealtimeVFSServer.shared.streamURL(forRemoteID: remID, fileName: node.name) {
            let avPlayer = AVPlayer(url: httpStreamURL)
            self.player = avPlayer
            avPlayer.play()
            return
        }
        let streamCacheURL = AppModel.streamCacheDirectoryURL.appendingPathComponent(node.name)
        let avPlayer = AVPlayer(url: streamCacheURL)
        self.player = avPlayer
        avPlayer.play()
    }

    private func streamSpecificChunk(node: DriveNode, chunkIndex: Int, totalChunks: Int) {
        guard !isStreamingChunk, let remID = node.remoteID else { return }
        isStreamingChunk = true
        selectedChunkPreviewIndex = chunkIndex
        let chunkSize = HeliumRealtimeVFSServer.chunkSizeBytes
        let offset = Int64(chunkIndex) * Int64(chunkSize)
        let readLen = Int(min(Int64(chunkSize), max(0, node.size - offset)))

        Task { @MainActor in
            defer { isStreamingChunk = false }
            do {
                let data = try await model.fetchRealtimeChunkFromPool(remoteID: remID, offset: offset, length: max(1, readLen))
                // Save to HeliumRealtimeVFSServer chunk cache so subsequent Finder reads hit instant cache
                let safeID = remID.replacingOccurrences(of: "/", with: "_")
                let itemDir = HeliumRealtimeVFSServer.shared.realtimeChunksRootURL.appendingPathComponent(safeID, isDirectory: true)
                try? FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)
                let chunkFile = itemDir.appendingPathComponent("chunk_\(chunkIndex).bin")
                try? data.write(to: chunkFile, options: .atomic)

                model.recordRealtimeChunkRead(
                    fileName: node.name,
                    chunkIndex: chunkIndex,
                    totalChunks: totalChunks,
                    bytesCount: data.count,
                    fromCache: false
                )
                let hexBytes = data.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " ")
                chunkHexPreview = "\(hexBytes) … (\(data.count) bytes streamed)"
            } catch {
                chunkHexPreview = "Error streaming chunk: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Encrypted File Requests Manager Sheet ("Request Files…")
struct FileRequestsManagerSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String = "Client Drops"
    @State private var requestTitle: String = "Send files to my Helium Drive"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Request Files into Helium")
                        .font(.title3.bold())
                    Text("Let anyone send you files via a link — sealed with an ephemeral P-256 key directly into your Helium Google Drive pool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Target Folder Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                TextField("Request Title", text: $requestTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Create & Copy Link") {
                    model.createFileRequest(folderName: folderName, title: requestTitle)
                }
                .buttonStyle(.borderedProminent)
            }

            if !model.fileRequests.isEmpty {
                Divider()
                Text("Active File Request Links")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.fileRequests) { req in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(req.title) → /\(req.folderName)")
                                        .font(.subheadline.bold())
                                    Text("\(req.urlString) • P-256 Public Key: \(req.publicKeyHex)…")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Copy Link") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(req.urlString, forType: .string)
                                    model.statusMessage = "Copied file request link to clipboard"
                                }
                                .controlSize(.small)
                                Button("Close") {
                                    model.closeFileRequest(id: req.id)
                                }
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(22)
        .frame(width: 580)
    }
}
