import XCTest
@testable import Weather

final class ModelsTests: XCTestCase {

    // MARK: weatherEmoji

    func testWeatherEmojiClearSky() { XCTAssertEqual(weatherEmoji(0), "☀️") }
    func testWeatherEmojiMainlyClear() { XCTAssertEqual(weatherEmoji(1), "🌤️") }
    func testWeatherEmojiPartlyCloudy() { XCTAssertEqual(weatherEmoji(2), "⛅") }
    func testWeatherEmojiOvercast() { XCTAssertEqual(weatherEmoji(3), "☁️") }
    func testWeatherEmojiFog() { XCTAssertEqual(weatherEmoji(45), "🌫️") }
    func testWeatherEmojiDrizzle() { XCTAssertEqual(weatherEmoji(51), "🌦️") }
    func testWeatherEmojiRain() { XCTAssertEqual(weatherEmoji(61), "🌧️") }
    func testWeatherEmojiSnow() { XCTAssertEqual(weatherEmoji(71), "🌨️") }
    func testWeatherEmojiThunderstorm() { XCTAssertEqual(weatherEmoji(95), "⛈️") }
    func testWeatherEmojiUnknown() { XCTAssertEqual(weatherEmoji(999), "🌡️") }

    // MARK: weatherDescription

    func testWeatherDescriptionClearSky() { XCTAssertEqual(weatherDescription(0), "Clear sky") }
    func testWeatherDescriptionMainlyClear() { XCTAssertEqual(weatherDescription(1), "Mainly clear") }
    func testWeatherDescriptionPartly() { XCTAssertEqual(weatherDescription(2), "Partly cloudy") }
    func testWeatherDescriptionOvercast() { XCTAssertEqual(weatherDescription(3), "Overcast") }
    func testWeatherDescriptionFoggy() { XCTAssertEqual(weatherDescription(45), "Foggy") }
    func testWeatherDescriptionDrizzle() { XCTAssertEqual(weatherDescription(51), "Drizzle") }
    func testWeatherDescriptionRain() { XCTAssertEqual(weatherDescription(61), "Rain") }
    func testWeatherDescriptionSnow() { XCTAssertEqual(weatherDescription(71), "Snow") }
    func testWeatherDescriptionThunder() { XCTAssertEqual(weatherDescription(95), "Thunderstorm") }
    func testWeatherDescriptionUnknown() { XCTAssertEqual(weatherDescription(999), "Unknown") }

    // MARK: windDirectionString

    func testWindNorth() { XCTAssertEqual(windDirectionString(0.0), "N") }
    func testWindNorthEast() { XCTAssertEqual(windDirectionString(45.0), "NE") }
    func testWindEast() { XCTAssertEqual(windDirectionString(90.0), "E") }
    func testWindSouthEast() { XCTAssertEqual(windDirectionString(135.0), "SE") }
    func testWindSouth() { XCTAssertEqual(windDirectionString(180.0), "S") }
    func testWindSouthWest() { XCTAssertEqual(windDirectionString(225.0), "SW") }
    func testWindWest() { XCTAssertEqual(windDirectionString(270.0), "W") }
    func testWindNorthWest() { XCTAssertEqual(windDirectionString(315.0), "NW") }
    func testWindWrap() { XCTAssertEqual(windDirectionString(360.0), "N") }
    func testWindBoundary() { XCTAssertEqual(windDirectionString(337.5), "N") }

    // MARK: formatTemperature

    func testFormatCelsiusWhole() { XCTAssertEqual(formatTemperature(0.0, unit: .celsius), "0°C") }
    func testFormatCelsiusDecimal() { XCTAssertEqual(formatTemperature(14.5, unit: .celsius), "14.5°C") }
    func testFormatCelsiusNegative() { XCTAssertEqual(formatTemperature(-5.2, unit: .celsius), "-5.2°C") }
    func testFormatFahrenheitWhole() { XCTAssertEqual(formatTemperature(32.0, unit: .fahrenheit), "32°F") }
    func testFormatFahrenheitDec() { XCTAssertEqual(formatTemperature(58.3, unit: .fahrenheit), "58.3°F") }
    func testFormatRoundsToOneDP() { XCTAssertEqual(formatTemperature(14.56, unit: .celsius), "14.6°C") }
}
