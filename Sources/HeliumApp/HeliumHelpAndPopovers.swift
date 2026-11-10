import AppKit
import OrbitCore
import SwiftUI

// MARK: - Cogify Branding Footer / Badge ("Made with ❤️ by cogify.me")
public struct CogifyBrandingView: View {
    public var compact: Bool
    @State private var isHoveringLink: Bool = false

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("Made with")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
            Text("❤️")
                .font(compact ? .caption2 : .caption)
            Text("by")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
            Button {
                if let url = URL(string: "https://cogify.me") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("cogify.me")
                    .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                    .foregroundStyle(isHoveringLink ? Color.blue : Color.accentColor)
                    .underline(isHoveringLink, color: .blue)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringLink = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("Visit https://cogify.me")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Made with love by cogify.me")
    }
}

// MARK: - Contextual Feature Help Topics & Popover Button
public enum HeliumFeatureHelpTopic: String, Identifiable, CaseIterable, Sendable {
    case placementEngine = "Storage Pool Placement Engine: Both vs Mode 1 vs Mode 2"
    case uploadPriority = "Google Account Upload Priority & Routing (#1 → #2 → #3)"
    case zeroKnowledge = "Zero-Knowledge Encryption vs Direct Google Drive Mode"
    case virtualDisk = "Finder Virtual Disk (/Volumes/Helium) & Offline Pinning"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var subtitle: String {
        switch self {
        case .placementEngine:
            return "Choose how Helium places and splits files across your linked Google Drives."
        case .uploadPriority:
            return "Control which Google Drive receives new uploads first and how overflow is handled."
        case .zeroKnowledge:
            return "Understand client-side AES-256-GCM encryption versus native Google Drive web compatibility."
        case .virtualDisk:
            return "How /Volumes/Helium streams files on demand without using local Mac SSD space."
        }
    }

    public var symbol: String {
        switch self {
        case .placementEngine: return "square.stack.3d.up.fill"
        case .uploadPriority: return "list.number"
        case .zeroKnowledge: return "lock.shield.fill"
        case .virtualDisk: return "externaldrive.fill.badge.icloud"
        }
    }

    public var accentColor: Color {
        switch self {
        case .placementEngine: return .blue
        case .uploadPriority: return .indigo
        case .zeroKnowledge: return .teal
        case .virtualDisk: return .purple
        }
    }

    public var items: [(badge: String, title: String, detail: String, color: Color)] {
        switch self {
        case .placementEngine:
            return [
                (
                    badge: "RECOMMENDED",
                    title: "Both (Smart Whole-File + Auto Striping)",
                    detail: "Hybrid mode. Stores everyday files (< threshold or fitting on a single drive) as one intact file in Google Drive so you can preview and open them directly on drive.google.com, and automatically switches to cross-account segment striping when a file is larger than any single account's free space.",
                    color: .blue
                ),
                (
                    badge: "MODE 1",
                    title: "Mode 1: Whole-File Smart Placement",
                    detail: "Always keeps every file as 1 complete, unsplit file on your highest-priority Google Drive account that has enough free space. Best when you want 100% of files directly playable and downloadable from Google Drive web without Helium.",
                    color: .green
                ),
                (
                    badge: "MODE 2",
                    title: "Mode 2: Always Cross-Account Striping",
                    detail: "Splits every uploaded file into encrypted/chunked segments (e.g. 64 MiB–256 MiB) distributed across all linked Google Drives in parallel. Maximizes combined upload/download bandwidth and pools small fragments of free space across accounts.",
                    color: .purple
                )
            ]
        case .uploadPriority:
            return [
                (
                    badge: "PRIORITY #1 → #2 → #3",
                    title: "Priority Order (#1 → #2 → #3…)",
                    detail: "Uploads go to your #1 Google Drive first until it fills up, then automatically overflow to #2, #3, and beyond. Reorder accounts anytime using the ↑ / ↓ buttons in the Google Drive Pool view.",
                    color: .blue
                ),
                (
                    badge: "MOST FREE",
                    title: "Most Free Space First",
                    detail: "Automatically picks whichever linked Google Drive currently has the most free gigabytes available for each new upload.",
                    color: .teal
                ),
                (
                    badge: "PINNED",
                    title: "Preferred Target Account",
                    detail: "Pins a specific Google Drive account for your next uploads, with automatic overflow to your other pooled drives if the preferred drive runs out of space.",
                    color: .indigo
                )
            ]
        case .zeroKnowledge:
            return [
                (
                    badge: "DIRECT DRIVE",
                    title: "Direct Google Drive Mode (Default in Mode 1)",
                    detail: "Files uploaded as Whole-File remain standard Google Drive files inside your 'Helium Pool' folder. You can preview videos, PDFs, and docs directly on drive.google.com from any device.",
                    color: .green
                ),
                (
                    badge: "ZERO-KNOWLEDGE",
                    title: "Zero-Knowledge Vault Encryption (AES-256-GCM)",
                    detail: "Encrypts file contents and filenames on your Mac before upload using a 256-bit master key stored in macOS Keychain. Google only sees opaque encrypted blocks.",
                    color: .blue
                ),
                (
                    badge: "52-CHAR KEY",
                    title: "Recovery Key Protection",
                    detail: "Your 52-character Recovery Key is the only way to unlock a Zero-Knowledge vault on a new Mac. Save it in Apple Passwords or keep an offline copy.",
                    color: .orange
                )
            ]
        case .virtualDisk:
            return [
                (
                    badge: "ZERO LOCAL SPACE",
                    title: "Instant On-Demand Streaming",
                    detail: "Files in /Volumes/Helium take 0 bytes on your Mac until opened. Helium fetches only the byte ranges requested by Finder, Quick Look, or Final Cut Pro.",
                    color: .blue
                ),
                (
                    badge: "KEEP OFFLINE",
                    title: "Pinning Files for Offline Use",
                    detail: "Click the pin icon on any file or folder to keep a full copy cached locally on your Mac for airplane or offline work.",
                    color: .orange
                ),
                (
                    badge: "SMART CACHE",
                    title: "Automatic LRU Cache Eviction",
                    detail: "Recently accessed blocks are cached up to your configured limit (Settings → Storage) and automatically evicted when macOS storage runs low.",
                    color: .teal
                )
            ]
        }
    }
}

