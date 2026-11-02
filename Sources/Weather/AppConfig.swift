import Foundation
import MenuBarKit

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

extension AppConfig: DefaultInitializable {}
typealias AppConfigStore = JSONDefaultsStore<AppConfig>

private let sharedConfigStore = AppConfigStore(defaults: UserDefaults(suiteName: "weather") ?? .standard)

extension JSONDefaultsStore where Value == AppConfig {
    static var shared: AppConfigStore { sharedConfigStore }
}
