import SwiftUI
import UIKit

/// Pairing, the glasses' registration, how it reads and listens, and the log.
struct SettingsView: View {
    @EnvironmentObject private var duty: OnDuty
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var link: Link
    @EnvironmentObject private var glasses: Glasses
    @Environment(\.dismiss) private var dismiss

    @Environment(\.openURL) private var openURL

    @State private var pasted = ""
    @State private var speechCheck = ""
    @State private var confirmUnpair = false
    @State private var topicCopied = false

    /// The ntfy app on the App Store (it has no link of its own to open it with).
    private static let ntfyApp = URL(string: "https://apps.apple.com/app/id1625396347")!

    var body: some View {
        NavigationStack {
            Form {
                pairing
                notifications
                glassesSection
                voiceSection
                diagnostics
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: MailPilot

    private var pairing: some View {
        Section {
            LabeledContent("Status", value: link.status.label)
            if link.paired {
                if let host = link.host, !host.isEmpty { LabeledContent("Paired with", value: host) }
                if let id = link.deviceId { LabeledContent("This phone", value: String(id.prefix(8))) }
                Button("Forget this pairing", role: .destructive) { confirmUnpair = true }
                    .confirmationDialog("Forget the pairing with MailPilot?", isPresented: $confirmUnpair, titleVisibility: .visible) {
                        Button("Forget", role: .destructive) {
                            if duty.stage != .off { duty.stop() }
                            link.unpair()
                            duty.cards.clear()
                        }
                    } message: {
                        Text("Remove this phone in MailPilot too (Glasses, Phones).")
                    }
            }
            if let note = link.pairingNote {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
            TextField("Or paste the pairing link", text: $pasted)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !pasted.isEmpty {
                Button(link.pairingBusy ? "Pairing…" : "Pair with this link") {
                    link.pair(pasted)
                    pasted = ""
                }
                .disabled(link.pairingBusy)
            }
        } header: {
            Text("MailPilot")
        } footer: {
            Text("In MailPilot, open Glasses and choose Pair a phone. Scan the code with the iPhone camera: it opens this app. The code works once and for 10 minutes. Everything between this phone and MailPilot is encrypted with a key only the two of them have.")
        }
    }

    // MARK: Notifications

    private var notifications: some View {
        Section {
            if let notify = link.notify {
                LabeledContent("Topic", value: "••••••" + String(notify.topic.suffix(4)))
                if let own = notify.ownServer {
                    LabeledContent("Server", value: own)
                }
                Button {
                    UIPasteboard.general.string = notify.topic
                    topicCopied = true
                } label: {
                    Label(topicCopied ? "Copied" : "Copy the topic", systemImage: topicCopied ? "checkmark" : "doc.on.doc")
                }
                Button {
                    openURL(Self.ntfyApp)
                } label: {
                    Label("ntfy on the App Store", systemImage: "bell.badge")
                }
            } else {
                Text(link.paired
                     ? "Off in MailPilot. Turn them on there: Glasses, Notifications, Make a topic."
                     : "Pair with MailPilot first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(link.notify?.ownServer == nil
                 ? "Off duty or with this app closed, MailPilot notifies you through the free ntfy app when an agent waits on you. Install ntfy, allow its notifications, then in ntfy: +, paste the topic, Subscribe. A notification only says what kind of thing waits; tap it to answer here. While you're on duty or have this app open, nothing is sent."
                 : "Off duty or with this app closed, MailPilot notifies you through the free ntfy app when an agent waits on you. Install ntfy, allow its notifications, then in ntfy: +, paste the topic, choose Use another server and enter the server above, Subscribe. A notification only says what kind of thing waits; tap it to answer here. While you're on duty or have this app open, nothing is sent.")
        }
    }

    // MARK: Glasses

    private var glassesSection: some View {
        Section {
            LabeledContent("Meta AI app", value: glasses.registered ? "registered" : glasses.registration)
            Text(glasses.deviceInfo).font(.footnote).foregroundStyle(.secondary)
            if glasses.registered {
                Button("Unregister", role: .destructive) { glasses.unregister() }
            } else {
                Button("Register with the Meta AI app") { glasses.register() }
            }
            Toggle("Show cards on the glasses", isOn: $settings.useLens)
            if !glasses.status.isEmpty {
                Text(glasses.status).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Glasses")
        } footer: {
            Text("Registering opens the Meta AI app once, to allow this app. It needs Developer Mode there: Settings, App Info, tap the version number five times. Without the glasses, the phone reads the cards and shows them on its own screen.")
        }
    }

    // MARK: Voice

    private var voiceSection: some View {
        Section {
            Picker("Language", selection: $settings.language) {
                Text("The iPhone's").tag("auto")
                Text("English").tag("en")
                Text("Nederlands").tag("nl")
            }
            VStack(alignment: .leading) {
                Text("Speaking speed")
                Slider(value: $settings.speechRate, in: 0.7...1.5, step: 0.05)
            }
            Toggle("Read a new card out loud", isOn: $settings.readCards)
            Picker("Listens for an answer", selection: $settings.listenSeconds) {
                Text("5 seconds").tag(5)
                Text("8 seconds").tag(8)
                Text("15 seconds").tag(15)
                Text("30 seconds").tag(30)
            }
            Toggle("Answer over it", isOn: $settings.bargeIn)
            if let speech = link.speech {
                LabeledContent("Speech server", value: URL(string: speech.url)?.host ?? speech.url)
                Button("Test the speech server") {
                    speechCheck = "Asking…"
                    SttClient.health(base: speech.url, key: speech.key) { text, _ in speechCheck = text }
                }
                if !speechCheck.isEmpty { Text(speechCheck).font(.footnote).foregroundStyle(.secondary) }
            } else {
                Text("No speech server yet: MailPilot sends its address when the phone is paired and on every connect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("A new card comes with a short sound and is read out; then the microphone listens this long for an answer. Say one of its answers (\"yes\", \"no\", \"build it\"), \"later\", \"why\" to hear it again, or \"next\". On a card that takes your own words, what you say is shown back first and only goes after \"send\". A yes is only ever taken from a card's own words, never guessed.\n\n\"Answer over it\" keeps listening while it reads: only useful when the microphone doesn't pick up the glasses' own speakers.")
        }
    }

    // MARK: Diagnostics

    private var diagnostics: some View {
        Section {
            NavigationLink("Log") { LogView() }
            ShareLink("Share the log", item: Log.shared.file)
            LabeledContent("Version", value: Link.appVersion)
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("The log holds what the app did and the words it heard. It holds no keys.")
        }
    }
}

struct LogView: View {
    @ObservedObject private var log = Log.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                ForEach(Array(log.lines.enumerated().reversed()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: Log.shared.file) }
        }
    }
}
