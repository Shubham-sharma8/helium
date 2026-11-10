import AppKit
import SwiftUI

/// Provides original Helium visual assets from `Assets.car` with automatic SF Symbol fallbacks
/// when running outside the packaged `.app` bundle (such as during `swift test`).
public enum HeliumAsset {
    @MainActor
    private static var imageCache: [String: NSImage] = [:]

    @MainActor
    public static func nsImage(_ name: String) -> NSImage? {
        if let cached = imageCache[name] {
            return cached
        }
        // Prioritize the new Helium smiling folder icon across all mascot, sidebar, and menu bar contexts
        switch name {
        case "MenuBarIconHappy", "MenuBarIcon", "MenuBarIconBusy", "MenuBarIconSleepy", "MenuBarIconWorried":
            if let menuURL = Bundle.main.url(forResource: "MenuBarSmile", withExtension: "png")
                ?? Bundle.main.url(forResource: "HeliumMascot", withExtension: "png"),
               let img = NSImage(contentsOf: menuURL) {
                img.size = NSSize(width: 18, height: 18)
                imageCache[name] = img
                return img
            }
            let localPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/MenuBarSmile.png")
            if let img = NSImage(contentsOf: localPath) {
                img.size = NSSize(width: 18, height: 18)
                imageCache[name] = img
                return img
            }
        case "HeliumHappy", "HeliumWink", "HeliumLove", "HeliumBusy", "HeliumSurprised", "HeliumSleepy", "HeliumWorried", "HeliumSad", "Orbit", "OrbitMark", "OrbitSidebar":
            if let mascotURL = Bundle.main.url(forResource: "HeliumMascot", withExtension: "png")
                ?? Bundle.main.url(forResource: "HeliumIcon", withExtension: "png"),
               let img = NSImage(contentsOf: mascotURL) {
                imageCache[name] = img
                return img
            }
            let localPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/HeliumMascot.png")
            if let img = NSImage(contentsOf: localPath) {
                imageCache[name] = img
                return img
            }
        default:
            break
        }

        if let img = NSImage(named: NSImage.Name(name)) {
            imageCache[name] = img
            return img
        }
        if let carURL = Bundle.main.url(forResource: "Assets", withExtension: "car"),
           let bundle = Bundle(url: carURL.deletingLastPathComponent()),
           let img = bundle.image(forResource: NSImage.Name(name)) {
            imageCache[name] = img
            return img
        }
        return nil
    }

