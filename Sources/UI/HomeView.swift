import SwiftUI

/// The phone's one screen: whether it is on duty and connected, and the card on
/// show, answered with a tap the same way a pinch on the lens answers it.
struct HomeView: View {
    @EnvironmentObject private var duty: OnDuty
    @EnvironmentObject private var link: Link
    @EnvironmentObject private var glasses: Glasses
    @EnvironmentObject private var cards: Cards
    @EnvironmentObject private var ears: Ears
    @State private var settingsOpen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusStrip
                    dutyButton
                    if let banner = duty.banner ?? glasses.banner {
                        Label(banner, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if let warning = link.warning {
                        Label(warning, systemImage: "clock.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if let note = cards.note {
                        Label(note.text, systemImage: note.ok ? "checkmark.circle" : "exclamationmark.circle")
                            .foregroundStyle(note.ok ? Color.green : Color.orange)
                    }
                    if let card = cards.card {
                        CardPanel(card: card, more: cards.more)
                    } else {
                        quiet
                    }
                }
                .padding(18)
            }
            .navigationTitle("Glance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settingsOpen = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $settingsOpen) { SettingsView() }
        }
    }

    // MARK: Pieces

    private var statusStrip: some View {
        HStack(spacing: 14) {
            Label(link.status.label, systemImage: link.online ? "link" : "link.badge.plus")
                .foregroundStyle(link.online ? Color.green : Color.secondary)
            Label(glasses.connected ? (glasses.worn ? "worn" : "connected") : "no glasses", systemImage: "eyeglasses")
                .foregroundStyle(glasses.connected ? Color.primary : Color.secondary)
            if let ms = link.roundTripMs {
                Text("\(ms) ms").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.footnote)
    }

    private var dutyButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                duty.stage == .off ? duty.start() : duty.stop()
            } label: {
                Label(dutyLabel, systemImage: duty.isOn ? "bell.badge.fill" : "bell.slash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(duty.isOn ? .orange : .gray)
            .disabled(duty.stage == .starting || duty.stage == .ending || !link.paired)
            Text(dutyHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if duty.isOn {
                HStack(spacing: 12) {
                    Text("Lens: \(duty.lens)")
                    Text("Voice: \(ears.mode.rawValue)")
                    if !ears.partial.isEmpty { Text("“\(ears.partial)”").lineLimit(1) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let problem = ears.problem {
                    Text(problem).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var dutyLabel: String {
        switch duty.stage {
        case .off: return "Go on duty"
        case .starting: return "Going on duty…"
        case .on: return "On duty"
        case .ending: return "Going off duty…"
        }
    }

    private var dutyHint: String {
        if !link.paired { return "Pair this phone with MailPilot first: Settings." }
        if duty.isOn {
            return "When an agent waits on you, you hear it and see it on the lens. Lock the phone and put it away. Tap to go off duty."
        }
        return link.notify == nil
            ? "Off duty, nothing rings: the cards only show here. Notifications can be set up in Settings."
            : "Off duty, the ntfy app notifies you when an agent waits; a tap brings you here."
    }

    /// Nothing waits: what MailPilot counts, and why it may be quiet. Not before MailPilot said so: opened from a
    /// notification, the link may still be connecting.
    @ViewBuilder
    private var quiet: some View {
        if link.paired, link.status == .connecting {
            HStack(spacing: 10) {
                ProgressView()
                Text("Getting what waits…").font(.title3.weight(.semibold))
            }
        } else if link.paired, !link.online {
            VStack(alignment: .leading, spacing: 6) {
                Label("Not connected to MailPilot", systemImage: "link.badge.plus")
                    .font(.title3.weight(.semibold))
                if let detail = link.status.detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } else {
            nothingWaits
        }
    }

    private var nothingWaits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nothing waits on you", systemImage: "checkmark.circle")
                .font(.title3.weight(.semibold))
            if let attention = link.attention {
                HStack(spacing: 18) {
                    count(attention.counts.running, "running", .cyan)
                    count(attention.counts.review, "to review", .orange)
                    count(attention.counts.failed, "failed", .gray)
                }
                if attention.waiting > 0 {
                    Text(waitingNote(attention))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if link.paired {
                Text("MailPilot hasn't sent anything yet.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func waitingNote(_ attention: Attention) -> String {
        let what = attention.waiting == 1 ? "1 thing waits" : "\(attention.waiting) things wait"
        if attention.atDesk { return "\(what) at the desk: you're there, so it shows there." }
        if attention.inMeeting { return "\(what) until your meeting ends." }
        return "\(what), put off for later."
    }

    private func count(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(.title2.weight(.semibold)).foregroundStyle(n > 0 ? color : .secondary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The card on show, as on the lens, with its answers as buttons.
struct CardPanel: View {
    @EnvironmentObject private var duty: OnDuty
    @EnvironmentObject private var cards: Cards
    let card: AttentionCard
    let more: Int
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(AttentionCardView.label(card))
                if let until = card.until {
                    Text("· on hold") + Text(" ") + Text(until, style: .relative)
                }
                Spacer()
                if more > 0 {
                    Button("+\(more)") { duty.showNext() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .font(.footnote)
            .foregroundStyle(card.deskOnly ? Color.red : Color.orange)

            Text(card.headline).font(.title2.weight(.semibold))
            Text(card.line).foregroundStyle(.secondary)
            Text(card.speak).font(.footnote).foregroundStyle(.secondary)
            if card.deskOnly {
                Label("Only the desk can say yes to this.", systemImage: "desktopcomputer")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let words = cards.heard {
                Text("Heard: “\(words)”").font(.headline)
                HStack {
                    Button("Send") { duty.tap(LensTap.send) }.buttonStyle(.borderedProminent)
                    Button("Again") { duty.tap(LensTap.again) }.buttonStyle(.bordered)
                    Button("Cancel", role: .cancel) { duty.tap(LensTap.cancel) }.buttonStyle(.bordered)
                }
            } else {
                ForEach(Array(card.options.prefix(3).enumerated()), id: \.offset) { index, option in
                    if index == 0 {
                        Button {
                            duty.tap(LensTap.option(option.key))
                        } label: {
                            Text(option.label).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            duty.tap(LensTap.option(option.key))
                        } label: {
                            Text(option.label).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if card.takesWords {
                    HStack {
                        TextField("Or your own answer", text: $typed)
                            .textFieldStyle(.roundedBorder)
                        Button("Use") {
                            cards.hear(typed)
                            typed = ""
                        }
                        .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                HStack {
                    Button("Later") { duty.later() }.buttonStyle(.bordered)
                    if duty.isOn {
                        Button { duty.talk() } label: { Label("Talk", systemImage: "mic") }.buttonStyle(.bordered)
                        Button("Show on the lens") { duty.reopenLens() }.buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.12)))
    }

    private var symbol: String {
        if card.deskOnly { return "exclamationmark.triangle" }
        switch card.kind {
        case "permission": return "lock"
        case "question": return "text.bubble"
        case "outline": return "list.bullet"
        case "restart": return "clock.arrow.circlepath"
        case "signedOut": return "key"
        default: return "wand.and.stars"
        }
    }
}
