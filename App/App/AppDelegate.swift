import AppKit
import SwiftUI

@main
@available(macOS 26.0, *)
struct AppleBaseLMMain {
    static func main() {
        let app = AppleBaseLMApp()
        let view = ChatTestView(app: app)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AppleBaseLM Chat"
        window.center()
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName("AppleBaseLMWindow")

        NSApp.run()
    }
}
