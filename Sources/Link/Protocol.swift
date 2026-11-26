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
    /// What this app says it can in its hello: the agents' cards, and no walk.
    static let can = ["attention"]
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

enum LensDown: Equatable {
    case attention(Attention)
    case done(AttentionDone)
    case pong(Int)
    case paired(LensPaired)
    case config(LensConfig)

    private struct Head: Decodable {
        var t: String
        var v: Int?
    }

    private struct AttentionBody: Decodable { var attention: Attention }
    private struct PongBody: Decodable { var n: Int }

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
    /// notification. It counts only while the phone is heard from.
    case watching(Bool)

    var kind: String {
        switch self {
        case .hello: return "hello"
        case .ping: return "ping"
        case .pair: return "pair"
        case .act: return "attention-act"
        case .later: return "attention-later"
        case .seen: return "attention-seen"
        case .watching: return "watch"
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
        case .watching(let on):
            out["on"] = on
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
