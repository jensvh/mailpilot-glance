import Combine
import Foundation

/// What can be chosen in Settings. Nothing secret here: keys live in the Keychain.
@MainActor
final class AppSettings: ObservableObject {
    private let store = UserDefaults.standard

    /// "auto" (the iPhone's language), "en" or "nl".
    @Published var language: String { didSet { store.set(language, forKey: "language") } }
    /// How fast it talks: 1 is the iPhone's normal speed.
    @Published var speechRate: Double { didSet { store.set(speechRate, forKey: "speechRate") } }
    /// Show cards on the glasses. Off: the phone alone, its voice and its own screen.
    @Published var useLens: Bool { didSet { store.set(useLens, forKey: "useLens") } }
    /// Read a new card out loud. Off: a short sound only; "why" still reads it.
    @Published var readCards: Bool { didSet { store.set(readCards, forKey: "readCards") } }
    /// Keep listening while it speaks, so you can answer over it. Only when the
    /// microphone doesn't pick up the glasses' own speakers.
    @Published var bargeIn: Bool { didSet { store.set(bargeIn, forKey: "bargeIn") } }
    /// How long the microphone stays open for an answer after a card came.
    @Published var listenSeconds: Int { didSet { store.set(listenSeconds, forKey: "listenSeconds") } }

    init() {
        language = store.string(forKey: "language") ?? "auto"
        speechRate = store.object(forKey: "speechRate") as? Double ?? 1.0
        useLens = store.object(forKey: "useLens") as? Bool ?? true
        readCards = store.object(forKey: "readCards") as? Bool ?? true
        bargeIn = store.object(forKey: "bargeIn") as? Bool ?? false
        listenSeconds = store.object(forKey: "listenSeconds") as? Int ?? 8
    }

    /// "en" or "nl": the chosen language, or the iPhone's when it is one of the two.
    var spokenLanguage: String {
        if language == "en" || language == "nl" { return language }
        let phone = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return phone.hasPrefix("nl") ? "nl" : "en"
    }
}