public struct FeatureHelpPopoverButton: View {
    public let topic: HeliumFeatureHelpTopic
    public var onOpenHelpCenter: (() -> Void)?
    @State private var showPopover: Bool = false
    @State private var isHovering: Bool = false

    public init(topic: HeliumFeatureHelpTopic, onOpenHelpCenter: (() -> Void)? = nil) {
        self.topic = topic
        self.onOpenHelpCenter = onOpenHelpCenter
    }

    public var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering || showPopover ? topic.accentColor : Color.secondary.opacity(0.75))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isHovering || showPopover ? topic.accentColor.opacity(0.14) : Color.clear)
                )
                .scaleEffect(isHovering ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Learn more about \(topic.title)")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [topic.accentColor.opacity(0.22), topic.accentColor.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: topic.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(topic.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic.title)
                            .font(.subheadline.bold())
                        Text(topic.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(topic.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text(item.badge)
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(item.color.opacity(0.16))
                                    .foregroundStyle(item.color)
                                    .clipShape(Capsule())
                                Text(item.title)
                                    .font(.caption.bold())
                            }
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(item.color.opacity(0.22), lineWidth: 1)
                        )
                    }
                }

                HStack {
                    CogifyBrandingView(compact: true)
                    Spacer()
                    if let onOpenHelpCenter {
                        Button {
                            showPopover = false
                            onOpenHelpCenter()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Open Interactive Help Center")
                                Image(systemName: "arrow.up.right.circle.fill")
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(width: 440)
        }
    }
}

// MARK: - Redesigned Interactive Helium Help Center Sheet & Embedded View
public struct HeliumHelpCenterSheet: View {
    public enum HelpCategory: String, CaseIterable, Identifiable, Sendable {
        case startHere = "START HERE"
        case poolEngine = "STORAGE POOL ENGINE"
        case diskAndSecurity = "DISK & PRIVACY"
        case diagnosticsAndSupport = "DOCTOR & SUPPORT"

        public var id: String { rawValue }
    }

    public enum HelpArticle: String, CaseIterable, Identifiable, Sendable {
        case overview = "Quick Start & Architecture"
        case placementEngine = "Placement Engine & Simulator"
        case accountPriority = "Account Priority & Migration"
        case virtualDisk = "Finder Disk & Offline Pinning"
        case privacyAndEncryption = "Zero-Knowledge & Recovery Key"
        case shortcutsAndTroubleshooting = "System Doctor, Shortcuts & FAQ"
        case contactAndEmailSupport = "Email Support (connect@cogify.me)"

