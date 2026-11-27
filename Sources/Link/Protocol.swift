import Foundation

// What MailPilot and this app say to each other: version 1 of MailPilot's link,
// the part about what the agents wait on. MailPilot owns all of it: after every
// change it sends the whole list, and this app only draws it and sends back what
// you answered.
//
// Only Foundation here: the build also compiles this file into a small check
// that opens messages sealed by MailPilot's own code (tools/interop).

enum LensWire {
    static let version = 1
    /// What this app says it can in its hello: the agents' cards and the board of runs, and no walk.
    static let can = ["attention", "board"]
}

// MARK: - MailPilot -> phone

/// What the agents wait on, for this phone now. Sent whole after the hello and after every change.
struct Attention: Decodable, Equatable {
    var version: String
    /// You're at the desk: the desk has it, so only an escalated permission question is here.
    var atDesk: Bool
    /// An Outlook meeting is on: only permission questions are here.
    var inMeeting: Bool
    /// What else waits on you, not shown here.
    var waiting: Int
    var counts: AttentionCounts
    /// Most urgent first. The first is the one on show.
    var cards: [AttentionCard]
}

struct AttentionCounts: Decodable, Equatable {
    var running: Int
    var review: Int
    var failed: Int
}

/// One thing an agent can't go on without, worded by MailPilot for a glance.
struct AttentionCard: Decodable, Equatable, Identifiable {
    var id: String
    /// Sent back with an answer: an answer to a card that changed since is refused.
    var version: String
    /// "permission", "question", "outline", "restart" or "signedOut". Kept as a string, so a new kind still draws.
    var kind: String
    var run: String?
    /// At most 40 characters.
    var headline: String
    /// At most 60 characters.
    var line: String
    /// One or two sentences, for when the lens isn't looked at.
    var speak: String
    /// At most three; the first is the recommended one, the one a pinch takes.
    var options: [AttentionOption]
    /// Own words are taken too: shown back with Send before they go.
    var takesWords: Bool
    /// When a live permission question goes on hold.
    var until: Date?
    var step: Int?
    var steps: Int?
    /// Shown, but only the desk can say yes.
    var deskOnly: Bool
    var since: Date

    var isPermission: Bool { kind == "permission" }
}

struct AttentionOption: Decodable, Equatable {
    var key: String
    var label: String
    var primary: Bool
    /// What may be said for it ("allow", "yes", "ja").
    var words: [String]
}

/// What came of an answer: "Allowed once", or why it was refused.
struct AttentionDone: Decodable, Equatable {
    var id: String
    var text: String
    var ok: Bool
}

/// A piece of speech, with its language when it is known ("en", "nl").
struct LensSay: Decodable, Equatable {
    var text: String
    var lang: String?
}

struct LensPaired: Decodable, Equatable {
    var device: String
    var key: String
    var relay: String
    var speechUrl: String?
    var speechKey: String?
    var host: String?
}

struct LensConfig: Decodable, Equatable {
    var relay: String?
    var speechUrl: String?
    var speechKey: String?
    /// The ntfy server the phone's notifications come through, and the topic to subscribe to in the ntfy app. Both
    /// missing while MailPilot's notifications are off or not set up.
    var notifyServer: String?
    var notifyTopic: String?
}

// MARK: - The board of runs

/// Every run worth a look, as MailPilot decided it: which lane it sits in, what it is at, its git facts and what can
/// be done to it now. Sent whole while this app is on the screen; the app draws it and holds no rules of its own.
struct RunBoard: Decodable, Equatable {
    var version: String
    /// What can be asked of the board itself: "new" when runs may be started from the phone.
    var acts: [String]
    /// In the order to show them: by lane, most pressing first.
    var runs: [BoardRun]
    /// Repos whose dev holds merged work that isn't on main yet: one release brings it all.
    var repos: [BoardRepo]
    /// Everything that waits on you, also what MailPilot would keep at the desk: the board is something you open.
    var waiting: [AttentionCard]
}

struct BoardRun: Decodable, Equatable, Identifiable {
    var id: String
    /// Sent back with an action: one on a run that changed since it was drawn is refused.
    var version: String
    var title: String
    /// "bug", "feature", "chore" or "job".
    var kind: String
    var project: String?
    var hue: Int
    var emoji: String?
    /// "owner/name"; none for a job.
    var repo: String?
    /// "you", "working", "review", "dev", "done" or "stopped". Kept as a string, so a new one still draws.
    var lane: String
    /// One word for what it is at ("coding", "pr", "conflicts", …): an icon and a colour here.
    var stage: String
    var branch: String?
    var base: String?
    var commits: Int?
    var files: Int?
    var plus: Int?
    var minus: Int?
    /// Its pull request's number.
    var pr: Int?
    var tests: Bool?
    var model: String
    var effort: String
    var rounds: Int
    /// When it came to where it is now, in seconds since 1970.
    var since: Double?
    var note: String?
    /// An action asked from a phone is under way: "merging".
    var busy: String?
    /// What can be done to it now: "prompt", "publish", "merge", "resolve", "stop", "retry".
    var can: [String]
    /// What it would allow, but is switched off in MailPilot.
    var off: [String]?
}

