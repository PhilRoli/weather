# Weather Swift — Design Spec

_2026-06-01_

## Goal

A native macOS menu bar app in Swift that replaces the existing Rust/xbar weather plugin. It shows current weather conditions and forecasts from Open-Meteo in the menu bar, supports automatic location via CoreLocation, and lets the user save and switch between favorite locations.

## Architecture

Seven Swift files, zero third-party dependencies (URLSession + AppKit + CoreLocation):

```
weather/
  Sources/Weather/
    main.swift                        — NSApplication entry, LSUIElement = YES
    AppDelegate.swift                 — creates StatusBarController on launch
    StatusBarController.swift         — NSStatusItem, 5-min timer, menu building, menu actions
    PreferencesWindowController.swift — NSPanel: location search, favorites, °C/°F toggle
    OpenMeteoClient.swift             — URLSession: forecast + geocoding API calls
    WeatherFetcher.swift              — CoreLocation, 5-min cache, fetch orchestration
    AppConfig.swift                   — Codable config + UserDefaults persistence
    Models.swift                      — API response types + internal display types
  Tests/WeatherTests/
    AppConfigTests.swift
    ModelsTests.swift
    OpenMeteoClientTests.swift
    WeatherFetcherTests.swift
    StatusBarControllerTests.swift
  Info.plist                          — NSLocationWhenInUseUsageDescription, LSUIElement = YES
  Package.swift
  rebuild.sh
```

Data flow:

```
Timer (5 min) or manual Refresh
  → WeatherFetcher.fetch(config:)
      → if auto-location: CLLocationManager.requestLocation() via async/await continuation
      → check 5-min in-memory cache; skip API call if coordinates unchanged and fresh
      → OpenMeteoClient.fetchForecast(lat:lon:unit:) via URLSession
      → returns WeatherResult (.data / .noLocation / .noConnection / .locationDenied)
  → StatusBarController rebuilds NSMenu and updates title string
```

`PreferencesWindowController` is independent: calls `OpenMeteoClient.geocode(query:)` as the user types (300ms debounce), writes the chosen location to `AppConfig`, and triggers a cache-busting refresh on close.

## API

**Open-Meteo forecast:**
```
GET https://api.open-meteo.com/v1/forecast
    ?latitude=<lat>&longitude=<lon>
    &current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m
    &hourly=temperature_2m,precipitation_probability,weather_code
    &daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max
    &timezone=auto&temperature_unit=<celsius|fahrenheit>&wind_speed_unit=kmh&precipitation_unit=mm
```

**Open-Meteo geocoding:**
```
GET https://geocoding-api.open-meteo.com/v1/search?name=<query>&count=10&language=en&format=json
```

Both are free, no API key required.

## Models

### Internal display types

```swift
enum WeatherResult {
    case data(WeatherData)
    case noLocation          // no location configured yet
    case noConnection        // network or decode error
    case locationDenied      // CoreLocation permission denied
}

struct WeatherData {
    let location: String
    let latitude: Double
    let longitude: Double
    let current: CurrentWeather
    let hourly: [HourlyForecast]   // all hourly entries from API (next 7 days)
    let daily: [DailyForecast]     // 7 days
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
```

### Config & Persistence

Stored in `UserDefaults` suite `"weather"` as a single JSON-encoded `AppConfig` blob — same `AppConfigStore` pattern as TrainTracker.

```swift
enum TemperatureUnit: String, Codable { case celsius, fahrenheit }

struct FavoriteLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

struct AppConfig: Codable {
    var location: String?
    var latitude: Double?
    var longitude: Double?
    var temperatureUnit: TemperatureUnit   // default .celsius
    var useAutoLocation: Bool              // default false
    var favorites: [FavoriteLocation]      // default []
}
```

## WeatherFetcher

```swift
final class WeatherFetcher: NSObject, CLLocationManagerDelegate {
    private let client: OpenMeteoClientProtocol
    private let locationManager = CLLocationManager()
    private var cachedResult: (WeatherData, Date)?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    func fetch(config: AppConfig) async -> WeatherResult
    func invalidateCache()
}
```

**Fetch logic:**

1. If `useAutoLocation` → `requestWhenInUseAuthorization()` if needed, then `requestLocation()` wrapped in a `CheckedContinuation`. Timeout after 10s → `.noConnection`. Permission denied → `.locationDenied`.
2. If manual → use `config.latitude` / `config.longitude`. If nil → `.noLocation`.
3. Check cache: if less than 5 minutes old and coordinates match → return `.data(cached)`.
4. Call `OpenMeteoClient.fetchForecast`. Network/decode error → `.noConnection`. Success → update cache, return `.data`.

**CLLocationManager setup:**
- `desiredAccuracy = kCLLocationAccuracyThreeKilometers` — sufficient for weather, avoids GPS spin-up
- Authorization requested once on first auto-location fetch

