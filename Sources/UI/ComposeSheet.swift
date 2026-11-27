import SwiftUI

/// A prompt for the agent: another round for a run on the board, or a new run in a project. The words, then what it
/// runs on: a model and a thinking level, both on Auto until one is picked (MailPilot then chooses as it does at the
/// desk).
struct ComposeSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    /// The run that gets another round; nil starts a new run.
    let run: BoardRun?

    /// What the sheet starts with: empty in the app, filled in for the build machine's screenshots.
    struct Draft {
        var words = ""
        var kind = "feature"
        var model: String?
        var effort: Int?
    }

    @State private var project: String?
    /// One of the project's repos; nil leaves it to MailPilot.
    @State private var repo: String?
    @State private var kind: String
    @State private var words: String
    /// A model's key; nil is Auto.
    @State private var model: String?
    /// 0 … 4; nil is Auto.
    @State private var effort: Int?
    @State private var asked: String?
    @FocusState private var typing: Bool

    init(run: BoardRun?, draft: Draft = Draft()) {
        self.run = run
        _kind = State(initialValue: draft.kind)
        _words = State(initialValue: draft.words)
        _model = State(initialValue: draft.model)
        _effort = State(initialValue: draft.effort)
    }

    private var projects: [BoardProject] { store.choices?.projects ?? [] }

    private var models: [BoardModel] { store.choices?.models ?? [] }

    private var chosenProject: BoardProject? { projects.first { $0.id == project } }

    private var chosenModel: BoardModel? { models.first { $0.key == model } }

    /// Prompts may be sent from this phone: for this run, or for a new one.
    private var allowed: Bool { run.map { $0.allows("prompt") } ?? store.canStart }

    private var sending: Bool { asked.map { store.pending[$0] != nil } ?? false }

    private var failure: String? {
        guard let asked, let answer = store.answers[asked], !answer.ok else { return nil }
        return answer.text
    }

    private var text: String { words.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSend: Bool { allowed && !sending && !text.isEmpty && (run != nil || project != nil) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                head

                if run == nil {
                    target
                }

                editor

                label("Model", value: chosenModel?.source)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ChoiceChip(text: "Auto", icon: "wand.and.stars", color: Theme.accent, selected: model == nil) { model = nil }
                        ForEach(models) { choice in
                            ChoiceChip(text: choice.label, color: Theme.tint(choice.hue), selected: model == choice.key) {
                                model = choice.key
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if chosenModel?.thinking != false {
                    label("Thinking", value: effort.map { EffortBars.names[$0] } ?? "Auto")
                    EffortBars(level: effort, color: Theme.cyan, height: 34) { level in
                        // A second tap on the chosen level goes back to Auto.
                        effort = effort == level ? nil : level
                    }
                }

                if let failure {
                    Label(failure, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !allowed {
                    Label("Prompts from the phone are off: MailPilot, Glasses, From the phone.", systemImage: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sendButton
            }
            .padding(Theme.pad)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .onAppear {
            if project == nil { project = projects.first?.id }
        }
        .task {
            // Straight to the words: the keyboard (and its microphone) comes up by itself on an empty sheet.
            guard words.isEmpty, allowed else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            typing = true
        }
        .onChange(of: store.answers) { _, answers in
            if let asked, answers[asked]?.ok == true { dismiss() }
        }
    }

    // MARK: Pieces

    private var head: some View {
        HStack(spacing: 10) {
            if let run {
                Orb(emoji: run.emoji, name: run.project ?? run.title, hue: run.hue, ring: StageLook.of(run.stage).color, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Another round").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text(run.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                }
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.accent.opacity(0.16)))
                Text("New run").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 4)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.panel))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    /// Where a new run goes and what kind of change it is.
    @ViewBuilder
    private var target: some View {
        if projects.isEmpty {
            Text("No project with a repo yet: link one in MailPilot.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(projects) { choice in
                        ChoiceChip(text: choice.name, emoji: choice.emoji == "📁" ? nil : choice.emoji, color: Theme.tint(choice.hue), selected: project == choice.id) {
                            project = choice.id
                            repo = nil
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }

        // A project with several repos: MailPilot picks one from the words, unless one is named here.
        if let chosen = chosenProject, chosen.repos.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ChoiceChip(text: "Auto", icon: "wand.and.stars", color: Theme.accent, selected: repo == nil) { repo = nil }
                    ForEach(chosen.repos, id: \.repo) { choice in
                        ChoiceChip(text: choice.repo.split(separator: "/").last.map(String.init) ?? choice.repo, icon: "shippingbox", color: Theme.cyan, selected: repo == choice.repo) {
                            repo = choice.repo
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }

        HStack(spacing: 8) {
            ForEach(["bug", "feature", "chore"], id: \.self) { choice in
                ChoiceChip(text: KindLook.name(choice), icon: KindLook.icon(choice), color: KindLook.color(choice), selected: kind == choice) {
                    kind = choice
                }
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $words)
                .focused($typing)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            if words.isEmpty {
                Text(run == nil ? "What should be built or fixed?" : "What should change?")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.faint)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))
    }

    private func label(_ name: String, value: String?) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            Spacer(minLength: 4)
            if let value { Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.cyan) }
        }
        .padding(.bottom, -8)
    }

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 8) {
                if sending {
                    ProgressView().tint(Theme.bg)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(sending ? "Sending…" : run == nil ? "Start" : "Send")
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.bg)
            .background(Capsule().fill(Theme.accent))
            .opacity(canSend || sending ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private func send() {
        guard canSend else { return }
        typing = false
        // A model that takes no thinking level gets none.
        let level = chosenModel?.thinking == false ? nil : effort.map { EffortBars.keys[$0] }
        if let run {
            asked = store.act("prompt", on: run, words: text, model: model, effort: level)
        } else if let project {
            asked = store.start(project: project, repo: repo, kind: kind, words: text, model: model, effort: level)
        }
    }
}