struct BoardRepo: Decodable, Equatable, Identifiable {
    var repo: String
    var project: String?
    var hue: Int
    var emoji: String?
    var from: String
    var to: String
    var count: Int
    /// A release can be asked from here; false when that is switched off in MailPilot.
    var can: Bool
    var busy: String?

    var id: String { repo + ">" + to }
}

/// What a prompt can choose from: the projects with a repo, the models that can run, the thinking levels.
struct BoardChoices: Decodable, Equatable {
    var version: String
    var projects: [BoardProject]
    var models: [BoardModel]
    var efforts: [String]
}

struct BoardProject: Decodable, Equatable, Identifiable {
    var id: String
    var name: String
    var emoji: String?
    var hue: Int
    var repos: [BoardProjectRepo]
}

struct BoardProjectRepo: Decodable, Equatable {
    var repo: String
    var base: String?
}

struct BoardModel: Decodable, Equatable, Identifiable {
    var key: String
    var label: String
    /// 1 lightest … 4 strongest.
    var tier: Int
    var hue: Int
    /// It takes a thinking level.
    var thinking: Bool
    /// The connection it runs on; none for the Claude account's own.
    var source: String?

    var id: String { key }
}

/// What came of something asked of a run: "Merged into dev", or why it was refused.
struct RunDone: Decodable, Equatable {
    /// The id this app gave its ask.
    var id: String
    var ok: Bool
    var text: String
    var run: String?
    /// What a release would bring, in answer to "plan".
    var plan: ReleasePlan?
}

/// What a release of a repo would bring to main right now: the facts to confirm before it is asked for.
struct ReleasePlan: Decodable, Equatable {
    var repo: String
    var from: String
    var to: String
    /// How many commits dev holds that main doesn't.
    var ahead: Int
    var subject: String
    var changes: [PlanChange]
    /// Changes beyond the ones listed.
    var more: Int
    /// Sent back with the release: it is refused when dev moved since.
    var version: String
}

struct PlanChange: Decodable, Equatable {
    var title: String
    var n: Int?
    /// "feature", "fix", "dependencies" or "other".
    var kind: String
}

enum LensDown: Equatable {
    case attention(Attention)
    case done(AttentionDone)
    case pong(Int)
    case paired(LensPaired)
    case config(LensConfig)
    case board(RunBoard)
    case choices(BoardChoices)
    case runDone(RunDone)

    private struct Head: Decodable {
        var t: String
        var v: Int?
    }

    private struct AttentionBody: Decodable { var attention: Attention }
    private struct PongBody: Decodable { var n: Int }
    private struct BoardBody: Decodable { var board: RunBoard }
    private struct ChoicesBody: Decodable { var choices: BoardChoices }

    /// MailPilot writes times as ISO 8601, with or without fractions of a second.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { from in
            let text = try from.singleValueContainer().decode(String.self)
            if let date = Self.dates.date(from: text) ?? Self.wholeSeconds.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: from.codingPath, debugDescription: "Not a time: \(text)"))
        }
        return decoder
    }()

    private static let dates: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let wholeSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// A message from MailPilot; nil when it isn't one this app knows (the old walk's messages included).
    static func read(_ json: String) -> LensDown? {
        let data = Data(json.utf8)
        guard let head = try? decoder.decode(Head.self, from: data), (head.v ?? LensWire.version) == LensWire.version else { return nil }
        switch head.t {
        case "attention": return (try? decoder.decode(AttentionBody.self, from: data)).map { .attention($0.attention) }
        case "attention-done": return (try? decoder.decode(AttentionDone.self, from: data)).map { .done($0) }
        case "pong": return (try? decoder.decode(PongBody.self, from: data)).map { .pong($0.n) }
        case "paired": return (try? decoder.decode(LensPaired.self, from: data)).map { .paired($0) }
        case "config": return (try? decoder.decode(LensConfig.self, from: data)).map { .config($0) }
        case "board": return (try? decoder.decode(BoardBody.self, from: data)).map { .board($0.board) }
        case "choices": return (try? decoder.decode(ChoicesBody.self, from: data)).map { .choices($0.choices) }
        case "run-done": return (try? decoder.decode(RunDone.self, from: data)).map { .runDone($0) }
        default: return nil
        }
    }
}

// MARK: - phone -> MailPilot

