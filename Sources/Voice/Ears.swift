import Combine
import Foundation

/// What the microphone's audio is used for right now. Read on the audio thread.
final class PcmGate: @unchecked Sendable {
    enum Mode {
        /// Nothing goes to the speech server.
        case closed
        /// Silence goes instead of the microphone: it is speaking, and mustn't hear itself.
        case silence
        case open
    }

    private let lock = NSLock()
    private var value: Mode = .closed

    var mode: Mode {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

/// Speaking and listening for a card, taken from MailPilot Lens's voice loop
/// (tried on the glasses) and cut down to what a card needs:
///
/// - It reads a card, then listens for a few seconds for an answer, then goes
///   to sleep. A pinch, the Talk button or a new card wakes it.
/// - While it speaks the speech server gets silence, so it doesn't answer
///   itself (unless "answer over it" is on in Settings).
/// - Asleep: the headset link stays up (dropping it upsets the glasses), but
///   nothing is sent anywhere.
@MainActor
final class Ears: ObservableObject {
    enum Mode: String {
        case off, asleep, listening, speaking
    }

    @Published private(set) var mode: Mode = .off
    /// The words so far of what is being said.
    @Published private(set) var partial = ""
    @Published private(set) var lastHeard = ""
    /// What is wrong with speech to text, when something is.
    @Published private(set) var problem: String?

    /// A finished utterance. Never sent anywhere as it is: the app matches it to a card's answers.
    var onHeard: ((String) -> Void)?
    var onModeChanged: (() -> Void)?
    /// Where speech to text is; nil when MailPilot didn't give one.
    var speechServer: () -> (url: String, key: String)? = { nil }

    private let audio: Audio
    private let stt: SttClient
    private let speaker: Speaker
    private let settings: AppSettings
    private let gate = PcmGate()
    private var quietTimer: Task<Void, Never>?
    private var tail: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var retries = 0
    /// Listen once it has spoken.
    private var listenAfter = false

    init(audio: Audio, stt: SttClient, speaker: Speaker, settings: AppSettings) {
        self.audio = audio
        self.stt = stt
        self.speaker = speaker
        self.settings = settings

        stt.onPartial = { [weak self] words in self?.heardPartial(words) }
        stt.onFinal = { [weak self] words in self?.heardFinal(words) }
        stt.onClosed = { [weak self] why in self?.streamClosed(why) }
        speaker.onFinished = { [weak self] _, _ in self?.spoke() }
    }

    var isOn: Bool { mode != .off }

    /// What happens with each piece of microphone audio. It runs on the audio
    /// thread, so it is made outside the main actor.
    private nonisolated static func feeder(_ gate: PcmGate, _ stt: SttClient) -> (Data) -> Void {
        { pcm in
            switch gate.mode {
            case .open: stt.feed(pcm)
            case .silence: stt.feed(Data(count: pcm.count))
            case .closed: break
            }
        }
    }

    // MARK: On and off duty

    /// The headset link is up: start asleep.
    func begin() {
        guard mode == .off else { return }
        audio.onPCM = Self.feeder(gate, stt)
        retries = 0
        problem = nil
        setMode(.asleep)
    }

    func end() {
        quietTimer?.cancel()
        tail?.cancel()
        watchdog?.cancel()
        retry?.cancel()
        gate.mode = .closed
        audio.onPCM = nil
        stt.stop()
        speaker.stop()
        partial = ""
        listenAfter = false
        setMode(.off)
    }

    // MARK: Listening

    /// Opens the microphone for an answer. `interrupt`: you asked to talk, so what is being said stops.
    func listen(_ why: String, chime: Bool = true, interrupt: Bool = false) {
        guard mode != .off else { return }
        if mode == .speaking {
            guard interrupt else {
                listenAfter = true
                return
            }
            tail?.cancel()
            watchdog?.cancel()
            speaker.stop()
        }
        if mode == .asleep, chime { audio.earcon("wake") }
        Log.say("voice: listening (\(why))")
        openStream()
        gate.mode = .open
        setMode(.listening)
        restartQuietTimer()
    }

    /// Closes the microphone until the next card or a pinch.
    func sleep(_ why: String, chime: Bool = true) {
        guard mode == .listening || mode == .speaking else { return }
        quietTimer?.cancel()
        retry?.cancel()
        partial = ""
        listenAfter = false
        Log.say("voice: asleep (\(why))")
        gate.mode = .closed
        stt.stop()
        if chime, mode == .listening { audio.earcon("sleep") }
        setMode(.asleep)
    }

    /// Quiet for long enough: sleep.
    private func restartQuietTimer() {
        quietTimer?.cancel()
        guard mode == .listening else { return }
        let seconds = max(4, settings.listenSeconds)
        quietTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if !self.partial.isEmpty {
                self.restartQuietTimer()
            } else {
                self.sleep("quiet for \(seconds) s")
            }
        }
    }

    // MARK: Speaking

    /// Says something, after a short sound when one is given. `thenListen`: the microphone opens when it is done.
    func say(_ text: String, earcon: String? = nil, thenListen: Bool = false) {
        guard mode != .off else { return }
        speaker.stop()
        if let earcon { audio.earcon(earcon) }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else {
            if thenListen { listen("nothing to say", chime: false) }
            return
        }
        listenAfter = thenListen
        tail?.cancel()
        quietTimer?.cancel()
        speaker.rate = settings.speechRate
        speaker.language = settings.spokenLanguage
        // The stream stays open while it speaks: it hears silence, unless you may answer over it.
        if stt.isOn { gate.mode = settings.bargeIn ? .open : .silence }
        setMode(.speaking)
        speaker.speak(id: "say-\(UUID().uuidString.prefix(6))", parts: [LensSay(text: words, lang: nil)], lead: earcon == nil ? 0 : 0.3)
        watchSpeech()
    }

    /// Just a sound.
    func earcon(_ name: String) {
        audio.earcon(name)
    }

    func stopSpeaking() {
        speaker.stop()
    }

    /// While it speaks, the microphone hears silence. So "speaking" must end when the voice does, even if the
    /// voice never says it finished: every half second it checks, and after a second and a half of a quiet voice
    /// it goes on as if the speech ended.
    private func watchSpeech() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            var quiet = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled, self.mode == .speaking else { return }
                quiet = self.speaker.busy ? 0 : quiet + 1
                guard quiet >= 3 else { continue }
                self.speaker.settle()
                if self.mode == .speaking, !self.speaker.speaking {
                    Log.say("voice: the speech ended without a word from the voice; going on")
                    self.tail?.cancel()
                    self.afterSpeech()
                }
                return
            }
        }
    }

    private func spoke() {
        guard mode == .speaking, !speaker.speaking else { return }
        // A short tail, so the last word's echo isn't taken for an answer.
        tail?.cancel()
        tail = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled, self.mode == .speaking, !self.speaker.speaking else { return }
            self.afterSpeech()
        }
    }

    private func afterSpeech() {
        watchdog?.cancel()
        guard mode == .speaking else { return }
        if listenAfter {
            listenAfter = false
            setMode(.asleep)
            listen("it spoke", chime: false)
        } else {
            gate.mode = .closed
            stt.stop()
            setMode(.asleep)
        }
    }

    // MARK: Speech in

    private func openStream() {
        guard !stt.isOn else { return }
        guard let server = speechServer() else {
            problem = "No speech server. Set one in MailPilot (Settings, Speech), then reconnect."
            return
        }
        stt.start(base: server.url, key: server.key)
    }

    private func heardPartial(_ words: String) {
        guard mode == .listening || mode == .speaking else { return }
        partial = words
        guard !words.isEmpty else { return }
        if problem != nil { problem = nil }
        retries = 0
        // Talking over it stops it (only with "answer over it" on: otherwise it hears silence while it speaks).
        if mode == .speaking, settings.bargeIn, words.split(separator: " ").count >= 2 {
            speaker.stop()
        }
        restartQuietTimer()
    }

    private func heardFinal(_ words: String) {
        partial = ""
        guard mode == .listening || (mode == .speaking && settings.bargeIn) else { return }
        let said = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { return }
        lastHeard = said
        Log.say("heard: “\(said.prefix(80))”")
        onHeard?(said)
        restartQuietTimer()
    }

    /// The stream to the speech server dropped: three quick tries, then a slow one.
    private func streamClosed(_ why: String) {
        guard mode == .listening || mode == .speaking else { return }
        retries += 1
        problem = "The speech server dropped (\(why)). Trying again."
        let wait: Double = retries <= 3 ? Double(retries) : 10
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard let self, !Task.isCancelled, self.mode == .listening || self.mode == .speaking else { return }
            self.openStream()
        }
    }

    private func setMode(_ next: Mode) {
        guard mode != next else { return }
        mode = next
        onModeChanged?()
    }
}
