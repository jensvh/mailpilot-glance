import Combine
import Foundation
// No SwiftUI in this file: MWDATDisplay has its own Text and Button.
import MWDATDisplay
import UIKit

/// The app's one coordinator. On duty, it keeps the link with MailPilot and
/// the glasses' headset link up with the phone locked in a pocket, the way
/// MailPilot Lens kept a walk going. When an agent starts waiting on you, the
/// card comes with a short sound, is read out, goes on the lens, and the
/// microphone opens for a few seconds for your answer. Answered or put off,
/// the lens goes dark again.
///
/// Off duty, the phone's own screen still shows the cards and takes answers.
@MainActor
final class OnDuty: ObservableObject {
    enum Stage: String {
        case off, starting, on, ending
    }

    @Published private(set) var stage: Stage = .off
    /// Why going on duty didn't work, or what to do first.
    @Published private(set) var banner: String?
    /// What the lens shows, in a few words, for the phone's status strip.
    @Published private(set) var lens = "off"

    let settings = AppSettings()
    let link = Link()
    let audio = Audio()
    let stt = SttClient()
    let speaker = Speaker()
    let ears: Ears
    let glasses = Glasses()
    let cards = Cards()

    /// What the lens shows now, so the same view isn't sent twice.
    private var shown: String?
    private var observers: [NSObjectProtocol] = []

    init() {
        ears = Ears(audio: audio, stt: stt, speaker: speaker, settings: settings)
        wire()
        Log.say("MailPilot Glance \(Link.appVersion) on iOS \(UIDevice.current.systemVersion)")
        link.start()
    }

    var isOn: Bool { stage == .on }

