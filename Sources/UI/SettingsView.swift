import SwiftUI
import UIKit

/// Pairing, the notifications, the glasses' registration, how it reads and listens, and the log. Each row says what
/// it is with an icon and a word; the longer words sit in a footnote only where they are needed.
struct SettingsView: View {
    @EnvironmentObject private var shell: Shell
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var pasted = ""
    @State private var confirmUnpair = false
    @State private var topicCopied = false

    /// The ntfy app on the App Store (it has no link of its own to open it with).
    private static let ntfyApp = URL(string: "https://apps.apple.com/app/id1625396347")!

    var body: some View {
        NavigationStack {
            Form {
                pairing
                notifications
                glasses
                voice
                diagnostics
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: MailPilot

    private var pairing: some View {
        Section {
            row("link", linkColor, "MailPilot") {
                HStack(spacing: 6) {
                    Circle().fill(linkColor).frame(width: 8, height: 8)
                    Text(linkWord).foregroundStyle(Theme.muted)
                }
            }
            if shell.paired {
                if let host = shell.host, !host.isEmpty {
                    row("desktopcomputer", Theme.cyan, "Paired with") { Text(host).foregroundStyle(Theme.muted) }
                }
                if let id = shell.deviceShort {
                    row("iphone", Theme.cyan, "This phone") {
                        Text(id).font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                }
                Button(role: .destructive) { confirmUnpair = true } label: {
                    Label("Forget this pairing", systemImage: "trash")
                }
                .confirmationDialog("Forget the pairing with MailPilot?", isPresented: $confirmUnpair, titleVisibility: .visible) {
                    Button("Forget", role: .destructive) { shell.unpair() }
                } message: {
                    Text("Remove this phone in MailPilot too (Glasses, Phones).")
                }
            }
            if let note = shell.pairingNote {
                Text(note).font(.footnote).foregroundStyle(Theme.amber)
            }
            TextField("Paste a pairing link", text: $pasted)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !pasted.isEmpty {
                Button(shell.pairingBusy ? "Pairing…" : "Pair with this link") {
                    shell.pair(pasted)
                    pasted = ""
                }
                .disabled(shell.pairingBusy)
            }
        } footer: {
            Text("A code works once, for 10 minutes. Everything between this phone and MailPilot is encrypted.")
        }
        .listRowBackground(Theme.panel)
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
        case .online: return shell.pingMs.map { "connected · \($0) ms" } ?? "connected"
        case .connecting: return "connecting"
        case .silent: return "no answer"
        case .offline: return "offline"
        case .unpaired: return "not paired"
        }
    }

    // MARK: Notifications

    private var notifications: some View {
        Section {
            if let topic = shell.notifyTopic {
                row("bell.badge.fill", Theme.amber, "Topic") {
                    Text("••••••" + String(topic.suffix(4)))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                if let server = shell.notifyServer {
                    row("server.rack", Theme.amber, "Server") { Text(server).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                Button {
                    UIPasteboard.general.string = topic
                    topicCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        topicCopied = false
                    }
                } label: {
                    Label(topicCopied ? "Copied" : "Copy the topic", systemImage: topicCopied ? "checkmark" : "doc.on.doc")
                }
                Button { openURL(Self.ntfyApp) } label: {
                    Label("ntfy on the App Store", systemImage: "arrow.up.right.square")
                }
            } else {
                Text(shell.paired ? "Off in MailPilot: Glasses, Notifications, Make a topic." : "Pair with MailPilot first.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(shell.notifyServer == nil
                 ? "With this app closed, the ntfy app tells you when an agent waits. In ntfy: +, paste the topic, Subscribe."
                 : "With this app closed, the ntfy app tells you when an agent waits. In ntfy: +, paste the topic, Use another server, Subscribe.")
        }
        .listRowBackground(Theme.panel)
    }

    // MARK: Glasses

    private var glasses: some View {
        Section {
            row("eyeglasses", Theme.violet, "Meta AI app") {
                Text(shell.glassesRegistered ? "registered" : shell.glassesRegistration).foregroundStyle(Theme.muted)
            }
            if !shell.glassesInfo.isEmpty {
                Text(shell.glassesInfo).font(.footnote).foregroundStyle(Theme.muted)
            }
            if shell.glassesRegistered {
                Button(role: .destructive) { shell.unregisterGlasses() } label: { Label("Unregister", systemImage: "xmark.circle") }
            } else {
                Button { shell.registerGlasses() } label: { Label("Register with the Meta AI app", systemImage: "arrow.up.forward.app") }
            }
            Toggle(isOn: $settings.useLens) { Label("Cards on the lens", systemImage: "rectangle.on.rectangle") }
            if !shell.glassesStatus.isEmpty {
                Text(shell.glassesStatus).font(.footnote).foregroundStyle(Theme.muted)
            }
        } header: {
            Text("Glasses")
        } footer: {
            Text("Registering needs Developer Mode in the Meta AI app: Settings, App Info, tap the version five times.")
        }
        .listRowBackground(Theme.panel)
    }

    // MARK: Voice

    private var voice: some View {
        Section {
            Picker(selection: $settings.language) {
                Text("The iPhone's").tag("auto")
                Text("English").tag("en")
                Text("Nederlands").tag("nl")
            } label: {
                Label("Language", systemImage: "globe")
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Speaking speed", systemImage: "speedometer")
                Slider(value: $settings.speechRate, in: 0.7...1.5, step: 0.05)
            }
            Toggle(isOn: $settings.readCards) { Label("Read a new card out loud", systemImage: "speaker.wave.2") }
            Picker(selection: $settings.listenSeconds) {
                Text("5 s").tag(5)
                Text("8 s").tag(8)
                Text("15 s").tag(15)
                Text("30 s").tag(30)
            } label: {
                Label("Listens for an answer", systemImage: "mic")
            }
            Toggle(isOn: $settings.bargeIn) { Label("Answer over it", systemImage: "waveform") }
            if let host = shell.speechHost {
                row("waveform.badge.mic", Theme.cyan, "Speech server") { Text(host).foregroundStyle(Theme.muted).lineLimit(1) }
                Button { shell.testSpeech() } label: { Label("Test the speech server", systemImage: "checkmark.circle") }
                if !shell.speechCheck.isEmpty {
                    Text(shell.speechCheck).font(.footnote).foregroundStyle(Theme.muted)
                }
            } else {
                Text("No speech server yet: MailPilot sends it on every connect.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("Say one of a card's answers, \"later\", \"why\" or \"next\". Your own words are shown back first and go after \"send\".")
        }
        .listRowBackground(Theme.panel)
    }

    // MARK: Diagnostics

    private var diagnostics: some View {
        Section {
            NavigationLink {
                LogView()
            } label: {
                Label("Log", systemImage: "text.alignleft")
            }
            ShareLink(item: Log.shared.file) { Label("Share the log", systemImage: "square.and.arrow.up") }
            row("info.circle", Theme.muted, "Version") { Text(shell.version).foregroundStyle(Theme.muted) }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("The log holds what the app did and the words it heard. No keys.")
        }
        .listRowBackground(Theme.panel)
    }

    /// A fact as a row: an icon in its colour, its name, and what it is on the right.
    private func row<Value: View>(_ icon: String, _ color: Color, _ name: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(name)
            Spacer(minLength: 8)
            value()
        }
    }
}

/// The app's last lines, newest first.
struct LogView: View {
    @ObservedObject private var log = Log.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                ForEach(Array(log.lines.enumerated().reversed()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .background(Theme.bg)
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: Log.shared.file) }
        }
    }
}
