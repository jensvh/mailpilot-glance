import SwiftUI

/// Something an agent waits on, with its answers: the question in full, its options as buttons with the recommended
/// one filled, and a field for your own words where it takes them. Only its own options are ever sent; a yes to what
/// only the desk may allow isn't among them.
struct CardPanel: View {
    @EnvironmentObject private var shell: Shell

    let card: AttentionCard

    @State private var typed = ""
    /// The version of the card an answer went for: its buttons rest until the card changes or goes.
    @State private var sent: String?
    @FocusState private var typing: Bool

    private var color: Color { card.deskOnly ? Theme.red : Theme.amber }

    /// "Later" only keeps a card off the glasses; on the phone's own screen it would change nothing.
    private var options: [AttentionOption] { card.options.filter { $0.key != "later" }.prefix(3).map { $0 } }

    private var waiting: Bool { sent == card.version }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: CardLook.icon(card))
                Text(CardLook.label(card))
                if let until = card.until {
                    Text("· on hold in")
                    Text(until, style: .timer).monospacedDigit()
                }
                Spacer(minLength: 0)
                if waiting { ProgressView().controlSize(.small).tint(color) }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)

            Text(card.headline)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.speak)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if card.deskOnly {
                Label("Only the desk can say yes", systemImage: "desktopcomputer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.red)
            }

            if !options.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { buttons }
                    VStack(spacing: 8) { buttons }
                }
            }

            if card.takesWords {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Your own answer", text: $typed, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($typing)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.panelStrong))
                    IconButton(icon: "arrow.up", color: color, filled: true, label: "Send your answer", size: 40) {
                        let words = typed.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !words.isEmpty, !waiting else { return }
                        sent = card.version
                        typing = false
                        shell.answerWords(card, words)
                        typed = ""
                    }
                    .opacity(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                }
            }

            if shell.onDuty {
                HStack(spacing: 8) {
                    Button { shell.talk() } label: { Label("Talk", systemImage: "mic.fill") }
                    Button { shell.showOnLens() } label: { Label("On the lens", systemImage: "eyeglasses") }
                }
                .font(.system(size: 13, weight: .medium))
                .buttonStyle(.bordered)
                .tint(Theme.muted)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(color.opacity(0.28), lineWidth: 1))
        .onChange(of: card.version) { _, _ in sent = nil }
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
            Button {
                guard !waiting else { return }
                // Never a yes from here to what only the desk may allow; MailPilot refuses it too.
                if card.deskOnly, option.key == "allow" { return }
                sent = card.version
                shell.answer(card, option.key)
            } label: {
                Text(option.label)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 10)
                    .foregroundStyle(index == 0 ? Theme.bg : Theme.text)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(index == 0 ? color : Theme.panelStrong))
            }
            .buttonStyle(.plain)
            .opacity(waiting ? 0.5 : 1)
        }
    }
}