        public var id: String { rawValue }

        public var category: HelpCategory {
            switch self {
            case .overview:
                return .startHere
            case .placementEngine, .accountPriority:
                return .poolEngine
            case .virtualDisk, .privacyAndEncryption:
                return .diskAndSecurity
            case .shortcutsAndTroubleshooting, .contactAndEmailSupport:
                return .diagnosticsAndSupport
            }
        }

        public var symbol: String {
            switch self {
            case .overview: return "sparkles"
            case .placementEngine: return "square.stack.3d.up.fill"
            case .accountPriority: return "list.number"
            case .virtualDisk: return "externaldrive.fill.badge.icloud"
            case .privacyAndEncryption: return "lock.shield.fill"
            case .shortcutsAndTroubleshooting: return "stethoscope"
            case .contactAndEmailSupport: return "envelope.badge.fill"
            }
        }

        public var tint: Color {
            switch self {
            case .overview: return .blue
            case .placementEngine: return .purple
            case .accountPriority: return .indigo
            case .virtualDisk: return .teal
            case .privacyAndEncryption: return .green
            case .shortcutsAndTroubleshooting: return .orange
            case .contactAndEmailSupport: return .pink
            }
        }

        public var badgeText: String {
            switch self {
            case .overview: return "GUIDE"
            case .placementEngine: return "INTERACTIVE"
            case .accountPriority: return "LIVE QUEUE"
            case .virtualDisk: return "FINDER"
            case .privacyAndEncryption: return "AES-256"
            case .shortcutsAndTroubleshooting: return "DOCTOR"
            case .contactAndEmailSupport: return "DIRECT MAIL"
            }
        }

        public var summary: String {
            switch self {
            case .overview:
                return "How Helium combines multiple Google Drives into /Volumes/Helium."
            case .placementEngine:
                return "Compare Both, Mode 1, and Mode 2 + test file sizes in the live simulator."
            case .accountPriority:
                return "Control #1 → #2 → #3 upload priority and move files across accounts."
            case .virtualDisk:
                return "Stream files with 0 local bytes, pin offline, and manage LRU cache."
            case .privacyAndEncryption:
                return "Direct Google Drive mode vs Zero-Knowledge E2EE & 52-char Recovery Key."
            case .shortcutsAndTroubleshooting:
                return "Run the 1-click System & Pool Health Doctor, view shortcuts, and browse FAQs."
            case .contactAndEmailSupport:
                return "Compose support, bug report, or feature emails to connect@cogify.me."
            }
        }
    }

    @ObservedObject var model: AppModel
    public var isEmbeddedInMainWindow: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedArticle: HelpArticle
    @State private var searchQuery: String = ""
    @State private var simulatedFileSizeGB: Double = 2.5
    @State private var simulatedPolicy: PlacementPolicy = .automatic
    @State private var expandedFAQIndex: Int? = 0

    public init(
        model: AppModel,
        initialArticle: HelpArticle = .overview,
        isEmbeddedInMainWindow: Bool = false
    ) {
        self.model = model
        self.isEmbeddedInMainWindow = isEmbeddedInMainWindow
        self._selectedArticle = State(initialValue: initialArticle)
    }

