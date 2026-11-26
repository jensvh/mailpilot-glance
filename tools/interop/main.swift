import Foundation

// Opens messages that MailPilot's own code sealed (vectors.json, made with a
// made-up key) and reads them the way the app does. If this passes, the phone
// and MailPilot derive the same keys and agree on every field name. The build
// compiles it together with Sources/Link/Envelope.swift and Protocol.swift and
// runs it on the Mac that builds the app.

var failures = 0

func check(_ ok: Bool, _ what: String) {
    if ok {
        print("ok    \(what)")
    } else {
        failures += 1
        print("FAIL  \(what)")
    }
}

func object(_ json: String) -> NSDictionary? {
    (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? NSDictionary
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "tools/interop/vectors.json"
guard let file = FileManager.default.contents(atPath: path),
      let root = (try? JSONSerialization.jsonObject(with: file)) as? [String: Any],
      let device = root["device"] as? String,
      let key = (root["key"] as? String).flatMap({ Data(base64Encoded: $0) }),
      let items = root["items"] as? [[String: Any]],
      let envelope = LensEnvelope(device: device, key: key) else {
    print("FAIL  could not read \(path)")
    exit(1)
}

// The phone's own messages, as this app writes them: they must mean the same as MailPilot's, in the file's order.
let mine: [String: [LensUp]] = [
    "hello": [.hello(device: "abc123", app: "0.1.0 (1)", language: "nl")],
    "ping": [.ping(7)],
    "pair": [.pair(name: "iPhone", app: "0.1.0 (1)")],
    "attention-act": [.act(id: "ask:req-1", option: "allow", words: nil, version: "a1b2c3d4"),
                      .act(id: "q:6f1c2d8e-0000-4000-8000-000000000002:1:0", option: nil, words: "week numbers", version: "e5f6a7b8")],
    "attention-later": [.later(id: "ask:req-1")],
    "attention-seen": [.seen(id: "ask:req-1")],
    "watch": [.watching(true), .watching(false)],
]
var configs: [LensConfig] = []
var used: [String: Int] = [:]
var kinds = Set<String>()
var attentions: [Attention] = []
var dones: [AttentionDone] = []

for item in items {
    guard let way = item["direction"] as? String, let direction = LensDirection(rawValue: way),
          let plain = item["plain"] as? String, let sealedText = item["sealedText"] as? String else {
        check(false, "an item in the file is incomplete")
        continue
    }
    let kind = (object(plain)?["t"] as? String) ?? "?"
    kinds.insert("\(way) \(kind)")

    // 1. It opens with this app's keys, and says what MailPilot wrote.
    let opened = envelope.open(direction, json: sealedText)
    check(opened?.message == plain, "\(way) \(kind): opens")

    // 2. It doesn't open as a message for the other way, or for another device.
    let other: LensDirection = direction == .up ? .down : .up
    check(envelope.open(other, json: sealedText) == nil, "\(way) \(kind): does not open the other way round")
    check(LensEnvelope(device: "someone-else", key: key)?.open(direction, json: sealedText) == nil, "\(way) \(kind): does not open for another device")

    if direction == .down {
        // 3. The app reads it.
        switch LensDown.read(plain) {
        case .attention(let attention)?:
            attentions.append(attention)
        case .done(let done)?:
            dones.append(done)
        case .pong(let n)?:
            check(n == 9, "down pong: its number")
        case .paired(let paired)?:
            check(paired.device == "abc123" && Data(base64Encoded: paired.key) == key && paired.host == "PC", "down paired: device, key, host")
            check(paired.relay == "wss://relay.example/client/hubs/mailpilot?access_token=x" && paired.speechUrl == "https://stt.example" && paired.speechKey == "made-up-speech-key", "down paired: addresses")
        case .config(let config)?:
            configs.append(config)
            check(config.relay == "wss://relay.example/client/hubs/mailpilot?access_token=y" && config.speechUrl == "https://stt.example" && config.speechKey == "made-up-speech-key", "down config: addresses")
        case nil:
            check(false, "down \(kind): the app can't read it")
        }
    } else {
        // 4. What this app would send for the same thing means the same, and survives its own seal.
        let index = used[kind, default: 0]
        used[kind] = index + 1
        guard let list = mine[kind], index < list.count else {
            check(false, "up \(kind): this check has no message of that kind")
            continue
        }
        let text = list[index].json()
        check(object(text) == object(plain), "up \(kind): the app writes the same message")
        check(text.hasPrefix("{\"t\":\"\(kind)\""), "up \(kind): its kind comes first")
        let again = envelope.seal(.up, text, at: 1_795_000_000_100).flatMap { envelope.open(.up, $0) }
        check(again?.message == text && again?.at == 1_795_000_000_100, "up \(kind): sealed and opened again")
    }
}

// What the agents wait on, field by field.
check(attentions.count == 2, "down attention: both read")
if let full = attentions.first {
    check(full.version == "0123456789ab" && !full.atDesk && full.inMeeting && full.waiting == 3, "down attention: its own fields")
    check(full.counts == AttentionCounts(running: 1, review: 2, failed: 0), "down attention: counts")
    check(full.cards.count == 2, "down attention: two cards")
    if full.cards.count == 2 {
        let ask = full.cards[0]
        check(ask.id == "ask:req-1" && ask.version == "a1b2c3d4" && ask.kind == "permission" && ask.isPermission, "card: id, version, kind")
        check(ask.run == "6f1c2d8e-0000-4000-8000-000000000001", "card: run")
        check(ask.headline == "List outdated packages?" && ask.line == "Atlas import fix · 4:12", "card: headline, line")
        check(ask.speak.hasPrefix("The agent wants to run dotnet list"), "card: speak")
        check(ask.options.map(\.key) == ["allow", "no"] && ask.options[0].primary && !ask.options[1].primary, "card: options, the first recommended")
        check(ask.options[0].label == "Allow once" && ask.options[0].words == ["allow", "yes", "ja"], "card: an option's label and words")
        check(!ask.takesWords && !ask.deskOnly && ask.step == nil && ask.steps == nil, "card: words, desk, steps")
        check(ask.until.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) } == 1_795_000_300_000, "card: until")
        check(Int64((ask.since.timeIntervalSince1970 * 1000).rounded()) == 1_794_999_960_000, "card: since")
        let question = full.cards[1]
        check(question.kind == "question" && question.takesWords && question.step == 1 && question.steps == 2 && question.until == nil, "question card: words, steps, no clock")
        // A time with fractions of a second reads too.
        check(Int64((question.since.timeIntervalSince1970 * 1000).rounded()) == 1_794_999_000_123, "question card: since, with milliseconds")
    }
}
if attentions.count == 2 {
    let empty = attentions[1]
    check(empty.atDesk && empty.cards.isEmpty && empty.waiting == 0, "down attention: an empty one")
}
check(dones == [AttentionDone(id: "ask:req-1", text: "Allowed once", ok: true),
                AttentionDone(id: "ask:req-1", text: "The agent isn't waiting on this any more.", ok: false)], "down attention-done: both read")

