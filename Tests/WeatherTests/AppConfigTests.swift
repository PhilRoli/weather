import XCTest
@testable import Weather

final class AppConfigTests: XCTestCase {

    // MARK: Defaults

    func testDefaultValues() {
        let cfg = AppConfig()
        XCTAssertNil(cfg.location)
        XCTAssertNil(cfg.latitude)
        XCTAssertNil(cfg.longitude)
        XCTAssertEqual(cfg.temperatureUnit, .celsius)
        XCTAssertFalse(cfg.useAutoLocation)
        XCTAssertTrue(cfg.favorites.isEmpty)
    }

    // MARK: Round-trip

    func testEncodeDecodeRoundTrip() throws {
        var cfg = AppConfig()
        cfg.location = "Vienna"
        cfg.latitude = 48.2082
        cfg.longitude = 16.3738
        cfg.temperatureUnit = .fahrenheit
        cfg.useAutoLocation = true
        cfg.favorites = [FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)]

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.location, "Vienna")
        XCTAssertEqual(decoded.latitude, 48.2082)
        XCTAssertEqual(decoded.longitude, 16.3738)
        XCTAssertEqual(decoded.temperatureUnit, .fahrenheit)
        XCTAssertTrue(decoded.useAutoLocation)
        XCTAssertEqual(decoded.favorites.count, 1)
        XCTAssertEqual(decoded.favorites[0].name, "Vienna")
    }

    func testDecodesMissingOptionalFieldsGracefully() throws {
        let json = #"{"temperatureUnit":"celsius","useAutoLocation":false,"favorites":[]}"#
        let decoded = try JSONDecoder().decode(AppConfig.self, from: json.data(using: .utf8)!)
        XCTAssertNil(decoded.location)
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }

    // MARK: AppConfigStore persistence

    func testStoreLoadReturnDefaultWhenEmpty() {
        let store = AppConfigStore(suiteName: "test.\(UUID().uuidString)")
        let cfg = store.load()
        XCTAssertNil(cfg.location)
        XCTAssertEqual(cfg.temperatureUnit, .celsius)
    }

    func testStoreSaveAndLoad() {
        let store = AppConfigStore(suiteName: "test.\(UUID().uuidString)")
        var cfg = AppConfig()
        cfg.location = "Berlin"
        cfg.latitude = 52.52
        cfg.longitude = 13.405
        store.save(cfg)

        let loaded = store.load()
        XCTAssertEqual(loaded.location, "Berlin")
        XCTAssertEqual(loaded.latitude, 52.52)
        XCTAssertEqual(loaded.longitude, 13.405)
    }

    // MARK: Favorites

    func testFavoriteEquatability() {
        let a = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        let b = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        XCTAssertEqual(a, b)
    }

    func testFavoriteNotEqualDifferentCoords() {
        let a = FavoriteLocation(name: "Vienna", latitude: 48.2082, longitude: 16.3738)
        let b = FavoriteLocation(name: "Vienna", latitude: 48.2083, longitude: 16.3738)
        XCTAssertNotEqual(a, b)
    }
}
