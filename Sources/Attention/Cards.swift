import Combine
import Foundation

/// The cards as MailPilot last sent them, which one is on show, and what you
/// said that waits for Send. Draws nothing and sends nothing itself.
@MainActor
final class Cards: ObservableObject {
    /// MailPilot's whole list, as it came.
    @Published private(set) var attention: Attention?
    /// The id of the card on show; the first card when that one is gone.
    @Published private(set) var showingId: String?
    /// Your own words for the card on show, waiting for Send.
    @Published private(set) var heard: String?
    /// What came of the last answer, for a moment: "Allowed once".
    @Published private(set) var note: (text: String, ok: Bool)?

    /// Card versions already announced: a card is new when its version wasn't seen, so a question that went on hold
    /// (a new version of the same card) is announced again.
    private var announced: Set<String> = []

    var cards: [AttentionCard] { attention?.cards ?? [] }

    var card: AttentionCard? {
        cards.first { $0.id == showingId } ?? cards.first
    }

    /// "+2": how many more wait behind the one on show.
    var more: Int { max(0, cards.count - 1) }

    /// Takes MailPilot's new list. Returns the cards that are new since the last one (to announce), in order.
    @discardableResult
    func take(_ next: Attention) -> [AttentionCard] {
        attention = next
        if let id = showingId, !next.cards.contains(where: { $0.id == id }) {
            showingId = nil
        }
        // A card that changed under your words (answered at the desk, gone on hold) doesn't keep them.
        if heard != nil, let id = showingId ?? next.cards.first?.id, next.cards.first(where: { $0.id == id })?.takesWords != true {
            heard = nil
        }
        let fresh = next.cards.filter { !announced.contains($0.version) }
        announced.formUnion(next.cards.map(\.version))
        // Kept small: only what is still on the list matters.
        announced = announced.intersection(next.cards.map(\.version))
        // A new card that is more urgent than the one on show takes its place, unless you're answering that one.
        if let first = next.cards.first, fresh.contains(where: { $0.id == first.id }), heard == nil {
            showingId = first.id
        }
        return fresh
    }

    /// The most urgent card: what a tapped notification was about.
    func showFirst() {
        guard showingId != nil, heard == nil else { return }
        showingId = nil
    }

    /// The next card, round the list.
    func showNext() {
        guard cards.count > 1, let current = card, let at = cards.firstIndex(where: { $0.id == current.id }) else { return }
        showingId = cards[(at + 1) % cards.count].id
        heard = nil
    }

    func hear(_ words: String) {
        heard = words
    }

    func dropHeard() {
        heard = nil
    }

    func done(_ text: String, ok: Bool) {
        note = (text, ok)
        let shown = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, self.note?.text == shown else { return }
            self.note = nil
        }
    }

    func clear() {
        attention = nil
        showingId = nil
        heard = nil
        note = nil
        announced = []
    }
}
