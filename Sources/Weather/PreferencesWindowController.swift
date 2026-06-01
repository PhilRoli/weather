// Sources/Weather/PreferencesWindowController.swift
import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onClose: (() -> Void)?

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Weather"
        panel.isReleasedWhenClosed = false
        panel.center()
        self.init(window: panel)
    }

    @MainActor override func close() {
        super.close()
        onClose?()
    }
}
