import SwiftUI

/// One run on the board: its project's square with a ring in the colour of what it is at, its name, and one line of
/// facts that depends on its lane. What it needs most is one tap away on the right: yes or no to a permission
/// question, or the merge.
struct RunRow: View {
    @EnvironmentObject private var shell: Shell
    @EnvironmentObject private var store: BoardStore

    let run: BoardRun
    var open: () -> Void

    /// An answer went from this row: until the board changes, it isn't asked twice.
    @State private var answered: String?

    var body: some View {
        let look = StageLook.of(run.stage)
        let card = store.cards(for: run).first
        HStack(spacing: 12) {
            Orb(emoji: run.emoji, name: run.project ?? run.title, hue: run.hue, ring: look.color,
                live: run.lane == "working" && run.stage != "queued")
            VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                meta(look, card)
            }
            Spacer(minLength: 6)
            trailing(card)
        }
        .rowSurface()
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: The line under the name

    @ViewBuilder
    private func meta(_ look: StageLook, _ card: AttentionCard?) -> some View {
        HStack(spacing: 6) {
            switch run.lane {
            case "you":
                Image(systemName: card.map(CardLook.icon) ?? look.icon)
                Text(card?.headline ?? look.label)
            case "working":
                StepDots(total: 4, done: StageLook.working(run.stage), color: look.color)
                Text(look.label).foregroundStyle(look.color)
                Text("· \(run.model)")
                if let ago = Ago.short(run.since) { Text("· \(ago)") }
            case "review":
                Image(systemName: look.icon).foregroundStyle(look.color)
                if let pr = run.pr {
                    Text("#\(pr)")
                    if run.stage != "pr" { Text(look.label).foregroundStyle(look.color) }
                } else {
                    Text(look.label).foregroundStyle(look.color)
                }
                if let plus = run.plus { Text("+\(plus)").foregroundStyle(Theme.lime) }
                if let minus = run.minus { Text("−\(minus)").foregroundStyle(Theme.red) }
                if let tests = run.tests {
                    Image(systemName: tests ? "checkmark" : "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tests ? Theme.lime : Theme.red)
                }
            default:
                Image(systemName: look.icon).foregroundStyle(look.color)
                Text(look.label).foregroundStyle(look.color)
                if let pr = run.pr { Text("· #\(pr)") }
                if let ago = Ago.short(run.since) { Text("· \(ago)") }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(run.lane == "you" ? Theme.amber : Theme.muted)
        .lineLimit(1)
    }

    // MARK: What it needs most

    @ViewBuilder
    private func trailing(_ card: AttentionCard?) -> some View {
        if run.busy != nil || store.isBusy(run.id) || (answered != nil && answered == card?.version) {
            ProgressView().tint(Theme.muted).frame(width: 38, height: 38)
        } else if let card, card.kind == "permission", !card.deskOnly,
                  let yes = card.options.first(where: { $0.key == "allow" }),
                  let no = card.options.first(where: { $0.key == "no" }) {
            HStack(spacing: 8) {
                IconButton(icon: "xmark", color: Theme.muted, label: no.label) {
                    answered = card.version
                    shell.answer(card, no.key)
                }
                IconButton(icon: "checkmark", color: Theme.amber, filled: true, label: yes.label) {
                    answered = card.version
                    shell.answer(card, yes.key)
                }
            }
        } else if run.lane == "review", run.allows("merge") || run.isOff("merge") {
            IconButton(icon: "arrow.triangle.merge", color: Theme.violet, locked: run.isOff("merge"), label: "Merge into \(run.base ?? "dev")", action: open)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
    }
}

/// A repo whose dev holds merged work that isn't on main yet: one release brings it all, so it is one row.
struct ReleaseRow: View {
    @EnvironmentObject private var store: BoardStore

    let repo: BoardRepo
    var open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Orb(emoji: repo.emoji, name: repo.project ?? repo.repoName, hue: repo.hue, ring: Theme.lime)
            VStack(alignment: .leading, spacing: 4) {
                Text(repo.repoName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(repo.from)
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                    Text(repo.to)
                    StepDots(total: min(repo.count, 8), done: min(repo.count, 8), color: Theme.lime)
                    Text(repo.count == 1 ? "1 change" : "\(repo.count) changes")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            if repo.busy != nil || store.isBusy(repo.id) {
                ProgressView().tint(Theme.muted).frame(width: 38, height: 38)
            } else {
                IconButton(icon: "paperplane.fill", color: Theme.lime, locked: !repo.can, label: "Release to \(repo.to)", action: open)
            }
        }
        .rowSurface()
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Something that waits and belongs to no run on the board: an expired sign-in, or a card from a MailPilot that
/// sends no board yet.
struct CardRow: View {
    let card: AttentionCard
    var open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: CardLook.icon(card))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(card.deskOnly ? Theme.red : Theme.amber)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((card.deskOnly ? Theme.red : Theme.amber).opacity(0.16)))
            VStack(alignment: .leading, spacing: 4) {
                Text(card.headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(card.line)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
        .rowSurface()
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