    @MainActor
    @ViewBuilder
    public static func mascot(_ name: String, size: CGFloat = 72) -> some View {
        if let nsImg = nsImage(name) {
            Image(nsImage: nsImg)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemSymbol(for: name))
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.75, height: size * 0.75)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
        }
    }

    @MainActor
    @ViewBuilder
    public static func icon(_ name: String, size: CGFloat = 16, tint: Color? = nil) -> some View {
        if let nsImg = nsImage(name) {
            Image(nsImage: nsImg)
                .resizable()
                .interpolation(.high)
                .renderingMode(tint == nil ? .original : .template)
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint ?? .primary)
        } else {
            Image(systemName: fallbackSystemSymbol(for: name))
                .font(.system(size: size * 0.88, weight: .medium))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
        }
    }

    public static func fallbackSystemSymbol(for name: String) -> String {
        switch name {
        case "HeliumHappy", "MenuBarIconHappy":
            return "externaldrive.fill.badge.checkmark"
        case "HeliumBusy", "MenuBarIconBusy":
            return "arrow.triangle.2.circlepath.icloud.fill"
        case "HeliumLove":
            return "heart.circle.fill"
        case "HeliumSad", "HeliumWorried", "MenuBarIconWorried":
            return "exclamationmark.icloud.fill"
        case "HeliumSleepy", "MenuBarIconSleepy":
            return "moon.zzz.fill"
        case "HeliumSurprised":
            return "sparkles"
        case "HeliumWink":
            return "face.smiling.inverse"
        case "Orbit", "OrbitMark", "OrbitSidebar", "MenuBarIcon":
            return "externaldrive.fill.badge.icloud"
        case "account":
            return "person.crop.circle"
        case "alert":
            return "exclamationmark.triangle.fill"
        case "cancel":
            return "xmark.circle.fill"
        case "check":
            return "checkmark"
        case "check-circle":
            return "checkmark.circle.fill"
        case "chevron":
            return "chevron.right"
        case "circle":
            return "circle.fill"
        case "clock":
            return "clock"
        case "download":
            return "arrow.down.circle"
        case "eject":
            return "eject.fill"
        case "external":
            return "arrow.up.forward.square"
        case "feedback":
            return "bubble.left.and.bubble.right"
        case "flash":
            return "bolt.fill"
        case "folder":
            return "folder.fill"
        case "folder-add":
            return "folder.badge.plus"
        case "folder-cloud":
            return "folder.fill.badge.person.crop"
        case "key":
            return "key.fill"
        case "lock":
            return "lock.shield.fill"
        case "offline":
            return "wifi.slash"
        case "pause":
            return "pause.circle"
        case "quit":
            return "power"
        case "search":
            return "magnifyingglass"
        case "settings":
            return "gearshape"
        case "storage":
            return "internaldrive"
        case "update":
            return "arrow.triangle.2.circlepath"
        case "upload":
            return "arrow.up.doc.fill"
        case "window":
            return "macwindow"
        default:
            return "icloud.fill"
        }
    }

    public static let accountPalette: [Color] = [
        Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
        Color(red: 0.20, green: 0.66, blue: 0.33), // Google Green
        Color(red: 0.98, green: 0.74, blue: 0.02), // Google Yellow/Amber
        Color(red: 0.92, green: 0.26, blue: 0.21), // Google Red
        Color(red: 0.58, green: 0.34, blue: 0.92), // Pool Purple
        Color(red: 0.00, green: 0.72, blue: 0.83)  // Pool Cyan
    ]

    public static func colorForAccount(at index: Int) -> Color {
        accountPalette[index % accountPalette.count]
    }

    public static func fileIconAndColor(for filename: String, isFolder: Bool) -> (symbol: String, color: Color) {
        if isFolder {
            return ("folder.fill", Color(red: 0.24, green: 0.58, blue: 0.98))
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "webm", "m4v":
            return ("film.fill", .purple)
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "tiff":
            return ("photo.fill", .pink)
        case "mp3", "wav", "m4a", "flac", "aac", "ogg":
            return ("waveform.circle.fill", .orange)
        case "zip", "tar", "gz", "7z", "rar", "dmg", "pkg", "iso":
            return ("archivebox.fill", .brown)
        case "pdf":
            return ("doc.richtext.fill", .red)
        case "swift", "py", "js", "ts", "tsx", "jsx", "json", "yaml", "yml", "sh", "html", "css", "c", "cpp", "rs", "go":
            return ("chevron.left.forwardslash.chevron.right", .teal)
        case "csv", "xls", "xlsx", "numbers":
            return ("tablecells.fill", .green)
        case "ppt", "pptx", "key":
            return ("play.rectangle.on.rectangle.fill", .indigo)
        case "txt", "md", "rtf", "doc", "docx", "pages":
            return ("doc.text.fill", .blue)
        default:
            return ("doc.fill", .cyan)
        }
    }
}

/// Critically-damped and bouncy spring animations tuned for macOS desktop interactions.
public enum HeliumSpring {
    public static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.85, blendDuration: 0)
    public static let fluid = Animation.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0)
    public static let bouncy = Animation.spring(response: 0.44, dampingFraction: 0.72, blendDuration: 0)
    public static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.88, blendDuration: 0)
}

/// Tactile press-scale button style inspired by Apple HIG & Emil design engineering principles.
public struct HeliumPressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(HeliumSpring.snappy, value: configuration.isPressed)
    }
}

/// Animated Helium mascot with gentle floating motion and interactive hover/click reaction.
public struct HeliumAnimatedMascot: View {
    public let name: String
    public var size: CGFloat = 72
    public var showAura: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false
    @State private var isHovered = false
    @State private var bounceTrigger = false

    public init(name: String, size: CGFloat = 72, showAura: Bool = true) {
        self.name = name
        self.size = size
        self.showAura = showAura
    }

    public var body: some View {
        ZStack {
            if showAura {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(isHovered ? 0.26 : 0.14),
                                Color.cyan.opacity(isHovered ? 0.14 : 0.04),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.68
                        )
                    )
                    .frame(width: size * 1.28, height: size * 1.28)
                    .scaleEffect(isFloating ? 1.05 : 0.95)
            }

            HeliumAsset.mascot(name, size: size)
                .scaleEffect(bounceTrigger ? 1.12 : (isHovered ? 1.05 : 1.0))
                .rotationEffect(.degrees(isHovered ? -3 : 0))
                .offset(y: (!reduceMotion && isHovered) ? -2.0 : 0.0)
                .shadow(color: Color.blue.opacity(isHovered ? 0.25 : 0.12), radius: isHovered ? 10 : 5, x: 0, y: 4)
        }
        .onHover { hovering in
            withAnimation(HeliumSpring.bouncy) {
                isHovered = hovering
                isFloating = hovering
            }
        }
        .onTapGesture {
            guard !reduceMotion else { return }
            withAnimation(HeliumSpring.bouncy) {
                bounceTrigger = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(HeliumSpring.bouncy) {
                    bounceTrigger = false
                }
            }
        }
    }
}

