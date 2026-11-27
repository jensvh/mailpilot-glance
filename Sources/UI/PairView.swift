import SwiftUI

/// The first screen of a phone that isn't paired yet: three steps as pictures, and a field for the pairing link when
/// the camera isn't at hand.
struct PairView: View {
    @EnvironmentObject private var shell: Shell

    @State private var pasted = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OrbitArt(size: 170)
                    .padding(.top, 40)

                VStack(spacing: 6) {
                    Text("Pair with MailPilot")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Your agents' runs, at a glance.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 14) {
                    step(1, "desktopcomputer", "In MailPilot: Glasses, Pair a phone")
                    step(2, "qrcode.viewfinder", "Scan the code with the camera")
                    step(3, "checkmark.seal.fill", "This app opens, paired")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))

                VStack(spacing: 10) {
                    TextField("Or paste the pairing link", text: $pasted)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.panel))
                    if !pasted.isEmpty || shell.pairingBusy {
                        Button {
                            shell.pair(pasted)
                            pasted = ""
                        } label: {
                            HStack(spacing: 8) {
                                if shell.pairingBusy { ProgressView().tint(Theme.bg) }
                                Text(shell.pairingBusy ? "Pairing…" : "Pair")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(Theme.bg)
                            .background(Capsule().fill(Theme.accent))
                        }
                        .buttonStyle(.plain)
                        .disabled(shell.pairingBusy)
                    }
                    if let note = shell.pairingNote {
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.amber)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Label("Encrypted with a key only this phone and MailPilot have", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func step(_ number: Int, _ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.accent.opacity(0.16)))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.faint)
        }
    }
}
