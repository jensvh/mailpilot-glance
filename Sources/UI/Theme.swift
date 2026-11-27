import SwiftUI

/// The app's look in one place: dark and calm, with colour only where it means something. The same meanings as
/// MailPilot at the desk: lime is done or live, amber waits on you, cyan works, violet is the agents' own, red failed.
/// A project keeps its own hue on its square.
enum Theme {
    // Surfaces
    static let bg = Color(red: 0.043, green: 0.047, blue: 0.063)
    static let panel = Color.white.opacity(0.055)
    static let panelStrong = Color.white.opacity(0.09)
    static let line = Color.white.opacity(0.09)

    // Text
    static let text = Color(red: 0.925, green: 0.925, blue: 0.94)
    static let muted = Color(red: 0.62, green: 0.63, blue: 0.69)
    static let faint = Color(red: 0.42, green: 0.43, blue: 0.49)

    // Meanings
    static let amber = Color(red: 0.96, green: 0.75, blue: 0.36)
    static let cyan = Color(red: 0.37, green: 0.80, blue: 0.95)
    static let violet = Color(red: 0.66, green: 0.60, blue: 0.98)
    static let lime = Color(red: 0.62, green: 0.89, blue: 0.45)
    static let red = Color(red: 0.96, green: 0.47, blue: 0.48)
    static let pink = Color(red: 0.96, green: 0.52, blue: 0.75)
    static let accent = violet

    // Shape
    static let radius: CGFloat = 14
    static let radiusSmall: CGFloat = 10
    static let pad: CGFloat = 16

    /// A colour from hue, saturation and lightness, as the desk's style sheet writes them.
    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double, _ alpha: Double = 1) -> Color {
        let s = saturation / 100
        let l = lightness / 100
        let v = l + s * min(l, 1 - l)
        let sv = v == 0 ? 0 : 2 * (1 - l / v)
        var h = hue.truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        return Color(hue: h / 360, saturation: sv, brightness: v, opacity: alpha)
    }

    /// The colour of something in a hue: a project's letters, a chip's words.
    static func tint(_ hue: Int) -> Color { hsl(Double(hue), 72, 78) }

    /// The quiet fill behind it.
    static func fill(_ hue: Int) -> Color { hsl(Double(hue), 52, 52, 0.24) }
}

/// How a lane shows: its name, its icon and its colour.
struct LaneLook {
    var key: String
    var name: String
    var icon: String
    var color: Color

    static let you = LaneLook(key: "you", name: "Needs you", icon: "bell.badge.fill", color: Theme.amber)
    static let working = LaneLook(key: "working", name: "Working", icon: "bolt.fill", color: Theme.cyan)
    static let review = LaneLook(key: "review", name: "Review", icon: "arrow.triangle.pull", color: Theme.violet)
    static let dev = LaneLook(key: "dev", name: "In dev", icon: "shippingbox.fill", color: Theme.lime)
    static let recent = LaneLook(key: "recent", name: "Recent", icon: "clock", color: Theme.muted)

    /// The four that count: a chip each at the top.
    static let chips = [you, working, review, dev]

    static func of(_ lane: String) -> LaneLook {
        switch lane {
        case "you": return you
        case "working": return working
        case "review": return review
        case "dev": return dev
        default: return recent
        }
    }
}

/// How a stage shows: a word or two, an icon, a colour. A stage this build doesn't know still shows, as its own word.
struct StageLook {
    var label: String
    var icon: String
    var color: Color

