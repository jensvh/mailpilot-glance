# MailPilot Glance

The iPhone side of MailPilot's coding agents, for two things:

- **On the phone, the board.** Every run in one list: what waits on you, what the agent works on, what is finished and waits in a pull request, what sits in dev. Answer a question, send a prompt, merge a pull request or release, from where you are.
- **On Meta Ray-Ban Display glasses, the question.** When an agent waits on you and you're away from your desk, its question is on the lens, and you answer it with a pinch or a word.

MailPilot (a separate, private app on a PC) decides everything: what waits, how it is worded, where a run stands, what can be done to it, who is told, and what each answer does. This app is the thin part in your pocket. It draws what MailPilot sends, reads the cards out, listens for your answer and sends it back. It holds no rules about agents and stores nothing.

```
Glasses ──Bluetooth── iPhone (this app) ──wss──► your speech-to-text server
 lens, microphone,        │
 speakers                 └──wss──► relay (Azure Web PubSub) ◄──wss── MailPilot on the PC
                                    sees ciphertext only
```

It replaces MailPilot Lens (the walk through mail, tasks and runs), which is no longer worked on.

> **Status: not yet tried on a phone or on the glasses.** It compiles, the build proves that this app and MailPilot seal and read each other's messages the same way, and it takes pictures of every screen on made-up data. Its link, voice and glasses code comes from MailPilot Lens, where it was tried on the device. What has to be found out on the device is in [docs/device-check.md](docs/device-check.md).

## The board

One list, grouped by what a run needs. A colour means a lane; a project keeps its own colour on its square.

| Lane | What is in it | On the row |
|---|---|---|
| **Needs you** (amber) | a permission question, the agent's questions, an outline, a run on hold | the question; yes or no right on the row for a permission |
| **Working** (cyan) | queued, preparing, coding, testing, opening the pull request | where it is, the model, how long |
| **Review** (violet) | a finished branch, an open or draft pull request, conflicts, a job's result | its number, lines added and removed, tests, the merge |
| **In dev** (green) | one row per repo with merged work that isn't on main yet | `dev → main`, how many changes, the release |
| **Recent** (grey) | what went live, failed or was stopped in the last week | folded away until you open it |

- The four counts at the top also filter: a tap shows only that lane.
- **A tap on a run** opens it: what waits on you first, then its way from code to main, its commits, lines and tests, its branch and pull request, the model and thinking level, and what can be done now.
- **The plus** sends a prompt: a new run in a project (bug, feature or chore), or another round for a run. The model and the thinking level are on Auto until you pick one; MailPilot then chooses as it does at the desk.
- **A merge is a slide**, not a tap. A release first shows what dev holds right now, then asks for the slide, and releases exactly that: when dev moved since, MailPilot and GitHub both refuse.

What the phone may do is switched on in MailPilot (Glasses page, *From the phone*): prompts, merge into dev, release to main, each on its own and all off until you turn them on. What is off shows with a lock. Answering what waits and stopping a run need no switch.

The board is sent only while Glance is on the screen.

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

- A yes is only ever one of the card's own words (MailPilot sends them with the card), never a guess. "Always allow" and a command Claude Code's safety check flagged are never offered here: only the desk can do them. On the glasses nothing is merged or released; that is on the phone's board, behind its switches and a slide.
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

Tap the glasses at the top of the board with the app open (iOS only lets an app open the microphone while it is in front), then lock the phone and put it away. From then on:

- When an agent starts waiting on you and you're away from the desk, you hear a short sound, the card is read out and is on the lens, and the microphone listens for a few seconds.
- At the desk you hear nothing: MailPilot shows it there. A permission question you leave at the desk for 90 seconds comes to the glasses as well, before it puts its run on hold.
- In an Outlook meeting only permission questions come through.
- Answered or put off, the lens goes dark.

Tap **On duty** again to stop. On duty with the screen off, MailPilot sends only what waits, not the board.

## Off duty: notifications

Without the glasses on, MailPilot tells you through a notification instead, so an agent never waits unnoticed. It goes through the free [ntfy](https://apps.apple.com/app/id1625396347) app, so no paid Apple account is needed.

- **When.** An agent waits on you, you're away from the desk (or a permission question waited there 90 seconds), and no phone shows it: Glance is off duty and not on the screen. About 10 seconds after the card came; what was answered at the desk in those seconds is never mentioned.
- **How often.** Each card once, at most one notification a minute (what comes in between goes with the next one), and one reminder when a permission question puts its run on hold. A card that came while you were on duty or had Glance open was shown there and is never notified.
- **What it says.** Only the kind of thing: "An agent asks for permission", "2 things wait on you". Never the project, the command or the question: those stay between MailPilot and this app. Permission questions are time-sensitive, so they come through a Focus.
- **A tap** opens Glance, which connects at once and shows the most urgent card. Answer it here as always.

To set it up: on MailPilot's Glasses page, under Notifications, choose **Make a topic**. In Glance, Settings, Notifications, **Copy the topic**; in ntfy, tap **+**, paste it and Subscribe. **Test** on the Glasses page puts one on the phone.

Glance tells MailPilot whether it watches (on duty, or on the screen) after every connect and whenever that changes. If the phone goes quiet without saying so, MailPilot stops counting it after 70 seconds and notifies.

## How it is built

| Folder | What |
|---|---|
| `Sources/Link` | Pairing, the relay connection and the sealed messages (AES-GCM, a key per phone). From MailPilot Lens. |
| `Sources/Voice` | The microphone through the glasses, the speech server, the iPhone's voices. From MailPilot Lens. |
| `Sources/Glasses` | The toolkit's session and display (from MailPilot Lens), and the card on the lens. |
| `Sources/Attention` | The cards as MailPilot sent them, and the fixed rules from a sentence to an answer. |
| `Sources/Board` | The board as MailPilot sent it, and what this phone asked of the runs and still waits on. |
| `Sources/UI` | Every screen. They only know plain values and closures (`Shell`) and the board: not the link, the glasses or the microphone. |
| `Sources/App` | The app's entry, and `Live`, the one place that joins the screens to the real things. |
| `Sources/Demo` | The same screens on made-up data, as an app of its own without the glasses' toolkit. |
| `Sources/OnDuty.swift` | What happens when a card comes, and what an answer does. |
| `tools/interop` | Messages sealed by MailPilot's own code; the build opens and reads them all. |
| `tools/answer` | The answer rules, checked by the build. |
| `tools/icon` | Draws the app's icon in the build; no picture is kept here. |

There is no Mac in this project, so the build is also the eyes: its **Screens** job runs the demo app in the simulator, opens it on one screen at a time and keeps the pictures (the `screens` artifact):

```powershell
gh run download --repo jensvh/mailpilot-glance --name screens --dir screens
```

The messages are MailPilot's link, version 1, with `can: ["attention", "board"]` in the hello, `watch` after it, and no walk. MailPilot's `docs/AGENT-UNBLOCKER.md` describes them under "On the link".
