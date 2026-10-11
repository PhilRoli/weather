import AppKit
import XCTest
@testable import Weather

@MainActor
final class PreferencesWindowControllerTests: XCTestCase {
    private func textFields(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { sub -> [NSTextField] in
            let nested = textFields(in: sub)
            if let field = sub as? NSTextField { return [field] + nested }
            return nested
        }
    }

    func testShowsVersionLineWithoutOverlappingSaveButton() throws {
        let controller = PreferencesWindowController()
        let content = try XCTUnwrap(controller.window?.contentView)
        let fields = textFields(in: content)
        let version = try XCTUnwrap(
            fields.first { $0.stringValue.hasPrefix("Version") || $0.stringValue == "Development build" }
        )
        let save = try XCTUnwrap(content.subviews.compactMap { $0 as? NSButton }.first { $0.title.hasPrefix("Save") })
        XCTAssertFalse(version.frame.intersects(save.frame))
        XCTAssertTrue(content.bounds.contains(version.frame))
    }
}
