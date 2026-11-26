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
