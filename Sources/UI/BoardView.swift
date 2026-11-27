import SwiftUI

/// The app's one screen: every run in one list, grouped by what it needs. On top the link, the glasses and four
/// counts that also filter; under it what waits on you, what the agent works on, what is finished and waits for a
/// look, what sits in dev, and what ended lately. A tap opens a run; the plus sends a new prompt.
struct BoardView: View {
    @EnvironmentObject private var shell: Shell
    @EnvironmentObject private var store: BoardStore

    /// What a tap opened, as a sheet.
    enum Route: Identifiable, Equatable {
        case run(String)
        case card(String)
        case release(String)
        /// A prompt: for the run with this id, or a new run.
        case compose(String?)
        case settings

        var id: String {
            switch self {
            case .run(let id): return "run:" + id
            case .card(let id): return "card:" + id
            case .release(let id): return "release:" + id
            case .compose(let id): return "compose:" + (id ?? "")
            case .settings: return "settings"
            }
        }
    }

    /// A sheet that is open from the start, and what a prompt sheet starts with: for the build machine's screenshots.
    var opening: Route?
    var draft = ComposeSheet.Draft()
    var plan: ReleasePlan?
    var recentOpen = false

    @State private var route: Route?
    /// The lane the list is narrowed to; nil shows them all.
    @State private var filter: String?
    @State private var showRecent = false
    @State private var opened = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            if shell.paired {
                list
                if store.board != nil {
                    HStack {
                        Spacer()
                        compose
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }
            } else {
                PairView()
                    .overlay(alignment: .topTrailing) {
                        gear.padding(.trailing, Theme.pad).padding(.top, 8)
                    }
            }

            if let toast = store.toast {
                ToastView(text: toast.text, ok: toast.ok)
                    .padding(.bottom, shell.paired && store.board != nil ? 84 : 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .sheet(item: $route) { route in
            sheet(route)
                .environmentObject(shell)
                .environmentObject(store)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .onAppear {
            guard !opened else { return }
            opened = true
            showRecent = recentOpen
            route = opening
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: The list

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header

                if shell.duty != .off { DutyBar() }

                if let banner = shell.banner {
                    Label(banner, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                }

                if store.board != nil {
                    chips
                    lanes
                } else if !store.waiting.isEmpty {
                    LaneHeader(look: .you, count: store.waiting.count)
                    ForEach(store.waiting) { card in
                        CardRow(card: card) { route = .card(card.id) }
                    }
                    Text("This MailPilot sends no runs yet: they show after its update.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 8)
                } else {
                    waitingForBoard
                }
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Glance")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            linkMark
            Spacer(minLength: 4)
            dutyPill
            gear
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// The link as a dot: lime when MailPilot answers; with a word when it doesn't.
    private var linkMark: some View {
        HStack(spacing: 5) {
            Circle().fill(linkColor).frame(width: 8, height: 8)
            if shell.link != .online {
                Text(linkWord).font(.system(size: 12, weight: .medium)).foregroundStyle(linkColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MailPilot: \(linkWord)")
    }

    private var linkColor: Color {
        switch shell.link {
        case .online: return Theme.lime
        case .connecting, .silent: return Theme.amber
        case .offline: return Theme.red
        case .unpaired: return Theme.faint
        }
    }

    private var linkWord: String {
        switch shell.link {
        case .online: return "connected"
        case .connecting: return "connecting"
        case .silent: return "no answer"
        case .offline: return "offline"
        case .unpaired: return "not paired"
        }
    }

    /// On or off duty with the glasses: a tap switches.
    private var dutyPill: some View {
        Button { shell.toggleDuty() } label: {
            HStack(spacing: 6) {
                Image(systemName: "eyeglasses").font(.system(size: 13, weight: .semibold))
                Text(dutyWord).font(.system(size: 13, weight: .semibold))
                if shell.glasses == .worn { Circle().fill(Theme.lime).frame(width: 6, height: 6) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(dutyColor)
            .background(Capsule().fill(dutyColor.opacity(shell.duty == .off ? 0.12 : 0.18)))
        }
        .buttonStyle(.plain)
        .disabled(shell.duty == .starting || shell.duty == .ending)
        .accessibilityLabel(shell.duty == .off ? "Go on duty with the glasses" : "On duty. Tap to go off duty")
    }

    private var dutyWord: String {
        switch shell.duty {
        case .off: return "Off"
        case .starting: return "Starting"
        case .on: return "On duty"
        case .ending: return "Ending"
        }
    }

    private var dutyColor: Color {
        switch shell.duty {
        case .off: return Theme.muted
        case .on: return Theme.lime
        default: return Theme.amber
        }
    }

    private var gear: some View {
        Button { route = .settings } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    // MARK: Counts and lanes

    private var needsYou: Int { store.runs(in: "you").count + store.looseCards.count }

    private var inDev: Int { store.repos.reduce(0) { $0 + $1.count } }

    private func count(_ lane: String) -> Int {
        switch lane {
        case "you": return needsYou
        case "dev": return inDev
        default: return store.runs(in: lane).count
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(LaneLook.chips, id: \.key) { look in
                CountChip(look: look, count: count(look.key), selected: filter == look.key) {
                    filter = filter == look.key ? nil : look.key
                }
            }
        }
        .padding(.bottom, 2)
    }

    private func shows(_ lane: String) -> Bool { filter == nil || filter == lane }

    @ViewBuilder
    private var lanes: some View {
        let recent = store.runs.filter { $0.lane == "done" || $0.lane == "stopped" }
        let quiet = needsYou == 0 && store.runs(in: "working").isEmpty && store.runs(in: "review").isEmpty && store.repos.isEmpty

        if shows("you"), needsYou > 0 {
            LaneHeader(look: .you, count: needsYou)
            ForEach(store.runs(in: "you")) { run in
                RunRow(run: run) { route = .run(run.id) }
            }
            ForEach(store.looseCards) { card in
                CardRow(card: card) { route = .card(card.id) }
            }
        }

        if shows("working"), !store.runs(in: "working").isEmpty {
            LaneHeader(look: .working, count: store.runs(in: "working").count)
            ForEach(store.runs(in: "working")) { run in
                RunRow(run: run) { route = .run(run.id) }
            }
        }

        if shows("review"), !store.runs(in: "review").isEmpty {
            LaneHeader(look: .review, count: store.runs(in: "review").count)
            ForEach(store.runs(in: "review")) { run in
                RunRow(run: run) { route = .run(run.id) }
            }
        }

        if shows("dev"), !store.repos.isEmpty {
            LaneHeader(look: .dev, count: inDev)
            ForEach(store.repos) { repo in
                ReleaseRow(repo: repo) { route = .release(repo.id) }
            }
        }

        if quiet, filter == nil {
            VStack(spacing: 10) {
                OrbitArt(size: 150)
                Text("All quiet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Nothing waits, nothing runs.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else if let filter, count(filter) == 0 {
            Text("Nothing here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }

        if filter == nil, !recent.isEmpty {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showRecent.toggle() } } label: {
                LaneHeader(look: .recent, count: recent.count, trailing: showRecent ? "hide" : "show")
            }
            .buttonStyle(.plain)
            if showRecent {
                ForEach(recent) { run in
                    RunRow(run: run) { route = .run(run.id) }
                }
            }
        }
    }

    /// Paired, but nothing came yet: connecting, or MailPilot doesn't answer.
    private var waitingForBoard: some View {
        VStack(spacing: 12) {
            if shell.link == .connecting {
                ProgressView().tint(Theme.muted)
                Text("Getting the board…").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
            } else {
                OrbitArt(size: 130, color: shell.link == .online ? Theme.violet : Theme.amber)
                Text(shell.link == .online ? "Nothing waits on you" : "Not connected to MailPilot")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                if let detail = shell.linkDetail, shell.link != .online {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// The plus: a prompt for a new run.
    private var compose: some View {
        Button { route = .compose(nil) } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.bg)
                .frame(width: 56, height: 56)
                .background(Circle().fill(LinearGradient(colors: [Theme.violet, Theme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: Theme.violet.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New prompt")
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheet(_ route: Route) -> some View {
        switch route {
        case .run(let id):
            if let run = store.run(id) {
                RunSheet(opened: run) { self.route = .compose(run.id) }
                    .presentationDetents([.medium, .large])
            } else {
                gone("This run is no longer on the board.")
            }
        case .card(let id):
            if let card = store.waiting.first(where: { $0.id == id }) {
                ScrollView {
                    CardPanel(card: card).padding(Theme.pad).padding(.top, 12)
                }
                .background(Theme.bg)
                .presentationDetents([.medium, .large])
            } else {
                gone("Answered: nothing waits here any more.")
            }
        case .release(let id):
            if let repo = store.repos.first(where: { $0.id == id }) {
                ReleaseSheet(opened: repo, preset: plan)
                    .presentationDetents([.medium, .large])
            } else {
                gone("Released: nothing waits in dev here.")
            }
        case .compose(let id):
            ComposeSheet(run: store.run(id), draft: draft)
                .presentationDetents([.large])
        case .settings:
            SettingsView()
        }
    }

    private func gone(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle").font(.system(size: 34)).foregroundStyle(Theme.lime)
            Text(text).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .presentationDetents([.fraction(0.25)])
    }
}

/// On duty: what the lens shows and what the microphone does, and your own words when they wait for Send.
struct DutyBar: View {
    @EnvironmentObject private var shell: Shell

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eyeglasses")
                Text(shell.lens)
                Text("·").foregroundStyle(Theme.faint)
                Image(systemName: "mic.fill")
                Text(shell.voice)
                if !shell.partial.isEmpty {
                    Text("“\(shell.partial)”").foregroundStyle(Theme.text).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.muted)

            if let heard = shell.heard {
                Text("“\(heard)”")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button { shell.sendHeard() } label: { Label("Send", systemImage: "arrow.up") }
                        .buttonStyle(.borderedProminent)
                    Button { shell.againHeard() } label: { Label("Again", systemImage: "mic") }
                        .buttonStyle(.bordered)
                    Button { shell.cancelHeard() } label: { Text("Cancel") }
                        .buttonStyle(.bordered)
                }
                .font(.system(size: 13, weight: .medium))
                .tint(Theme.lime)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.lime.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.lime.opacity(0.22), lineWidth: 1))
    }
}
