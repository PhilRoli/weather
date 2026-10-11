import Foundation

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
    let time: [Double]
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
    let time: [Double]
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

// swiftlint:disable:next cyclomatic_complexity
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

// swiftlint:disable:next cyclomatic_complexity
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
    let idx = ((Int((degrees + 22.5) / 45.0) % 8) + 8) % 8
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
