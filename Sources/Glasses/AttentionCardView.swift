// No SwiftUI in this file: MWDATDisplay has its own Text, Button and Image.
import Foundation
import MWDATDisplay

/// What a pinch on the lens sends back to the app.
enum LensTap {
    static let optionPrefix = "option:"
    static let send = "send"
    static let again = "again"
    static let cancel = "cancel"

    static func option(_ key: String) -> String { optionPrefix + key }
}

/// The card on the lens. The lens is 600×600 and read with one eye, so a card
/// is: what kind of wait it is (and when it goes on hold), one headline, one
/// line, and at most three buttons with the recommended one first and in
/// focus. MailPilot clamps the words; this only draws.
///
/// The toolkit has two text colours and no accent colour, so the kind is
/// carried by its icon, and a desk-only card by a warning sign.
enum AttentionCardView {
    static func card(_ card: AttentionCard, more: Int, onTap: @escaping @Sendable (String) -> Void) -> FlexBox {
        var parts: [any ViewComponent] = [
            headLine(card, more: more),
            Text(card.headline, style: .heading, color: .primary),
            Text(card.line, style: .body, color: .secondary),
        ]
        if card.deskOnly {
            parts.append(Text("Only the desk can say yes to this.", style: .meta, color: .secondary))
        } else if card.takesWords {
            parts.append(Text("Or say your own answer.", style: .meta, color: .secondary))
        }
        parts.append(buttons(Array(card.options.prefix(3)), onTap))
        let all = parts
        return FlexBox(direction: .column, spacing: 14, alignment: .start, crossAlignment: .start) {
            for part in all { part }
        }
    }

    /// Your own words, before they go: Send, Again, or Cancel.
    static func heard(_ words: String, for card: AttentionCard, onTap: @escaping @Sendable (String) -> Void) -> FlexBox {
        FlexBox(direction: .column, spacing: 14, alignment: .start, crossAlignment: .start) {
            FlexBox(direction: .row, spacing: 10, alignment: .start, crossAlignment: .center) {
                Icon(name: .speechBubble, style: .outline)
                Text("Heard · \(card.headline)", style: .meta, color: .secondary)
            }
            Text("“\(words)”", style: .heading, color: .primary)
            ButtonGroup(alignment: .start) {
                Button(label: "Send", style: .primary, iconName: .checkmark, onClick: { onTap(LensTap.send) }).actionRole(.primary)
                Button(label: "Again", style: .secondary, iconName: .speechBubble, onClick: { onTap(LensTap.again) })
                Button(label: "Cancel", style: .outline, iconName: .x, onClick: { onTap(LensTap.cancel) })
            }
        }
    }

    /// What came of an answer, for a moment.
    static func note(_ text: String, ok: Bool) -> FlexBox {
        FlexBox(direction: .row, spacing: 12, alignment: .start, crossAlignment: .center) {
            Icon(name: ok ? IconName.checkmarkCircle : IconName.exclamationCircle, style: .outline)
            Text(text, style: .heading, color: .primary)
        }
    }

    // MARK: Pieces

    /// "🔒 Permission · holds at 14:32 · +2".
    private static func headLine(_ card: AttentionCard, more: Int) -> FlexBox {
        var meta = [label(card)]
        if let until = card.until { meta.append("on hold at \(clock.string(from: until))") }
        if more > 0 { meta.append("+\(more)") }
        let text = meta.joined(separator: " · ")
        return FlexBox(direction: .row, spacing: 10, alignment: .start, crossAlignment: .center) {
            Icon(name: card.deskOnly ? IconName.exclamationTriangle : icon(card.kind), style: .outline)
            Text(text, style: .meta, color: .secondary)
        }
    }

    private static func buttons(_ options: [AttentionOption], _ onTap: @escaping @Sendable (String) -> Void) -> ButtonGroup {
        var made: [Button] = []
        for (index, option) in options.enumerated() {
            let id = LensTap.option(option.key)
            let button = Button(label: option.label, style: index == 0 ? .primary : .secondary, iconName: nil, onClick: { onTap(id) })
            made.append(index == 0 ? button.actionRole(.primary) : button)
        }
        let all = made
        return ButtonGroup(alignment: .start) {
            for button in all { button }
        }
    }

    static func label(_ card: AttentionCard) -> String {
        switch card.kind {
        case "permission": return "Permission"
        case "question":
            if let step = card.step, let steps = card.steps, steps > 1 { return "Question \(step) of \(steps)" }
            return "Question"
        case "outline": return "Outline"
        case "restart": return "Stuck"
        case "signedOut": return "Sign-in"
        default: return "The agent waits"
        }
    }

    static func icon(_ kind: String) -> IconName {
        switch kind {
        case "permission": return .padlockClosed
        case "question": return .speechBubble
        case "outline": return .threeHorizontalLines
        case "restart": return .clock
        case "signedOut": return .exclamationTriangle
        default: return .magicWand
        }
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
