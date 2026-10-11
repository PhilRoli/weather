// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Weather",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/PhilRoli/menubar-kit", from: "1.3.0")],
    targets: [
        .executableTarget(
            name: "Weather",
            dependencies: [.product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Sources/Weather"
        ),
        .testTarget(
            name: "WeatherTests",
            dependencies: ["Weather", .product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Tests/WeatherTests"
        )
    ]
)
