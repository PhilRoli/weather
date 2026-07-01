import Foundation
import CoreLocation

@MainActor
final class WeatherFetcher: NSObject, CLLocationManagerDelegate {
    private let client: any OpenMeteoClientProtocol
    private let locationManager = CLLocationManager()
    private var cachedResult: (WeatherData, Date)?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var awaitingAuthorizationDecision = false

    private static let cacheTTL: TimeInterval = 300  // 5 minutes
    private static let coordTolerance: Double = 0.01 // ~1 km

    init(client: any OpenMeteoClientProtocol = OpenMeteoClient()) {
        self.client = client
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Main entry point

    func fetch(config: AppConfig) async -> WeatherResult {
        let lat: Double
        let lon: Double
        let locationName: String

        if config.useAutoLocation {
            do {
                let clLocation = try await requestCurrentLocation()
                lat = clLocation.coordinate.latitude
                lon = clLocation.coordinate.longitude
                locationName = await reverseGeocode(clLocation)
            } catch let error as CLError where error.code == .denied {
                return .locationDenied
            } catch {
                // CoreLocation can fail transiently (e.g. no Wi-Fi scan available).
                // Fall back to the last known fix rather than reporting no connection.
                if let (cached, _) = cachedResult {
                    lat = cached.latitude
                    lon = cached.longitude
                    locationName = cached.location
                } else if let configLat = config.latitude, let configLon = config.longitude {
                    lat = configLat
                    lon = configLon
                    locationName = config.location ?? String(format: "%.4f, %.4f", lat, lon)
                } else {
                    return .noConnection
                }
            }
        } else {
            guard let configLat = config.latitude, let configLon = config.longitude else {
                return .noLocation
            }
            lat = configLat
            lon = configLon
            locationName = config.location ?? String(format: "%.4f, %.4f", lat, lon)
        }

        // Check cache
        if let (cached, fetchedAt) = cachedResult,
           abs(cached.latitude - lat) < Self.coordTolerance,
           abs(cached.longitude - lon) < Self.coordTolerance,
           Date().timeIntervalSince(fetchedAt) < Self.cacheTTL {
            return .data(cached)
        }

        // Fetch from API
        do {
            let data = try await client.fetchForecast(lat: lat, lon: lon, unit: config.temperatureUnit, location: locationName)
            cachedResult = (data, Date())
            return .data(data)
        } catch {
            return .noConnection
        }
    }

    func invalidateCache() {
        cachedResult = nil
    }

    // MARK: - CoreLocation

    private func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            // Cancel any in-flight request
            locationContinuation?.resume(throwing: CancellationError())
            locationContinuation = nil

            let status = locationManager.authorizationStatus
            switch status {
            case .denied, .restricted:
                continuation.resume(throwing: CLError(.denied))
                return
            case .authorizedWhenInUse, .authorizedAlways, .authorized:
                awaitingAuthorizationDecision = false
                locationContinuation = continuation
                locationManager.requestLocation()
            case .notDetermined:
                awaitingAuthorizationDecision = true
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                awaitingAuthorizationDecision = true
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }

            // 10-second timeout
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, self.locationContinuation != nil else { return }
                self.locationContinuation?.resume(throwing: CLError(.locationUnknown))
                self.locationContinuation = nil
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        }
        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
            ?? String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = manager.authorizationStatus
            switch status {
            case .denied, .restricted:
                self.locationContinuation?.resume(throwing: CLError(.denied))
                self.locationContinuation = nil
            case .authorizedWhenInUse, .authorizedAlways, .authorized:
                if self.locationContinuation != nil && self.awaitingAuthorizationDecision {
                    self.awaitingAuthorizationDecision = false
                    manager.requestLocation()
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }
}
