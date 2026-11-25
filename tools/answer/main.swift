import Foundation

// What a heard sentence does on a card: the fixed rules of Sources/Attention/Answer.swift.
// The build compiles it with Answer.swift and Protocol.swift and runs it.

var failures = 0

func check(_ got: Answer, _ expected: Answer, _ what: String) {
    if got == expected {
        print("ok    \(what)")
    } else {
        failures += 1
        print("FAIL  \(what): got \(got), expected \(expected)")
    }
}

let permission = AttentionCard(
    id: "ask:req-1", version: "a1b2c3d4", kind: "permission", run: nil,
    headline: "List outdated packages?", line: "Atlas import fix", speak: "The agent wants to run dotnet list.",
    options: [AttentionOption(key: "allow", label: "Allow once", primary: true, words: ["allow", "allow it", "allow once", "yes", "ja", "oui"]),
              AttentionOption(key: "no", label: "No", primary: false, words: ["no", "nee", "non"])],
    takesWords: false, until: nil, step: nil, steps: nil, deskOnly: false, since: Date())
let question = AttentionCard(
    id: "q:1:1:0", version: "e5f6a7b8", kind: "question", run: nil,
    headline: "Which date format?", line: "Question 1 of 2 · Atlas export", speak: "Which date format?",
    options: [AttentionOption(key: "1", label: "ISO 8601", primary: true, words: ["iso 8601", "1"]),
              AttentionOption(key: "2", label: "dd/MM/yyyy", primary: false, words: ["dd/mm/yyyy", "2"]),
              AttentionOption(key: "decide", label: "Let it decide", primary: false, words: ["let it decide", "you decide", "beslis zelf"])],
    takesWords: true, until: nil, step: 1, steps: 2, deskOnly: false, since: Date())

// A permission question: only its own words say yes.
check(Answer.of("Yes.", card: permission), .option("allow"), "“Yes.” allows")
check(Answer.of("uh, allow it please", card: permission), .option("allow"), "fillers around it don't matter")
check(Answer.of("Ja", card: permission), .option("allow"), "Dutch")
check(Answer.of("no", card: permission), .option("no"), "“no” refuses")
check(Answer.of("yes but only once and not the tests", card: permission), .unknown, "a longer sentence is never a yes")
check(Answer.of("okay", card: permission), .unknown, "“okay” is not one of its words")
check(Answer.of("sure go ahead", card: permission), .unknown, "a permission question takes no own words")
check(Answer.of("later", card: permission), .later, "later")
check(Answer.of("why?", card: permission), .read, "why reads it again")
check(Answer.of("next", card: permission), .next, "next")

// The agent's question: its answers, its number, or own words.
check(Answer.of("ISO 8601", card: question), .option("1"), "an answer by its label")
check(Answer.of("one", card: question), .words("one"), "a number in words is own words (MailPilot sends digits)")
check(Answer.of("2", card: question), .option("2"), "an answer by its number")
check(Answer.of("you decide", card: question), .option("decide"), "let it decide")
check(Answer.of("week numbers", card: question), .words("week numbers"), "own words, to show back")
check(Answer.of("   ", card: question), .unknown, "nothing")

// While "Heard: …" waits for Send.
check(Answer.of("send it", card: question, heardUp: true), .send, "send")
check(Answer.of("yes", card: question, heardUp: true), .send, "yes sends what was heard")
check(Answer.of("again", card: question, heardUp: true), .again, "again")
check(Answer.of("cancel", card: question, heardUp: true), .cancel, "cancel")
check(Answer.of("week numbers please", card: question, heardUp: true), .words("week numbers please"), "said again in full")

// No card.
check(Answer.of("yes", card: nil), .unknown, "no card, no answer")

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
