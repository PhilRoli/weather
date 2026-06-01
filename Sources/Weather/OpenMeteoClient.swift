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
            URLQueryItem(name: "latitude",          value: "\(lat)"),
            URLQueryItem(name: "longitude",         value: "\(lon)"),
            URLQueryItem(name: "current",           value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly",            value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "daily",             value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max"),
            URLQueryItem(name: "timezone",          value: "auto"),
            URLQueryItem(name: "temperature_unit",  value: unit.rawValue),
            URLQueryItem(name: "wind_speed_unit",   value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
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
        let hourlyTimes = resp.hourly.time
        let hourlyTemps = resp.hourly.temperature2m
        let hourlyProbs = resp.hourly.precipitationProbability
        let hourlyCodes = resp.hourly.weatherCode
        let minHourlyCount = min(hourlyTimes.count, hourlyTemps.count, hourlyProbs.count, hourlyCodes.count)
        let hourly: [HourlyForecast] = (0..<minHourlyCount).compactMap { i in
            guard let date = hourlyFmt.date(from: hourlyTimes[i]) else { return nil }
            return HourlyForecast(
                time: date,
                temperature: hourlyTemps[i],
                precipitationProbability: hourlyProbs[i],
                weatherCode: hourlyCodes[i]
            )
        }

        let dailyFmt = makeDateFormatter(format: "yyyy-MM-dd")
        let dailyTimes = resp.daily.time
        let dailyCodes = resp.daily.weatherCode
        let dailyTMax = resp.daily.temperature2mMax
        let dailyTMin = resp.daily.temperature2mMin
        let dailyPrecipSum = resp.daily.precipitationSum
        let dailyPrecipProb = resp.daily.precipitationProbabilityMax
        let dailyWind = resp.daily.windSpeed10mMax
        let minDailyCount = min(dailyTimes.count, dailyCodes.count, dailyTMax.count, dailyTMin.count,
                                dailyPrecipSum.count, dailyPrecipProb.count, dailyWind.count)
        let daily: [DailyForecast] = (0..<minDailyCount).compactMap { i in
            guard let date = dailyFmt.date(from: dailyTimes[i]) else { return nil }
            return DailyForecast(
                date: date, weatherCode: dailyCodes[i],
                tempMax: dailyTMax[i], tempMin: dailyTMin[i],
                precipitationSum: dailyPrecipSum[i], precipitationProbabilityMax: dailyPrecipProb[i],
                windSpeedMax: dailyWind[i]
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
