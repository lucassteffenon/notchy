import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = NotchController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.model.unlockKeyboard()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // sem ícone no Dock
app.run()