enum LensUp {
    /// The phone connected (again). It says what it can: the agents' cards, no walk.
    case hello(device: String, app: String?, language: String?)
    case ping(Int)
    /// Asks to be paired; sealed with the pairing code's secret.
    case pair(name: String, app: String?)
    /// A pinch on an option (`option` is its key), or own words where the card takes them.
    case act(id: String, option: String?, words: String?, version: String)
    /// "Later": off the glasses until the card changes. Answers nothing.
    case later(id: String)
    /// The card was on the lens.
    case seen(id: String)
    /// Whether this phone shows what waits right now (on duty, or the app in front): while it does, MailPilot sends no
    /// notification. It counts only while the phone is heard from. `board` says the app is on the screen, so the board
    /// of runs is drawn: only then does MailPilot send it, and `boardV` and `choicesV` say which ones the app holds,
    /// so what it has isn't sent again.
    case watching(Bool, board: Bool? = nil, boardV: String? = nil, choicesV: String? = nil)
    /// Something asked of a run, a repo or the board: `action` is "new", "prompt", "publish", "merge", "resolve",
    /// "retry", "stop", "plan" or "release". `id` is this app's own; the answer comes back under it.
    case runAct(id: String, action: String, run: String? = nil, repo: String? = nil, version: String? = nil,
                words: String? = nil, model: String? = nil, effort: String? = nil, project: String? = nil, kind: String? = nil)

    var kind: String {
        switch self {
        case .hello: return "hello"
        case .ping: return "ping"
        case .pair: return "pair"
        case .act: return "attention-act"
        case .later: return "attention-later"
        case .seen: return "attention-seen"
        case .watching: return "watch"
        case .runAct: return "run-act"
        }
    }

    private var fields: [String: Any] {
        var out: [String: Any] = ["v": LensWire.version]
        switch self {
        case .hello(let device, let app, let language):
            out["device"] = device
            if let app { out["app"] = app }
            if let language { out["language"] = language }
            // MailPilot writes this field always; the walk's "fresh" means nothing without a walk.
            out["fresh"] = false
            out["can"] = LensWire.can
        case .ping(let n):
            out["n"] = n
        case .pair(let name, let app):
            out["name"] = name
            if let app { out["app"] = app }
        case .act(let id, let option, let words, let version):
            out["id"] = id
            if let option { out["option"] = option }
            if let words { out["words"] = words }
            out["version"] = version
        case .later(let id), .seen(let id):
            out["id"] = id
        case .watching(let on, let board, let boardV, let choicesV):
            out["on"] = on
            if let board { out["board"] = board }
            if let boardV { out["boardV"] = boardV }
            if let choicesV { out["choicesV"] = choicesV }
        case .runAct(let id, let action, let run, let repo, let version, let words, let model, let effort, let project, let kind):
            out["id"] = id
            out["action"] = action
            if let run { out["run"] = run }
            if let repo { out["repo"] = repo }
            if let version { out["version"] = version }
            if let words { out["words"] = words }
            if let model { out["model"] = model }
            if let effort { out["effort"] = effort }
            if let project { out["project"] = project }
            if let kind { out["kind"] = kind }
        }
        return out
    }

    /// The message as JSON, its kind ("t") first.
    func json() -> String {
        let body = (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? Data("{}".utf8)
        let text = String(data: body, encoding: .utf8) ?? "{}"
        return "{\"t\":\"\(kind)\"," + text.dropFirst()
    }
}

// MARK: - The pairing code

/// What a pairing code holds: mailpilotglance://pair?p=<pairing>&s=<secret>&r=<relay address>.
struct LensInvite: Equatable {
    static let scheme = "mailpilotglance"

    var pairing: String
    var secret: Data
    var relay: URL

    static func parse(_ link: String) -> LensInvite? {
        // A code from before Glance (mailpilotlens://) holds the same.
        guard let parts = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == scheme || parts.scheme == "mailpilotlens", parts.host == "pair" else { return nil }
        var values: [String: String] = [:]
        for item in parts.queryItems ?? [] { values[item.name] = item.value ?? "" }
        guard let pairing = values["p"], !pairing.isEmpty,
              let secret = values["s"].flatMap(Base64Url.decode), secret.count == LensEnvelope.keyBytes,
              let address = values["r"].flatMap(Base64Url.decode).flatMap({ String(data: $0, encoding: .utf8) }),
              let relay = URL(string: address), relay.scheme == "wss" || relay.scheme == "ws" else { return nil }
        return LensInvite(pairing: pairing, secret: secret, relay: relay)
    }
}

enum Base64Url {
    static func decode(_ text: String) -> Data? {
        var s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }
}

enum LensGroups {
    static func up(_ device: String) -> String { "up-" + device }
    static func down(_ device: String) -> String { "down-" + device }
    static func pairUp(_ pairing: String) -> String { "pair-up-" + pairing }
    static func pairDown(_ pairing: String) -> String { "pair-down-" + pairing }
}
