import AppKit
import ApplicationServices
import Foundation

@MainActor
final class SelectionReader {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        let options =
            [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func readSelectedText() async -> String? {
        guard Self.isAccessibilityTrusted else { return nil }

        if let text = selectedTextFromAccessibility(), let cleaned = Self.cleaned(text) {
            return cleaned
        }

        return await selectedTextByCopying()
    }

    private func selectedTextFromAccessibility() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusResult == .success, let focusedValue else { return nil }
        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var selectedValue: CFTypeRef?
        let selectionResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )

        guard selectionResult == .success else { return nil }
        return selectedValue as? String
    }

    /// Some apps don't expose selected text through Accessibility. Copying is a
    /// compatibility fallback; the user's clipboard is restored immediately.
    private func selectedTextByCopying() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        guard postCommandC() else { return nil }

        try? await Task.sleep(nanoseconds: 140_000_000)
        defer { snapshot.restore(to: pasteboard) }

        guard pasteboard.changeCount != originalChangeCount else { return nil }
        return pasteboard.string(forType: .string).flatMap(Self.cleaned)
    }

    private func postCommandC() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func cleaned(_ value: String) -> String? {
        let cleaned =
            value
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(8_000))
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(
                uniqueKeysWithValues: item.types.compactMap { type in
                    item.data(forType: type).map { (type, $0) }
                })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
