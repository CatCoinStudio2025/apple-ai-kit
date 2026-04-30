import SwiftUI

@main
@available(macOS 26.0, *)
struct AppleBaseLMDesktopApp: App {
    private let app = AppleBaseLMApp()

    var body: some Scene {
        WindowGroup("AppleBaseLM Chat") {
            ChatTestView(app: app)
                .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 600, height: 500)
    }
}
