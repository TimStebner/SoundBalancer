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
    private var sigintSource: DispatchSourceSignal?
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let mixerStore = AppMixerStore()
        self.store = mixerStore
        self.menuBarController = MenuBarController(store: mixerStore)

        setupSignalHandlers()
    }

    private func setupSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigint.setEventHandler {
            NSApplication.shared.terminate(nil)
        }
        sigint.resume()
        self.sigintSource = sigint

        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigterm.setEventHandler {
            NSApplication.shared.terminate(nil)
        }
        sigterm.resume()
        self.sigtermSource = sigterm
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.teardown()
    }
}