// The notifications' address: missing while they are off in MailPilot, there when they are on.
check(configs.count == 2, "down config: both read")
if configs.count == 2 {
    check(configs[0].notifyServer == nil && configs[0].notifyTopic == nil, "down config: no notifications")
    check(configs[1].notifyServer == "https://ntfy.sh" && configs[1].notifyTopic == "glance-test-topic-0123456789", "down config: the notifications' server and topic")
}

for expected in ["down attention", "down attention-done", "down pong", "down paired", "down config",
                 "up hello", "up ping", "up pair", "up attention-act", "up attention-later", "up attention-seen", "up watch"] {
    check(kinds.contains(expected), "the file holds a \(expected)")
}

// The old walk's messages are not read: this app takes no walk.
check(LensDown.read("{\"t\":\"state\",\"state\":{\"rev\":1,\"sid\":\"s\"},\"v\":1}") == nil, "a walk's state is not read")

// A message that was changed on the way doesn't open.
if let first = items.first?["sealedText"] as? String, var sealed = (try? JSONSerialization.jsonObject(with: Data(first.utf8))) as? [String: Any] {
    sealed["n"] = NSNumber(value: 1_795_000_000_999 as Int64)
    check(envelope.open(.down, sealed) == nil, "a changed time doesn't open")
}

// The clock: newer than the last one, and close to now.
var time: Int64 = 1_000_000
let clock = LensClock(now: { time })
check(clock.next() == 1_000_000 && clock.next() == 1_000_001, "the clock never gives the same time twice")
check(clock.accept(1_000_010) && !clock.accept(1_000_010) && !clock.accept(1_000_005), "a message is taken once, and not an older one after it")
check(!clock.accept(1_000_000 + LensClock.windowMs + 1), "a message from too far ahead is refused")
time += 10 * 60 * 1000
check(!clock.accept(1_000_020), "a message from long ago is refused")

// The pairing code: Glance's own, and an older one from before Glance.
let relay = "wss://relay.example/client/hubs/mailpilot?access_token=abc"
func base64Url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
let invite = LensInvite.parse("mailpilotglance://pair?p=p1a2b3&s=\(base64Url(key))&r=\(base64Url(Data(relay.utf8)))")
check(invite?.pairing == "p1a2b3" && invite?.secret == key && invite?.relay.absoluteString == relay, "the pairing code is read")
check(LensInvite.parse("mailpilotlens://pair?p=p1a2b3&s=\(base64Url(key))&r=\(base64Url(Data(relay.utf8)))") != nil, "an older pairing code is read")
check(LensInvite.parse("mailpilotglance://pair?p=p1&s=AAAA&r=\(base64Url(Data(relay.utf8)))") == nil, "a pairing code with a short secret is refused")
check(LensInvite.parse("https://example.com/pair?p=1") == nil, "another link is not a pairing code")

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
