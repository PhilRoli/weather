// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Weather",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Weather",
            path: "Sources/Weather"
        ),
        .testTarget(
            name: "WeatherTests",
            dependencies: ["Weather"],
            path: "Tests/WeatherTests"
        )
    ]
)
