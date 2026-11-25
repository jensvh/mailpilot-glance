# MailPilot Glance

The iPhone side of MailPilot for Meta Ray-Ban Display glasses, for one thing: when a coding agent waits on you and you're away from your desk, its question is on the lens, and you answer it with a pinch or a word.

MailPilot (a separate, private app on a PC) decides everything: what waits, how it is worded, who is told (the desk while you're at it, the glasses when you're away), and what each answer does. This app is the thin part in your pocket. It shows MailPilot's cards on the lens, reads them out, listens for your answer and sends it back. It holds no logic about agents and stores nothing.

```
Glasses ──Bluetooth── iPhone (this app) ──wss──► your speech-to-text server
 lens, microphone,        │
 speakers                 └──wss──► relay (Azure Web PubSub) ◄──wss── MailPilot on the PC
                                    sees ciphertext only
```

It replaces MailPilot Lens (the walk through mail, tasks and runs), which is no longer worked on.

> **Status: not yet tried on a phone or on the glasses.** It compiles, and the build proves that this app and MailPilot seal and read each other's messages the same way. Its link, voice and glasses code comes from MailPilot Lens, where it was tried on the device. What has to be found out on the device is in [docs/device-check.md](docs/device-check.md).

## What a card is

One thing an agent can't go on without:

| Card | What you can say or pinch |
|---|---|
| **Permission**: the agent wants to run a command | **Allow once** ("yes", "allow") · **No** |
| **Question**: the agent asks before it goes on | one of its answers (the recommended one first), **Let it decide**, or your own words |
| **Outline**: a plan is ready | **Build it** · **Later**, or a change in your own words |
| **Stuck**: a run couldn't continue after a restart | **Continue** · **Later** |
| **Sign-in**: Claude's sign-in expired | shown once; only the desk can sign in |

Everywhere: "later" (off the glasses until it changes), "why" (read it again), "next" (the next card).

- A yes is only ever one of the card's own words (MailPilot sends them with the card), never a guess. "Always allow", a command Claude Code's safety check flagged, and anything that can't be undone are never offered here: only the desk can do them.
- Your own words are read back ("Heard: … Send it?") and only go after "send" or a pinch on **Send**.
- A card that changed while you answered (it went on hold, it was answered at the desk) refuses the answer and says so.

## What you need

- Meta Ray-Ban Display glasses, connected to the Meta AI app, with **Developer Mode** on there (Settings → App Info → tap the version number five times). In Developer Mode no Meta app ID is needed.
- An iPhone with iOS 17.2 or newer, with Developer Mode on (Settings → Privacy & Security → Developer Mode).
- MailPilot running, with a relay set up on its Glasses page, and a speech-to-text server set in its settings.
- A Windows PC or a Mac to sign the app with your own Apple ID.

The app also works without glasses: the phone reads the card and shows it on its own screen.

## Install

GitHub Actions builds an unsigned `MailPilotGlance.ipa` on every push. Download the newest one:

```powershell
gh run download --repo jensvh/mailpilot-glance --name MailPilotGlance --dir build-out
```

An unsigned app has to be signed with your Apple ID before iOS installs it. Without a Mac that means a signing tool on Windows (Sideloadly or AltStore), or a paid Apple developer account. With a free Apple ID the app works for 7 days and then needs signing again.

The build holds no keys and no addresses. The app gets them when you pair it.

## First start

1. **Glasses.** Open Glance, tap the gear, then **Register with the Meta AI app** and allow Glance there.
2. **MailPilot.** On the PC, open MailPilot's Glasses page and choose **Pair a phone**. Scan the code with the iPhone camera: it opens Glance, and a few seconds later it says "connected". The code works once and for 10 minutes.

Pairing gives the phone its own key, its address on the relay and the speech server's address and key, all sealed with the code's secret. They are kept in the iPhone's Keychain, on this device only. To remove a phone, use **Revoke** on MailPilot's Glasses page.

## On duty

Tap **Go on duty** with the app open (iOS only lets an app open the microphone while it is in front), then lock the phone and put it away. From then on:

- When an agent starts waiting on you and you're away from the desk, you hear a short sound, the card is read out and is on the lens, and the microphone listens for a few seconds.
- At the desk you hear nothing: MailPilot shows it there. A permission question you leave at the desk for 90 seconds comes to the glasses as well, before it puts its run on hold.
- In an Outlook meeting only permission questions come through.
- Answered or put off, the lens goes dark.

Tap **On duty** again to stop.

## How it is built

| Folder | What |
|---|---|
| `Sources/Link` | Pairing, the relay connection and the sealed messages (AES-GCM, a key per phone). From MailPilot Lens. |
| `Sources/Voice` | The microphone through the glasses, the speech server, the iPhone's voices. From MailPilot Lens. |
| `Sources/Glasses` | The toolkit's session and display (from MailPilot Lens), and the card on the lens. |
| `Sources/Attention` | The cards as MailPilot sent them, and the fixed rules from a sentence to an answer. |
| `Sources/OnDuty.swift` | What happens when a card comes, and what an answer does. |
| `tools/interop` | Messages sealed by MailPilot's own code; the build opens and reads them all. |
| `tools/answer` | The answer rules, checked by the build. |

The messages are MailPilot's link, version 1, with `can: ["attention"]` in the hello and no walk. MailPilot's `docs/AGENT-UNBLOCKER.md` describes them under "On the link".
