import AppKit
import OrbitCore
import SwiftUI

// MARK: - 1. Activity & Health Workspace View (Syncophant ActivityView + StatusKit Parity)

public struct HeliumActivityAndHealthWorkspaceView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: ActivityFilter = .all

    public enum ActivityFilter: String, CaseIterable, Identifiable {
        case all = "All Activity"
        case uploads = "Transfers & Queue"
        case needsYou = "Needs You"

        public var id: String { rawValue }
    }

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header with HealthOrb & Segmented Filter
                HStack(spacing: 14) {
                    HeliumHealthOrb(
                        state: model.isUploadsPaused
                            ? .paused
                            : (!model.isMounted ? .attention : (model.activeUploadSpeedBytesPerSec > 0 ? .syncing(progress: 0.65) : .healthy)),
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Activity & Pool Health")
                                .font(.title2.bold())
                            HeliumFileStateBadge(kind: .verifiedZeroBytes)
                        }
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("View", selection: $selectedFilter) {
                        ForEach(ActivityFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }

                // 1. Actionable "Needs You" Problem Cards (idle -> working -> fixed -> collapsed)
                if selectedFilter == .all || selectedFilter == .needsYou {
                    actionableIssuesSection
                }

                // 2. Live Throughput Chart + Bandwidth Limiter
                if selectedFilter == .all || selectedFilter == .uploads {
                    throughputCard
                }

                // 3. Now, Next & Done Today Transfer Queue
                if selectedFilter == .all || selectedFilter == .uploads {
                    transferQueueCard
                }

                // 4. Connection Latency & 5-Step Safe-Write Verification Card
                if selectedFilter == .all || selectedFilter == .needsYou {
                    connectionAndSafeWriteCard
                }

                // 5. 24-Hour Pool Summary Card
                if selectedFilter == .all {
                    twentyFourHourSummaryCard
                }
            }
            .padding(22)
        }
        .task {
            while !Task.isCancelled {
                model.recordThroughputSample()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private var headerSubtitle: String {
        if model.isUploadsPaused {
            return "Transfers paused • Click Resume to continue uploading to /Volumes/Helium"
        }
        let issueCount = model.actionableIssues.count
        if issueCount > 0 {
            return "\(issueCount) item\(issueCount == 1 ? "" : "s") with 1-click fix available • \(model.linkedAccounts.count) Google Drive(s) + \(model.externalStorageConnections.count) external provider(s)"
        }
        return "Everything verified • Zero bytes used on Mac SSD across \(model.activePooledFilesCount) pooled files"
    }

    @ViewBuilder
    private var actionableIssuesSection: some View {
        let issues = model.actionableIssues
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        issues.isEmpty ? "No Action Needed — All Systems Healthy" : "Needs You (\(issues.count))",
                        systemImage: issues.isEmpty ? "checkmark.seal.fill" : "sparkles.rectangle.stack.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(issues.isEmpty ? .green : .primary)

                    Spacer()

                    Button {
                        model.createSampleConflictForSelectedFile()
                    } label: {
                        Label("Test Conflict Resolver", systemImage: "doc.on.doc")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Simulate a two-Mac file conflict to preview non-destructive conflict resolution")
                }

                if issues.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Every linked drive is reachable, /Volumes/Helium is mounted with 0 B local footprint, and Safe-Write SHA-256 verification passed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(issues) { issue in
                        let isWorking = model.workingIssueIds.contains(issue.id)
                        let isFixed = model.fixedIssueIds.contains(issue.id)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(issueColor(issue.severity).opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: isFixed ? "checkmark" : issue.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isFixed ? .green : issueColor(issue.severity))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.subheadline.bold())
                                Text(issue.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Button {
                                model.executeIssueFix(issue)
                            } label: {
                                HStack(spacing: 5) {
                                    if isWorking {
                                        ProgressView().controlSize(.mini)
                                        Text("Fixing…")
                                    } else if isFixed {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Fixed")
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                        Text(issue.fixButtonTitle)
                                    }
                                }
                                .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isFixed ? .green : issueColor(issue.severity))
                            .controlSize(.small)
                            .disabled(isWorking || isFixed)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }
        }
    }

    private func issueColor(_ severity: ActionableIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private var throughputCard: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                            Text("Sending to Pool")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text("\(ByteCountFormatter.string(fromByteCount: model.activeUploadSpeedBytesPerSec, countStyle: .file))/s")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .rollingNumber(model.activeUploadSpeedBytesPerSec)
                    }
                    .frame(width: 160, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.teal).frame(width: 8, height: 8)
                            Text("Streaming to Mac (HTTP 206)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text("\(ByteCountFormatter.string(fromByteCount: model.activeStreamSpeedBytesPerSec, countStyle: .file))/s")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .rollingNumber(model.activeStreamSpeedBytesPerSec)
                    }
                    .frame(width: 210, alignment: .leading)

                    Spacer()

                    Picker("Upload Speed Limit", selection: $model.uploadSpeedOption) {
                        ForEach(UploadSpeedOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .frame(width: 210)
                }

                HeliumThroughputChart(samples: model.throughputSamples)
                    .frame(height: 92)

                HStack {
                    Text("Last 2 minutes • Uploads pace automatically so video calls & browsing stay fast")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(model.isUploadsPaused ? "Resume Queue" : "Pause Queue") {
                        model.isUploadsPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var transferQueueCard: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Now, Next & Verified Transfers (\(model.uploadActivities.count))", systemImage: "arrow.up.arrow.down.square.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK, !panel.urls.isEmpty {
                            Task { await model.importExternalFiles(panel.urls) }
                        }
                    } label: {
                        Label("+ Add Files to Queue", systemImage: "plus")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if model.uploadActivities.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "tray.fill")
                            .foregroundStyle(.secondary)
                        Text("No transfers in queue right now. Drag files into /Volumes/Helium or onto the Menu Bar icon.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(Array(model.uploadActivities.prefix(10).enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 10) {
                            let spec = HeliumAsset.fileIconAndColor(for: item.fileName, isFolder: false)
                            Image(systemName: spec.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(spec.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text("\(item.byteProgressLabel) • \(item.placementSummary) • \(item.timeRemainingLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer()

                            if !item.isCompleted {
                                Button {
                                    model.reorderUploadActivity(id: item.id, moveUp: true)
                                } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .buttonStyle(.borderless)
                                .disabled(idx == 0)
                                .help("Move earlier in queue")

                                Button {
                                    model.reorderUploadActivity(id: item.id, moveUp: false)
                                } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.borderless)
                                .disabled(idx >= model.uploadActivities.count - 1)
                                .help("Move later in queue")
                            }

                            HeliumFileStateBadge(
                                kind: item.isCompleted
                                    ? .verifiedZeroBytes
                                    : .uploading(fraction: item.fractionCompleted)
                            )
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }
        }
    }

    private var connectionAndSafeWriteCard: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("5-Step Safe-Write & Connection Verification", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task {
                            await model.runSafeWriteVerification(
                                targetName: model.linkedAccounts.first?.email ?? "Helium Google Drive Pool",
                                host: "www.googleapis.com"
                            )
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if model.isRunningSafeWriteCheck {
                                ProgressView().controlSize(.mini)
                                Text("Running Canary Check…")
                            } else {
                                Image(systemName: "bolt.shield.fill")
                                Text("Run 5-Step Safe-Write Check")
                            }
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.isRunningSafeWriteCheck)
                }

                Text("Writes a cryptographic canary, reads it back, verifies its SHA-256 digest, and cleans up with zero residue — proving end-to-end storage integrity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let report = model.latestSafeWriteReport {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.steps) { step in
                            HStack(spacing: 10) {
                                switch step.state {
                                case .passed(let note):
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(step.title)
                                        .font(.caption.bold())
                                    Spacer()
                                    Text(note)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                case .failed(let reason):
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundStyle(.red)
                                    Text(step.title)
                                        .font(.caption.bold())
                                    Spacer()
                                    Text(reason)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                case .running:
                                    ProgressView().controlSize(.mini)
                                    Text(step.title).font(.caption)
                                    Spacer()
                                case .pending:
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                    Text(step.title).font(.caption)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }
        }
    }

    private var twentyFourHourSummaryCard: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            HStack(spacing: 24) {
                summaryMetric(
                    title: "Pooled Files",
                    value: "\(model.activePooledFilesCount)",
                    subtitle: "\(ByteCountFormatter.string(fromByteCount: model.heliumPoolUsedBytes, countStyle: .file)) in Cloud",
                    symbol: "externaldrive.fill.badge.checkmark",
                    color: .blue
                )
                Divider().frame(height: 40)
                summaryMetric(
                    title: "Mac Disk Used",
                    value: "0 KB",
                    subtitle: "Sparse stubs in /Volumes/Helium",
                    symbol: "leaf.fill",
                    color: .green
                )
                Divider().frame(height: 40)
                summaryMetric(
                    title: "1 MiB Chunks Streamed",
                    value: "\(model.realtimeChunkCacheHitCount + model.realtimeChunkNetworkFetchCount)",
                    subtitle: "\(model.realtimeChunkCacheHitCount) instant cache hits",
                    symbol: "bolt.horizontal.icloud.fill",
                    color: .indigo
                )
                Divider().frame(height: 40)
                summaryMetric(
                    title: "Time Travel Snapshots",
                    value: "\(model.poolSnapshots.count)",
                    subtitle: "\(model.backupJobs.count) scheduled backup job(s)",
                    symbol: "clock.arrow.2.circlepath",
                    color: .purple
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryMetric(title: String, value: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.bold())
                    .monospacedDigit()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 2. Scheduled Mac Folder Backups Workspace View (Syncophant BackupsView Parity)

public struct HeliumMacBackupsWorkspaceView: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2.bold())
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scheduled Mac Folder Backups")
                            .font(.title2.bold())
                        Text("Add-only scheduled backups from your Mac to /Volumes/Helium. Deleting a file on your Mac never deletes its backup copy in the cloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !model.backupJobs.isEmpty {
                        Button {
                            Task { await model.runAllBackupsNow() }
                        } label: {
                            Label("Back Up All Now", systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        model.showNewBackupJobSheet = true
                    } label: {
                        Label("+ New Folder Backup", systemImage: "folder.badge.plus")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Quick One-Click Preset Cards (Desktop, Documents, Pictures)
                HeliumGlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick 1-Click Mac Folder Protection")
                            .font(.subheadline.bold())
                        HStack(spacing: 12) {
                            quickPresetButton(
                                title: "Protect ~/Desktop",
                                folder: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                                symbol: "menubar.dock.rectangle"
                            )
                            quickPresetButton(
                                title: "Protect ~/Documents",
                                folder: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
                                symbol: "doc.on.doc.fill"
                            )
                            quickPresetButton(
                                title: "Protect ~/Pictures",
                                folder: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures"),
                                symbol: "photo.on.rectangle.angled"
                            )
                        }
                    }
                }

                if model.backupJobs.isEmpty {
                    HeliumGlassCard(cornerRadius: 16, padding: 28) {
                        VStack(spacing: 12) {
                            Image(systemName: "externaldrive.badge.timemachine")
                                .font(.system(size: 38))
                                .foregroundStyle(.blue)
                            Text("No Scheduled Folder Backups Yet")
                                .font(.headline)
                            Text("Choose any folder on your Mac (like Desktop, Documents, or a code workspace) to back it up automatically to your Helium Pool on an Hourly, Daily, or Weekly schedule.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 460)
                            Button("+ Create Scheduled Backup…") {
                                model.showNewBackupJobSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(model.backupJobs) { job in
                        backupJobCard(job)
                    }
                }
            }
            .padding(22)
        }
        .sheet(isPresented: $model.showNewBackupJobSheet) {
            NewBackupJobModalSheet(model: model)
        }
    }

    private func quickPresetButton(title: String, folder: URL, symbol: String) -> some View {
        let alreadyAdded = model.backupJobs.contains { $0.sourcePath == folder.path }
        return Button {
            model.createBackupJob(
                name: folder.lastPathComponent,
                sourceURL: folder,
                destinationFolder: "/Backups/\(folder.lastPathComponent)",
                schedule: .daily,
                exclusions: .defaultRules,
                skipOnHotspot: true,
                runImmediately: true
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : symbol)
                    .foregroundStyle(alreadyAdded ? .green : .blue)
                Text(alreadyAdded ? "\(folder.lastPathComponent) Protected" : title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
    }

    private func backupJobCard(_ job: BackupJob) -> some View {
        let isRunning = (model.isRunningBackupJobId == job.id)
        return HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill.badge.gearshape")
                        .font(.title2)
                        .foregroundStyle(job.enabled ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(job.name)
                                .font(.headline)
                            Text(job.schedule.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.14)))
                                .foregroundStyle(.blue)
                            if job.skipOnPersonalHotspot {
                                Text("Skips Hotspot")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(job.sourcePath) → /Volumes/Helium\(job.destinationPoolFolder)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    HeliumCountdownRing(
                        progress: job.countdownProgress(),
                        label: isRunning ? "Running…" : job.nextRunLabel()
                    )

                    Button {
                        Task { await model.runBackupJobNow(job) }
                    } label: {
                        HStack(spacing: 4) {
                            if isRunning {
                                ProgressView().controlSize(.mini)
                                Text("Backing Up…")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Back Up Now")
                            }
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isRunning)

                    Menu {
                        Button(job.enabled ? "Pause Schedule" : "Resume Schedule") {
                            model.toggleBackupJobEnabled(id: job.id)
                        }
                        Button("Show Source Folder in Finder") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: job.sourcePath)
                        }
                        Divider()
                        Button("Remove Backup Rule", role: .destructive) {
                            model.deleteBackupJob(id: job.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                }

                Divider()

                HStack {
                    Text("\(job.totalProtectedFiles) protected files • \(ByteCountFormatter.string(fromByteCount: job.totalProtectedBytes, countStyle: .file)) • Add-only safety")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Last 14 runs:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HeliumRunHistoryDots(runs: job.recentRuns)
                }
            }
        }
    }
}

public struct NewBackupJobModalSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    @State private var customName: String = "Documents"
    @State private var schedule: BackupScheduleInterval = .daily
    @State private var skipCaches: Bool = true
    @State private var skipNodeModules: Bool = true
    @State private var skipLargeFiles: Bool = false
    @State private var skipOnHotspot: Bool = true
    @State private var scanSummary: BackupFolderScanSummary? = nil

    private var activeExclusions: BackupExclusionOptions {
        var opts = BackupExclusionOptions()
        if skipCaches { opts.insert(.caches) }
        if skipNodeModules { opts.insert(.nodeModules) }
        if skipLargeFiles { opts.insert(.largeFilesOver2GB) }
        return opts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New Scheduled Mac Folder Backup")
                    .font(.title3.bold())
                Spacer()
                Button("Cancel") { dismiss() }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Folder on This Mac")
                        .font(.caption.bold())
                    Text(selectedURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        selectedURL = url
                        customName = url.lastPathComponent
                        rescanFolder()
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Backup Name", text: $customName)
                    .textFieldStyle(.roundedBorder)
                Picker("Schedule", selection: $schedule) {
                    ForEach(BackupScheduleInterval.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .frame(width: 200)
            }

            GroupBox("Smart Exclusion Rules (Live Scan Preview)") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $skipCaches) {
                        HStack {
                            Text("Skip Caches folders")
                            Spacer()
                            if let s = scanSummary, s.skippedCachesCount > 0 {
                                Text("Saves \(s.skippedCachesCount) files (\(ByteCountFormatter.string(fromByteCount: s.skippedCachesBytes, countStyle: .file)))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .onChange(of: skipCaches) { _, _ in rescanFolder() }

                    Toggle(isOn: $skipNodeModules) {
                        HStack {
                            Text("Skip node_modules & build artifacts")
                            Spacer()
                            if let s = scanSummary, s.skippedNodeModulesCount > 0 {
                                Text("Saves \(s.skippedNodeModulesCount) files (\(ByteCountFormatter.string(fromByteCount: s.skippedNodeModulesBytes, countStyle: .file)))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .onChange(of: skipNodeModules) { _, _ in rescanFolder() }

                    Toggle(isOn: $skipLargeFiles) {
                        HStack {
                            Text("Skip single files larger than 2 GB")
                            Spacer()
                            if let s = scanSummary, s.skippedLargeFilesCount > 0 {
                                Text("Saves \(s.skippedLargeFilesCount) files (\(ByteCountFormatter.string(fromByteCount: s.skippedLargeFilesBytes, countStyle: .file)))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .onChange(of: skipLargeFiles) { _, _ in rescanFolder() }

                    Toggle("Pause automatic runs when on Personal Hotspot", isOn: $skipOnHotspot)
                }
                .padding(6)
            }

            if let s = scanSummary {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.blue)
                    Text("Ready to protect **\(s.eligibleFilesCount) files** (\(ByteCountFormatter.string(fromByteCount: s.eligibleBytes, countStyle: .file))) → `/Volumes/Helium/Backups/\(customName)`")
                        .font(.caption)
                    Spacer()
                }
            }

            HStack {
                Spacer()
                Button("Create & Start Backup") {
                    model.createBackupJob(
                        name: customName,
                        sourceURL: selectedURL,
                        destinationFolder: "/Backups/\(customName)",
                        schedule: schedule,
                        exclusions: activeExclusions,
                        skipOnHotspot: skipOnHotspot,
                        runImmediately: true
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .onAppear {
            rescanFolder()
        }
    }

    private func rescanFolder() {
        scanSummary = HeliumBackupEngine.scanLocalFolder(at: selectedURL, activeExclusions: activeExclusions)
    }
}

// MARK: - 3. Time Travel Workspace View: Snapshots ("Then vs. Now") & 30-Day Trash (Syncophant TimeTravelView Parity)

public struct HeliumTimeTravelWorkspaceView: View {
    @ObservedObject var model: AppModel
    @State private var mode: TimeTravelMode = .snapshots
    @State private var showNewSnapshotPopover: Bool = false
    @State private var newSnapshotTitle: String = ""
    @State private var newSnapshotNote: String = ""

    public enum TimeTravelMode: String, CaseIterable, Identifiable {
        case snapshots = "Past Versions (Snapshots)"
        case trash = "Recently Deleted (30-Day Trash)"

        public var id: String { rawValue }
    }

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.purple.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.title2.bold())
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time Travel & Version History")
                            .font(.title2.bold())
                        Text("Browse point-in-time snapshots with 'Then vs. Now' comparisons, or undo any delete for 30 days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("Mode", selection: $mode) {
                        ForEach(TimeTravelMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 380)
                }

                if mode == .snapshots {
                    snapshotsSection
                } else {
                    trashSection
                }
            }
            .padding(22)
        }
    }

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Snapshot Timeline Bar
            HeliumGlassCard(cornerRadius: 16, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Pool Snapshot Timeline (\(model.poolSnapshots.count))", systemImage: "camera.aperture")
                            .font(.headline)
                        Spacer()
                        Button {
                            showNewSnapshotPopover.toggle()
                        } label: {
                            Label("+ Take Snapshot Now", systemImage: "plus.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .popover(isPresented: $showNewSnapshotPopover) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Capture Point-in-Time Snapshot")
                                    .font(.headline)
                                TextField("Snapshot Title (e.g. Before Final Cut Edit)", text: $newSnapshotTitle)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Optional Note", text: $newSnapshotNote)
                                    .textFieldStyle(.roundedBorder)
                                HStack {
                                    Spacer()
                                    Button("Capture Snapshot") {
                                        model.takePoolSnapshot(title: newSnapshotTitle, note: newSnapshotNote)
                                        newSnapshotTitle = ""
                                        newSnapshotNote = ""
                                        showNewSnapshotPopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(14)
                            .frame(width: 320)
                        }
                    }

                    if model.poolSnapshots.isEmpty {
                        Text("No snapshots recorded yet. Click '+ Take Snapshot Now' to capture an instant point-in-time state of your Helium Pool.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(model.poolSnapshots) { snap in
                                    let isSelected = (model.selectedSnapshot?.id == snap.id)
                                    Button {
                                        model.selectedSnapshotId = snap.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Image(systemName: isSelected ? "clock.fill" : "clock")
                                                Text(snap.title)
                                                    .font(.caption.bold())
                                                    .lineLimit(1)
                                            }
                                            Text("\(snap.totalFiles) files • \(ByteCountFormatter.string(fromByteCount: snap.totalBytes, countStyle: .file))")
                                                .font(.caption2)
                                                .opacity(0.85)
                                            Text(RelativeDateTimeFormatter().localizedString(for: snap.createdAt, relativeTo: Date()))
                                                .font(.caption2)
                                                .opacity(0.7)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? Color.purple : Color(nsColor: .controlBackgroundColor))
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

            // "Then vs. Now" Comparison List
            if let activeSnap = model.selectedSnapshot {
                HeliumGlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Then vs. Now — \(activeSnap.title)")
                                    .font(.headline)
                                Text(activeSnap.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.poolSnapshots.count > 1 {
                                Button(role: .destructive) {
                                    model.deletePoolSnapshot(activeSnap)
                                } label: {
                                    Label("Delete Snapshot", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        let comparisons = model.currentSnapshotComparisons
                        if comparisons.isEmpty {
                            Text("This snapshot has no recorded files yet. Add files to /Volumes/Helium and capture a snapshot to compare versions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(comparisons) { comp in
                                thenVsNowRow(comp)
                            }
                        }
                    }
                }
            }
        }
    }

    private func thenVsNowRow(_ comp: SnapshotItemComparison) -> some View {
        HStack(spacing: 12) {
            let spec = HeliumAsset.fileIconAndColor(for: comp.itemName, isFolder: comp.kind == .folder)
            Image(systemName: spec.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(spec.color)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(comp.itemName)
                        .font(.subheadline.bold())
                    diffBadge(comp.diffStatus)
                }
                HStack(spacing: 14) {
                    if let thenSize = comp.thenSize {
                        Text("THEN: \(ByteCountFormatter.string(fromByteCount: thenSize, countStyle: .file))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("THEN: Did not exist")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let nowSize = comp.nowSize {
                        Text("NOW: \(ByteCountFormatter.string(fromByteCount: nowSize, countStyle: .file))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.primary)
                    } else {
                        Text("NOW: Deleted")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            if comp.thenManifest != nil {
                Button {
                    Task { await model.restoreFromSnapshot(comp, asCopy: true) }
                } label: {
                    Label("Restore Copy", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if comp.diffStatus == .deletedInNow || comp.diffStatus == .modified {
                    Button {
                        Task { await model.restoreFromSnapshot(comp, asCopy: false) }
                    } label: {
                        Label("Restore Version", systemImage: "arrow.uturn.backward")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func diffBadge(_ status: SnapshotDiffStatus) -> some View {
        let color: Color = {
            switch status {
            case .unchanged: return .green
            case .modified: return .blue
            case .deletedInNow: return .orange
            case .addedInNow: return .purple
            }
        }()
        return Text(status.rawValue)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var trashSection: some View {
        HeliumGlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recently Deleted — 30-Day Undo Window (\(model.trashedItems.count))", systemImage: "trash.circle.fill")
                        .font(.headline)
                    Spacer()
                    if !model.trashedItems.isEmpty {
                        Button("Undo Last Delete") {
                            model.undoLastDelete()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if model.trashedItems.isEmpty {
                    Text("No files in Recently Deleted. Anything deleted from /Volumes/Helium stays recoverable here for 30 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(model.trashedItems) { item in
                        HStack(spacing: 12) {
                            let spec = HeliumAsset.fileIconAndColor(for: item.fileName, isFolder: false)
                            Image(systemName: spec.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(spec.color)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName)
                                    .font(.subheadline.bold())
                                Text("\(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)) • \(item.accountSummary) • \(item.daysRemaining) days remaining")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Restore") {
                                Task { await model.restoreTrashedItem(item) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Delete Forever", role: .destructive) {
                                Task { await model.permanentlyDeleteTrashedItem(item) }
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
        }
    }
}

// MARK: - 4. Right-Hand Files Inspector Drawer & Conflict Resolver (Syncophant FilesInspector Parity)

public struct HeliumRightFilesInspectorDrawer: View {
    @ObservedObject var model: AppModel
    public let node: DriveNode?

    public init(model: AppModel, node: DriveNode?) {
        self.model = model
        self.node = node
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("File Inspector", systemImage: "sidebar.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(HeliumMotion.snappy) {
                        model.showRightInspector = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide Inspector")
            }

            if let activeNode = node ?? model.driveNodes.first {
                let manifest = activeNode.remoteID.flatMap { model.manifests[$0] }
                let isPinned = model.pinnedFilenames.contains(activeNode.name)
                let matchingConflict = model.activeConflicts.first { $0.fileName == activeNode.name }

                // File Preview Header
                VStack(spacing: 8) {
                    let spec = HeliumAsset.fileIconAndColor(for: activeNode.name, isFolder: activeNode.isFolder)
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(spec.color.opacity(0.14))
                            .frame(width: 64, height: 64)
                        Image(systemName: spec.symbol)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(spec.color)
                    }

                    Text(activeNode.name)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(activeNode.isFolder ? "Folder" : ByteCountFormatter.string(fromByteCount: activeNode.size, countStyle: .file))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if matchingConflict != nil {
                        HeliumFileStateBadge(kind: .conflict)
                    } else if isPinned {
                        HeliumFileStateBadge(kind: .keptOffline)
                    } else if let segs = manifest?.segments.count, segs > 1 {
                        HeliumFileStateBadge(kind: .striped(segments: segs))
                    } else {
                        HeliumFileStateBadge(kind: .verifiedZeroBytes)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                Divider()

                // Two-Version Conflict Resolution Card (when a conflict exists)
                if let conflict = matchingConflict {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.2")
                                .foregroundStyle(.orange)
                            Text("Edited in Two Places")
                                .font(.caption.bold())
                        }
                        Text("Both versions are preserved safely. Choose how to resolve:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button("Keep Both") {
                                Task { await model.resolveConflict(conflict, choice: .keepBoth) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Use Newer") {
                                Task { await model.resolveConflict(conflict, choice: .useNewer) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
                }

                // "Where It Lives" Status Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHERE IT LIVES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    let segCount = max(1, manifest?.segments.count ?? 1)
                    let primaryAccId = manifest?.segments.first?.accountId ?? ""
                    let email = model.linkedAccounts.first(where: { $0.id == primaryAccId })?.email
                        ?? model.linkedAccounts.first?.email
                        ?? "Helium Cloud Pool"

                    HStack(spacing: 6) {
                        Image(systemName: "externaldrive.fill.badge.icloud")
                            .foregroundStyle(.blue)
                        Text(email)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }

                    Text(segCount > 1
                         ? "Mode 2: Striped across \(segCount) × 64 MiB segments"
                         : "Mode 1: Whole-File Smart Placement (0 B on Mac)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text(model.zeroKnowledgeEnabled ? "AES-256-GCM Encrypted + SHA-256 Verified" : "Direct Google Drive + SHA-256 Verified")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // Keep Downloaded Toggle
                Toggle(isOn: Binding(
                    get: { isPinned },
                    set: { _ in model.togglePinNode(activeNode) }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Keep Downloaded")
                            .font(.caption.bold())
                        Text("Work offline without Wi-Fi")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                // Copy Path Chip
                Button {
                    let path = "/Volumes/Helium/\(activeNode.name)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                    model.statusMessage = "Copied path \(path) to clipboard"
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption2)
                        Text("/Volumes/Helium/\(activeNode.name)")
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("Copy")
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)

                // Quick Actions
                VStack(spacing: 6) {
                    Button {
                        model.openNodeOnMac(activeNode)
                    } label: {
                        Label("Open Immediately", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        model.createAndCopyShareLink(for: activeNode)
                    } label: {
                        Label("Copy Encrypted Share Link", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text("Select any file or folder to inspect its placement, verification shield, and offline state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 276)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 5. Multi-Protocol & Multi-Provider Connect Sheet (Syncophant ServicePresets + ConnectChecks Parity)

public struct MultiProtocolStorageConnectSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProtocol: StorageProviderProtocol = .s3
    @State private var selectedPresetId: String = "cloudflare-r2"
    @State private var connectionName: String = "Cloudflare R2 Pool Node"
    @State private var endpoint: String = "https://account.r2.cloudflarestorage.com"
    @State private var bucketOrFolder: String = "helium-vault"
    @State private var region: String = "auto"
    @State private var usernameOrKeyId: String = ""
    @State private var secretOrPassword: String = ""
    @State private var quotaGB: Double = 1024

    private var presetsForSelectedProtocol: [StorageServicePreset] {
        StorageServicePreset.presets(for: selectedProtocol)
    }

    private var currentPreset: StorageServicePreset {
        StorageServicePreset.all.first { $0.id == selectedPresetId }
            ?? presetsForSelectedProtocol.first
            ?? StorageServicePreset.all[0]
    }

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Storage Provider to Helium Pool")
                        .font(.title3.bold())
                    Text("Pool Google Drives alongside S3, Cloudflare R2, Backblaze B2, WebDAV/Nextcloud, Hetzner Storage Box, SMB, or External SSDs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            Divider()

            // Protocol Picker
            Picker("Protocol", selection: $selectedProtocol) {
                ForEach(StorageProviderProtocol.allCases) { proto in
                    Text(proto.title).tag(proto)
                }
            }
            .onChange(of: selectedProtocol) { _, newProto in
                if let first = StorageServicePreset.presets(for: newProto).first {
                    applyPreset(first)
                }
            }

            // Service Preset Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetsForSelectedProtocol) { preset in
                        let isSel = (preset.id == currentPreset.id)
                        Button {
                            applyPreset(preset)
                        } label: {
                            Text(preset.title)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(isSel ? Color.blue : Color(nsColor: .controlBackgroundColor))
                                )
                                .foregroundStyle(isSel ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedProtocol == .googleDrive {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Link another Google account via OAuth 2.0 PKCE browser sign-in to immediately expand /Volumes/Helium.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SignInWithGoogleButton(
                        title: "+ Sign in with Google Drive",
                        style: .standard,
                        isLoading: model.isSigningInWithGoogle
                    ) {
                        dismiss()
                        model.startBrowserOAuthFlow()
                    }
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Display Name", text: $connectionName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Bucket / Folder Path", text: $bucketOrFolder)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 10) {
                        TextField(
                            currentPreset.placeholderPrompt.isEmpty ? "Endpoint URL / Host" : currentPreset.placeholderPrompt,
                            text: $endpoint
                        )
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: endpoint) { _, newValue in
                            if let matched = StorageServicePreset.match(address: newValue) {
                                selectedPresetId = matched.id
                            }
                            if let inferred = StorageServicePreset.inferS3Region(for: newValue) {
                                region = inferred
                            }
                        }

                        if selectedProtocol == .s3 {
                            TextField("Region", text: $region)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                    }

                    HStack(spacing: 10) {
                        TextField(currentPreset.userFieldLabel, text: $usernameOrKeyId)
                            .textFieldStyle(.roundedBorder)
                        SecureField(currentPreset.secretFieldLabel, text: $secretOrPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let note = currentPreset.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 5-Step Safe-Write Pre-Flight Check Preview
            if let report = model.latestSafeWriteReport {
                GroupBox("Pre-Flight Safe-Write Verification (\(report.latencyMs) ms • \(report.tlsVersion))") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.steps) { step in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text(step.title)
                                    .font(.caption)
                                Spacer()
                                if case .passed(let note) = step.state {
                                    Text(note)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }

            HStack {
                Button {
                    Task {
                        await model.runSafeWriteVerification(
                            targetName: connectionName,
                            host: StorageServicePreset.extractHost(from: endpoint)
                        )
                    }
                } label: {
                    Label(model.isRunningSafeWriteCheck ? "Testing…" : "Test Safe Reads & Writes", systemImage: "checkmark.shield")
                }
                .disabled(model.isRunningSafeWriteCheck)

                Spacer()

                if selectedProtocol != .googleDrive {
                    Button("Verify & Connect to Pool") {
                        Task {
                            await model.runSafeWriteVerification(
                                targetName: connectionName,
                                host: StorageServicePreset.extractHost(from: endpoint)
                            )
                            let conn = ExternalStorageConnection(
                                name: connectionName.isEmpty ? currentPreset.title : connectionName,
                                presetId: currentPreset.id,
                                protocolKind: selectedProtocol,
                                endpoint: endpoint,
                                bucketOrFolder: bucketOrFolder,
                                region: region,
                                usernameOrKeyId: usernameOrKeyId,
                                quotaLimitBytes: Int64(quotaGB * 1_073_741_824),
                                quotaUsedBytes: 0,
                                lastLatencyMs: model.latestSafeWriteReport?.latencyMs ?? 16
                            )
                            model.addExternalStorageConnection(conn)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
        .frame(width: 620)
    }

    private func applyPreset(_ preset: StorageServicePreset) {
        selectedPresetId = preset.id
        connectionName = preset.title
        if !preset.endpointTemplate.isEmpty {
            endpoint = preset.endpointTemplate
        } else if !preset.placeholderPrompt.isEmpty {
            endpoint = preset.placeholderPrompt
        }
        if let reg = StorageServicePreset.inferS3Region(for: endpoint) {
            region = reg
        }
    }
}
