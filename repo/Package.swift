// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DealerOps",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    targets: [
        // Core library — all non-UIKit code, compilable on macOS and iOS
        .target(
            name: "DealerOpsCore",
            path: ".",
            exclude: [
                "App/AppDelegate.swift",
                "App/BootstrapViewController.swift",
                "App/HomeViewController.swift",
                "App/LoginViewController.swift",
                "App/MainSplitViewController.swift",
                "App/Views",
                "Tests",
                "Resources",
                "scripts",
                "Dockerfile",
                "docker-compose.yml",
                "run_tests.sh",
                "DealerOps.xcodeproj",
                ".tmp",
            ],
            sources: [
                "Models",
                "Repositories",
                "Persistence",
                "Services",
                "App/ServiceContainer.swift",
                "App/MediaCache.swift",
                "App/ViewModels",
            ]
        ),
        // Test target
        .executableTarget(
            name: "DealerOpsTests",
            dependencies: ["DealerOpsCore"],
            path: "Tests"
        ),
    ]
)
