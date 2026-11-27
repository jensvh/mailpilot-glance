# What only the phone and the glasses can tell

Glance was written without a phone or glasses at hand. Its link, voice and glasses code was tried on the device in MailPilot Lens; these are the things that are new here, each with how to find out. Fill in the "Found" lines after trying.

## Before you start

- MailPilot is updated (it sends the agents' cards and opens `mailpilotglance://` pairing codes).
- Pair Glance as a new phone. MailPilot Lens can stay paired; it gets no cards.
- An agent run that will wait on you: a coding run that asks permission for a command, or one that stopped with questions or an outline.

## 1. A card on the lens

Go on duty, walk away from the PC (or close MailPilot's tabs), and let a run wait on you.

- Expect: a short sound within 2 minutes of leaving the desk, the card read out, the card on the lens.
- Found: sound ___, read out ___, on the lens ___, seconds from the run waiting to the sound ___.

## 2. Readable in a glance

- Is the headline readable without effort, outdoors too? Do three buttons fit in one row?
- Found: headline ___, line ___, buttons in a row ___.

## 3. Answering

- Pinch the first button; say "yes" on a permission card; say "later"; say your own words on a question and then "send".
- Found: pinch ___, "yes" ___, "later" ___, own words and "send" ___, misheard as an answer ___ times.

## 4. On duty in the pocket

The question that decides whether this works without Apple's push notifications.

- Go on duty, lock the phone, put it away for an hour. Let a run wait on you after 15 minutes and after 55.
- Expect: both cards come. If they don't, the log (Settings, Share the log) shows when the link dropped.
- Found: after 15 min ___, after 55 min ___, phone battery ___ % per hour, glasses battery ___ % per hour.

## 5. The lens coming on by itself

- With the lens dark (nothing waiting), does a new card bring it back, or only after a pinch on the glasses?
- Found: ___.

## 6. At the desk

- With a MailPilot tab open and in use, let a permission question come. Nothing should ring. Leave it 90 seconds.
- Found: quiet at the desk ___, came to the glasses after 90 s ___.

## 7. Notifications off duty

Set them up first: MailPilot's Glasses page, Notifications, Make a topic; Glance, Settings, Notifications, Copy the topic; ntfy, +, paste, Subscribe. Then Test on the Glasses page.

- **Closed.** Close Glance (swipe it away), walk away from the PC, let a run wait on you. Expect one notification within about 15 seconds, time-sensitive for a permission question.
- **The tap.** Tap it. Expect Glance to open (not ntfy, not Safari), say "Getting what waits…" for a moment, then show the card. This is the one thing nobody has seen yet: the ntfy app opens the `mailpilotglance://cards` link itself.
- **Open.** With Glance on the screen, off duty: a new card gives a short buzz and no notification.
- **On duty.** Go on duty and lock the phone: the card comes to the glasses and no notification comes.
- **Cut.** On duty, put the phone in flight mode for two minutes, let a run wait, then turn flight mode off. Expect a notification (MailPilot stops counting a phone it doesn't hear from for 70 seconds).
- **Reminder.** Let a permission question wait 5 minutes unanswered with Glance closed: one more "Still waiting" when its run goes on hold, then nothing.
- Found: closed ___ s, opens Glance ___, buzz ___, quiet on duty ___, after the cut ___, reminder once ___.

## 8. The board

Needs MailPilot with the board (its Glasses page shows *From the phone*) and Glance 0.3.0. First with every switch off, then with them on.

- **Shows.** Open Glance. Expect your runs within a second or two, grouped: needs you, working, review, in dev; "Recent" folded. The counts at the top match, and a tap on one filters.
- **Readable.** Is a row readable at arm's length? Do the name and the line under it fit on a small iPhone, or are they cut too soon?
- **Locked.** With the switches off: the merge, the release and the plus show a lock, and say where to turn them on. Nothing is sent.
- **A permission from the row.** Let a run ask permission. Tap the tick on its row. Expect "Allowed once" and the row moving to Working.
- **A question.** Open a run that asks something: its answers as buttons, your own words in the field. Answer.
- **A follow-up.** Open a finished run, Prompt, type or dictate, pick a model and a thinking level, Send. Expect it under Working, on what you picked.
- **A new run.** The plus: project, bug/feature/chore, the words, Start. Expect it under Working and a task for it in MailPilot.
- **Merge into dev.** Open a run with an open pull request and slide. Expect "Merged into dev" and one more change under In dev. Slide half-way and let go: nothing happens.
- **Release.** Tap a repo under In dev. Expect the list of what dev holds, then the slide; after it, "Live on main" and the row gone. Push something to dev between the list and the slide: expect a refusal and "Look again".
- **Locked phone.** On duty, lock the phone for ten minutes while a run goes through its stages, then open Glance: the board is current within a second or two (MailPilot sent none while the screen was off).
- Found: shows in ___ s, readable ___, locked ___, tick on the row ___, question ___, follow-up ___, new run ___, merge ___, release ___, refused after a push ___, after a lock ___.