    private var filteredArticles: [HelpArticle] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return HelpArticle.allCases }
        return HelpArticle.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(trimmed) ||
            $0.summary.localizedCaseInsensitiveContains(trimmed) ||
            $0.badgeText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            helpHeroHeaderBar

            Divider()

            HStack(spacing: 0) {
                helpNavigationRail

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        articleDetailView(for: selectedArticle)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
            }

            Divider()

            helpFooterBar
        }
        .frame(
            minWidth: isEmbeddedInMainWindow ? 680 : 900,
            idealWidth: isEmbeddedInMainWindow ? nil : 920,
            maxWidth: .infinity,
            minHeight: isEmbeddedInMainWindow ? 540 : 640,
            idealHeight: isEmbeddedInMainWindow ? nil : 650,
            maxHeight: .infinity
        )
        .onAppear {
            simulatedPolicy = model.placementPolicy
            if model.diagnosticChecks.isEmpty {
                Task { await model.runSystemHealthDoctor() }
            }
        }
    }

    // MARK: - Top Hero Header Bar
    private var helpHeroHeaderBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                HeliumAnimatedMascot(name: "HeliumHappy", size: 48, showAura: true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Helium Knowledge & Diagnostic Center")
                            .font(.title3.bold())

                        Text("v\(AppModel.appVersion) • BUILD \(AppModel.appBuild)")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.16))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())

                        HStack(spacing: 4) {
                            Circle()
                                .fill(model.isMounted ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(model.isMounted ? "/Volumes/Helium Ready" : "Pool Ready")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background((model.isMounted ? Color.green : Color.orange).opacity(0.14))
                        .foregroundStyle(model.isMounted ? .green : .orange)
                        .clipShape(Capsule())
                    }

                    Text("Interactive guides, live Placement Engine simulator, System Health Doctor, and direct engineering support.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Search Box
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search topics, modes, shortcuts…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 190)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )

                if !isEmbeddedInMainWindow {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.07),
                    Color.purple.opacity(0.04),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Left Categorized Navigation Rail
    private var helpNavigationRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(HelpCategory.allCases) { category in
                    let categoryArticles = filteredArticles.filter { $0.category == category }
                    if !categoryArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)

                            ForEach(categoryArticles) { article in
                                let isSelected = selectedArticle == article
                                Button {
                                    withAnimation(HeliumSpring.snappy) {
                                        selectedArticle = article
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(isSelected ? article.tint : article.tint.opacity(0.14))
                                                .frame(width: 28, height: 28)
                                            Image(systemName: article.symbol)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(isSelected ? .white : article.tint)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 5) {
                                                Text(article.rawValue)
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Spacer(minLength: 0)
                                                Text(article.badgeText)
                                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(article.tint.opacity(0.16))
                                                    .foregroundStyle(article.tint)
                                                    .clipShape(Capsule())
                                            }
                                            Text(article.summary)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .padding(9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isSelected ? article.tint.opacity(0.14) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(isSelected ? article.tint.opacity(0.35) : Color.clear, lineWidth: 1)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // Quick Pool Snapshot Card inside Rail
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("YOUR POOL SNAPSHOT")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(model.linkedAccounts.count) Drive\(model.linkedAccounts.count == 1 ? "" : "s")")
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                    }
                    Text("\(ByteCountFormatter.string(fromByteCount: model.totalFreeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: model.totalPoolBytes, countStyle: .file))")
                        .font(.caption.bold())
                    Text("Active Mode: \(model.policyDescription(model.placementPolicy))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Footer Bar
    private var helpFooterBar: some View {
        HStack(spacing: 12) {
            CogifyBrandingView()

            Button {
                withAnimation(HeliumSpring.snappy) {
                    selectedArticle = .contactAndEmailSupport
                }
            } label: {
                Label("connect@cogify.me", systemImage: "envelope.fill")
                    .font(.caption2.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                withAnimation(HeliumSpring.snappy) {
                    selectedArticle = .shortcutsAndTroubleshooting
                }
                Task { await model.runSystemHealthDoctor() }
            } label: {
                Label("Run System Doctor", systemImage: "stethoscope")
                    .font(.caption2.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Text("Helium v\(AppModel.appVersion) (Build \(AppModel.appBuild)) • Multi-Account Google Drive Virtual Pool")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Article Detail Dispatcher
    @ViewBuilder
    private func articleDetailView(for article: HelpArticle) -> some View {
        switch article {
        case .overview:
            overviewArticleContent
        case .placementEngine:
            placementEngineArticleContent
        case .accountPriority:
            accountPriorityArticleContent
        case .virtualDisk:
            virtualDiskArticleContent
        case .privacyAndEncryption:
            privacyAndEncryptionArticleContent
        case .shortcutsAndTroubleshooting:
            shortcutsAndDoctorArticleContent
        case .contactAndEmailSupport:
            contactSupportArticleContent
        }
    }

    // MARK: - 1. Overview & Quick Start Content
    private var overviewArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Welcome to Helium Pool",
                subtitle: "Combine multiple Google Drive accounts into one fast, unified macOS virtual disk at /Volumes/Helium.",
                symbol: "sparkles",
                tint: .blue
            )

            // Interactive Quick Actions Launchpad
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK ACTIONS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    quickActionCard(
                        title: "Open /Volumes/Helium in Finder",
                        subtitle: "Browse your unified cloud drive directly in macOS Finder.",
                        symbol: "folder.fill",
                        color: .blue,
                        buttonTitle: "Open Finder"
                    ) {
                        model.openInFinder()
                    }

                    quickActionCard(
                        title: "Link Another Google Account",
                        subtitle: "Add +15 GB (or Workspace storage) to your Helium pool.",
                        symbol: "plus.circle.fill",
                        color: .green,
                        buttonTitle: "+ Add Google Account"
                    ) {
                        model.startBrowserOAuthFlow()
                    }

                    quickActionCard(
                        title: "Startup & Menu Bar Preferences",
                        subtitle: "Choose whether Helium starts on bootup or runs in the taskbar only.",
                        symbol: "menubar.rectangle",
                        color: .purple,
                        buttonTitle: "Configure Startup…"
                    ) {
                        model.askStartupPreferencesAgain()
                    }

                    quickActionCard(
                        title: "Open Helium Pool in Google Drive Web",
                        subtitle: "Inspect your 'Helium Pool' folder directly on drive.google.com.",
                        symbol: "safari.fill",
                        color: .orange,
                        buttonTitle: "Open Google Drive"
                    ) {
                        model.openGoogleDriveVaultInBrowser()
                    }
                }
            }
        }
    }

    // MARK: - 2. Placement Engine & Interactive Simulator Content
    private var placementEngineArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Storage Pool Placement Engine & Live Simulator",
                subtitle: "Compare Both (Hybrid), Mode 1 (Whole-File), and Mode 2 (Cross-Account Striping) — or switch modes with one click.",
                symbol: "square.stack.3d.up.fill",
                tint: .purple
            )

            // Interactive Mode Switcher Cards
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SELECT ACTIVE PLACEMENT MODE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Currently Active: \(model.policyDescription(model.placementPolicy))")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }

                placementModeInteractiveCard(
                    policy: .automatic,
                    badge: "RECOMMENDED • HYBRID",
                    title: "Both (Smart Whole-File + Auto Striping)",
                    detail: "Keeps files smaller than \(String(format: "%.1f", model.autoStripeAboveGB)) GB (that fit on one account) as a single intact file in Google Drive so you can preview them on drive.google.com, and automatically stripes larger files across accounts.",
                    color: .blue
                )

                placementModeInteractiveCard(
                    policy: .preferWholeFile,
                    badge: "MODE 1 • 100% WEB PLAYABLE",
                    title: "Mode 1: Whole-File Smart Placement",
                    detail: "Always places each uploaded file onto a single Google Drive account (#1 → #2 → #3) as a complete unsplit file. Best when you want every file directly accessible from Google Drive web without Helium.",
                    color: .green
                )

                placementModeInteractiveCard(
                    policy: .alwaysStripe,
                    badge: "MODE 2 • PARALLEL STRIPING",
                    title: "Mode 2: Always Cross-Account Striping",
                    detail: "Splits every file into \(model.segmentSizeMiB) MiB segments distributed across all linked Google Drives in parallel. Combines small pockets of free space across multiple accounts into one large contiguous volume.",
                    color: .purple
                )
            }

            // Live Interactive Placement Simulator
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Interactive File Placement Simulator", systemImage: "slider.horizontal.below.square.and.square.filled")
                        .font(.subheadline.bold())
                    Spacer()
                    Picker("Simulate Mode:", selection: $simulatedPolicy) {
                        Text("Both (Hybrid)").tag(PlacementPolicy.automatic)
                        Text("Mode 1 (Whole-File)").tag(PlacementPolicy.preferWholeFile)
                        Text("Mode 2 (Always Stripe)").tag(PlacementPolicy.alwaysStripe)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                HStack(spacing: 16) {
                    Text("Test File Size: \(String(format: "%.1f", simulatedFileSizeGB)) GB")
                        .font(.caption.monospacedDigit().bold())
                        .frame(width: 140, alignment: .leading)

                    Slider(value: $simulatedFileSizeGB, in: 0.2...24.0, step: 0.2)

                    Button("0.5 GB") { simulatedFileSizeGB = 0.5 }
                        .controlSize(.mini)
                    Button("5.0 GB") { simulatedFileSizeGB = 5.0 }
                        .controlSize(.mini)
                    Button("18.0 GB") { simulatedFileSizeGB = 18.0 }
                        .controlSize(.mini)
                }

                let allocations = model.simulatePlacementPlan(fileSizeGB: simulatedFileSizeGB, policy: simulatedPolicy)
                let isWhole = allocations.first?.isWholeFile ?? true

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isWhole
                             ? "Result: Stored as 1 Intact Whole File on \(allocations.first?.accountEmail ?? "Primary Account")"
                             : "Result: Striped into \(allocations.count) Parallel Segments Across \(Set(allocations.map(\.accountEmail)).count) Google Drive(s)")
                            .font(.caption.bold())
                            .foregroundStyle(isWhole ? .green : .purple)
                        Spacer()
                        Text(isWhole ? "Direct Google Drive Web Preview Supported" : "Requires Helium to Reassemble Segments")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allocations.prefix(12)) { seg in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(seg.isWholeFile ? "WHOLE FILE" : "SEGMENT #\(seg.segmentIndex + 1)")
                                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                                        .foregroundStyle(seg.isWholeFile ? .green : .purple)
                                    Text(seg.accountEmail)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: seg.bytes, countStyle: .file))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill((seg.isWholeFile ? Color.green : Color.purple).opacity(0.12))
                                )
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - 3. Account Priority & Migration Content
    private var accountPriorityArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Google Account Upload Priority (#1 → #2 → #3) & File Migration",
                subtitle: "Control the exact order your Google Drives fill up and migrate existing files between accounts anytime.",
                symbol: "list.number",
                tint: .indigo
            )

            ForEach(Array(HeliumFeatureHelpTopic.uploadPriority.items.enumerated()), id: \.offset) { _, item in
                helpBadgedCard(badge: item.badge, title: item.title, detail: item.detail, color: item.color)
            }

            // Live Interactive Account Queue inside Help
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Your Live Google Drive Upload Priority Queue", systemImage: "arrow.up.arrow.down.circle.fill")
                        .font(.subheadline.bold())
                    Spacer()
                    Button("+ Link Google Account") {
                        model.startBrowserOAuthFlow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if model.linkedAccounts.isEmpty {
                    Text("No Google Drive accounts connected yet. Click '+ Link Google Account' above to connect your first drive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(Array(model.linkedAccounts.enumerated()), id: \.element.id) { idx, acc in
                        let isPrimary = model.primaryUploadTargetAccount?.id == acc.id
                        HStack(spacing: 12) {
                            Text("#\(acc.uploadPriority)")
                                .font(.system(.caption, design: .rounded).bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isPrimary ? Color.blue : Color.secondary.opacity(0.18))
                                .foregroundStyle(isPrimary ? .white : .primary)
                                .clipShape(Capsule())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(acc.email)
                                        .font(.caption.bold())
                                    if isPrimary {
                                        Text("PRIMARY TARGET")
                                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.16))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(ByteCountFormatter.string(fromByteCount: acc.freeBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: acc.quotaLimitBytes, countStyle: .file)) • \(model.filesCountForAccount(acc.id)) files")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if model.linkedAccounts.count > 1 {
                                Button {
                                    Task { await model.moveAccountPriority(acc.id, delta: -1) }
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .controlSize(.mini)
                                .disabled(idx == 0)

                                Button {
                                    Task { await model.moveAccountPriority(acc.id, delta: 1) }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .controlSize(.mini)
                                .disabled(idx == model.linkedAccounts.count - 1)
                            }

                            if !isPrimary {
                                Button("Make #1") {
                                    Task {
                                        await model.prioritiseAccountFirst(acc.id)
                                        await model.setPreferredUploadAccount(acc.id)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    // MARK: - 4. Virtual Disk & Offline Pinning Content
    private var virtualDiskArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Finder Virtual Disk (/Volumes/Helium) & Offline Pinning",
                subtitle: "Stream terabytes of cloud files on demand with zero local SSD footprint, or pin important files for offline travel.",
                symbol: "externaldrive.fill.badge.icloud",
                tint: .teal
            )

            ForEach(Array(HeliumFeatureHelpTopic.virtualDisk.items.enumerated()), id: \.offset) { _, item in
                helpBadgedCard(badge: item.badge, title: item.title, detail: item.detail, color: item.color)
            }

            HStack(spacing: 12) {
                Button {
                    model.openInFinder()
                } label: {
                    Label("Open /Volumes/Helium in Finder", systemImage: "folder.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await model.syncWithGoogleDrive() }
                } label: {
                    Label("Sync Pool Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)

                Button {
                    model.removeRecentCachedFiles()
                } label: {
                    Label("Clear Recent Local Cache (\(ByteCountFormatter.string(fromByteCount: model.cachedBytesOnMac, countStyle: .file)))", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 5. Privacy & Encryption Content
    private var privacyAndEncryptionArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Privacy, Zero-Knowledge Encryption & Recovery Key",
                subtitle: "Choose between Direct Google Drive compatibility and client-side AES-256-GCM Zero-Knowledge encryption.",
                symbol: "lock.shield.fill",
                tint: .green
            )

            ForEach(Array(HeliumFeatureHelpTopic.zeroKnowledge.items.enumerated()), id: \.offset) { _, item in
                helpBadgedCard(badge: item.badge, title: item.title, detail: item.detail, color: item.color)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        model.zeroKnowledgeEnabled
                            ? "Current Mode: Zero-Knowledge E2EE Enabled"
                            : "Current Mode: Direct Google Drive Mode (Human-Readable Files)",
                        systemImage: model.zeroKnowledgeEnabled ? "lock.shield.fill" : "externaldrive.fill.badge.icloud"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(model.zeroKnowledgeEnabled ? .green : .blue)

                    Spacer()

                    Toggle(
                        "Enable Zero-Knowledge E2EE",
                        isOn: Binding(
                            get: { model.zeroKnowledgeEnabled },
                            set: { model.setZeroKnowledgeEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        model.copyRecoveryKeyToClipboard()
                    } label: {
                        Label("Copy 52-Char Recovery Key", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)

                    Button {
                        model.saveRecoveryKeyToDisk()
                    } label: {
                        Label("Save Recovery Key File…", systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.small)

                    Button {
                        model.openApplePasswordsApp()
                    } label: {
                        Label("Open Apple Passwords", systemImage: "key.fill")
                    }
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    // MARK: - 6. System Doctor, Shortcuts & FAQ Content
    private var shortcutsAndDoctorArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "System & Pool Health Doctor, Shortcuts & FAQ",
                subtitle: "Run automated health checks on your Helium drive and Google OAuth tokens, or browse keyboard shortcuts.",
                symbol: "stethoscope",
                tint: .orange
            )

            // Interactive System & Pool Health Doctor Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("System & Storage Pool Health Doctor", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        Task { await model.runSystemHealthDoctor() }
                    } label: {
                        Label("Re-Run Diagnostics", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                ForEach(model.diagnosticChecks) { check in
                    let statusColor: Color = {
                        switch check.status {
                        case .healthy: return .green
                        case .warning: return .orange
                        case .actionNeeded: return .red
                        }
                    }()

                    HStack(spacing: 12) {
                        Image(systemName: check.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .frame(width: 28, height: 28)
                            .background(statusColor.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(check.title)
                                    .font(.caption.bold())
                                Text(check.status.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(statusColor.opacity(0.16))
                                    .foregroundStyle(statusColor)
                                    .clipShape(Capsule())
                            }
                            Text(check.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let actionTitle = check.actionTitle {
                            Button(actionTitle) {
                                performDiagnosticAction(for: check.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Keyboard Shortcuts Grid
            VStack(alignment: .leading, spacing: 10) {
                Text("KEYBOARD SHORTCUTS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    shortcutRowCard(keys: "⌃ ⌥ O", title: "Global Spotlight Search", subtitle: "Search across all pooled Google Drives from anywhere")
                    shortcutRowCard(keys: "⌘ R", title: "Sync with Google Pool", subtitle: "Refresh files and quotas across all linked accounts")
                    shortcutRowCard(keys: "⇧ ⌘ O", title: "Open /Volumes/Helium", subtitle: "Open your Helium virtual drive directly in Finder")
                    shortcutRowCard(keys: "⇧ ⌘ B", title: "Rebalance Storage Pool", subtitle: "Migrate whole files onto drives with more free space")
                    shortcutRowCard(keys: "⌘ ,", title: "Open Helium Settings", subtitle: "Configure General, Account, Privacy, Storage & Updates")
                    shortcutRowCard(keys: "⌘ ?", title: "Open Help Center", subtitle: "Launch this interactive Knowledge & Diagnostic Center")
                }
            }

            // Expandable FAQ Accordion
            VStack(alignment: .leading, spacing: 8) {
                Text("FREQUENTLY ASKED QUESTIONS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(Array(faqItems.enumerated()), id: \.offset) { idx, faq in
                    let isExpanded = expandedFAQIndex == idx
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(HeliumSpring.snappy) {
                                expandedFAQIndex = isExpanded ? nil : idx
                            }
                        } label: {
                            HStack {
                                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                                    .foregroundStyle(.blue)
                                Text(faq.question)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            Text(faq.answer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                                .padding(.leading, 22)
                                .transition(.opacity)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }
        }
    }

    // MARK: - 7. Contact & Email Support Content (connect@cogify.me)
    private var contactSupportArticleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            helpArticleHeader(
                title: "Write Email to connect@cogify.me",
                subtitle: "Choose an email template below, customize your note, and launch it in Mail or copy the complete draft to your clipboard.",
                symbol: "envelope.badge.fill",
                tint: .pink
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CHOOSE EMAIL TEMPLATE")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.copySupportEmailAddress()
                    } label: {
                        Label("Copy connect@cogify.me", systemImage: "doc.on.doc")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SupportEmailTemplate.allCases) { tmpl in
                        let selected = model.selectedEmailTemplate == tmpl
                        Button {
                            model.selectedEmailTemplate = tmpl
                            model.feedbackText = tmpl.defaultPromptPlaceholder
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tmpl.symbol)
                                Text(tmpl.rawValue)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Color.blue.opacity(0.18) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(selected ? .blue : .primary)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                let draft = model.buildSupportEmailDraft(
                    template: model.selectedEmailTemplate,
                    customNotes: model.feedbackText,
                    includeDiagnostics: model.feedbackIncludeDiagnostics
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("To:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(AppModel.supportEmail)
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("Subject: \(draft.subject)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
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
                    .frame(height: 150)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                    Toggle("Include Helium v\(AppModel.appVersion) & Storage Pool diagnostics in email", isOn: $model.feedbackIncludeDiagnostics)
                        .font(.caption)

                    HStack(spacing: 10) {
                        Button {
                            model.composeSupportEmail(
                                template: model.selectedEmailTemplate,
                                customNotes: model.feedbackText,
                                includeDiagnostics: model.feedbackIncludeDiagnostics
                            )
                        } label: {
                            Label("Open in Mail App (connect@cogify.me)", systemImage: "paperplane.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.copySupportEmailDraft(
                                template: model.selectedEmailTemplate,
                                customNotes: model.feedbackText,
                                includeDiagnostics: model.feedbackIncludeDiagnostics
                            )
                        } label: {
                            Label("Copy Complete Email Draft", systemImage: "doc.on.clipboard")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }

    // MARK: - Helper Subviews
    private var faqItems: [(question: String, answer: String)] {
        [
            (
                question: "Where do my uploaded files appear in Google Drive web?",
                answer: "Every file uploaded by Helium is stored inside a dedicated 'Helium Pool' folder in the root of your linked Google Drive account(s). In Mode 1 or Both (for whole files), you can open, preview, and download them directly on drive.google.com."
            ),
            (
                question: "What happens when my #1 Priority Google Drive fills up?",
                answer: "Helium automatically overflows to your #2, #3, and subsequent Google Drive accounts in your priority queue—or stripes a huge file across multiple accounts in Mode 2 / Both mode—without interrupting your upload."
            ),
            (
                question: "How do I stop the Startup / Taskbar prompt from asking me on launch?",
                answer: "Check the 'Don't ask me again' checkbox inside the 'How should Helium run on your Mac?' prompt (or click Save Preferences). You can change Startup and Taskbar-only settings anytime in Settings → General or the Menu Bar popover."
            ),
            (
                question: "How can I move an existing file from one Google account to another?",
                answer: "In Helium Home, right-click any file (or click the 'i' inspector icon) and select 'Move to Google Account → <email>'. Helium migrates the file between your Google Drives while keeping its path in /Volumes/Helium unchanged."
            )
        ]
    }

    private func performDiagnosticAction(for checkID: String) {
        switch checkID {
        case "mount":
            model.openInFinder()
        case "accounts":
            model.startBrowserOAuthFlow()
        case "security":
            model.saveRecoveryKeyToDisk()
        default:
            break
        }
    }

    private func helpArticleHeader(title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.24), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func architectureStepCard(step: String, title: String, detail: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(step)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.16))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.caption.bold())
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: . topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
        )
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.bold())
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Spacer()
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func placementModeInteractiveCard(
        policy: PlacementPolicy,
        badge: String,
        title: String,
        detail: String,
        color: Color
    ) -> some View {
        let isActive = model.placementPolicy == policy
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(badge)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.16))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                if isActive {
                    Label("ACTIVE MODE", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Button("Activate Mode") {
                        Task { await model.updateAllocatorPolicy(policy) }
                        simulatedPolicy = policy
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? color.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? color.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func shortcutRowCard(keys: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.14))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func helpBadgedCard(badge: String, title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(badge)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.16))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
                Text(title)
                    .font(.subheadline.bold())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }
}
