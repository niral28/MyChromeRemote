import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import TVRemoteProtocol

enum InputControllerError: LocalizedError {
    case accessibilityNotTrusted
    case chromeNotFrontmost(frontmost: String)
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotTrusted:
            return "Touchpad needs Accessibility permission for TV Remote on this Mac"
        case let .chromeNotFrontmost(name):
            return "Touchpad only works while Chrome is frontmost (currently \(name))"
        case .eventCreationFailed:
            return "Could not create a Mac input event"
        }
    }
}

/// Pure gate logic, kept testable without touching real system input.
enum ChromeGate {
    static let chromeBundleID = "com.google.Chrome"
    static func allows(frontmostBundleID: String?) -> Bool {
        frontmostBundleID == chromeBundleID
    }
}

@MainActor
final class InputController: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    private var cursor: CGPoint?
    private var isMouseDown = false

    func refreshTrust() -> Bool {
        isAccessibilityTrusted = AXIsProcessTrusted()
        return isAccessibilityTrusted
    }

    @discardableResult
    func requestAccessibilityPrompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        return isAccessibilityTrusted
    }

    func perform(_ event: InputEvent) throws {
        guard refreshTrust() else { throw InputControllerError.accessibilityNotTrusted }
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard ChromeGate.allows(frontmostBundleID: frontmost?.bundleIdentifier) else {
            throw InputControllerError.chromeNotFrontmost(frontmost: frontmost?.localizedName ?? "no app")
        }

        switch event {
        case let .move(dx, dy):
            try move(byX: dx, y: dy)
        case let .scroll(dx, dy):
            try scroll(deltaX: dx, deltaY: dy)
        case .click:
            try postMouse(.leftMouseDown)
            try postMouse(.leftMouseUp)
        case .mouseDown:
            guard !isMouseDown else { return }
            isMouseDown = true
            try postMouse(.leftMouseDown)
        case .mouseUp:
            guard isMouseDown else { return }
            isMouseDown = false
            try postMouse(.leftMouseUp)
        case let .typeText(text):
            // Bound work per message so a paired client cannot flood the Mac.
            for character in text.prefix(500) { try type(character) }
        case .back:
            try key(code: 33, flags: .maskCommand) // Cmd+[ is Chrome Back.
        case .enter:
            try key(code: 36, flags: [])
        }
    }

    private func currentCursor() -> CGPoint {
        if let cursor { return cursor }
        let location = NSEvent.mouseLocation // bottom-left origin
        let height = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: location.x, y: height - location.y)
        cursor = point
        return point
    }

    private func move(byX dx: Double, y dy: Double) throws {
        var point = currentCursor()
        // Clamp relative deltas so a malformed client cannot jump absurdly.
        point.x += CGFloat(max(-200, min(200, dx)))
        point.y += CGFloat(max(-200, min(200, dy)))
        if let screen = NSScreen.screens.first {
            point.x = max(0, min(screen.frame.width - 1, point.x))
            point.y = max(0, min(screen.frame.height - 1, point.y))
        }
        cursor = point
        try postMouse(isMouseDown ? .leftMouseDragged : .mouseMoved, at: point)
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint? = nil) throws {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point ?? currentCursor(),
            mouseButton: .left
        ) else { throw InputControllerError.eventCreationFailed }
        event.post(tap: .cghidEventTap)
    }

    private func scroll(deltaX dx: Double, deltaY dy: Double) throws {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(max(-120, min(120, -dy))),
            wheel2: Int32(max(-120, min(120, -dx))),
            wheel3: 0
        ) else { throw InputControllerError.eventCreationFailed }
        event.location = currentCursor()
        event.post(tap: .cghidEventTap)
    }

    private func type(_ character: Character) throws {
        let string = String(character)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else {
                throw InputControllerError.eventCreationFailed
            }
            var chars = Array(string.utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event.post(tap: .cghidEventTap)
        }
    }

    private func key(code: CGKeyCode, flags: CGEventFlags) throws {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else {
                throw InputControllerError.eventCreationFailed
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
