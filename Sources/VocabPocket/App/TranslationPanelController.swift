import AppKit
import Combine
import SwiftUI

@MainActor
final class TranslationPanelController {
    private let panel: NSPanel
    private var popupSubscription: AnyCancellable?

    init(model: AppModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(
            rootView: TranslationPopupView(model: model)
                .background(TranslationBridge(model: model))
        )

        popupSubscription = model.$popup.sink { [weak self] state in
            guard let self else { return }
            if state.phase == .idle {
                panel.orderOut(nil)
            } else {
                showNearPointer()
            }
        }
    }

    private func showNearPointer() {
        let pointer = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let panelSize = panel.frame.size
        let desiredX = pointer.x + 14
        let desiredY = pointer.y - panelSize.height - 14
        let x = min(max(desiredX, visibleFrame.minX + 12), visibleFrame.maxX - panelSize.width - 12)
        let y = min(max(desiredY, visibleFrame.minY + 12), visibleFrame.maxY - panelSize.height - 12)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }
}
