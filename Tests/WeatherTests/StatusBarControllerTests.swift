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

    // MARK: Menu footer

    @MainActor
    private func footer(favorites: [FavoriteLocation] = []) -> [NSMenuItem] {
        var config = AppConfig()
        config.favorites = favorites
        return StatusBarController.footerItems(
            config: config, data: makeWeatherData(temp: 10, code: 0),
            updatedAt: Date(timeIntervalSince1970: 0), target: NSObject()
        )
    }

    private func allTitles(_ items: [NSMenuItem]) -> [String] {
        items.flatMap { [$0.title] + allTitles($0.submenu?.items ?? []) }
    }

    @MainActor
    func testFooterControlsHaveNoEmojiDecoration() {
        let fav = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        let titles = allTitles(footer(favorites: [fav]))
        let decorated = titles.filter { title in
            title.unicodeScalars.contains { $0.properties.isEmoji && $0.value > 0x238C }
        }
        XCTAssertEqual(decorated, [])
    }

    @MainActor
    func testFooterHasUpdatedLineAndSingleRefreshNow() throws {
        let items = footer()
        let updated = try XCTUnwrap(items.first { $0.title.hasPrefix("Updated ") })
        XCTAssertFalse(updated.isEnabled)
        let refreshItems = items.filter { $0.title.contains("Refresh") }
        XCTAssertEqual(refreshItems.map(\.title), ["Refresh Now"])
        XCTAssertEqual(refreshItems.first?.keyEquivalent, "r")
        XCTAssertNil(refreshItems.first?.submenu)
    }

    @MainActor
    func testFooterKeepsSettingsSubmenuPreferencesAndQuit() throws {
        let items = footer()
        let settings = try XCTUnwrap(items.first { $0.title == "Settings" })
        XCTAssertEqual(settings.submenu?.items.map(\.title), [
            "Temperature: Celsius", "Location: Manual", "Add to Favorites"
        ])
        XCTAssertEqual(items.first { $0.title == "Preferences…" }?.keyEquivalent, ",")
        XCTAssertEqual(items.last?.title, "Quit")
        XCTAssertEqual(items.last?.keyEquivalent, "q")
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
