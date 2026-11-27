import Combine
import Foundation

/// The board of runs as MailPilot last sent it, what a prompt can choose from, and what this phone asked and is
/// still waiting on. It decides nothing about a run: lanes, stages and what a run allows all come from MailPilot.
/// It knows nothing of the link either: what it asks goes out through `send`, set by whoever owns the link.
@MainActor
final class BoardStore: ObservableObject {
    /// The whole board, as it came. Nil until MailPilot sent one (an older MailPilot never does).
    @Published private(set) var board: RunBoard?
    @Published private(set) var choices: BoardChoices?
    /// What waits on you as an older MailPilot sends it: only the cards, no runs.
    @Published private(set) var legacy: Attention?
    /// The asks MailPilot hasn't answered yet, by their id.
    @Published private(set) var pending: [String: Ask] = [:]
    /// The answers that came, by the ask's id; kept a while for the sheet that asked.
    @Published private(set) var answers: [String: RunDone] = [:]
    /// What just happened, for a moment: "Merged into dev".
    @Published private(set) var toast: Toast?

    /// Sends a message to MailPilot; false when not connected.
    var send: (LensUp) -> Bool = { _ in false }

    struct Ask: Equatable {
        var action: String
        /// The run or the repo it is about.
        var about: String?
        var at: Date
    }

    struct Toast: Equatable {
        var text: String
        var ok: Bool
        var at: Date
    }

    /// How long an ask may go unanswered before the phone says so. A merge or a release takes GitHub a while.
    static let patience: TimeInterval = 90

    private var number = 0

    // MARK: What MailPilot says

    func take(_ next: RunBoard) {
        board = next
    }

    func take(_ next: BoardChoices) {
        choices = next
    }

    func take(_ next: Attention) {
        legacy = next
    }

    func take(_ done: RunDone) {
        guard let ask = pending.removeValue(forKey: done.id) else { return }
        answers[done.id] = done
        // A plan is read on its own sheet; everything else says what came of it.
        if ask.action != "plan", !done.text.isEmpty {
            say(done.text, ok: done.ok)
        }
        forget(done.id, after: 120)
    }

    /// Unpaired, or paired with another MailPilot: nothing of the old one stays.
    func clear() {
        board = nil
        choices = nil
        legacy = nil
        pending = [:]
        answers = [:]
        toast = nil
    }

    // MARK: What is on it

    var runs: [BoardRun] { board?.runs ?? [] }

    var repos: [BoardRepo] { board?.repos ?? [] }

    /// Everything that waits on you: the board's when there is one, else what an older MailPilot sent.
    var waiting: [AttentionCard] { board?.waiting ?? legacy?.cards ?? [] }

    /// Runs may be started from this phone.
    var canStart: Bool { board?.acts.contains("new") ?? false }

    func runs(in lane: String) -> [BoardRun] { runs.filter { $0.lane == lane } }

    func cards(for run: BoardRun) -> [AttentionCard] { waiting.filter { $0.run == run.id } }

    /// Cards that belong to no run on the board: an expired sign-in, or everything an older MailPilot sends.
    var looseCards: [AttentionCard] {
        let ids = Set(runs.map(\.id))
        return waiting.filter { card in card.run.map { !ids.contains($0) } ?? true }
    }

    func run(_ id: String?) -> BoardRun? {
        guard let id else { return nil }
        return runs.first { $0.id == id }
    }

    /// Something is being done to this run or repo: asked here and not answered yet, or MailPilot says so.
    func isBusy(_ about: String) -> Bool {
        pending.values.contains { $0.about == about }
    }

    // MARK: Asking

    /// Asks something of a run. Returns the ask's id: its answer comes under it in `answers`.
    @discardableResult
    func act(_ action: String, on run: BoardRun, words: String? = nil, model: String? = nil, effort: String? = nil) -> String {
        ask(action, about: run.id) { id in
            .runAct(id: id, action: action, run: run.id, version: run.version, words: words, model: model, effort: effort)
        }
    }

    /// Starts a run from a sentence in a project.
    @discardableResult
    func start(project: String, repo: String?, kind: String, words: String, model: String?, effort: String?) -> String {
        ask("new", about: nil) { id in
            .runAct(id: id, action: "new", repo: repo, words: words, model: model, effort: effort, project: project, kind: kind)
        }
    }

    /// Asks what a release of this repo would bring.
    @discardableResult
    func plan(_ repo: BoardRepo) -> String {
        ask("plan", about: nil) { id in .runAct(id: id, action: "plan", repo: repo.repo) }
    }

    /// Releases a repo: only what the plan showed.
    @discardableResult
    func release(_ repo: BoardRepo, plan: ReleasePlan) -> String {
        ask("release", about: repo.id) { id in .runAct(id: id, action: "release", repo: repo.repo, version: plan.version) }
    }

    private func ask(_ action: String, about: String?, _ message: (String) -> LensUp) -> String {
        number += 1
        let id = "g\(Int(Date().timeIntervalSince1970))-\(number)"
        guard send(message(id)) else {
            answers[id] = RunDone(id: id, ok: false, text: "Not connected to MailPilot.", run: nil, plan: nil)
            if action != "plan" { say("Not connected to MailPilot.", ok: false) }
            forget(id, after: 120)
            return id
        }
        pending[id] = Ask(action: action, about: about, at: Date())
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.patience * 1_000_000_000))
            self?.gaveUp(id)
        }
        return id
    }

    /// No answer came: the phone stops waiting. MailPilot may still be at it; the board will say.
    private func gaveUp(_ id: String) {
        guard let ask = pending.removeValue(forKey: id) else { return }
        let text = "No answer from MailPilot yet. It may still be working: the board will say."
        answers[id] = RunDone(id: id, ok: false, text: text, run: nil, plan: nil)
        if ask.action != "plan" { say(text, ok: false) }
        forget(id, after: 120)
    }

    private func forget(_ id: String, after seconds: Double) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self?.answers[id] = nil
        }
    }

    // MARK: Saying what happened

    func say(_ text: String, ok: Bool) {
        let shown = Toast(text: text, ok: ok, at: Date())
        toast = shown
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, self.toast == shown else { return }
            self.toast = nil
        }
    }
}
