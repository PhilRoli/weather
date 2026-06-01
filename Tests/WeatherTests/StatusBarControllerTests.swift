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
