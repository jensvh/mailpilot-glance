import MWDATCore
import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var duty: OnDuty

    init() {
        // The toolkit must be configured once, before anything else uses it.
        do { try Wearables.configure() } catch { print("Wearables.configure failed: \(error)") }
        _duty = StateObject(wrappedValue: OnDuty())
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(duty)
                .environmentObject(duty.settings)
                .environmentObject(duty.link)
                .environmentObject(duty.glasses)
                .environmentObject(duty.cards)
                .environmentObject(duty.ears)
                .onOpenURL { url in duty.open(url) }
                .preferredColorScheme(.dark)
        }
    }
}
