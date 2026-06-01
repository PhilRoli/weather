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
