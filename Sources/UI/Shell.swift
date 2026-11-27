import Combine
import Foundation

/// Everything the screens show about the phone itself and everything they can ask for, as plain values and plain
/// closures. The screens know only this and the board: not the link, the glasses or the microphone. The app fills it
/// from the real things (`Live`); the demo fills it with made-up ones, which is how the screens are drawn on a build
/// machine without a phone.
@MainActor
final class Shell: ObservableObject {
    enum LinkState: Equatable {
        case unpaired, connecting, online, silent, offline
    }

    enum Duty: Equatable {
        case off, starting, on, ending
    }

    enum GlassesState: Equatable {
        case none, connected, worn
    }

    // MARK: MailPilot

    @Published var link: LinkState = .unpaired
    /// Why it isn't connected, in a sentence.
    @Published var linkDetail: String?
    /// The PC this phone is paired with.
    @Published var host: String?
    /// The first characters of this phone's id, as MailPilot lists it.
    @Published var deviceShort: String?
    @Published var pingMs: Int?
    @Published var pairingNote: String?
    @Published var pairingBusy = false

    // MARK: On duty

    @Published var duty: Duty = .off
    @Published var glasses: GlassesState = .none
    /// What the lens shows, in a word or two.
    @Published var lens = "off"
    /// What the microphone does: "listening", "speaking", "asleep".
    @Published var voice = "off"
    /// The words being heard, as they come.
    @Published var partial = ""
    /// Your own words for the card on the lens, waiting for Send.
    @Published var heard: String?
    /// Something to do or to know: the microphone was refused, the clocks differ.
    @Published var banner: String?

    // MARK: Settings

    /// The ntfy topic MailPilot's notifications come on; nil while they are off there.
    @Published var notifyTopic: String?
    /// The ntfy server when it isn't ntfy.sh.
    @Published var notifyServer: String?
    @Published var glassesRegistered = false
    @Published var glassesRegistration = "unknown"
    @Published var glassesInfo = ""
    @Published var glassesStatus = ""
    /// The speech server's host, when MailPilot sent one.
    @Published var speechHost: String?
    @Published var speechCheck = ""
    @Published var version = ""

    // MARK: What the screens ask for

    var toggleDuty: () -> Void = {}
    var pair: (String) -> Void = { _ in }
    var unpair: () -> Void = {}
    /// An answer to a card: one of its options.
    var answer: (AttentionCard, String) -> Void = { _, _ in }
    /// An answer to a card in your own words.
    var answerWords: (AttentionCard, String) -> Void = { _, _ in }
    var later: (AttentionCard) -> Void = { _ in }
    /// The words on the lens: send them, say them again, or drop them.
    var sendHeard: () -> Void = {}
    var againHeard: () -> Void = {}
    var cancelHeard: () -> Void = {}
    var talk: () -> Void = {}
    var showOnLens: () -> Void = {}
    var registerGlasses: () -> Void = {}
    var unregisterGlasses: () -> Void = {}
    var testSpeech: () -> Void = {}

    var paired: Bool { link != .unpaired }
    var online: Bool { link == .online }
    var onDuty: Bool { duty == .on }
}
