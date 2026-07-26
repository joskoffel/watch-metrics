// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MetricsCore",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MetricsCore",
            targets: ["MetricsCore"]
        ),
        .library(
            name: "WatchMetricsSupport",
            targets: ["WatchMetricsSupport"]
        )
    ],
    targets: [
        .target(
            name: "MetricsCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "WatchMetricsSupport",
            dependencies: ["MetricsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MetricsCoreTests",
            dependencies: ["MetricsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "WatchMetricsSupportTests",
            dependencies: ["WatchMetricsSupport", "MetricsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
