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
