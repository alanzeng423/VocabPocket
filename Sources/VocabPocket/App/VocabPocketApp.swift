import SwiftUI

@main
struct VocabPocketApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("VocabPocket", systemImage: "character.book.closed.fill") {
            MenuBarContentView(model: model)
                .environmentObject(model.store)
        }
        .menuBarExtraStyle(.window)

        Window("VocabPocket 生词本", id: "library") {
            MainView(model: model)
                .environmentObject(model.store)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 960, height: 660)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(model: model)
                .frame(width: 640, height: 700)
        }
    }
}
