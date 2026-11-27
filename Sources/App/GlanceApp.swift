import MWDATCore
import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var duty: OnDuty
    /// Keeps the screens' plain values in step with the link, the glasses and the microphone.
    private let live: Live

    init() {
        // The toolkit must be configured once, before anything else uses it.
        do { try Wearables.configure() } catch { print("Wearables.configure failed: \(error)") }
        let duty = OnDuty()
        _duty = StateObject(wrappedValue: duty)
        live = Live(duty: duty)
    }

    var body: some Scene {
        WindowGroup {
            BoardView()
                .environmentObject(live.shell)
                .environmentObject(duty.board)
                .environmentObject(duty.settings)
                .onOpenURL { url in duty.open(url) }
        }
    }
}
