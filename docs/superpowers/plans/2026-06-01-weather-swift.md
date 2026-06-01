# Weather Swift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar weather app in Swift at `/Users/philipp/Development/weather/` that shows Open-Meteo weather data, supports native CoreLocation auto-location, and manages favorite locations.

**Architecture:** SPM executable (`Package.swift`) wrapped in a `.app` bundle via `rebuild.sh`. `StatusBarController` owns a 5-minute `Timer` and a `WeatherFetcher`; `WeatherFetcher` holds a `CLLocationManager`, a 5-minute in-memory cache, and calls `OpenMeteoClient`. `PreferencesWindowController` is an `NSPanel` opened on demand.

**Tech Stack:** Swift 5.9+, macOS 13+, AppKit, CoreLocation, URLSession. Zero third-party dependencies.

---

## File Map

| File | Responsibility |
|------|----------------|
| `Package.swift` | SPM config: executable + test targets, macOS 13 |
| `Info.plist` | `LSUIElement`, `NSLocationWhenInUseUsageDescription`, bundle ID |
| `rebuild.sh` | Build binary, wrap in `.app` bundle, `codesign` |
| `Sources/Weather/main.swift` | `NSApplication` entry point |
| `Sources/Weather/AppDelegate.swift` | Creates `StatusBarController` on launch |
| `Sources/Weather/Models.swift` | All data types + pure helpers (`weatherEmoji`, `formatTemperature`, etc.) |
| `Sources/Weather/AppConfig.swift` | `AppConfig` struct + `AppConfigStore` (UserDefaults) |
| `Sources/Weather/OpenMeteoClient.swift` | URLSession: forecast + geocoding; URL constructors (static); response processing |
| `Sources/Weather/WeatherFetcher.swift` | `CLLocationManager` + 5-min cache + fetch orchestration |
| `Sources/Weather/StatusBarController.swift` | `NSStatusItem`, 5-min timer, menu building, all menu actions |
| `Sources/Weather/PreferencesWindowController.swift` | `NSPanel`: location search, favorites list, auto-location checkbox, unit toggle |
| `Tests/WeatherTests/ModelsTests.swift` | Pure function coverage |
| `Tests/WeatherTests/AppConfigTests.swift` | Config encode/decode, favorites round-trip |
| `Tests/WeatherTests/OpenMeteoClientTests.swift` | URL construction, JSON decoding |
| `Tests/WeatherTests/WeatherFetcherTests.swift` | Cache hit/miss, manual location, error paths |
| `Tests/WeatherTests/StatusBarControllerTests.swift` | `titleString(for:unit:)` for all states |

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Info.plist`
- Create: `Sources/Weather/main.swift`
- Create: `Sources/Weather/AppDelegate.swift`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/philipp/Development/weather
mkdir -p Sources/Weather Tests/WeatherTests
```

- [ ] **Step 2: Write `Package.swift`**

```swift
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
```

- [ ] **Step 3: Write `Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.philipp.weather</string>
    <key>CFBundleName</key>
    <string>Weather</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Weather needs your location to show local conditions.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 4: Write `Sources/Weather/main.swift`**

```swift
// Sources/Weather/main.swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 5: Write `Sources/Weather/AppDelegate.swift` (stub — wired up in Task 9)**

```swift
// Sources/Weather/AppDelegate.swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // wired up in Task 9
    }
}
```

- [ ] **Step 6: Verify scaffold builds**

```bash
swift build
```