/// Reusable glassmorphic card container with specular border and optional hover elevation.
public struct HeliumGlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var interactiveHover: Bool
    public var accentTint: Color
    @ViewBuilder public let content: () -> Content

    @State private var isHovered = false

    public init(
        cornerRadius: CGFloat = 14,
        padding: CGFloat = 16,
        interactiveHover: Bool = false,
        accentTint: Color = .blue,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.interactiveHover = interactiveHover
        self.accentTint = accentTint
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentTint.opacity(interactiveHover && isHovered ? 0.08 : 0.03),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (interactiveHover && isHovered) ? accentTint.opacity(0.45) : Color.primary.opacity(0.12),
                                Color.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(interactiveHover && isHovered ? 0.12 : 0.05),
                radius: interactiveHover && isHovered ? 10 : 4,
                x: 0,
                y: interactiveHover && isHovered ? 4 : 2
            )
            .scaleEffect(interactiveHover && isHovered ? 1.006 : 1.0)
            .animation(HeliumSpring.snappy, value: isHovered)
            .onHover { hovering in
                if interactiveHover {
                    isHovered = hovering
                }
            }
    }
}

/// Official Google "G" multi-color badge rendered in pure SwiftUI vector graphics
/// for crisp Retina display on every "Sign in with Google" button.
public struct GoogleLogoBadge: View {
    public var size: CGFloat = 18

    public init(size: CGFloat = 18) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)

            Circle()
                .trim(from: 0.0, to: 0.25)
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: size * 0.18)
                .frame(width: size * 0.62, height: size * 0.62)
                .rotationEffect(.degrees(-15))

            Circle()
                .trim(from: 0.25, to: 0.55)
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: size * 0.18)
                .frame(width: size * 0.62, height: size * 0.62)
                .rotationEffect(.degrees(-15))

            Circle()
                .trim(from: 0.55, to: 0.78)
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: size * 0.18)
                .frame(width: size * 0.62, height: size * 0.62)
                .rotationEffect(.degrees(-15))

            Circle()
                .trim(from: 0.78, to: 0.94)
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: size * 0.18)
                .frame(width: size * 0.62, height: size * 0.62)
                .rotationEffect(.degrees(-15))

            Rectangle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: size * 0.34, height: size * 0.15)
                .offset(x: size * 0.14, y: 0)
        }
    }
}

/// Reusable, HIG-compliant "Sign in with Google" button supporting primary hero and compact toolbar styles.
public struct SignInWithGoogleButton: View {
    public enum Style {
        case hero
        case standard
        case compact
    }

    public let title: String
    public let subtitle: String?
    public let style: Style
    public let isLoading: Bool
    public let action: () -> Void

    @State private var isHovered = false

    public init(
        title: String = "Sign in with Google",
        subtitle: String? = nil,
        style: Style = .standard,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: style == .compact ? 6 : 10) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    GoogleLogoBadge(size: style == .hero ? 22 : (style == .compact ? 15 : 18))
                        .scaleEffect(isHovered ? 1.06 : 1.0)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(style == .hero ? .headline : (style == .compact ? .caption.bold() : .subheadline.bold()))
                        .lineLimit(1)
                    if let subtitle, style == .hero {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .opacity(0.88)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, style == .hero ? 18 : (style == .compact ? 10 : 14))
            .padding(.vertical, style == .hero ? 10 : (style == .compact ? 5 : 7))
            .background(
                RoundedRectangle(cornerRadius: style == .hero ? 10 : 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isHovered
                                ? [
                                    Color(red: 0.20, green: 0.49, blue: 0.96),
                                    Color(red: 0.13, green: 0.40, blue: 0.88)
                                ]
                                : [
                                    Color(red: 0.16, green: 0.44, blue: 0.92),
                                    Color(red: 0.11, green: 0.36, blue: 0.82)
                                ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: style == .hero ? 10 : 8, style: .continuous)
                    .strokeBorder(.white.opacity(isHovered ? 0.35 : 0.22), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .shadow(color: Color.blue.opacity(isHovered ? 0.36 : 0.22), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 3 : 2)
        }
        .buttonStyle(HeliumPressableButtonStyle())
        .onHover { hovering in
            withAnimation(HeliumSpring.snappy) {
                isHovered = hovering
            }
        }
        .disabled(isLoading)
    }
}
