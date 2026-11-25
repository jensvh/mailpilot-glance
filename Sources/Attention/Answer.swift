import Foundation

/// What a heard sentence means for the card on show. Fixed rules only: an
/// option is taken when the whole sentence is one of its own words (MailPilot
/// sends them with the card), never by a guess. Anything else, on a card that
/// takes words, is your own answer, shown back before it goes.
///
/// Only Foundation here: the build compiles this file into a check of its own
/// (tools/answer).
enum Answer: Equatable {
    /// One of the card's options, by its key.
    case option(String)
    /// Off the glasses until the card changes.
    case later
    /// Read the card out loud again.
    case read
    /// The next card, when more than one waits.
    case next
    /// Your own words for a card that takes them: shown back as "Heard: …" first.
    case words(String)
    /// While "Heard: …" is up: send it, say it again, or drop it.
    case send, again, cancel
    /// Not understood: nothing happens.
    case unknown

    static let laterWords: Set<String> = ["later", "not now", "snooze", "straks", "niet nu", "later graag", "plus tard", "pas maintenant"]
    static let readWords: Set<String> = ["why", "read it", "read", "repeat", "say again", "what", "waarom", "lees", "lees voor", "herhaal", "wat", "pourquoi", "répète", "repete"]
    static let nextWords: Set<String> = ["next", "next one", "volgende", "suivant"]
    static let sendWords: Set<String> = ["send", "send it", "yes send", "yes", "ok", "okay", "verstuur", "verstuur het", "stuur", "ja", "envoie", "oui"]
    static let againWords: Set<String> = ["again", "no", "redo", "opnieuw", "nee", "nog eens", "encore", "non"]
    static let cancelWords: Set<String> = ["cancel", "stop", "never mind", "annuleer", "laat maar", "annule"]
    /// Said around an answer, and not part of it.
    static let fillers: Set<String> = ["uh", "um", "uhm", "euh", "eh", "please", "graag", "alsjeblieft", "alstublieft", "svp"]

    /// What `heard` means for `card`. `heardUp`: "Heard: …" is on show, waiting for Send.
    static func of(_ heard: String, card: AttentionCard?, heardUp: Bool = false) -> Answer {
        let said = normal(heard)
        guard !said.isEmpty else { return .unknown }
        if heardUp {
            if sendWords.contains(said) { return .send }
            if againWords.contains(said) { return .again }
            if cancelWords.contains(said) { return .cancel }
            // Said again in full: it takes the place of what was heard.
            return .words(heard.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let card else { return .unknown }

        // An option's own words win over everything: "no" on a permission card is its "No".
        let matches = card.options.filter { option in
            option.words.contains { normal($0) == said } || normal(option.label) == said
        }
        if matches.count == 1, let only = matches.first { return .option(only.key) }
        if matches.count > 1 { return .unknown }

        if laterWords.contains(said) { return .later }
        if readWords.contains(said) { return .read }
        if nextWords.contains(said) { return .next }
        if card.takesWords, said.split(separator: " ").count >= 1, !cancelWords.contains(said) {
            return .words(heard.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .unknown
    }

    /// Lower case, no punctuation, single spaces, without the filler words around it.
    static func normal(_ text: String) -> String {
        let lowered = text.lowercased()
        var kept = ""
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                kept.unicodeScalars.append(scalar)
            } else {
                kept.append(" ")
            }
        }
        var words = kept.split(separator: " ").map(String.init)
        while let first = words.first, fillers.contains(first) { words.removeFirst() }
        while let last = words.last, fillers.contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }
}
