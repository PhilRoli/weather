// Sources/Weather/StatusBarController.swift
import AppKit
import MenuBarKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let fetcher = WeatherFetcher()
    private var lastConfig = AppConfigStore.shared.load()
    private var lastResult: WeatherResult = .noLocation
    private var prefsController: PreferencesWindowController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛅ Weather"
        startTimer()
        Task { await refresh() }
    }

    // MARK: - Timer

    private func startTimer() {
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Refresh

    func refresh() async {
        let config = AppConfigStore.shared.load()
        lastConfig = config
        let result = await fetcher.fetch(config: config)
        lastResult = result
        statusItem.button?.title = Self.titleString(for: result, unit: config.temperatureUnit)
        statusItem.menu = buildMenu(for: result, config: config)
    }

    // MARK: - Title string (nonisolated static for testability)

    nonisolated static func titleString(for result: WeatherResult, unit: TemperatureUnit) -> String {
        switch result {
        case .data(let data):
            let emoji = weatherEmoji(data.current.weatherCode)
            return "\(emoji) \(formatTemperature(data.current.temperature, unit: unit))"
        case .noConnection:
            return "❌ No Connection"
        case .noLocation, .locationDenied:
            return "⛅ Weather"
        }
    }

    // MARK: - Menu building

    private func buildMenu(for result: WeatherResult, config: AppConfig) -> NSMenu {
        let menu = NSMenu()
        switch result {
        case .noLocation:
            menu.addItem(disabled("Open Preferences to configure a location"))
        case .locationDenied:
            menu.addItem(disabled("❌ Location access denied"))
            menu.addItem(disabled("ℹ️ Enable in: System Settings → Privacy → Location Services"))
        case .noConnection:
            menu.addItem(disabled("Unable to fetch weather — check your internet connection"))
        case .data(let data):
            buildWeatherItems(data, config: config, into: menu)
        }
        menu.addItem(.separator())
        var currentData: WeatherData?
        if case .data(let d) = result { currentData = d }
        for item in Self.footerItems(config: config, data: currentData, updatedAt: Date(), target: self) {
            menu.addItem(item)
        }
        return menu
    }

    private func buildWeatherItems(_ data: WeatherData, config: AppConfig, into menu: NSMenu) {
        menu.addItem(disabled("📍 \(data.location)"))
        let temp = formatTemperature(data.current.temperature, unit: config.temperatureUnit)
        let feelsLike = formatTemperature(data.current.apparentTemperature, unit: config.temperatureUnit)
        menu.addItem(disabled("🌡️ \(temp) (feels like \(feelsLike))"))
        let code = data.current.weatherCode
        menu.addItem(disabled("☁️ \(weatherEmoji(code)) \(weatherDescription(code))"))
        menu.addItem(disabled("💧 Humidity: \(data.current.humidity)%"))
        let windDirection = windDirectionString(data.current.windDirection)
        menu.addItem(disabled("💨 Wind: \(Int(data.current.windSpeed)) km/h \(windDirection)"))
        if data.current.precipitation > 0 {
            menu.addItem(disabled(String(format: "🌧️ Precipitation: %.1f mm", data.current.precipitation)))
        }

        menu.addItem(.separator())
        menu.addItem(disabled("⏰ Next 24 Hours"))
        let now = Date()
        let hourlyEntries = data.hourly.filter { $0.time >= now }.prefix(24).stride(by: 3).prefix(8)
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        for entry in hourlyEntries {
            let timeStr = timeFmt.string(from: entry.time)
            let temp = formatTemperature(entry.temperature, unit: config.temperatureUnit)
            let precip = entry.precipitationProbability > 0 ? " 💧\(entry.precipitationProbability)%" : ""
            menu.addItem(disabled("\(timeStr): \(weatherEmoji(entry.weatherCode)) \(temp)\(precip)"))
        }

        menu.addItem(.separator())
        menu.addItem(disabled("📅 7-Day Forecast"))
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE"
        for (idx, day) in data.daily.enumerated() {
            let label = idx == 0 ? "Today" : idx == 1 ? "Tomorrow" : dateFmt.string(from: day.date)
            let tMax = formatTemperature(day.tempMax, unit: config.temperatureUnit)
            let tMin = formatTemperature(day.tempMin, unit: config.temperatureUnit)
            let precip = day.precipitationSum > 0
                ? String(format: " 💧%.1fmm (%d%%)", day.precipitationSum, day.precipitationProbabilityMax)
                : ""
            let emoji = weatherEmoji(day.weatherCode)
            menu.addItem(disabled("\(label): \(emoji) \(tMin) – \(tMax)\(precip) 💨\(Int(day.windSpeedMax))km/h"))
        }
    }

    /// Refresh, Settings, Preferences and Quit. Static so the menu structure can be tested without a controller.
    static func footerItems(config: AppConfig, data: WeatherData?, updatedAt: Date, target: AnyObject) -> [NSMenuItem] {
        let time = DateFormatter.localizedString(from: updatedAt, dateStyle: .none, timeStyle: .medium)
        let updated = NSMenuItem(title: "Updated \(time)", action: nil, keyEquivalent: "")
        updated.isEnabled = false
        return [
            updated,
            .item("Refresh Now", action: #selector(StatusBarController.manualRefresh), key: "r", target: target),
            settingsItem(config: config, data: data, target: target),
            .item("Preferences…", action: #selector(StatusBarController.openPreferences), key: ",", target: target),
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        ]
    }

    private static func settingsItem(config: AppConfig, data: WeatherData?, target: AnyObject) -> NSMenuItem {
        let settings = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let unitLabel = config.temperatureUnit == .fahrenheit ? "Temperature: Fahrenheit" : "Temperature: Celsius"
        sub.addItem(.item(unitLabel, action: #selector(StatusBarController.toggleUnit), target: target))

        let locLabel = config.useAutoLocation ? "Location: Automatic" : "Location: Manual"
        sub.addItem(.item(locLabel, action: #selector(StatusBarController.toggleAutoLocation), target: target))

        if let data = data {
            let isFav = config.favorites.contains {
                abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001
            }
            if isFav {
                sub.addItem(.item("Remove from Favorites", action: #selector(StatusBarController.removeFavorite),
                                  target: target))
            } else {
                sub.addItem(.item("Add to Favorites", action: #selector(StatusBarController.addFavorite),
                                  target: target))
            }
        }

        if !config.favorites.isEmpty {
            let favsItem = NSMenuItem(title: "Favorite Locations", action: nil, keyEquivalent: "")
            let favsSub = NSMenu()
            for fav in config.favorites {
                let isCurrent = data.map {
                    abs($0.latitude - fav.latitude) < 0.001 && abs($0.longitude - fav.longitude) < 0.001
                } ?? false
                let label = isCurrent ? "✓ \(fav.name)" : fav.name
                let item = NSMenuItem.item(label, action: #selector(StatusBarController.setFavoriteLocation(_:)),
                                           target: target)
                item.representedObject = fav
                favsSub.addItem(item)
            }
            favsItem.submenu = favsSub
            sub.addItem(favsItem)
        }

        settings.submenu = sub
        return settings
    }

    // MARK: - Menu helpers

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleUnit() {
        var config = AppConfigStore.shared.load()
        config.temperatureUnit = config.temperatureUnit == .fahrenheit ? .celsius : .fahrenheit
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func toggleAutoLocation() {
        var config = AppConfigStore.shared.load()
        config.useAutoLocation.toggle()
        AppConfigStore.shared.save(config)
        fetcher.invalidateCache()
        Task { await refresh() }
    }

    @objc private func addFavorite() {
        guard case .data(let data) = lastResult else { return }
        var config = AppConfigStore.shared.load()
        let alreadyExists = config.favorites.contains {
            abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001
        }
        guard !alreadyExists else { return }
        config.favorites.append(
            FavoriteLocation(name: data.location, latitude: data.latitude, longitude: data.longitude)
        )
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func removeFavorite() {
        guard case .data(let data) = lastResult else { return }
        var config = AppConfigStore.shared.load()
        config.favorites.removeAll {
            abs($0.latitude - data.latitude) < 0.001 && abs($0.longitude - data.longitude) < 0.001
        }
        AppConfigStore.shared.save(config)
        Task { await refresh() }
    }

    @objc private func setFavoriteLocation(_ sender: NSMenuItem) {
        guard let fav = sender.representedObject as? FavoriteLocation else { return }
        var config = AppConfigStore.shared.load()
        config.location = fav.name
        config.latitude = fav.latitude
        config.longitude = fav.longitude
        config.useAutoLocation = false
        AppConfigStore.shared.save(config)
        fetcher.invalidateCache()
        Task { await refresh() }
    }

    @objc private func openPreferences() {
        if prefsController == nil {
            prefsController = PreferencesWindowController()
            prefsController?.onClose = { [weak self] in
                self?.prefsController = nil
                self?.fetcher.invalidateCache()
                Task { await self?.refresh() }
            }
        }
        prefsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func manualRefresh() {
        fetcher.invalidateCache()
        Task { await refresh() }
    }
}

// MARK: - Collection stride helper

private extension Collection {
    func stride(by step: Int) -> [Element] {
        var result: [Element] = []
        var i = startIndex
        while i < endIndex {
            result.append(self[i])
            let dist = distance(from: i, to: endIndex)
            if dist <= step { break }
            i = index(i, offsetBy: step)
        }
        return result
    }
}
