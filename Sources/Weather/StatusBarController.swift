// Sources/Weather/StatusBarController.swift
import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private let fetcher = WeatherFetcher()
    private var lastConfig = AppConfigStore.shared.load()
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
        statusItem.button?.title = Self.titleString(for: result, unit: config.temperatureUnit)
        statusItem.menu = buildMenu(for: result, config: config)
    }

    // MARK: - Title string (nonisolated static for testability)

    nonisolated static func titleString(for result: WeatherResult, unit: TemperatureUnit) -> String {
        switch result {
        case .data(let data):
            let emoji = weatherEmoji(data.current.weatherCode)
            let temp  = formatTemperature(data.current.temperature, unit: unit)
            return "\(emoji) \(temp)"
        case .noConnection:
            return "❌ No Connection"
        case .noLocation, .locationDenied:
            return "⛅ Weather"
        }
    }

    // MARK: - Menu building (completed in Task 7)

    private func buildMenu(for result: WeatherResult, config: AppConfig) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loading…", action: nil, keyEquivalent: ""))
        return menu
    }

    // MARK: - Preferences

    @objc private func openPreferences() {
        if prefsController == nil {
            prefsController = PreferencesWindowController()
            prefsController?.onClose = { [weak self] in
                self?.prefsController = nil
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
