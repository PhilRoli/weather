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
