import AppKit
import OrbitCore
import SwiftUI

// MARK: - Syncophant-Inspired StatusKit Primitives for Helium

public enum HeliumTone: Equatable, Sendable {
    case accent
    case green
    case orange
    case red
    case purple
    case indigo
    case neutral

    public var color: Color {
        switch self {
        case .accent: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .indigo: return .indigo
        case .neutral: return .secondary
        }
    }

    public var softFill: Color {
        switch self {
        case .accent: return Color.blue.opacity(0.14)
        case .green: return Color.green.opacity(0.14)
        case .orange: return Color.orange.opacity(0.16)
        case .red: return Color.red.opacity(0.14)
        case .purple: return Color.purple.opacity(0.14)
        case .indigo: return Color.indigo.opacity(0.14)
        case .neutral: return Color.primary.opacity(0.06)
        }
    }
}

public enum HeliumMotion {
    public static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.88)
    public static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.96)
    public static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.72)

    public static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

private struct HeliumMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(HeliumMotion.resolve(animation, reduceMotion: reduceMotion), value: value)
    }
}

private struct HeliumRollingNumberModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        content
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(HeliumMotion.resolve(HeliumMotion.snappy, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    public func heliumMotion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(HeliumMotionModifier(animation: animation, value: value))
    }

    public func rollingNumber<V: Equatable>(_ value: V) -> some View {
        modifier(HeliumRollingNumberModifier(value: value))
    }
}

// MARK: - 1. HealthOrb (Menu Bar & Activity Status Orb)

public struct HeliumHealthOrb: View {
    public enum State: Equatable {
        case healthy
        case syncing(progress: Double?)
        case paused
        case attention
        case error
    }

    public let state: State
    public var size: CGFloat = 34

    public init(state: State, size: CGFloat = 34) {
        self.state = state
        self.size = size
    }

    private var tone: HeliumTone {
        switch state {
        case .healthy: return .green
        case .syncing: return .accent
        case .paused, .attention: return .orange
        case .error: return .red
        }
    }

