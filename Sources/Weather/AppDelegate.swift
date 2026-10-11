// Sources/Weather/AppDelegate.swift
import AppKit
import MenuBarKit

/// Accessory apps have no visible menu bar; without these items text fields can't use ⌘C/⌘V/⌘X/⌘A.
@MainActor
func installMainMenu() {
    NSApp.mainMenu = MainMenu.make(appName: "Weather")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusBarController = StatusBarController()
    }
}
