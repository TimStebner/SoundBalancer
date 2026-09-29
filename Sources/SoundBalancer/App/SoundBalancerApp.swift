import AppKit
import SwiftUI

@main
struct SoundBalancerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppMixerStore?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let mixerStore = AppMixerStore()
        self.store = mixerStore
        self.menuBarController = MenuBarController(store: mixerStore)

        signal(SIGINT) { _ in
            NSApplication.shared.terminate(nil)
        }
        signal(SIGTERM) { _ in
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.teardown()
    }
}
