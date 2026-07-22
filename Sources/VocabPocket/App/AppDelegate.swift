import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var translationPanelController: TranslationPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        translationPanelController = TranslationPanelController(model: .shared)
        AppModel.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.stop()
    }
}
