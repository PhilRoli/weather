<p align="center"><img src="Packaging/icon.png" width="128" alt="Weather icon"></p>

# Weather

Menu bar app that shows the current temperature with a weather emoji. Click it for conditions, the next 24 hours and a 7-day forecast, powered by [Open-Meteo](https://open-meteo.com) (no API key).

## Installation

### Homebrew

```bash
brew tap PhilRoli/tap
brew install --cask weather
```

Weather is ad-hoc signed (not notarized). On first launch, right-click the app in Finder and choose "Open" to bypass Gatekeeper, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Weather.app
```

## Usage

- Open Preferences to pick a location by search, or enable automatic location (asks for Location Services permission).
- Save favorite locations and switch between them from the menu.
- Choose Celsius or Fahrenheit.

## Development

- Build + install locally: `./rebuild.sh` (installs to /Applications, ad-hoc signed; needs [menubar-kit](https://github.com/PhilRoli/menubar-kit) cloned next to this repo or `MENUBAR_KIT` set).
- Tests: `swift test`. Lint: `swiftlint --strict`.
- Release: push a tag `vX.Y.Z`. The Release workflow builds a universal app, publishes `Weather-X.Y.Z.app.zip` and updates `Casks/weather.rb` in `PhilRoli/homebrew-tap` (needs the `HOMEBREW_TAP_TOKEN` repo secret).
- Regenerate the icon: `../menubar-kit/scripts/make-icon.sh ☀️`.

## License

MIT
