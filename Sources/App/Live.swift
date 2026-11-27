import Combine
import Foundation

/// Joins the screens to the real things. The screens only know `Shell` (plain values and closures) and the board;
/// this keeps the shell's values in step with the link, the glasses and the microphone, and sends what the screens
/// ask for to the coordinator. Nothing else in the app touches both sides.
@MainActor
final class Live {
    let shell = Shell()

    private let duty: OnDuty
    private var watching: Set<AnyCancellable> = []

    init(duty: OnDuty) {
        self.duty = duty
        shell.version = Link.appVersion

        shell.toggleDuty = { [weak duty] in
            guard let duty else { return }
            if duty.stage == .off { duty.start() } else { duty.stop() }
        }
        shell.pair = { [weak duty] link in duty?.link.pair(link) }
        shell.unpair = { [weak duty] in duty?.unpair() }
        shell.answer = { [weak duty] card, option in duty?.answer(card, option: option) }
        shell.answerWords = { [weak duty] card, words in duty?.answer(card, words: words) }
        shell.later = { [weak duty] card in duty?.later(card) }
        shell.sendHeard = { [weak duty] in duty?.tap(LensTap.send) }
        shell.againHeard = { [weak duty] in duty?.tap(LensTap.again) }
        shell.cancelHeard = { [weak duty] in duty?.tap(LensTap.cancel) }
        shell.talk = { [weak duty] in duty?.talk() }
        shell.showOnLens = { [weak duty] in duty?.reopenLens() }
        shell.registerGlasses = { [weak duty] in duty?.glasses.register() }
        shell.unregisterGlasses = { [weak duty] in duty?.glasses.unregister() }
        shell.testSpeech = { [weak self] in self?.testSpeech() }

        // Whatever changes in any of them: read all of it again, a moment later (the change has landed by then).
        let changes: [ObservableObjectPublisher] = [
            duty.objectWillChange, duty.link.objectWillChange, duty.glasses.objectWillChange,
            duty.ears.objectWillChange, duty.cards.objectWillChange,
        ]
        Publishers.MergeMany(changes)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &watching)
        refresh()
    }

    private func refresh() {
        let link = duty.link
        put(\.link, Self.state(link.status))
        put(\.linkDetail, link.status.detail)
        put(\.host, link.host)
        put(\.deviceShort, link.deviceId.map { String($0.prefix(8)) })
        put(\.pingMs, link.roundTripMs)
        put(\.pairingNote, link.pairingNote)
        put(\.pairingBusy, link.pairingBusy)
        put(\.notifyTopic, link.notify?.topic)
        put(\.notifyServer, link.notify?.ownServer)
        put(\.speechHost, link.speech.map { URL(string: $0.url)?.host ?? $0.url })

        put(\.duty, Self.stage(duty.stage))
        put(\.lens, duty.lens)
        put(\.voice, duty.ears.mode.rawValue)
        put(\.partial, duty.ears.partial)
        put(\.heard, duty.isOn ? duty.cards.heard : nil)
        put(\.banner, duty.banner ?? duty.glasses.banner ?? link.warning ?? duty.ears.problem)

        let glasses = duty.glasses
        put(\.glasses, glasses.connected ? (glasses.worn ? Shell.GlassesState.worn : .connected) : .none)
        put(\.glassesRegistered, glasses.registered)
        put(\.glassesRegistration, glasses.registration)
        put(\.glassesInfo, glasses.deviceInfo)
        put(\.glassesStatus, glasses.status)
    }

    /// Sets a value only when it differs: the screens draw again only for what changed.
    private func put<Value: Equatable>(_ path: ReferenceWritableKeyPath<Shell, Value>, _ value: Value) {
        if shell[keyPath: path] != value { shell[keyPath: path] = value }
    }

    private static func state(_ status: Link.Status) -> Shell.LinkState {
        switch status {
        case .unpaired: return .unpaired
        case .connecting: return .connecting
        case .online: return .online
        case .silent: return .silent
        case .offline: return .offline
        }
    }

    private static func stage(_ stage: OnDuty.Stage) -> Shell.Duty {
        switch stage {
        case .off: return .off
        case .starting: return .starting
        case .on: return .on
        case .ending: return .ending
        }
    }

    private func testSpeech() {
        guard let speech = duty.link.speech else { return }
        shell.speechCheck = "Asking…"
        SttClient.health(base: speech.url, key: speech.key) { [weak self] text, _ in
            self?.shell.speechCheck = text
        }
    }
}