    private func wire() {
        link.language = { [weak self] in self?.settings.spokenLanguage }
        link.onAttention = { [weak self] attention in self?.attentionChanged(attention) }
        link.onDone = { [weak self] done in self?.answered(done) }
        ears.speechServer = { [weak self] in self?.link.speech }
        ears.onHeard = { [weak self] words in self?.heard(words) }
        glasses.onSessionEnded = { [weak self] in self?.sessionEnded() }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                Log.say("app in front")
                self?.link.wake()
                self?.glasses.refreshDevice()
            }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                Log.say(self?.isOn == true ? "app in the background (on duty goes on)" : "app in the background (off duty)")
            }
        })
        observers.append(center.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdownNow() }
        })
    }

    /// A link the app was opened with: a pairing code, or the Meta AI app's answer.
    func open(_ url: URL) {
        if !link.open(url) { glasses.handle(url) }
    }

    // MARK: On and off duty

    func start() {
        guard stage == .off else { return }
        guard link.paired else {
            banner = "Pair this phone with MailPilot first: Settings, Pair."
            return
        }
        banner = nil
        stage = .starting
        shown = nil
        glasses.keepSessionOpen = true
        glasses.run("going on duty", timeout: 90) { [weak self] in await self?.begin() }
    }

    private func begin() async {
        // The headset link comes up before any glasses session: switching it
        // with a session open ends that session.
        if glasses.hasSession {
            await glasses.closeSession("the headset microphone comes on first", quiet: true)
            await rest(2)
        }
        guard await audio.startAsync() else {
            fail("The microphone couldn't be opened. Allow it in the iPhone's Settings, under MailPilot Glance.")
            return
        }
        await rest(1.5)  // let the Bluetooth route settle before a session opens
        guard stage == .starting else { return }
        ears.begin()
        stage = .on
        Log.say("on duty: microphone \(audio.input), lens \(settings.useLens ? "on" : "off")")
        link.sayHello()
        // What already waits is announced once, as if it came now.
        if let card = cards.card {
            announce(card)
        } else {
            ears.earcon("done")
        }
    }

    private func fail(_ why: String) {
        banner = why
        Log.say("on duty: \(why)")
        ears.end()
        audio.stop()
        glasses.keepSessionOpen = false
        stage = .off
    }

    func stop() {
        guard stage == .on || stage == .starting else { return }
        stage = .ending
        glasses.run("going off duty", timeout: 60, preempt: true) { [weak self] in await self?.finish() }
    }

    private func finish() async {
        ears.end()
        // The session first, the headset link last.
        await glasses.closeEverything()
        await rest(0.5)
        audio.stop()
        glasses.keepSessionOpen = false
        shown = nil
        lens = "off"
        stage = .off
        Log.say("on duty: ended")
    }

    /// The app is being closed: let go of the glasses and the headset link at once.
    private func shutdownNow() {
        Log.say("app closing: releasing the glasses")
        ears.end()
        glasses.shutdownNow()
        audio.stop()
    }

    // MARK: What MailPilot says

    private func attentionChanged(_ attention: Attention) {
        let fresh = cards.take(attention)
        Log.say("cards: \(attention.cards.count) to show, \(attention.waiting) waiting elsewhere\(attention.atDesk ? ", at the desk" : "")\(attention.inMeeting ? ", in a meeting" : "")")
        guard isOn else { return }
        if let card = cards.card, fresh.contains(where: { $0.id == card.id }) {
            announce(card)
        } else {
            render()
        }
    }

    /// A card came (or came back changed): a sound, its words, the lens, then a few seconds to answer.
    private func announce(_ card: AttentionCard) {
        Log.say("card: \(card.kind) \(card.id)")
        render()
        link.send(.seen(id: card.id))
        if settings.readCards {
            ears.say(card.speak, earcon: card.isPermission ? "ask" : "push", thenListen: true)
        } else {
            ears.earcon(card.isPermission ? "ask" : "push")
            ears.listen("a card came", chime: false)
        }
    }

    private func answered(_ done: AttentionDone) {
        Log.say("answer: \(done.ok ? "done" : "refused"), \(done.text)")
        cards.done(done.text, ok: done.ok)
        if isOn {
            ears.say(done.text, earcon: done.ok ? "done" : "error", thenListen: false)
            render()
            // The note stays a moment, then the next card or a dark lens.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                self?.render()
            }
        }
    }

    // MARK: What you said or pinched

    private func heard(_ words: String) {
        let card = cards.card
        switch Answer.of(words, card: card, heardUp: cards.heard != nil) {
        case .option(let key):
            answer(option: key)
        case .later:
            later()
        case .read:
            if let card { ears.say(card.speak, thenListen: true) }
        case .next:
            cards.showNext()
            if let next = cards.card { announce(next) }
        case .words(let said):
            cards.hear(said)
            render()
            ears.say("Heard: \(said). Send it?", thenListen: true)
        case .send:
            sendHeard()
        case .again:
            cards.dropHeard()
            render()
            ears.listen("say it again", chime: true)
        case .cancel:
            cards.dropHeard()
            render()
        case .unknown:
            ears.earcon("error")
        }
    }

    /// A pinch on the lens or a tap on the phone.
    func tap(_ id: String) {
        if id.hasPrefix(LensTap.optionPrefix) {
            answer(option: String(id.dropFirst(LensTap.optionPrefix.count)))
            return
        }
        switch id {
        case LensTap.send: sendHeard()
        case LensTap.again:
            cards.dropHeard()
            render()
            ears.listen("say it again", interrupt: true)
        case LensTap.cancel:
            cards.dropHeard()
            render()
        default: break
        }
    }

    /// The Talk button: listen now.
    func talk() {
        ears.listen("you asked to talk", interrupt: true)
    }

    func later() {
        guard let card = cards.card else { return }
        if !link.send(.later(id: card.id)) { offline() }
    }

    func showNext() {
        cards.showNext()
        render()
    }

    private func answer(option: String) {
        guard let card = cards.card else { return }
        // Never a yes from here to what only the desk may allow; MailPilot refuses it too.
        if card.deskOnly, option == "allow" { return }
        if !link.send(.act(id: card.id, option: option, words: nil, version: card.version)) { offline() }
    }

    private func sendHeard() {
        guard let card = cards.card, let words = cards.heard else { return }
        cards.dropHeard()
        if !link.send(.act(id: card.id, option: nil, words: words, version: card.version)) { offline() }
        render()
    }

    private func offline() {
        Log.say("answer not sent: not connected")
        cards.done("Not connected to MailPilot", ok: false)
        if isOn { ears.say("Not connected to MailPilot. Answer at the desk.", earcon: "error") }
        render()
    }

    // MARK: The lens

    /// Puts what there is on the lens: a note, the card or your words, or nothing (the lens goes dark).
    func render() {
        guard isOn, settings.useLens else { return }
        let onTap: @Sendable (String) -> Void = { id in Task { @MainActor [weak self] in self?.tap(id) } }
        if let note = cards.note {
            show("note:\(note.text)", AttentionCardView.note(note.text, ok: note.ok), label: "note")
        } else if let card = cards.card {
            if let words = cards.heard {
                show("heard:\(card.id):\(words)", AttentionCardView.heard(words, for: card, onTap: onTap), label: "your words")
            } else {
                show("card:\(card.version):\(cards.more)", AttentionCardView.card(card, more: cards.more, onTap: onTap), label: AttentionCardView.label(card))
            }
        } else if shown != nil {
            shown = nil
            lens = "dark"
            glasses.run("clearing the lens") { [weak self] in await self?.glasses.closeCard() }
        }
    }

    private func show(_ key: String, _ view: FlexBox, label: String) {
        guard key != shown else { return }
        shown = key
        lens = label
        glasses.run("showing \(label)") { [weak self] in
            guard let self else { return }
            let ok = await self.glasses.show(view: view, reopen: false)
            if !ok {
                self.shown = nil
                self.lens = "not shown"
            }
        }
    }

    /// The glasses ended the session (the back gesture, out of reach): the next card opens a new one.
    private func sessionEnded() {
        shown = nil
        lens = "closed on the glasses"
    }

    /// Shows the card again on a new session: after the back gesture, from the phone.
    func reopenLens() {
        shown = nil
        render()
    }
}