**Cache invalidation:** `invalidateCache()` called when user hits Refresh or changes settings in Preferences.

## Menu Bar UI

**Title strings:**

| State | Title |
|---|---|
| Data available | `⛅ 14.5°C` (emoji from WMO code + formatted temp) |
| No location / pending / denied | `⛅ Weather` |
| No connection | `❌ No Connection` |

**Menu when data available:**

```
📍 Vienna
🌡️ 14.5°C (feels like 12.3°C)
☁️ ⛅ Partly cloudy
💧 Humidity: 72%
💨 Wind: 18 km/h W
─────────────────────────────────
⏰ Next 24 Hours
  12:00: ⛅ 14°C
  15:00: ☁️ 13°C 💧20%
  18:00: 🌦️ 11°C 💧45%
  (up to 8 entries, every 3h, future only)
─────────────────────────────────
📅 7-Day Forecast
  Today:     ⛅ 8°C – 16°C 💨18km/h
  Tomorrow:  ☁️ 7°C – 14°C 💧2.5mm (60%)
  Wednesday: ...
─────────────────────────────────
⚙️ Settings  ▶
   Temperature: Celsius             (toggle)
   Location: 🎯 Automatic           (toggle)
   ⭐ Add to Favorites / Remove from Favorites
   📍 Favorite Locations  ▶
      ✓ Vienna
        Berlin
─────────────────────────────────
🔄 Refresh
   Last updated: 14:32:01           (disabled sub-item)
Quit
```

Error/no-config menus show a plain disabled message explaining the state, with Settings and Refresh below.

## Preferences Panel

`NSPanel`, ~380×220pt, `nonactivatingPanel`, centered:

```
┌─────────────────────────────────────────┐
│  Weather                                │
│                                         │
│  Location  [Vienna                    ] │
│            ┌──────────────────────────┐ │
│            │ Vienna, Vienna, Austria  │ │
│            │ Vienna, VA, United States│ │
│            └──────────────────────────┘ │
│                                         │
│  Favorites:                  [–]        │
│  ┌──────────────────────────────────┐   │
│  │ Vienna                           │   │
│  │ Berlin                           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ ] Use automatic location             │
│  Temperature:  ● Celsius  ○ Fahrenheit  │
│                                         │
│                          [Save & Close] │
└─────────────────────────────────────────┘
```

- Typing triggers 300ms-debounced geocoding search; clicking a result sets lat/lon/name
- "Use automatic location" disables the search field; uses CoreLocation on next fetch
- Favorites list: `–` button deletes selected row; if a manual location is set, it is auto-added to favorites on Save (if not already present); auto-location mode does not auto-add
- Save & Close: persists config, calls `invalidateCache()`, triggers immediate refresh

## Build & Deployment

`rebuild.sh` (mirrors TrainTracker):
1. `swift build -c release`
2. Create `Weather.app/Contents/MacOS/` and `Weather.app/Contents/Resources/`
3. Copy binary → `Weather.app/Contents/MacOS/Weather`
4. Copy `Info.plist` → `Weather.app/Contents/`
5. `codesign --force --sign - Weather.app`

`Info.plist` keys:
- `LSUIElement = YES` (no Dock icon)
- `NSLocationWhenInUseUsageDescription` — "Weather needs your location to show local conditions."
- `CFBundleIdentifier = com.philipp.weather`
- `CFBundleName = Weather`

## Testing

Protocol-based injection for the API client:

```swift
protocol OpenMeteoClientProtocol {
    func fetchForecast(lat: Double, lon: Double, unit: TemperatureUnit) async throws -> WeatherData
    func geocode(query: String) async throws -> [GeocodingResult]
}

struct GeocodingResult {
    let name: String      // display name, e.g. "Vienna, Vienna, Austria"
    let latitude: Double
    let longitude: Double
}
```

| Test file | Coverage |
|---|---|
| `ModelsTests` | `weatherEmoji`, `weatherDescription`, `windDirection`, `formatTemperature`, hourly date filtering |
| `OpenMeteoClientTests` | URL construction, JSON decoding of sample API responses |
| `WeatherFetcherTests` | Cache hit/miss, `noLocation` when coords nil, mock client integration |
| `AppConfigTests` | Default values, encode/decode round-trip, favorites add/remove |
| `StatusBarControllerTests` | `titleString(for:)` for all `WeatherResult` cases |

## Error Handling

| Failure | Behaviour |
|---|---|
| Network error | `.noConnection`; menu shows error message with Refresh |
| CoreLocation denied | `.locationDenied`; menu explains System Settings → Privacy → Location |
| CoreLocation timeout (10s) | `.noConnection` |
| Malformed API response | Decode failure treated as `.noConnection` |
| No location configured | `.noLocation`; menu prompts to open Preferences |

## Out of Scope

- Precipitation notifications / weather alerts
- Widgets or Today extensions
- Wind speed unit toggle (always km/h)
- Hourly precipitation amounts (probabilities only)
