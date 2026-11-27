import SwiftUI

/// A run, opened: what waits on you first, then where it is on its way from code to main, its git facts, what it runs
/// on, and what can be done to it now. The merge is a slide at the bottom: the facts above it are what you confirm.
struct RunSheet: View {
    @EnvironmentObject private var shell: Shell
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The run as it was when the sheet opened; the board's own copy is drawn while it is still there.
    let opened: BoardRun
    var prompt: () -> Void

    /// The ask this sheet sent last, to show its answer when it went wrong.
    @State private var asked: String?
    @State private var askedAction: String?

    private var run: BoardRun { store.run(opened.id) ?? opened }

    private var busy: Bool {
        run.busy != nil || store.isBusy(run.id)
    }

    private var failure: String? {
        guard let asked, let answer = store.answers[asked], !answer.ok else { return nil }
        return answer.text
    }

    var body: some View {
        let look = StageLook.of(run.stage)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                head(look)

                ForEach(store.cards(for: run)) { card in
                    CardPanel(card: card)
                }

                if run.kind != "job", StageLook.step(run.stage) != nil {
                    Track(stage: run.stage)
                        .padding(.horizontal, 4)
                }

                facts
                where_

                if let note = run.note {
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let failure {
                    Label(failure, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions
            }
            .padding(Theme.pad)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .onChange(of: store.answers) { _, answers in
            // A merge that went through: the board shows it now, and this sheet has nothing more to ask.
            guard let asked, let answer = answers[asked], answer.ok, askedAction == "merge" || askedAction == "stop" else { return }
            dismiss()
        }
    }

    // MARK: Pieces

    private func head(_ look: StageLook) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Orb(emoji: run.emoji, name: run.project ?? run.title, hue: run.hue, ring: look.color,
                live: run.lane == "working" && run.stage != "queued", size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: KindLook.icon(run.kind)).foregroundStyle(KindLook.color(run.kind))
                    Text([run.project, run.repoName].compactMap { $0 }.joined(separator: " · "))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Pill(text: look.label, icon: look.icon, color: look.color)
        }
    }

    /// Commits, lines and tests: a tile each, only what there is.
    @ViewBuilder
    private var facts: some View {
        if run.commits != nil || run.plus != nil || run.tests != nil {
            HStack(spacing: 8) {
                if let commits = run.commits {
                    FactTile(value: Text("\(commits)"), label: commits == 1 ? "commit" : "commits")
                }
                if run.plus != nil || run.minus != nil {
                    FactTile(
                        value: Text("+\(run.plus ?? 0)").foregroundColor(Theme.lime) + Text("  −\(run.minus ?? 0)").foregroundColor(Theme.red),
                        label: run.files.map { $0 == 1 ? "1 file" : "\($0) files" } ?? "lines")
                }
                if let tests = run.tests {
                    FactTile(
                        value: Text(Image(systemName: tests ? "checkmark" : "xmark")).foregroundColor(tests ? Theme.lime : Theme.red),
                        label: tests ? "tests pass" : "tests fail")
                }
            }
        }
    }

    /// The branch and its pull request, then the model, the thinking level and the rounds.
    private var where_: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let branch = run.branch {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.muted)
                    Text(branch)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let base = run.base {
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.faint)
                        Text(base).font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 4)
                    if let link = run.pullRequestLink, let pr = run.pr {
                        Button { openURL(link) } label: {
                            HStack(spacing: 4) {
                                Text("#\(pr)")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.cyan)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open pull request \(pr) on GitHub")
                    }
                }
                .font(.system(size: 13))
            }
            HStack(spacing: 10) {
                Pill(text: run.model, icon: "cpu", color: Theme.cyan)
                EffortBars(level: run.effortLevel, color: Theme.cyan)
                Text(EffortBars.names[run.effortLevel]).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer(minLength: 4)
                if run.rounds > 1 { Text("\(run.rounds) rounds").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                if let ago = Ago.short(run.since) { Text(ago).font(.system(size: 12)).foregroundStyle(Theme.faint) }
            }
        }
    }

    /// What can be done now. What is switched off in MailPilot shows with a lock, so it is clear why it isn't there.
    @ViewBuilder
    private var actions: some View {
        let plain = ["prompt", "publish", "resolve", "retry", "stop"].filter { run.allows($0) || run.isOff($0) }
        if busy {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.muted)
                Text(doing).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            if !plain.isEmpty {
                HStack(spacing: 8) {
                    ForEach(plain, id: \.self) { act in
                        actionButton(act)
                    }
                }
            }
            if run.allows("merge") {
                SlideToConfirm(label: "Slide to merge into \(run.base ?? "dev")", icon: "arrow.triangle.merge", color: Theme.violet) {
                    send("merge")
                }
            } else if run.isOff("merge") {
                offNote("Merging from the phone is off.")
            }
            if plain.contains(where: { run.isOff($0) }) {
                offNote("Some of this is off: MailPilot, Glasses, From the phone.")
            }
        }
    }

    private func actionButton(_ act: String) -> some View {
        let off = run.isOff(act)
        let look = Self.look(act)
        return Button {
            guard !off else { return }
            if act == "prompt" { prompt() } else { send(act) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: off ? "lock.fill" : look.icon).font(.system(size: 14, weight: .semibold))
                Text(look.label).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(off ? Theme.faint : act == "stop" ? Theme.red : Theme.text)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(off ? "\(look.label), switched off in MailPilot" : look.label)
    }

    private func offNote(_ text: String) -> some View {
        Label(text, systemImage: "lock.fill")
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
    }

    private static func look(_ act: String) -> (label: String, icon: String) {
        switch act {
        case "prompt": return ("Prompt", "square.and.pencil")
        case "publish": return ("Open PR", "arrow.up.circle")
        case "resolve": return ("Resolve", "arrow.triangle.merge")
        case "retry": return ("Run again", "arrow.clockwise")
        case "stop": return ("Stop", "stop.fill")
        default: return (act.capitalized, "circle")
        }
    }

    private var doing: String {
        switch run.busy ?? askedAction ?? "" {
        case "merging", "merge": return "Merging…"
        case "publishing", "publish": return "Opening the pull request…"
        case "resolving", "resolve": return "Resolving the conflicts…"
        case "starting", "retry": return "Starting again…"
        case "stop": return "Stopping…"
        default: return "Working…"
        }
    }

    private func send(_ act: String) {
        askedAction = act
        asked = store.act(act, on: run)
    }
}
