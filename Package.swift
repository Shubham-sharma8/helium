// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Helium",
    platforms: [
        .macOS("15.4")
    ],
    products: [
        .library(name: "OrbitCore", targets: ["OrbitCore"]),
        .executable(name: "Helium", targets: ["HeliumApp"]),
        .executable(name: "OrbitFS", targets: ["OrbitFS"]),
        .executable(name: "OrbitFinder", targets: ["OrbitFinder"]),
        .executable(name: "OrbitMountHelper", targets: ["OrbitMountHelper"])
    ],
    targets: [
        .target(
            name: "OrbitCore",
            path: "Sources/OrbitCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "HeliumApp",
            dependencies: ["OrbitCore"],
            path: "Sources/HeliumApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AuthenticationServices"),
                .linkedFramework("NetFS"),
                .linkedFramework("AVKit")
            ]
        ),
        .executableTarget(
            name: "OrbitFS",
            dependencies: ["OrbitCore"],
            path: "Sources/OrbitFS",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("FSKit")
            ]
        ),
        .executableTarget(
            name: "OrbitFinder",
            dependencies: ["OrbitCore"],
            path: "Sources/OrbitFinder",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("FinderSync"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "OrbitMountHelper",
            dependencies: ["OrbitCore"],
            path: "Sources/OrbitMountHelper",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "OrbitCoreTests",
            dependencies: ["OrbitCore"],
            path: "Tests/OrbitCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
