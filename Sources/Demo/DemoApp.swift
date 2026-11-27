import SwiftUI

/// The same screens as the app, on made-up data and without the glasses' toolkit: built for the simulator on the
/// build machine, opened on one screen at a time (`-demo board`, `-demo run`, …) and photographed. It is how the
/// app's look is checked without a Mac or a phone, and it proves the screens need nothing but plain values.
@main
struct GlanceDemoApp: App {
    @StateObject private var shell: Shell
    @StateObject private var store: BoardStore
    @StateObject private var settings = AppSettings()
    private let screen: String

    init() {
        let screen = UserDefaults.standard.string(forKey: "demo") ?? "board"
        self.screen = screen
        let shell = Shell()
        let store = BoardStore()
        DemoData.fill(shell, store, for: screen)
        _shell = StateObject(wrappedValue: shell)
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            DemoData.view(for: screen)
                .environmentObject(shell)
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