    static func of(_ stage: String) -> StageLook {
        switch stage {
        case "queued": return StageLook(label: "Queued", icon: "clock", color: Theme.muted)
        case "preparing": return StageLook(label: "Preparing", icon: "arrow.down.circle", color: Theme.cyan)
        case "coding": return StageLook(label: "Coding", icon: "chevron.left.forwardslash.chevron.right", color: Theme.cyan)
        case "testing": return StageLook(label: "Testing", icon: "checklist", color: Theme.cyan)
        case "publishing": return StageLook(label: "Opening PR", icon: "arrow.up.circle", color: Theme.cyan)
        case "resuming": return StageLook(label: "Resuming", icon: "play.circle", color: Theme.cyan)
        case "asks": return StageLook(label: "Asks permission", icon: "lock.fill", color: Theme.amber)
        case "questions": return StageLook(label: "Has questions", icon: "text.bubble.fill", color: Theme.amber)
        case "outline": return StageLook(label: "Outline ready", icon: "list.bullet", color: Theme.amber)
        case "hold": return StageLook(label: "On hold", icon: "pause.circle.fill", color: Theme.amber)
        case "branch": return StageLook(label: "Branch ready", icon: "arrow.triangle.branch", color: Theme.violet)
        case "result": return StageLook(label: "Result ready", icon: "doc.text.fill", color: Theme.violet)
        case "pr": return StageLook(label: "PR open", icon: "arrow.triangle.pull", color: Theme.violet)
        case "draft": return StageLook(label: "Draft PR", icon: "pencil.circle", color: Theme.violet)
        case "conflicts": return StageLook(label: "Conflicts", icon: "exclamationmark.triangle.fill", color: Theme.amber)
        case "dev": return StageLook(label: "In dev", icon: "arrow.triangle.merge", color: Theme.lime)
        case "merged": return StageLook(label: "Merged", icon: "arrow.triangle.merge", color: Theme.lime)
        case "live": return StageLook(label: "Live", icon: "checkmark.seal.fill", color: Theme.lime)
        case "done": return StageLook(label: "Done", icon: "checkmark.circle.fill", color: Theme.lime)
        case "nochange": return StageLook(label: "No change", icon: "minus.circle", color: Theme.muted)
        case "failed": return StageLook(label: "Failed", icon: "xmark.octagon.fill", color: Theme.red)
        case "stopped": return StageLook(label: "Stopped", icon: "stop.circle", color: Theme.muted)
        case "closed": return StageLook(label: "PR closed", icon: "xmark.circle", color: Theme.muted)
        default: return StageLook(label: stage.capitalized, icon: "circle.dotted", color: Theme.muted)
        }
    }

    /// Where a code run is on its way from code to main: how many of the five steps are behind it, and whether the
    /// next one is under way. Nil for what left the way (failed, stopped) and for a job.
    static func step(_ stage: String) -> (done: Int, active: Bool)? {
        switch stage {
        case "queued", "preparing", "coding", "resuming", "asks", "questions", "outline", "hold": return (0, true)
        case "testing": return (1, true)
        case "publishing": return (2, true)
        case "branch": return (2, false)
        case "pr", "draft", "conflicts": return (2, true)
        case "dev": return (3, true)
        case "merged": return (4, false)
        case "live": return (5, false)
        default: return nil
        }
    }

    /// The four steps while the agent works, for the dots on a row: 0 queued … 3 opening the pull request.
    static func working(_ stage: String) -> Int {
        switch stage {
        case "preparing": return 1
        case "coding", "resuming": return 2
        case "testing": return 3
        case "publishing": return 4
        default: return 0
        }
    }
}

/// A kind of change, as an icon.
enum KindLook {
    static func icon(_ kind: String) -> String {
        switch kind {
        case "bug", "fix": return "ladybug.fill"
        case "feature": return "sparkles"
        case "chore", "other", "dependencies": return "wrench.and.screwdriver.fill"
        case "job": return "wand.and.stars"
        default: return "circle"
        }
    }

    static func name(_ kind: String) -> String {
        switch kind {
        case "bug": return "Bug"
        case "feature": return "Feature"
        case "chore": return "Chore"
        case "job": return "Job"
        default: return kind.capitalized
        }
    }

    static func color(_ kind: String) -> Color {
        switch kind {
        case "bug", "fix": return Theme.red
        case "feature": return Theme.violet
        case "chore", "other", "dependencies": return Theme.amber
        default: return Theme.cyan
        }
    }
}

/// How a card that waits shows: its kind as a word and an icon.
enum CardLook {
    static func icon(_ card: AttentionCard) -> String {
        if card.deskOnly { return "desktopcomputer" }
        switch card.kind {
        case "permission": return "lock.fill"
        case "question": return "text.bubble.fill"
        case "outline": return "list.bullet"
        case "restart": return "clock.arrow.circlepath"
        case "signedOut": return "key.fill"
        default: return "wand.and.stars"
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
}

/// Short words for when: "now", "4m", "3h", "2d".
enum Ago {
    static func short(_ since: Double?, now: Date = Date()) -> String? {
        guard let since else { return nil }
        let seconds = max(0, now.timeIntervalSince1970 - since)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}

extension BoardRun {
    /// The repo's own name, without its owner.
    var repoName: String? { repo.map { $0.split(separator: "/").last.map(String.init) ?? $0 } }

    /// Its pull request on GitHub.
    var pullRequestLink: URL? {
        guard let repo, let pr else { return nil }
        return URL(string: "https://github.com/\(repo)/pull/\(pr)")
    }

    /// 0 … 4: where the thinking level sits among the five.
    var effortLevel: Int { ["low", "medium", "high", "xhigh", "max"].firstIndex(of: effort) ?? 1 }

    func allows(_ act: String) -> Bool { can.contains(act) }

    /// It would, but that is switched off in MailPilot.
    func isOff(_ act: String) -> Bool { off?.contains(act) ?? false }
}

extension BoardRepo {
    var repoName: String { repo.split(separator: "/").last.map(String.init) ?? repo }
}