Expected: `Build complete!` (the app launches but shows nothing yet — that's fine).

- [ ] **Step 7: Commit**

```bash
git add Package.swift Info.plist Sources/
git commit -m "chore: project scaffold"
```

---

### Task 2: Models — Data Types and Pure Helpers (TDD)

**Files:**
- Create: `Tests/WeatherTests/ModelsTests.swift`
- Create: `Sources/Weather/Models.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/WeatherTests/ModelsTests.swift
import XCTest
@testable import Weather

final class ModelsTests: XCTestCase {

    // MARK: weatherEmoji

    func testWeatherEmojiClearSky()      { XCTAssertEqual(weatherEmoji(0),  "☀️") }
    func testWeatherEmojiMainlyClear()   { XCTAssertEqual(weatherEmoji(1),  "🌤️") }
    func testWeatherEmojiPartlyCloudy()  { XCTAssertEqual(weatherEmoji(2),  "⛅") }
    func testWeatherEmojiOvercast()      { XCTAssertEqual(weatherEmoji(3),  "☁️") }
    func testWeatherEmojiFog()           { XCTAssertEqual(weatherEmoji(45), "🌫️") }
    func testWeatherEmojiDrizzle()       { XCTAssertEqual(weatherEmoji(51), "🌦️") }
    func testWeatherEmojiRain()          { XCTAssertEqual(weatherEmoji(61), "🌧️") }
    func testWeatherEmojiSnow()          { XCTAssertEqual(weatherEmoji(71), "🌨️") }
    func testWeatherEmojiThunderstorm()  { XCTAssertEqual(weatherEmoji(95), "⛈️") }
    func testWeatherEmojiUnknown()       { XCTAssertEqual(weatherEmoji(999), "🌡️") }

    // MARK: weatherDescription

    func testWeatherDescriptionClearSky()    { XCTAssertEqual(weatherDescription(0),  "Clear sky") }
    func testWeatherDescriptionPartly()      { XCTAssertEqual(weatherDescription(2),  "Partly cloudy") }
    func testWeatherDescriptionOvercast()    { XCTAssertEqual(weatherDescription(3),  "Overcast") }
    func testWeatherDescriptionFoggy()       { XCTAssertEqual(weatherDescription(45), "Foggy") }
    func testWeatherDescriptionDrizzle()     { XCTAssertEqual(weatherDescription(51), "Drizzle") }
    func testWeatherDescriptionRain()        { XCTAssertEqual(weatherDescription(61), "Rain") }
    func testWeatherDescriptionSnow()        { XCTAssertEqual(weatherDescription(71), "Snow") }
    func testWeatherDescriptionThunder()     { XCTAssertEqual(weatherDescription(95), "Thunderstorm") }
    func testWeatherDescriptionUnknown()     { XCTAssertEqual(weatherDescription(999), "Unknown") }

    // MARK: windDirectionString

    func testWindNorth()     { XCTAssertEqual(windDirectionString(0.0),   "N") }
    func testWindNorthEast() { XCTAssertEqual(windDirectionString(45.0),  "NE") }
    func testWindEast()      { XCTAssertEqual(windDirectionString(90.0),  "E") }
    func testWindSouthEast() { XCTAssertEqual(windDirectionString(135.0), "SE") }
    func testWindSouth()     { XCTAssertEqual(windDirectionString(180.0), "S") }
    func testWindSouthWest() { XCTAssertEqual(windDirectionString(225.0), "SW") }
    func testWindWest()      { XCTAssertEqual(windDirectionString(270.0), "W") }
    func testWindNorthWest() { XCTAssertEqual(windDirectionString(315.0), "NW") }
    func testWindWrap()      { XCTAssertEqual(windDirectionString(360.0), "N") }
    func testWindBoundary()  { XCTAssertEqual(windDirectionString(337.5), "N") }

    // MARK: formatTemperature

    func testFormatCelsiusWhole()    { XCTAssertEqual(formatTemperature(0.0,   unit: .celsius),    "0°C") }
    func testFormatCelsiusDecimal()  { XCTAssertEqual(formatTemperature(14.5,  unit: .celsius),    "14.5°C") }
    func testFormatCelsiusNegative() { XCTAssertEqual(formatTemperature(-5.2,  unit: .celsius),    "-5.2°C") }
    func testFormatFahrenheitWhole() { XCTAssertEqual(formatTemperature(32.0,  unit: .fahrenheit), "32°F") }
    func testFormatFahrenheitDec()   { XCTAssertEqual(formatTemperature(58.3,  unit: .fahrenheit), "58.3°F") }
    func testFormatRoundsToOneDP()   { XCTAssertEqual(formatTemperature(14.56, unit: .celsius),    "14.6°C") }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter ModelsTests 2>&1 | head -20
```

Expected: compile error — `weatherEmoji`, `weatherDescription`, etc. not found.

- [ ] **Step 3: Write `Sources/Weather/Models.swift`**

```swift
// Sources/Weather/Models.swift
import Foundation
import CoreLocation

// MARK: - Temperature unit

enum TemperatureUnit: String, Codable {
    case celsius
    case fahrenheit
}

// MARK: - Internal display types

enum WeatherResult {
    case data(WeatherData)
    case noLocation
    case noConnection
    case locationDenied
}

struct WeatherData {
    let location: String
    let latitude: Double
    let longitude: Double
    let current: CurrentWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

struct CurrentWeather {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let precipitation: Double
    let weatherCode: Int
    let windSpeed: Double
    let windDirection: Double
}

struct HourlyForecast {
    let time: Date
    let temperature: Double
    let precipitationProbability: Int
    let weatherCode: Int
}

struct DailyForecast {
    let date: Date
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
    let precipitationSum: Double
    let precipitationProbabilityMax: Int
    let windSpeedMax: Double
}

struct GeocodingResult {
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - API response types (Codable)

struct APIForecastResponse: Codable {
    let current: APICurrentWeather
    let hourly: APIHourlyData
    let daily: APIDailyData
}

struct APICurrentWeather: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let precipitation: Double
    let weatherCode: Int
    let windSpeed10m: Double
    let windDirection10m: Double

    enum CodingKeys: String, CodingKey {
        case temperature2m       = "temperature_2m"
        case relativeHumidity2m  = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitation
        case weatherCode         = "weather_code"
        case windSpeed10m        = "wind_speed_10m"
        case windDirection10m    = "wind_direction_10m"
    }
}

struct APIHourlyData: Codable {
    let time: [String]
    let temperature2m: [Double]
    let precipitationProbability: [Int]
    let weatherCode: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m            = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case weatherCode              = "weather_code"
    }
}

struct APIDailyData: Codable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationSum: [Double]
    let precipitationProbabilityMax: [Int]
    let windSpeed10mMax: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode                 = "weather_code"
        case temperature2mMax            = "temperature_2m_max"
        case temperature2mMin            = "temperature_2m_min"
        case precipitationSum            = "precipitation_sum"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case windSpeed10mMax             = "wind_speed_10m_max"
    }
}

struct APIGeocodingResponse: Codable {
    let results: [APIGeocodingResult]?
}

struct APIGeocodingResult: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}

// MARK: - Pure helper functions

func weatherEmoji(_ code: Int) -> String {
    switch code {
    case 0:           return "☀️"
    case 1:           return "🌤️"
    case 2:           return "⛅"
    case 3:           return "☁️"
    case 45, 48:      return "🌫️"
    case 51...55:     return "🌦️"
    case 56, 57:      return "🌧️"
    case 61...67:     return "🌧️"
    case 71...77:     return "🌨️"
    case 80:          return "🌦️"
    case 81:          return "🌧️"
    case 82:          return "⛈️"
    case 85, 86:      return "🌨️"
    case 95, 96, 99:  return "⛈️"
    default:          return "🌡️"
    }
}

func weatherDescription(_ code: Int) -> String {
    switch code {
    case 0:       return "Clear sky"
    case 1:       return "Mainly clear"
    case 2:       return "Partly cloudy"
    case 3:       return "Overcast"
    case 45, 48:  return "Foggy"
    case 51...53: return "Drizzle"
    case 54, 55:  return "Dense drizzle"
    case 56, 57:  return "Freezing drizzle"
    case 61...63: return "Rain"
    case 64, 65:  return "Heavy rain"
    case 66, 67:  return "Freezing rain"
    case 71...73: return "Snow"
    case 74...76: return "Heavy snow"
    case 77:      return "Snow grains"
    case 80:      return "Rain showers"
    case 81, 82:  return "Heavy rain showers"
    case 85, 86:  return "Snow showers"
    case 95:      return "Thunderstorm"
    case 96, 99:  return "Thunderstorm with hail"
    default:      return "Unknown"
    }
}

func windDirectionString(_ degrees: Double) -> String {
    let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let idx = Int((degrees + 22.5) / 45.0) % 8
    return dirs[idx]
}

func formatTemperature(_ value: Double, unit: TemperatureUnit) -> String {
    let suffix = unit == .fahrenheit ? "°F" : "°C"
    let rounded = (value * 10.0).rounded() / 10.0
    if rounded.truncatingRemainder(dividingBy: 1.0) == 0 {
        return "\(Int(rounded))\(suffix)"
    }
    return "\(rounded)\(suffix)"
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter ModelsTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Weather/Models.swift Tests/WeatherTests/ModelsTests.swift
git commit -m "feat: models and pure formatting helpers"
```

---

### Task 3: AppConfig (TDD)

**Files:**
- Create: `Tests/WeatherTests/AppConfigTests.swift`
- Create: `Sources/Weather/AppConfig.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/WeatherTests/AppConfigTests.swift
import XCTest
@testable import Weather

final class AppConfigTests: XCTestCase {

    // MARK: Defaults

    func testDefaultValues() {
        let cfg = AppConfig()
        XCTAssertNil(cfg.location)
        XCTAssertNil(cfg.latitude)
        XCTAssertNil(cfg.longitude)
        XCTAssertEqual(cfg.temperatureUnit, .celsius)
        XCTAssertFalse(cfg.useAutoLocation)
        XCTAssertTrue(cfg.favorites.isEmpty)
    }

    // MARK: Round-trip

    func testEncodeDecodeRoundTrip() throws {
        var cfg = AppConfig()
        cfg.location = "Vienna"
        cfg.latitude = 48.2082
        cfg.longitude = 16.3738
        cfg.temperatureUnit = .fahrenheit
        cfg.useAutoLocation = true
        cfg.favorites = [FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)]

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.location, "Vienna")
        XCTAssertEqual(decoded.latitude, 48.2082)
        XCTAssertEqual(decoded.longitude, 16.3738)
        XCTAssertEqual(decoded.temperatureUnit, .fahrenheit)
        XCTAssertTrue(decoded.useAutoLocation)
        XCTAssertEqual(decoded.favorites.count, 1)
        XCTAssertEqual(decoded.favorites[0].name, "Vienna")
    }

    func testDecodesMissingOptionalFieldsGracefully() throws {
        let json = #"{"temperatureUnit":"celsius","useAutoLocation":false,"favorites":[]}"#
        let decoded = try JSONDecoder().decode(AppConfig.self, from: json.data(using: .utf8)!)
        XCTAssertNil(decoded.location)
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }

    // MARK: AppConfigStore persistence

    func testStoreLoadReturnDefaultWhenEmpty() {
        let store = AppConfigStore(suiteName: "test.\(UUID().uuidString)")
        let cfg = store.load()
        XCTAssertNil(cfg.location)
        XCTAssertEqual(cfg.temperatureUnit, .celsius)
    }

    func testStoreSaveAndLoad() {
        let store = AppConfigStore(suiteName: "test.\(UUID().uuidString)")
        var cfg = AppConfig()
        cfg.location = "Berlin"
        cfg.latitude = 52.52
        cfg.longitude = 13.405
        store.save(cfg)

        let loaded = store.load()
        XCTAssertEqual(loaded.location, "Berlin")
        XCTAssertEqual(loaded.latitude, 52.52)
        XCTAssertEqual(loaded.longitude, 13.405)
    }

    // MARK: Favorites

    func testFavoriteEquatability() {
        let a = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        let b = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        XCTAssertEqual(a, b)
    }

    func testFavoriteNotEqualDifferentCoords() {
        let a = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        let b = FavoriteLocation(name: "Vienna", latitude: 48.2083, longitude: 16.3738)
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter AppConfigTests 2>&1 | head -20
```

Expected: compile error — `AppConfig` not found.

- [ ] **Step 3: Write `Sources/Weather/AppConfig.swift`**

```swift
// Sources/Weather/AppConfig.swift
import Foundation

struct FavoriteLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

struct AppConfig: Codable {
    var location: String?
    var latitude: Double?
    var longitude: Double?
    var temperatureUnit: TemperatureUnit = .celsius
    var useAutoLocation: Bool = false
    var favorites: [FavoriteLocation] = []
}

final class AppConfigStore {
    static let shared = AppConfigStore()

    private let key = "config"
    private let defaults: UserDefaults

    init(suiteName: String = "weather") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func load() -> AppConfig {
        guard let data = defaults.data(forKey: key),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return AppConfig() }
        return config
    }

    func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter AppConfigTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Weather/AppConfig.swift Tests/WeatherTests/AppConfigTests.swift
git commit -m "feat: app config and UserDefaults persistence"
```

---

### Task 4: OpenMeteoClient (TDD)

**Files:**
- Create: `Tests/WeatherTests/OpenMeteoClientTests.swift`
- Create: `Sources/Weather/OpenMeteoClient.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/WeatherTests/OpenMeteoClientTests.swift
import XCTest
@testable import Weather

final class OpenMeteoClientTests: XCTestCase {

    // MARK: URL construction

    func testForecastURLContainsLatLon() {
        let url = OpenMeteoClient.forecastURL(lat: 48.2082, lon: 16.3738, unit: .celsius)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.contains("latitude=48.2082"))
        XCTAssertTrue(str.contains("longitude=16.3738"))
        XCTAssertTrue(str.contains("temperature_unit=celsius"))
    }

    func testForecastURLFahrenheit() {
        let url = OpenMeteoClient.forecastURL(lat: 0, lon: 0, unit: .fahrenheit)
        XCTAssertTrue(url?.absoluteString.contains("temperature_unit=fahrenheit") == true)
    }

    func testForecastURLContainsRequiredFields() {
        let url = OpenMeteoClient.forecastURL(lat: 0, lon: 0, unit: .celsius)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.contains("current="))
        XCTAssertTrue(str.contains("hourly="))
        XCTAssertTrue(str.contains("daily="))
        XCTAssertTrue(str.contains("timezone=auto"))
    }

    func testGeocodingURLEncodesQuery() {
        let url = OpenMeteoClient.geocodingURL(query: "New York")
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.contains("New%20York") || str.contains("New+York"))
    }

    func testGeocodingURLContainsCount() {
        let url = OpenMeteoClient.geocodingURL(query: "test")
        XCTAssertTrue(url?.absoluteString.contains("count=10") == true)
    }

    // MARK: Response processing

    func testProcessResponseBuildsWeatherData() {
        let resp = makeSampleForecastResponse()
        let data = OpenMeteoClient.processResponse(resp, location: "Vienna", lat: 48.2082, lon: 16.3738)

        XCTAssertEqual(data.location, "Vienna")
        XCTAssertEqual(data.latitude, 48.2082)
        XCTAssertEqual(data.longitude, 16.3738)
        XCTAssertEqual(data.current.temperature, 14.5)
        XCTAssertEqual(data.current.humidity, 72)
        XCTAssertEqual(data.current.weatherCode, 2)
        XCTAssertEqual(data.current.windSpeed, 18.5)
    }

    func testProcessResponseBuildsHourly() {
        let resp = makeSampleForecastResponse()
        let data = OpenMeteoClient.processResponse(resp, location: "Vienna", lat: 0, lon: 0)
        XCTAssertEqual(data.hourly.count, 2)
        XCTAssertEqual(data.hourly[0].temperature, 14.5)
        XCTAssertEqual(data.hourly[0].precipitationProbability, 10)
        XCTAssertEqual(data.hourly[0].weatherCode, 2)
    }

    func testProcessResponseBuildsDaily() {
        let resp = makeSampleForecastResponse()
        let data = OpenMeteoClient.processResponse(resp, location: "Vienna", lat: 0, lon: 0)
        XCTAssertEqual(data.daily.count, 2)
        XCTAssertEqual(data.daily[0].tempMax, 16.0)
        XCTAssertEqual(data.daily[0].tempMin, 8.0)
        XCTAssertEqual(data.daily[1].precipitationSum, 2.5)
    }

    func testProcessResponseMismatchedArraysDoesNotCrash() {
        var resp = makeSampleForecastResponse()
        // Remove one temperature entry — zip stops at the shorter array
        resp = APIForecastResponse(
            current: resp.current,
            hourly: APIHourlyData(
                time: ["2024-01-01T12:00", "2024-01-01T13:00"],
                temperature2m: [14.5],
                precipitationProbability: [10, 20],
                weatherCode: [2, 3]
            ),
            daily: resp.daily
        )
        let data = OpenMeteoClient.processResponse(resp, location: "X", lat: 0, lon: 0)
        XCTAssertEqual(data.hourly.count, 1)
    }

    // MARK: Geocoding response processing

    func testProcessGeocodingBuildsDisplayName() {
        let results = OpenMeteoClient.processGeocoding(APIGeocodingResponse(results: [
            APIGeocodingResult(name: "Vienna", latitude: 48.2082, longitude: 16.3738, country: "Austria", admin1: "Vienna")
        ]))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Vienna, Vienna, Austria")
        XCTAssertEqual(results[0].latitude, 48.2082)
    }

    func testProcessGeocodingFallsBackToNameOnly() {
        let results = OpenMeteoClient.processGeocoding(APIGeocodingResponse(results: [
            APIGeocodingResult(name: "Somewhere", latitude: 0, longitude: 0, country: nil, admin1: nil)
        ]))
        XCTAssertEqual(results[0].name, "Somewhere")
    }

    func testProcessGeocodingEmptyResults() {
        let results = OpenMeteoClient.processGeocoding(APIGeocodingResponse(results: nil))
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: JSON decoding

    func testDecodesAPIForecastResponse() throws {
        let json = """
        {
          "current": {
            "temperature_2m": 14.5, "relative_humidity_2m": 72,
            "apparent_temperature": 12.3, "precipitation": 0.0,
            "weather_code": 2, "wind_speed_10m": 18.5, "wind_direction_10m": 270.0
          },
          "hourly": {
            "time": ["2024-01-01T12:00"],
            "temperature_2m": [14.5],
            "precipitation_probability": [10],
            "weather_code": [2]
          },
          "daily": {
            "time": ["2024-01-01"],
            "weather_code": [2],
            "temperature_2m_max": [16.0],
            "temperature_2m_min": [8.0],
            "precipitation_sum": [0.0],
            "precipitation_probability_max": [5],
            "wind_speed_10m_max": [20.0]
          }
        }
        """
        let resp = try JSONDecoder().decode(APIForecastResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(resp.current.temperature2m, 14.5)
        XCTAssertEqual(resp.current.relativeHumidity2m, 72)
        XCTAssertEqual(resp.hourly.time.count, 1)
        XCTAssertEqual(resp.daily.temperature2mMax[0], 16.0)
    }

    // MARK: Helpers

    private func makeSampleForecastResponse() -> APIForecastResponse {
        APIForecastResponse(
            current: APICurrentWeather(
                temperature2m: 14.5, relativeHumidity2m: 72,
                apparentTemperature: 12.3, precipitation: 0.0,
                weatherCode: 2, windSpeed10m: 18.5, windDirection10m: 270.0
            ),
            hourly: APIHourlyData(
                time: ["2024-01-01T12:00", "2024-01-01T13:00"],
                temperature2m: [14.5, 15.0],
                precipitationProbability: [10, 20],
                weatherCode: [2, 3]
            ),
            daily: APIDailyData(
                time: ["2024-01-01", "2024-01-02"],
                weatherCode: [2, 3],
                temperature2mMax: [16.0, 18.0],
                temperature2mMin: [8.0, 10.0],
                precipitationSum: [0.0, 2.5],
                precipitationProbabilityMax: [5, 60],
                windSpeed10mMax: [20.0, 25.0]
            )
        )
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter OpenMeteoClientTests 2>&1 | head -20
```

Expected: compile error — `OpenMeteoClient` not found.

- [ ] **Step 3: Write `Sources/Weather/OpenMeteoClient.swift`**

```swift
// Sources/Weather/OpenMeteoClient.swift
import Foundation

protocol OpenMeteoClientProtocol {
    func fetchForecast(lat: Double, lon: Double, unit: TemperatureUnit, location: String) async throws -> WeatherData
    func geocode(query: String) async throws -> [GeocodingResult]
}

enum OpenMeteoError: Error {
    case invalidURL
    case httpError(Int)
}

final class OpenMeteoClient: OpenMeteoClientProtocol {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    // MARK: - URL constructors (static for testability)

    static func forecastURL(lat: Double, lon: Double, unit: TemperatureUnit) -> URL? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            URLQueryItem(name: "latitude",  value: "\(lat)"),
            URLQueryItem(name: "longitude", value: "\(lon)"),
            URLQueryItem(name: "current",   value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly",    value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "daily",     value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max"),
            URLQueryItem(name: "timezone",          value: "auto"),
            URLQueryItem(name: "temperature_unit",  value: unit.rawValue),
            URLQueryItem(name: "wind_speed_unit",   value: "kmh"),
            URLQueryItem(name: "precipitation_unit",value: "mm"),
        ]
        return c?.url
    }

    static func geocodingURL(query: String) -> URL? {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        c?.queryItems = [
            URLQueryItem(name: "name",     value: query),
            URLQueryItem(name: "count",    value: "10"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format",   value: "json"),
        ]
        return c?.url
    }

    // MARK: - Response processing (static for testability)

    static func processResponse(
        _ resp: APIForecastResponse,
        location: String,
        lat: Double,
        lon: Double
    ) -> WeatherData {
        let current = CurrentWeather(
            temperature: resp.current.temperature2m,
            apparentTemperature: resp.current.apparentTemperature,
            humidity: resp.current.relativeHumidity2m,
            precipitation: resp.current.precipitation,
            weatherCode: resp.current.weatherCode,
            windSpeed: resp.current.windSpeed10m,
            windDirection: resp.current.windDirection10m
        )

        let hourlyFmt = makeDateFormatter(format: "yyyy-MM-dd'T'HH:mm")
        let hourly: [HourlyForecast] = zip(
            zip(zip(resp.hourly.time, resp.hourly.temperature2m), resp.hourly.precipitationProbability),
            resp.hourly.weatherCode
        ).compactMap { (((t, temp), prob), code) in
            guard let date = hourlyFmt.date(from: t) else { return nil }
            return HourlyForecast(time: date, temperature: temp, precipitationProbability: prob, weatherCode: code)
        }

        let dailyFmt = makeDateFormatter(format: "yyyy-MM-dd")
        let daily: [DailyForecast] = zip(
            zip(zip(zip(zip(zip(resp.daily.time, resp.daily.weatherCode), resp.daily.temperature2mMax), resp.daily.temperature2mMin), resp.daily.precipitationSum), resp.daily.precipitationProbabilityMax),
            resp.daily.windSpeed10mMax
        ).compactMap { (((((( t, code), tMax), tMin), precSum), precProb), wind) in
            guard let date = dailyFmt.date(from: t) else { return nil }
            return DailyForecast(
                date: date, weatherCode: code,
                tempMax: tMax, tempMin: tMin,
                precipitationSum: precSum, precipitationProbabilityMax: precProb,
                windSpeedMax: wind
            )
        }

        return WeatherData(location: location, latitude: lat, longitude: lon,
                           current: current, hourly: hourly, daily: daily)
    }

    static func processGeocoding(_ resp: APIGeocodingResponse) -> [GeocodingResult] {
        (resp.results ?? []).map { r in
            let name: String
            if let admin1 = r.admin1, let country = r.country {
                name = "\(r.name), \(admin1), \(country)"
            } else if let country = r.country {
                name = "\(r.name), \(country)"
            } else {
                name = r.name
            }
            return GeocodingResult(name: name, latitude: r.latitude, longitude: r.longitude)
        }
    }

    private static func makeDateFormatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }

    // MARK: - Network calls

    func fetchForecast(lat: Double, lon: Double, unit: TemperatureUnit, location: String) async throws -> WeatherData {
        guard let url = Self.forecastURL(lat: lat, lon: lon, unit: unit) else {
            throw OpenMeteoError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OpenMeteoError.httpError(http.statusCode)
        }
        let resp = try JSONDecoder().decode(APIForecastResponse.self, from: data)
        return Self.processResponse(resp, location: location, lat: lat, lon: lon)
    }

    func geocode(query: String) async throws -> [GeocodingResult] {
        guard let url = Self.geocodingURL(query: query) else {
            throw OpenMeteoError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OpenMeteoError.httpError(http.statusCode)
        }
        let resp = try JSONDecoder().decode(APIGeocodingResponse.self, from: data)
        return Self.processGeocoding(resp)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter OpenMeteoClientTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Weather/OpenMeteoClient.swift Tests/WeatherTests/OpenMeteoClientTests.swift
git commit -m "feat: OpenMeteoClient with URL construction and response processing"
```

---

### Task 5: WeatherFetcher (TDD)

**Files:**
- Create: `Tests/WeatherTests/WeatherFetcherTests.swift`
- Create: `Sources/Weather/WeatherFetcher.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/WeatherTests/WeatherFetcherTests.swift
import XCTest
import CoreLocation
@testable import Weather

// MARK: - Mock client

final class MockOpenMeteoClient: OpenMeteoClientProtocol {
    var fetchResult: Result<WeatherData, Error> = .success(MockOpenMeteoClient.dummyData())
    var fetchCallCount = 0

    func fetchForecast(lat: Double, lon: Double, unit: TemperatureUnit, location: String) async throws -> WeatherData {
        fetchCallCount += 1
        return try fetchResult.get()
    }

    func geocode(query: String) async throws -> [GeocodingResult] { [] }

    static func dummyData() -> WeatherData {
        WeatherData(
            location: "Vienna", latitude: 48.2082, longitude: 16.3738,
            current: CurrentWeather(
                temperature: 14.5, apparentTemperature: 12.3, humidity: 72,
                precipitation: 0.0, weatherCode: 2, windSpeed: 18.5, windDirection: 270.0
            ),
            hourly: [], daily: []
        )
    }
}

// MARK: - Tests

@MainActor
final class WeatherFetcherTests: XCTestCase {

    func testNoLocationWhenNoCoordsAndManual() async {
        let mock = MockOpenMeteoClient()
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = nil
        config.longitude = nil

        let result = await fetcher.fetch(config: config)
        guard case .noLocation = result else { XCTFail("Expected .noLocation, got \(result)"); return }
        XCTAssertEqual(mock.fetchCallCount, 0)
    }

    func testManualLocationCallsClient() async {
        let mock = MockOpenMeteoClient()
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = 48.2082
        config.longitude = 16.3738
        config.location = "Vienna"

        let result = await fetcher.fetch(config: config)
        guard case .data(let data) = result else { XCTFail("Expected .data, got \(result)"); return }
        XCTAssertEqual(data.location, "Vienna")
        XCTAssertEqual(mock.fetchCallCount, 1)
    }

    func testCacheHitSkipsSecondCall() async {
        let mock = MockOpenMeteoClient()
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = 48.2082
        config.longitude = 16.3738
        config.location = "Vienna"

        _ = await fetcher.fetch(config: config)
        _ = await fetcher.fetch(config: config)

        XCTAssertEqual(mock.fetchCallCount, 1, "Second fetch within cache window should reuse cached result")
    }

    func testInvalidateCacheForcesFetch() async {
        let mock = MockOpenMeteoClient()
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = 48.2082
        config.longitude = 16.3738
        config.location = "Vienna"

        _ = await fetcher.fetch(config: config)
        fetcher.invalidateCache()
        _ = await fetcher.fetch(config: config)

        XCTAssertEqual(mock.fetchCallCount, 2, "After invalidation, cache should be busted")
    }

    func testNetworkErrorReturnsNoConnection() async {
        let mock = MockOpenMeteoClient()
        mock.fetchResult = .failure(URLError(.notConnectedToInternet))
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = 48.2082
        config.longitude = 16.3738
        config.location = "Vienna"

        let result = await fetcher.fetch(config: config)
        guard case .noConnection = result else { XCTFail("Expected .noConnection, got \(result)"); return }
    }

    func testCoordinateChangeBustsCache() async {
        let mock = MockOpenMeteoClient()
        let fetcher = WeatherFetcher(client: mock)
        var config = AppConfig()
        config.useAutoLocation = false
        config.latitude = 48.2082
        config.longitude = 16.3738
        config.location = "Vienna"

        _ = await fetcher.fetch(config: config)

        // Change coordinates significantly
        config.latitude = 52.52
        config.longitude = 13.405
        config.location = "Berlin"

        _ = await fetcher.fetch(config: config)

        XCTAssertEqual(mock.fetchCallCount, 2, "Different coordinates should bypass cache")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter WeatherFetcherTests 2>&1 | head -20
```

Expected: compile error — `WeatherFetcher` not found.

- [ ] **Step 3: Write `Sources/Weather/WeatherFetcher.swift`**

```swift
// Sources/Weather/WeatherFetcher.swift
import Foundation
import CoreLocation

@MainActor
final class WeatherFetcher: NSObject, CLLocationManagerDelegate {
    private let client: any OpenMeteoClientProtocol
    private let locationManager = CLLocationManager()
    private var cachedResult: (WeatherData, Date)?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private static let cacheTTL: TimeInterval = 300  // 5 minutes
    private static let coordTolerance: Double = 0.01 // ~1 km

    init(client: any OpenMeteoClientProtocol = OpenMeteoClient()) {
        self.client = client
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Main entry point

    func fetch(config: AppConfig) async -> WeatherResult {
        let lat: Double
        let lon: Double
        let locationName: String

        if config.useAutoLocation {
            do {
                let clLocation = try await requestCurrentLocation()
                lat = clLocation.coordinate.latitude
                lon = clLocation.coordinate.longitude
                locationName = await reverseGeocode(clLocation)
            } catch let error as CLError where error.code == .denied {
                return .locationDenied
            } catch {
                return .noConnection
            }
        } else {
            guard let configLat = config.latitude, let configLon = config.longitude else {
                return .noLocation
            }
            lat = configLat
            lon = configLon
            locationName = config.location ?? String(format: "%.4f, %.4f", lat, lon)
        }

        // Check cache
        if let (cached, fetchedAt) = cachedResult,
           abs(cached.latitude - lat) < Self.coordTolerance,
           abs(cached.longitude - lon) < Self.coordTolerance,
           Date().timeIntervalSince(fetchedAt) < Self.cacheTTL {
            return .data(cached)
        }

        // Fetch from API
        do {
            let data = try await client.fetchForecast(lat: lat, lon: lon, unit: config.temperatureUnit, location: locationName)
            cachedResult = (data, Date())
            return .data(data)
        } catch {
            return .noConnection
        }
    }

    func invalidateCache() {
        cachedResult = nil
    }

    // MARK: - CoreLocation

    private func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            // Cancel any in-flight request
            locationContinuation?.resume(throwing: CancellationError())
            locationContinuation = nil

            let status = locationManager.authorizationStatus
            switch status {
            case .denied, .restricted:
                continuation.resume(throwing: CLError(.denied))
                return
            case .authorizedWhenInUse, .authorized:
                locationContinuation = continuation
                locationManager.requestLocation()
            case .notDetermined:
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }

            // 10-second timeout
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, self.locationContinuation != nil else { return }
                self.locationContinuation?.resume(throwing: CLError(.locationUnknown))
                self.locationContinuation = nil
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        }
        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
            ?? String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = manager.authorizationStatus
            switch status {
            case .denied, .restricted:
                self.locationContinuation?.resume(throwing: CLError(.denied))
                self.locationContinuation = nil
            case .authorizedWhenInUse, .authorized:
                if self.locationContinuation != nil {
                    manager.requestLocation()
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter WeatherFetcherTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Weather/WeatherFetcher.swift Tests/WeatherTests/WeatherFetcherTests.swift
git commit -m "feat: WeatherFetcher with CoreLocation, cache, and fetch orchestration"
```

---

### Task 6: StatusBarController — Title String (TDD)

**Files:**
- Create: `Tests/WeatherTests/StatusBarControllerTests.swift`
- Create: `Sources/Weather/StatusBarController.swift` (partial — title string only)

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/WeatherTests/StatusBarControllerTests.swift
import XCTest
@testable import Weather

final class StatusBarControllerTests: XCTestCase {

    func testTitleWithData() {
        let data = makeWeatherData(temp: 14.5, code: 2)
        let title = StatusBarController.titleString(for: .data(data), unit: .celsius)
        XCTAssertEqual(title, "⛅ 14.5°C")
    }

    func testTitleWithDataFahrenheit() {
        let data = makeWeatherData(temp: 58.1, code: 0)
        let title = StatusBarController.titleString(for: .data(data), unit: .fahrenheit)
        XCTAssertEqual(title, "☀️ 58.1°F")
    }

    func testTitleWithDataWholeNumber() {
        let data = makeWeatherData(temp: 10.0, code: 3)
        let title = StatusBarController.titleString(for: .data(data), unit: .celsius)
        XCTAssertEqual(title, "☁️ 10°C")
    }

    func testTitleNoLocation() {
        let title = StatusBarController.titleString(for: .noLocation, unit: .celsius)
        XCTAssertEqual(title, "⛅ Weather")
    }

    func testTitleNoConnection() {
        let title = StatusBarController.titleString(for: .noConnection, unit: .celsius)
        XCTAssertEqual(title, "❌ No Connection")
    }

    func testTitleLocationDenied() {
        let title = StatusBarController.titleString(for: .locationDenied, unit: .celsius)
        XCTAssertEqual(title, "⛅ Weather")
    }

    // MARK: Helper

    private func makeWeatherData(temp: Double, code: Int) -> WeatherData {
        WeatherData(
            location: "Vienna", latitude: 48.2082, longitude: 16.3738,
            current: CurrentWeather(
                temperature: temp, apparentTemperature: 12.0, humidity: 72,
                precipitation: 0.0, weatherCode: code, windSpeed: 18.5, windDirection: 270.0
            ),
            hourly: [], daily: []
        )
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter StatusBarControllerTests 2>&1 | head -20
```

Expected: compile error — `StatusBarController` not found.

- [ ] **Step 3: Write `Sources/Weather/StatusBarController.swift` (stub with title string)**

```swift
// Sources/Weather/StatusBarController.swift
import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let fetcher = WeatherFetcher()
    private var lastConfig = AppConfigStore.shared.load()
    private var prefsController: PreferencesWindowController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛅ Weather"
        startTimer()
        Task { await refresh() }
    }

    // MARK: - Timer

    private func startTimer() {
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Refresh

    func refresh() async {
        let config = AppConfigStore.shared.load()
        lastConfig = config
        let result = await fetcher.fetch(config: config)
        statusItem.button?.title = Self.titleString(for: result, unit: config.temperatureUnit)
        statusItem.menu = buildMenu(for: result, config: config)
    }

    // MARK: - Title string (nonisolated static for testability)

    nonisolated static func titleString(for result: WeatherResult, unit: TemperatureUnit) -> String {
        switch result {
        case .data(let data):
            let emoji = weatherEmoji(data.current.weatherCode)
            let temp  = formatTemperature(data.current.temperature, unit: unit)
            return "\(emoji) \(temp)"
        case .noConnection:
            return "❌ No Connection"
        case .noLocation, .locationDenied:
            return "⛅ Weather"
        }
    }

    // MARK: - Menu building (completed in Task 7)

    private func buildMenu(for result: WeatherResult, config: AppConfig) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loading…", action: nil, keyEquivalent: ""))
        return menu
    }

    // MARK: - Preferences

    @objc private func openPreferences() {
        if prefsController == nil {
            prefsController = PreferencesWindowController()
            prefsController?.onClose = { [weak self] in
                self?.prefsController = nil
                Task { await self?.refresh() }
            }
        }
        prefsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func manualRefresh() {
        fetcher.invalidateCache()
        Task { await refresh() }
    }
}
```

Note: `PreferencesWindowController` referenced here — create an empty stub now so the project compiles:

```swift
// Sources/Weather/PreferencesWindowController.swift
import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onClose: (() -> Void)?

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Weather"
        panel.isReleasedWhenClosed = false
        panel.center()
        self.init(window: panel)
    }

    @MainActor override func close() {
        super.close()
        onClose?()
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter StatusBarControllerTests
```

Expected: all tests pass.

- [ ] **Step 5: Verify full build**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Sources/Weather/StatusBarController.swift Sources/Weather/PreferencesWindowController.swift Tests/WeatherTests/StatusBarControllerTests.swift
git commit -m "feat: StatusBarController title string and stubs"
```

---

### Task 7: StatusBarController — Full Menu and Actions

**Files:**
- Modify: `Sources/Weather/StatusBarController.swift`

- [ ] **Step 1: Replace `buildMenu` with the full implementation**

Replace the stub `buildMenu` and add all menu action handlers. Replace the entire file content:

```swift
// Sources/Weather/StatusBarController.swift
import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let fetcher = WeatherFetcher()
    private var lastConfig = AppConfigStore.shared.load()
    private var lastResult: WeatherResult = .noLocation
    private var prefsController: PreferencesWindowController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛅ Weather"
        startTimer()
        Task { await refresh() }
    }

    // MARK: - Timer

    private func startTimer() {
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Refresh

    func refresh() async {
        let config = AppConfigStore.shared.load()
        lastConfig = config
        let result = await fetcher.fetch(config: config)
        lastResult = result
        statusItem.button?.title = Self.titleString(for: result, unit: config.temperatureUnit)
        statusItem.menu = buildMenu(for: result, config: config)
    }

    // MARK: - Title string (nonisolated static for testability)

    nonisolated static func titleString(for result: WeatherResult, unit: TemperatureUnit) -> String {
        switch result {
        case .data(let data):
            return "\(weatherEmoji(data.current.weatherCode)) \(formatTemperature(data.current.temperature, unit: unit))"
        case .noConnection:
            return "❌ No Connection"
        case .noLocation, .locationDenied:
            return "⛅ Weather"
        }
    }

    // MARK: - Menu building

    private func buildMenu(for result: WeatherResult, config: AppConfig) -> NSMenu {
        let menu = NSMenu()
        switch result {
        case .noLocation:
            menu.addItem(disabled("Open Preferences to configure a location"))
        case .locationDenied:
            menu.addItem(disabled("❌ Location access denied"))
            menu.addItem(disabled("ℹ️ Enable in: System Settings → Privacy → Location Services"))
        case .noConnection:
            menu.addItem(disabled("Unable to fetch weather — check your internet connection"))
        case .data(let data):
            buildWeatherItems(data, config: config, into: menu)
        }
        menu.addItem(.separator())
        appendSettingsSubmenu(to: menu, config: config, data: { if case .data(let d) = result { return d } else { return nil } }())
        menu.addItem(.separator())
        appendRefreshItems(to: menu)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func buildWeatherItems(_ data: WeatherData, config: AppConfig, into menu: NSMenu) {
        menu.addItem(disabled("📍 \(data.location)"))
        menu.addItem(disabled("🌡️ \(formatTemperature(data.current.temperature, unit: config.temperatureUnit)) (feels like \(formatTemperature(data.current.apparentTemperature, unit: config.temperatureUnit)))"))
        menu.addItem(disabled("☁️ \(weatherEmoji(data.current.weatherCode)) \(weatherDescription(data.current.weatherCode))"))
        menu.addItem(disabled("💧 Humidity: \(data.current.humidity)%"))
        menu.addItem(disabled("💨 Wind: \(Int(data.current.windSpeed)) km/h \(windDirectionString(data.current.windDirection))"))
        if data.current.precipitation > 0 {
            menu.addItem(disabled(String(format: "🌧️ Precipitation: %.1f mm", data.current.precipitation)))
        }

        menu.addItem(.separator())
        menu.addItem(disabled("⏰ Next 24 Hours"))
        let now = Date()
        let hourlyEntries = data.hourly.filter { $0.time >= now }.prefix(24).stride(by: 3).prefix(8)
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        for entry in hourlyEntries {
            let timeStr = timeFmt.string(from: entry.time)
            let temp = formatTemperature(entry.temperature, unit: config.temperatureUnit)
            let precip = entry.precipitationProbability > 0 ? " 💧\(entry.precipitationProbability)%" : ""
            menu.addItem(disabled("\(timeStr): \(weatherEmoji(entry.weatherCode)) \(temp)\(precip)"))
        }

        menu.addItem(.separator())
        menu.addItem(disabled("📅 7-Day Forecast"))
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE"
        for (idx, day) in data.daily.enumerated() {
            let label = idx == 0 ? "Today" : idx == 1 ? "Tomorrow" : dateFmt.string(from: day.date)
            let tMax = formatTemperature(day.tempMax, unit: config.temperatureUnit)
            let tMin = formatTemperature(day.tempMin, unit: config.temperatureUnit)
            let precip = day.precipitationSum > 0
                ? String(format: " 💧%.1fmm (%d%%)", day.precipitationSum, day.precipitationProbabilityMax)
                : ""
            menu.addItem(disabled("\(label): \(weatherEmoji(day.weatherCode)) \(tMin) – \(tMax)\(precip) 💨\(Int(day.windSpeedMax))km/h"))
        }
    }

    private func appendSettingsSubmenu(to menu: NSMenu, config: AppConfig, data: WeatherData?) {
        let settings = NSMenuItem(title: "⚙️ Settings", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let unitLabel = config.temperatureUnit == .fahrenheit ? "Temperature: Fahrenheit" : "Temperature: Celsius"
        sub.addItem(action(unitLabel, #selector(toggleUnit)))

        let locLabel = config.useAutoLocation ? "Location: 🎯 Automatic" : "Location: Manual"
        sub.addItem(action(locLabel, #selector(toggleAutoLocation)))

        if let data = data {
            let isFav = config.favorites.contains { abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001 }
            if isFav {
                sub.addItem(action("⭐ Remove from Favorites", #selector(removeFavorite)))
            } else {
                sub.addItem(action("⭐ Add to Favorites", #selector(addFavorite)))
            }
        }

        if !config.favorites.isEmpty {
            let favsItem = NSMenuItem(title: "📍 Favorite Locations", action: nil, keyEquivalent: "")
            let favsSub = NSMenu()
            for fav in config.favorites {
                let isCurrent = data.map { abs($0.latitude - fav.latitude) < 0.001 && abs($0.longitude - fav.longitude) < 0.001 } ?? false
                let label = isCurrent ? "✓ \(fav.name)" : fav.name
                let item = action(label, #selector(setFavoriteLocation(_:)))
                item.representedObject = fav
                favsSub.addItem(item)
            }
            favsItem.submenu = favsSub
            sub.addItem(favsItem)
        }

        settings.submenu = sub
        menu.addItem(settings)
    }

    private func appendRefreshItems(to menu: NSMenu) {
        let refreshItem = NSMenuItem(title: "🔄 Refresh", action: nil, keyEquivalent: "")
        let refreshSub = NSMenu()
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        refreshSub.addItem(disabled("Last updated: \(now)"))
        refreshItem.submenu = refreshSub
        menu.addItem(refreshItem)
        menu.addItem(action("🔄 Refresh Now", #selector(manualRefresh), key: "r"))
    }

    // MARK: - Menu helpers

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleUnit() {
        var config = AppConfigStore.shared.load()
        config.temperatureUnit = config.temperatureUnit == .fahrenheit ? .celsius : .fahrenheit
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func toggleAutoLocation() {
        var config = AppConfigStore.shared.load()
        config.useAutoLocation.toggle()
        AppConfigStore.shared.save(config)
        fetcher.invalidateCache()
        Task { await refresh() }
    }

    @objc private func addFavorite() {
        guard case .data(let data) = lastResult else { return }
        var config = AppConfigStore.shared.load()
        let alreadyExists = config.favorites.contains {
            abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001
        }
        guard !alreadyExists else { return }
        config.favorites.append(FavoriteLocation(name: data.location, latitude: data.latitude, longitude: data.longitude))
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func removeFavorite() {
        guard case .data(let data) = lastResult else { return }
        var config = AppConfigStore.shared.load()
        config.favorites.removeAll {
            abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001
        }
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func setFavoriteLocation(_ sender: NSMenuItem) {
        guard let fav = sender.representedObject as? FavoriteLocation else { return }
        var config = AppConfigStore.shared.load()
        config.location = fav.name
        config.latitude = fav.latitude
        config.longitude = fav.longitude
        config.useAutoLocation = false
        AppConfigStore.shared.save(config)
        fetcher.invalidateCache()
        Task { await refresh() }
    }

    @objc private func openPreferences() {
        if prefsController == nil {
            prefsController = PreferencesWindowController()
            prefsController?.onClose = { [weak self] in
                self?.prefsController = nil
                Task { await self?.refresh() }
            }
        }
        prefsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func manualRefresh() {
        fetcher.invalidateCache()
        Task { await refresh() }
    }
}

// MARK: - Collection stride helper

private extension Collection {
    func stride(by step: Int) -> [Element] {
        var result: [Element] = []
        var i = startIndex
        while i < endIndex {
            result.append(self[i])
            let dist = distance(from: i, to: endIndex)
            if dist <= step { break }
            i = index(i, offsetBy: step)
        }
        return result
    }
}
```

- [ ] **Step 2: Run all tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/Weather/StatusBarController.swift
git commit -m "feat: StatusBarController full menu and actions"
```

---

### Task 8: PreferencesWindowController

**Files:**
- Modify: `Sources/Weather/PreferencesWindowController.swift`

- [ ] **Step 1: Replace the stub with the full implementation**

```swift
// Sources/Weather/PreferencesWindowController.swift
import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onClose: (() -> Void)?

    private var locationField: NSTextField!
    private var resultsScrollView: NSScrollView!
    private var resultsTable: NSTableView!
    private var favoritesTable: NSTableView!
    private var deleteFavButton: NSButton!
    private var autoLocationCheckbox: NSButton!
    private var celsiusRadio: NSButton!
    private var fahrenheitRadio: NSButton!

    private var searchResults: [GeocodingResult] = []
    private var favorites: [FavoriteLocation] = []
    private var pendingLocation: String?
    private var pendingLatitude: Double?
    private var pendingLongitude: Double?
    private var pendingAutoLocation: Bool = false
    private var pendingUnit: TemperatureUnit = .celsius

    private var searchTimer: Timer?
    private var searchTask: Task<Void, Never>?
    private let client = OpenMeteoClient()

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 310),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Weather"
        panel.isReleasedWhenClosed = false
        panel.center()
        self.init(window: panel)
        loadCurrentConfig()
        setupUI()
    }

    private func loadCurrentConfig() {
        let config = AppConfigStore.shared.load()
        pendingLocation     = config.location
        pendingLatitude     = config.latitude
        pendingLongitude    = config.longitude
        pendingAutoLocation = config.useAutoLocation
        pendingUnit         = config.temperatureUnit
        favorites           = config.favorites
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }

        // Location label
        let locLabel = label("Location")
        locLabel.frame = NSRect(x: 16, y: 270, width: 70, height: 20)
        cv.addSubview(locLabel)

        // Location text field
        locationField = NSTextField()
        locationField.placeholderString = "Search for a city…"
        locationField.stringValue = pendingLocation ?? ""
        locationField.bezelStyle = .roundedBezel
        locationField.frame = NSRect(x: 90, y: 266, width: 274, height: 24)
        locationField.delegate = self
        cv.addSubview(locationField)

        // Search results (hidden until results arrive)
        resultsScrollView = NSScrollView(frame: NSRect(x: 90, y: 190, width: 274, height: 70))
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.borderType = .bezelBorder
        resultsTable = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "Result"
        resultsTable.addTableColumn(col)
        resultsTable.headerView = nil
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.action = #selector(resultRowClicked)
        resultsTable.target = self
        resultsScrollView.documentView = resultsTable
        resultsScrollView.isHidden = true
        cv.addSubview(resultsScrollView)

        // Favorites label
        let favLabel = label("Favorites:")
        favLabel.frame = NSRect(x: 16, y: 166, width: 80, height: 20)
        cv.addSubview(favLabel)

        // Delete button
        deleteFavButton = NSButton(title: "–", target: self, action: #selector(deleteSelectedFavorite))
        deleteFavButton.bezelStyle = .smallSquare
        deleteFavButton.frame = NSRect(x: 332, y: 162, width: 32, height: 24)
        deleteFavButton.isEnabled = false
        cv.addSubview(deleteFavButton)

        // Favorites table
        let favScroll = NSScrollView(frame: NSRect(x: 16, y: 88, width: 348, height: 70))
        favScroll.hasVerticalScroller = true
        favScroll.borderType = .bezelBorder
        favoritesTable = NSTableView()
        let favCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fav"))
        favCol.title = "Favorite"
        favoritesTable.addTableColumn(favCol)
        favoritesTable.headerView = nil
        favoritesTable.dataSource = self
        favoritesTable.delegate = self
        favoritesTable.action = #selector(favoriteRowClicked)
        favoritesTable.target = self
        favScroll.documentView = favoritesTable
        cv.addSubview(favScroll)

        // Auto-location checkbox
        autoLocationCheckbox = NSButton(checkboxWithTitle: "Use automatic location", target: self, action: #selector(autoLocationChanged))
        autoLocationCheckbox.state = pendingAutoLocation ? .on : .off
        autoLocationCheckbox.frame = NSRect(x: 16, y: 60, width: 220, height: 20)
        cv.addSubview(autoLocationCheckbox)
        locationField.isEnabled = !pendingAutoLocation

        // Temperature unit
        let unitLabel = label("Temperature:")
        unitLabel.frame = NSRect(x: 16, y: 32, width: 90, height: 20)
        cv.addSubview(unitLabel)

        celsiusRadio = NSButton(radioButtonWithTitle: "Celsius", target: self, action: #selector(unitChanged(_:)))
        celsiusRadio.frame = NSRect(x: 110, y: 32, width: 80, height: 20)
        celsiusRadio.state = pendingUnit == .celsius ? .on : .off
        cv.addSubview(celsiusRadio)

        fahrenheitRadio = NSButton(radioButtonWithTitle: "Fahrenheit", target: self, action: #selector(unitChanged(_:)))
        fahrenheitRadio.frame = NSRect(x: 195, y: 32, width: 100, height: 20)
        fahrenheitRadio.state = pendingUnit == .fahrenheit ? .on : .off
        cv.addSubview(fahrenheitRadio)

        // Save & Close
        let saveBtn = NSButton(title: "Save & Close", target: self, action: #selector(saveAndClose))
        saveBtn.bezelStyle = .rounded
        saveBtn.frame = NSRect(x: 264, y: 4, width: 100, height: 28)
        cv.addSubview(saveBtn)
    }

    // MARK: - Debounced search

    private func scheduleSearch(query: String) {
        searchTimer?.invalidate()
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            resultsTable.reloadData()
            resultsScrollView.isHidden = true
            return
        }
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.searchTask = Task { await self?.performSearch(query: query) }
            }
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        guard !Task.isCancelled else { return }
        guard let results = try? await client.geocode(query: query) else { return }
        guard !Task.isCancelled else { return }
        searchResults = results
        resultsTable.reloadData()
        resultsScrollView.isHidden = results.isEmpty
    }

    // MARK: - Actions

    @objc private func resultRowClicked() {
        let row = resultsTable.clickedRow
        guard row >= 0, row < searchResults.count else { return }
        let result = searchResults[row]
        pendingLocation  = result.name
        pendingLatitude  = result.latitude
        pendingLongitude = result.longitude
        locationField.stringValue = result.name
        searchResults = []
        resultsTable.reloadData()
        resultsScrollView.isHidden = true
    }

    @objc private func favoriteRowClicked() {
        let row = favoritesTable.clickedRow
        guard row >= 0, row < favorites.count else { return }
        let fav = favorites[row]
        pendingLocation  = fav.name
        pendingLatitude  = fav.latitude
        pendingLongitude = fav.longitude
        locationField.stringValue = fav.name
        searchResults = []
        resultsTable.reloadData()
        resultsScrollView.isHidden = true
    }

    @objc private func deleteSelectedFavorite() {
        let row = favoritesTable.selectedRow
        guard row >= 0, row < favorites.count else { return }
        favorites.remove(at: row)
        favoritesTable.reloadData()
        deleteFavButton.isEnabled = favoritesTable.selectedRow >= 0
    }

    @objc private func autoLocationChanged() {
        pendingAutoLocation = autoLocationCheckbox.state == .on
        locationField.isEnabled = !pendingAutoLocation
    }

    @objc private func unitChanged(_ sender: NSButton) {
        pendingUnit = sender === celsiusRadio ? .celsius : .fahrenheit
    }

    @objc private func saveAndClose() {
        var config = AppConfigStore.shared.load()
        config.useAutoLocation  = pendingAutoLocation
        config.temperatureUnit  = pendingUnit

        if !pendingAutoLocation {
            config.location   = pendingLocation
            config.latitude   = pendingLatitude
            config.longitude  = pendingLongitude

            // Auto-add manual location to favorites
            if let name = pendingLocation, let lat = pendingLatitude, let lon = pendingLongitude {
                let alreadyExists = favorites.contains { abs($0.latitude - lat) < 0.001 && abs($0.longitude - lon) < 0.001 }
                if !alreadyExists {
                    favorites.append(FavoriteLocation(name: name, latitude: lat, longitude: lon))
                }
            }
        }
        config.favorites = favorites
        AppConfigStore.shared.save(config)
        close()
    }

    @MainActor override func close() {
        super.close()
        onClose?()
    }

    // MARK: - UI helper

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: 13)
        return f
    }
}

