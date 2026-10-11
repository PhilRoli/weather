// Sources/Weather/PreferencesWindowController.swift
import AppKit
import MenuBarKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onClose: (() -> Void)?

    private var locationField: NSTextField!
    private var resultsScrollView: NSScrollView!
    private var resultsTable: NSTableView!
    private var favoritesTable: NSTableView!
    private var deleteFavButton: NSButton!
    private var autoLocationCheckbox: NSButton!
    private var celsiusRadio: NSButton!
    private var fahrenheitRadio: NSButton!

    private var searchResults: [GeocodingResult] = []
    private var favorites: [FavoriteLocation] = []
    private var pendingLocation: String?
    private var pendingLatitude: Double?
    private var pendingLongitude: Double?
    private var pendingAutoLocation: Bool = false
    private var pendingUnit: TemperatureUnit = .celsius

    private var searchTimer: Timer?
    private var searchTask: Task<Void, Never>?
    private let client = OpenMeteoClient()

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 310),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Weather"
        panel.isReleasedWhenClosed = false
        panel.center()
        self.init(window: panel)
        loadCurrentConfig()
        setupUI()
    }

    private func loadCurrentConfig() {
        let config = AppConfigStore.shared.load()
        pendingLocation     = config.location
        pendingLatitude     = config.latitude
        pendingLongitude    = config.longitude
        pendingAutoLocation = config.useAutoLocation
        pendingUnit         = config.temperatureUnit
        favorites           = config.favorites
    }

    // swiftlint:disable:next function_body_length
    private func setupUI() {
        guard let cv = window?.contentView else { return }

        // Location label
        let locLabel = label("Location")
        locLabel.frame = NSRect(x: 16, y: 270, width: 70, height: 20)
        cv.addSubview(locLabel)

        // Location text field
        locationField = NSTextField()
        locationField.placeholderString = "Search for a city…"
        locationField.stringValue = pendingLocation ?? ""
        locationField.bezelStyle = .roundedBezel
        locationField.frame = NSRect(x: 90, y: 266, width: 274, height: 24)
        locationField.delegate = self
        cv.addSubview(locationField)

        // Search results (hidden until results arrive)
        resultsScrollView = NSScrollView(frame: NSRect(x: 90, y: 190, width: 274, height: 70))
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.borderType = .bezelBorder
        resultsTable = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "Result"
        resultsTable.addTableColumn(col)
        resultsTable.headerView = nil
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.action = #selector(resultRowClicked)
        resultsTable.target = self
        resultsScrollView.documentView = resultsTable
        resultsScrollView.isHidden = true
        cv.addSubview(resultsScrollView)

        // Favorites label
        let favLabel = label("Favorites:")
        favLabel.frame = NSRect(x: 16, y: 166, width: 80, height: 20)
        cv.addSubview(favLabel)

        // Delete button
        deleteFavButton = NSButton(title: "–", target: self, action: #selector(deleteSelectedFavorite))
        deleteFavButton.bezelStyle = .smallSquare
        deleteFavButton.frame = NSRect(x: 332, y: 162, width: 32, height: 24)
        deleteFavButton.isEnabled = false
        cv.addSubview(deleteFavButton)

        // Favorites table
        let favScroll = NSScrollView(frame: NSRect(x: 16, y: 88, width: 348, height: 70))
        favScroll.hasVerticalScroller = true
        favScroll.borderType = .bezelBorder
        favoritesTable = NSTableView()
        let favCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fav"))
        favCol.title = "Favorite"
        favoritesTable.addTableColumn(favCol)
        favoritesTable.headerView = nil
        favoritesTable.dataSource = self
        favoritesTable.delegate = self
        favoritesTable.action = #selector(favoriteRowClicked)
        favoritesTable.target = self
        favScroll.documentView = favoritesTable
        cv.addSubview(favScroll)

        // Auto-location checkbox
        autoLocationCheckbox = NSButton(
            checkboxWithTitle: "Use automatic location", target: self, action: #selector(autoLocationChanged)
        )
        autoLocationCheckbox.state = pendingAutoLocation ? .on : .off
        autoLocationCheckbox.frame = NSRect(x: 16, y: 60, width: 220, height: 20)
        cv.addSubview(autoLocationCheckbox)
        locationField.isEnabled = !pendingAutoLocation

        // Temperature unit
        let unitLabel = label("Temperature:")
        unitLabel.frame = NSRect(x: 16, y: 32, width: 90, height: 20)
        cv.addSubview(unitLabel)

        celsiusRadio = NSButton(radioButtonWithTitle: "Celsius", target: self, action: #selector(unitChanged(_:)))
        celsiusRadio.frame = NSRect(x: 110, y: 32, width: 80, height: 20)
        celsiusRadio.state = pendingUnit == .celsius ? .on : .off
        cv.addSubview(celsiusRadio)

        fahrenheitRadio = NSButton(radioButtonWithTitle: "Fahrenheit", target: self, action: #selector(unitChanged(_:)))
        fahrenheitRadio.frame = NSRect(x: 195, y: 32, width: 100, height: 20)
        fahrenheitRadio.state = pendingUnit == .fahrenheit ? .on : .off
        cv.addSubview(fahrenheitRadio)

        // Save & Close
        let versionLabel = PreferencesLayout.versionLabel()
        versionLabel.frame = NSRect(x: 16, y: 10, width: 240, height: 16)
        cv.addSubview(versionLabel)

        let saveBtn = NSButton(title: "Save & Close", target: self, action: #selector(saveAndClose))
        saveBtn.bezelStyle = .rounded
        saveBtn.frame = NSRect(x: 264, y: 4, width: 100, height: 28)
        cv.addSubview(saveBtn)
    }

    // MARK: - Debounced search

    private func scheduleSearch(query: String) {
        searchTimer?.invalidate()
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            resultsTable.reloadData()
            resultsScrollView.isHidden = true
            return
        }
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.searchTask = Task { await self?.performSearch(query: query) }
            }
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        guard !Task.isCancelled else { return }
        guard let results = try? await client.geocode(query: query) else { return }
        guard !Task.isCancelled else { return }
        searchResults = results
        resultsTable.reloadData()
        resultsScrollView.isHidden = results.isEmpty
    }

    // MARK: - Actions

    @objc private func resultRowClicked() {
        let row = resultsTable.clickedRow
        guard row >= 0, row < searchResults.count else { return }
        let result = searchResults[row]
        pendingLocation  = result.name
        pendingLatitude  = result.latitude
        pendingLongitude = result.longitude
        locationField.stringValue = result.name
        searchResults = []
        resultsTable.reloadData()
        resultsScrollView.isHidden = true
    }

    @objc private func favoriteRowClicked() {
        let row = favoritesTable.clickedRow
        guard row >= 0, row < favorites.count else { return }
        let fav = favorites[row]
        pendingLocation  = fav.name
        pendingLatitude  = fav.latitude
        pendingLongitude = fav.longitude
        locationField.stringValue = fav.name
        searchResults = []
        resultsTable.reloadData()
        resultsScrollView.isHidden = true
    }

    @objc private func deleteSelectedFavorite() {
        let row = favoritesTable.selectedRow
        guard row >= 0, row < favorites.count else { return }
        favorites.remove(at: row)
        favoritesTable.reloadData()
        deleteFavButton.isEnabled = favoritesTable.selectedRow >= 0
    }

    @objc private func autoLocationChanged() {
        pendingAutoLocation = autoLocationCheckbox.state == .on
        locationField.isEnabled = !pendingAutoLocation
    }

    @objc private func unitChanged(_ sender: NSButton) {
        pendingUnit = sender === celsiusRadio ? .celsius : .fahrenheit
    }

    @objc private func saveAndClose() {
        var config = AppConfigStore.shared.load()
        config.useAutoLocation  = pendingAutoLocation
        config.temperatureUnit  = pendingUnit

        if !pendingAutoLocation {
            if pendingLatitude != nil && pendingLongitude != nil {
                config.location   = pendingLocation
                config.latitude   = pendingLatitude
                config.longitude  = pendingLongitude
            }

            // Auto-add manual location to favorites
            if let name = pendingLocation, let lat = pendingLatitude, let lon = pendingLongitude {
                let alreadyExists = favorites.contains {
                    abs($0.latitude - lat) < 0.001 && abs($0.longitude - lon) < 0.001
                }
                if !alreadyExists {
                    favorites.append(FavoriteLocation(name: name, latitude: lat, longitude: lon))
                }
            }
        }
        config.favorites = favorites
        AppConfigStore.shared.save(config)
        close()
    }

    @MainActor override func close() {
        super.close()
        onClose?()
    }

    // MARK: - UI helper

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: 13)
        return f
    }
}

// MARK: - NSTextFieldDelegate

extension PreferencesWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === locationField else { return }
        // Clear pending location when user types (new search needed)
        pendingLatitude  = nil
        pendingLongitude = nil
        scheduleSearch(query: field.stringValue)
    }
}

// MARK: - NSTableViewDataSource + Delegate

extension PreferencesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === resultsTable ? searchResults.count : favorites.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let t = notification.object as? NSTableView, t === favoritesTable else { return }
        deleteFavButton.isEnabled = favoritesTable.selectedRow >= 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 13)
        cell.stringValue = tableView === resultsTable ? searchResults[row].name : favorites[row].name
        return cell
    }
}