    private var symbol: String {
        switch state {
        case .healthy: return "checkmark.shield.fill"
        case .syncing: return "arrow.up.arrow.down.circle.fill"
        case .paused: return "pause.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(tone.softFill)
            if case .syncing(let progress) = state {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 2.5)
                    .padding(1.5)
                Circle()
                    .trim(from: 0, to: max(0.15, min(1.0, progress ?? 0.35)))
                    .stroke(tone.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(tone.color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 2. FileStateBadge (Verified Shield, Striped, Offline, Conflict)

public struct HeliumFileStateBadge: View {
    public enum Kind: Equatable {
        case verifiedZeroBytes
        case striped(segments: Int)
        case keptOffline
        case uploading(fraction: Double)
        case conflict
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        switch kind {
        case .verifiedZeroBytes:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Verified • 0 B on Mac")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.green.opacity(0.15)))
            .foregroundStyle(.green)

        case .striped(let segments):
            HStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Striped (\(segments) segments)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.purple.opacity(0.15)))
            .foregroundStyle(.purple)

        case .keptOffline:
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Kept on this Mac")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.blue.opacity(0.15)))
            .foregroundStyle(.blue)

        case .uploading(let fraction):
            HStack(spacing: 4) {
                ProgressView(value: min(1.0, max(0.05, fraction)))
                    .progressViewStyle(.circular)
                    .controlSize(.mini)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.blue.opacity(0.15)))
            .foregroundStyle(.blue)

        case .conflict:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.2")
                    .font(.system(size: 10, weight: .bold))
                Text("2 Versions (Conflict)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange.opacity(0.18)))
            .foregroundStyle(.orange)
        }
    }
}

// MARK: - 3. CountdownRing & RunHistoryDots (Scheduled Backups Visuals)

public struct HeliumCountdownRing: View {
    public let progress: Double
    public let label: String
    public var size: CGFloat = 30
    public var tint: Color = .blue

    public init(progress: Double, label: String, size: CGFloat = 30, tint: Color = .blue) {
        self.progress = progress
        self.label = label
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(1.0, max(0.04, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "clock.fill")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next scheduled backup")
        .accessibilityValue(label)
    }
}

public struct HeliumRunHistoryDots: View {
    public let runs: [BackupRunRecord]
    public var maxCount: Int = 14

    public init(runs: [BackupRunRecord], maxCount: Int = 14) {
        self.runs = runs
        self.maxCount = maxCount
    }

    public var body: some View {
        let visible = Array(runs.suffix(maxCount))
        let placeholders = max(0, maxCount - visible.count)
        HStack(spacing: 4) {
            ForEach(0..<placeholders, id: \.self) { _ in
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 7, height: 7)
            }
            ForEach(visible) { run in
                Circle()
                    .fill(color(for: run.outcome))
                    .frame(width: 7, height: 7)
                    .help("\(run.outcome.rawValue.capitalized) • \(run.uploadedFiles) files (\(ByteCountFormatter.string(fromByteCount: run.uploadedBytes, countStyle: .file)))")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent backup run history")
        .accessibilityValue("\(visible.filter { $0.outcome == .succeeded }.count) succeeded of \(visible.count) runs")
    }

    private func color(for outcome: BackupRunRecord.Outcome) -> Color {
        switch outcome {
        case .succeeded: return .green
        case .failed: return .red
        case .skippedHotspot: return .orange
        }
    }
}

// MARK: - 4. Dual-Series ThroughputChart (Syncophant ActivityView Parity)

public struct HeliumThroughputChart: View {
    public let samples: [ThroughputSample]

    public init(samples: [ThroughputSample]) {
        self.samples = samples
    }

    public var body: some View {
        let peak = max(
            samples.map { max($0.sendingBytesPerSec, $0.receivingBytesPerSec) }.max() ?? 0,
            1_048_576
        )

        GeometryReader { geo in
            ZStack {
                // Horizontal guide lines
                VStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }

                if samples.count > 1 {
                    seriesArea(values: samples.map(\.receivingBytesPerSec), peak: peak, size: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.24), Color.teal.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    seriesLine(values: samples.map(\.receivingBytesPerSec), peak: peak, size: geo.size)
                        .stroke(Color.teal, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    seriesArea(values: samples.map(\.sendingBytesPerSec), peak: peak, size: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.28), Color.blue.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    seriesLine(values: samples.map(\.sendingBytesPerSec), peak: peak, size: geo.size)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func points(values: [Double], peak: Double, size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let pad: CGFloat = 3
        let usableH = max(1, size.height - pad * 2)
        return values.enumerated().map { idx, val in
            let x = size.width * CGFloat(idx) / CGFloat(values.count - 1)
            let y = pad + usableH * (1.0 - CGFloat(min(max(val / peak, 0), 1)))
            return CGPoint(x: x, y: y)
        }
    }

    private func seriesLine(values: [Double], peak: Double, size: CGSize) -> Path {
        let pts = points(values: values, peak: peak, size: size)
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for pt in pts.dropFirst() {
            path.addLine(to: pt)
        }
        return path
    }

    private func seriesArea(values: [Double], peak: Double, size: CGSize) -> Path {
        let pts = points(values: values, peak: peak, size: size)
        var path = seriesLine(values: values, peak: peak, size: size)
        guard let first = pts.first, let last = pts.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - 5. Privacy Network Contact Map (Syncophant SettingsPrivacy Parity)

public struct HeliumNetworkContactMap: View {
    public let entries: [NetworkContactEntry]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(entries: [NetworkContactEntry]) {
        self.entries = entries
    }

    public var body: some View {
        let rowHeight: CGFloat = 42
        let gap: CGFloat = 10
        let totalHeight = max(110, CGFloat(max(1, entries.count)) * (rowHeight + gap) - gap)

        HStack(spacing: 0) {
            // Left: This Mac node
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 78, height: 64)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.blue)
                }
                Text("This Mac")
                    .font(.caption.bold())
                Text("/Volumes/Helium")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100, height: totalHeight)

            // Center: Bezier connection curves
            Canvas { context, size in
                let count = max(1, entries.count)
                for idx in 0..<count {
                    let y = CGFloat(idx) * (rowHeight + gap) + rowHeight / 2
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: y),
                        control1: CGPoint(x: size.width * 0.48, y: size.height / 2),
                        control2: CGPoint(x: size.width * 0.52, y: y)
                    )
                    let isRecent = idx < entries.count && Date().timeIntervalSince(entries[idx].lastContacted) < 300
                    let strokeColor = isRecent ? Color.blue.opacity(0.75) : Color.secondary.opacity(0.35)
                    context.stroke(
                        path,
                        with: .color(strokeColor),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5])
                    )
                }
            }
            .frame(minWidth: 70, maxWidth: 120, minHeight: totalHeight, maxHeight: totalHeight)
            .accessibilityHidden(true)

            // Right: Contacted host nodes
            VStack(alignment: .leading, spacing: gap) {
                ForEach(entries) { entry in
                    let isGoogle = entry.host.contains("googleapis.com") || entry.host.contains("google.com")
                    HStack(spacing: 10) {
                        Image(systemName: isGoogle ? "externaldrive.fill.badge.icloud" : "server.rack")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isGoogle ? .blue : .indigo)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(entry.host)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Text("\(entry.count)×")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.blue.opacity(0.14)))
                                    .foregroundStyle(.blue)
                            }
                            Text("\(entry.purpose) • Last: \(RelativeDateTimeFormatter().localizedString(for: entry.lastContacted, relativeTo: Date()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