// MARK: - NSTextFieldDelegate

extension PreferencesWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === locationField else { return }
        // Clear pending location when user types (new search needed)
        pendingLatitude  = nil
        pendingLongitude = nil
        scheduleSearch(query: field.stringValue)
    }
}

// MARK: - NSTableViewDataSource + Delegate

extension PreferencesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === resultsTable ? searchResults.count : favorites.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let t = notification.object as? NSTableView, t === favoritesTable else { return }
        deleteFavButton.isEnabled = favoritesTable.selectedRow >= 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 13)
        cell.stringValue = tableView === resultsTable ? searchResults[row].name : favorites[row].name
        return cell
    }
}
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 3: Run all tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Weather/PreferencesWindowController.swift
git commit -m "feat: PreferencesWindowController with location search and favorites"
```

---

### Task 9: Wire Up AppDelegate + Preferences Menu Item

**Files:**
- Modify: `Sources/Weather/AppDelegate.swift`
- Modify: `Sources/Weather/StatusBarController.swift` (add Preferences menu item)

- [ ] **Step 1: Update `AppDelegate` to create `StatusBarController`**

```swift
// Sources/Weather/AppDelegate.swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
```

- [ ] **Step 2: Add Preferences menu item to `StatusBarController.buildMenu`**

In `buildMenu(for:config:)`, add the preferences item before the Quit item. Find this line:

```swift
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
```

Replace with:

```swift
        menu.addItem(.separator())
        menu.addItem(action("Preferences…", #selector(openPreferences), key: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
```

- [ ] **Step 3: Run all tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Build and do a smoke test**

```bash
swift build && .build/debug/Weather
```

Expected: a `⛅ Weather` item appears in the menu bar. Click it — you should see a menu with "Open Preferences to configure a location" and a Preferences… item. Open Preferences → type a city → see geocoding results. The app should not crash.

Kill the process with Ctrl-C.

- [ ] **Step 5: Commit**

```bash
git add Sources/Weather/AppDelegate.swift Sources/Weather/StatusBarController.swift
git commit -m "feat: wire up AppDelegate and add Preferences menu item"
```

---

### Task 10: rebuild.sh and .app Bundle

**Files:**
- Create: `rebuild.sh`

- [ ] **Step 1: Write `rebuild.sh`**

```bash
#!/bin/bash
set -e

APP_NAME="Weather"
BUNDLE="$APP_NAME.app"
BINARY_NAME="Weather"
BUILD_DIR=".build/release"

echo "▶ Building..."
swift build -c release

echo "▶ Creating bundle..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

cp "$BUILD_DIR/$BINARY_NAME" "$BUNDLE/Contents/MacOS/$BINARY_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"

echo "▶ Signing..."
codesign --force --sign - "$BUNDLE"

echo "✅ $BUNDLE ready"
echo "   To install: cp -r $BUNDLE /Applications/"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x rebuild.sh
```

- [ ] **Step 3: Build the bundle**

```bash
./rebuild.sh
```

Expected output:
```
▶ Building...
Build complete!
▶ Creating bundle...
▶ Signing...
✅ Weather.app ready
   To install: cp -r Weather.app /Applications/
```

- [ ] **Step 4: Launch the bundle**

```bash
open Weather.app
```

Expected: `⛅ Weather` appears in the menu bar. The first time you enable automatic location, macOS will show a permission dialog using the text from `Info.plist`.

- [ ] **Step 5: Verify the full flow manually**
  - Open Preferences → type "Vienna" → see geocoding results → click one → Save & Close
  - Menu bar shows `⛅ 14.5°C` (or current conditions)
  - Click menu → current conditions, hourly, and 7-day forecast visible
  - Settings → toggle °C/°F → title updates
  - Settings → Add to Favorites → favorites submenu appears
  - Refresh Now → fetches fresh data

- [ ] **Step 6: Kill old debug process if running, then commit**

```bash
killall Weather 2>/dev/null || true
git add rebuild.sh
git commit -m "feat: rebuild.sh and .app bundle"
```

---

### Task 11: Final Polish — .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
.build/
*.app/
.DS_Store
.swiftpm/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

## Self-Review

**Spec coverage:**
- ✅ Menu bar title (emoji + temp) — `titleString(for:unit:)` in Task 6
- ✅ Current conditions (temp, feels like, humidity, wind, precipitation) — `buildWeatherItems` in Task 7
- ✅ Next 24h hourly (every 3h, future only, up to 8 entries) — `buildWeatherItems` in Task 7
- ✅ 7-day daily forecast — `buildWeatherItems` in Task 7
- ✅ °C/°F toggle — `toggleUnit` action in Task 7
- ✅ Auto-location via CoreLocation — `WeatherFetcher` in Task 5
- ✅ Manual location via geocoding search — `PreferencesWindowController` in Task 8
- ✅ Favorite locations (add/remove/switch) — `addFavorite`, `removeFavorite`, `setFavoriteLocation` in Task 7; favorites table in Task 8
- ✅ 5-minute refresh timer — `startTimer` in Task 6
- ✅ On-demand refresh — `manualRefresh` in Task 7
- ✅ 5-minute cache — `WeatherFetcher.cachedResult` in Task 5
- ✅ Error states (.noLocation, .noConnection, .locationDenied) — `buildMenu` in Task 7
- ✅ UserDefaults persistence — `AppConfigStore` in Task 3
- ✅ .app bundle + codesign — `rebuild.sh` in Task 10
- ✅ Info.plist with `LSUIElement` and `NSLocationWhenInUseUsageDescription` — Task 1

**No placeholders or TBD items found.**

**Type consistency:** All types (`WeatherResult`, `WeatherData`, `AppConfig`, `FavoriteLocation`, `GeocodingResult`, `OpenMeteoClientProtocol`) defined in Tasks 2–4 and used consistently in Tasks 5–8.
