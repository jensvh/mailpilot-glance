import SwiftUI

/// A release of a repo: everything on dev goes to main, so the sheet first asks MailPilot what dev holds right now
/// and lists it. Only then is there a slide, and it releases exactly what was listed: when dev moved since, MailPilot
/// and GitHub both refuse.
struct ReleaseSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    /// The repo as it was when the sheet opened; the board's own copy is drawn while it is still there.
    let opened: BoardRepo
    /// A plan to draw without asking, for the build machine's screenshots.
    var preset: ReleasePlan?

    @State private var planAsk: String?
    @State private var releaseAsk: String?

    private var repo: BoardRepo { store.repos.first { $0.id == opened.id } ?? opened }

    private var planAnswer: RunDone? { planAsk.flatMap { store.answers[$0] } }

    private var plan: ReleasePlan? { preset ?? planAnswer?.plan }

    private var releaseAnswer: RunDone? { releaseAsk.flatMap { store.answers[$0] } }

    private var releasing: Bool {
        repo.busy != nil || (releaseAsk.map { store.pending[$0] != nil } ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                head

                if !repo.can {
                    Label("Releasing from the phone is off: MailPilot, Glasses, From the phone.", systemImage: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let plan {
                    changes(plan)
                    confirm(plan)
                } else if let answer = planAnswer, !answer.ok {
                    problem(answer.text)
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.muted)
                        Text("Looking at what \(repo.from) brings…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            }
            .padding(Theme.pad)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .onAppear(perform: look)
        .onChange(of: store.answers) { _, _ in
            if releaseAnswer?.ok == true { dismiss() }
        }
    }

    // MARK: Pieces

    private var head: some View {
        HStack(alignment: .center, spacing: 12) {
            Orb(emoji: repo.emoji, name: repo.project ?? repo.repoName, hue: repo.hue, ring: Theme.lime, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(repo.repoName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(repo.from)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                    Text(repo.to)
                }
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.lime)
            }
            Spacer(minLength: 4)
            Pill(text: "Release", icon: "paperplane.fill", color: Theme.lime)
        }
    }

    /// What goes live: each change with its kind and its pull request, then how many commits that is.
    private func changes(_ plan: ReleasePlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.changes.enumerated()), id: \.offset) { index, change in
                HStack(spacing: 10) {
                    Image(systemName: KindLook.icon(change.kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KindLook.color(change.kind))
                        .frame(width: 20)
                    Text(change.title)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if let n = change.n {
                        Text("#\(n)").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 9)
                if index < plan.changes.count - 1 {
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
            }
            if plan.more > 0 {
                Text("and \(plan.more) more")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
            }
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                Text(plan.ahead == 1 ? "1 commit" : "\(plan.ahead) commits")
                Text("· everything on \(plan.from)")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.faint)
            .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))
    }

    @ViewBuilder
    private func confirm(_ plan: ReleasePlan) -> some View {
        if releasing {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.muted)
                Text("Releasing to \(plan.to)…").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else if let answer = releaseAnswer, !answer.ok {
            problem(answer.text)
        } else {
            SlideToConfirm(label: "Slide to release to \(plan.to)", icon: "paperplane.fill", color: Theme.lime) {
                releaseAsk = store.release(repo, plan: plan)
            }
        }
    }

    /// Why it didn't go, with a way to look again: what dev holds may simply have changed.
    private func problem(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.amber)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                releaseAsk = nil
                planAsk = store.plan(repo)
            } label: {
                Label("Look again", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Theme.text)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.panelStrong))
            }
            .buttonStyle(.plain)
        }
    }

    private func look() {
        guard preset == nil, repo.can, planAsk == nil else { return }
        planAsk = store.plan(repo)
    }
}
