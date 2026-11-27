import SwiftUI

/// Made-up runs, projects and answers, so every screen can be drawn on the build machine without a phone, a pairing
/// or MailPilot: the screenshots it takes are how this app is looked at before it is installed. None of it is real.
@MainActor
enum DemoData {
    static let screens = ["board", "recent", "run", "card", "release", "compose", "followup", "duty", "pair", "empty", "settings", "legacy"]

    private static let askingRun = "6f1c2d8e-0000-4000-8000-000000000001"
    private static let questionRun = "6f1c2d8e-0000-4000-8000-000000000002"
    private static let openRun = "6f1c2d8e-0000-4000-8000-000000000005"
    private static let atlas = "7a000000-0000-4000-8000-000000000001"

    // MARK: The screen to draw

    static func fill(_ shell: Shell, _ store: BoardStore, for screen: String) {
        shell.version = "0.3.0 (3)"
        shell.host = "STUDIO-PC"
        shell.deviceShort = "a1b2c3d4"
        shell.pingMs = 182
        shell.link = .online
        shell.notifyTopic = "glance-demo-topic-0123456789"
        shell.glassesRegistered = true
        shell.glassesInfo = "Ray-Ban Display · connected"
        shell.speechHost = "stt.example"

        switch screen {
        case "pair":
            shell.link = .unpaired
            shell.host = nil
            shell.deviceShort = nil
            shell.notifyTopic = nil
        case "empty":
            store.take(RunBoard(version: "e", acts: ["new"], runs: [], repos: [], waiting: []))
            store.take(choices)
        case "legacy":
            store.take(Attention(version: "l", atDesk: false, inMeeting: false, waiting: 0,
                                 counts: AttentionCounts(running: 1, review: 2, failed: 0), cards: [permission, question]))
        case "recent":
            // Only what works and what ended: so the folded-away part is on the first screen.
            let all = board
            store.take(RunBoard(version: "recent", acts: all.acts,
                                runs: all.runs.filter { $0.lane == "working" || $0.lane == "done" || $0.lane == "stopped" },
                                repos: [all.repos[1]], waiting: []))
            store.take(choices)
        case "duty":
            shell.duty = .on
            shell.glasses = .worn
            shell.lens = "Permission"
            shell.voice = "listening"
            shell.heard = "use week numbers"
            store.take(board)
            store.take(choices)
        default:
            store.take(board)
            store.take(choices)
        }
    }

    static func view(for screen: String) -> BoardView {
        switch screen {
        case "recent": return BoardView(recentOpen: true)
        case "run": return BoardView(opening: .run(openRun))
        case "card": return BoardView(opening: .run(questionRun))
        case "release": return BoardView(opening: .release("acme/atlas>main"), plan: plan)
        case "compose":
            return BoardView(opening: .compose(nil), draft: ComposeSheet.Draft(
                words: "Add a filter by supplier on the orders page, next to the date filter.", kind: "feature", model: "sonnet", effort: 2))
        case "followup":
            return BoardView(opening: .compose(openRun), draft: ComposeSheet.Draft(words: "Make the three buttons a little larger on small screens."))
        case "settings": return BoardView(opening: .settings)
        default: return BoardView()
        }
    }

    // MARK: What waits

    static var permission: AttentionCard {
        AttentionCard(
            id: "ask:req-1", version: "a1b2c3d4", kind: "permission", run: askingRun,
            headline: "Run the tests?", line: "Atlas import fix · 4:12",
            speak: "The agent wants to run dotnet test, to check its fix, for the Atlas import fix.",
            options: [AttentionOption(key: "allow", label: "Allow once", primary: true, words: ["allow", "yes"]),
                      AttentionOption(key: "no", label: "No", primary: false, words: ["no"])],
            takesWords: false, until: Date().addingTimeInterval(252), step: nil, steps: nil, deskOnly: false, since: Date().addingTimeInterval(-48))
    }

    static var question: AttentionCard {
        AttentionCard(
            id: "q:\(questionRun):1:0", version: "e5f6a7b8", kind: "question", run: questionRun,
            headline: "Which date format?", line: "Question 1 of 2 · Export to Excel",
            speak: "The agent asks, for Export to Excel: which date format should the export use? It suggests ISO 8601.",
            options: [AttentionOption(key: "1", label: "ISO 8601", primary: true, words: ["iso 8601", "1"]),
                      AttentionOption(key: "2", label: "dd/MM/yyyy", primary: false, words: ["2"]),
                      AttentionOption(key: "decide", label: "Let it decide", primary: false, words: ["let it decide"])],
            takesWords: true, until: nil, step: 1, steps: 2, deskOnly: false, since: Date().addingTimeInterval(-600))
    }

    // MARK: The board

    static var board: RunBoard {
        RunBoard(
            version: "demo0000demo", acts: ["new"],
            runs: [
                run(askingRun, "Atlas import fix", "bug", "Atlas", 20, "🧪", "acme/atlas", "you", "asks",
                    branch: "fix/atlas-import", model: "Opus", effort: "high", ago: 48, can: ["stop"]),
                run(questionRun, "Export to Excel", "feature", "Borealis", 150, "🌿", "acme/borealis", "you", "questions",
                    branch: "feat/export-excel", model: "Sonnet", effort: "medium", ago: 600, can: ["prompt"]),
                run("6f1c2d8e-0000-4000-8000-000000000003", "Batch import speed-up", "feature", "Atlas", 20, "🧪", "acme/atlas", "working", "coding",
                    branch: "feat/batch-import", model: "Opus", effort: "xhigh", ago: 372, can: ["stop"]),
                run("6f1c2d8e-0000-4000-8000-000000000004", "Rename the lab fields", "chore", "Borealis", 150, "🌿", "acme/borealis", "working", "queued",
                    branch: "chore/rename-lab-fields", model: "Haiku", effort: "low", ago: 95, can: ["stop"]),
                run(openRun, "Simplify the home page", "feature", "Atlas", 20, "🧪", "acme/atlas", "review", "pr",
                    branch: "feat/simplify-home", commits: 3, files: 8, plus: 120, minus: 30, pr: 55, tests: true,
                    model: "Sonnet", effort: "high", rounds: 2, ago: 5400,
                    note: "Home shows three quick actions instead of seven.", can: ["prompt", "merge"]),
                run("6f1c2d8e-0000-4000-8000-000000000006", "Dark mode for the charts", "feature", "Borealis", 150, "🌿", "acme/borealis", "review", "conflicts",
                    branch: "feat/dark-charts", commits: 5, files: 12, plus: 340, minus: 88, pr: 57,
                    model: "Opus", effort: "high", ago: 9200, can: ["prompt", "resolve"]),
                run("6f1c2d8e-0000-4000-8000-000000000007", "Supplier filter on orders", "feature", "Cinder", 265, nil, "acme/cinder", "review", "draft",
                    branch: "feat/supplier-filter", commits: 2, files: 4, plus: 96, minus: 4, pr: 12, tests: false,
                    model: "Sonnet", effort: "medium", ago: 86_400, can: ["prompt"], off: ["merge"]),
                run("6f1c2d8e-0000-4000-8000-000000000008", "The login timeout", "bug", "Atlas", 20, "🧪", "acme/atlas", "dev", "dev",
                    branch: "fix/login-timeout", commits: 1, files: 2, plus: 14, minus: 6, pr: 52, tests: true,
                    model: "Sonnet", effort: "medium", ago: 20_000),
                run("6f1c2d8e-0000-4000-8000-000000000009", "Quick actions on the home page", "feature", "Atlas", 20, "🧪", "acme/atlas", "dev", "dev",
                    branch: "feat/quick-actions", commits: 4, files: 9, plus: 210, minus: 41, pr: 50, tests: true,
                    model: "Opus", effort: "high", ago: 90_000),
                run("6f1c2d8e-0000-4000-8000-00000000000a", "Week numbers in the planner", "feature", "Borealis", 150, "🌿", "acme/borealis", "done", "live",
                    branch: "feat/week-numbers", commits: 2, files: 5, plus: 64, minus: 12, pr: 49, tests: true,
                    model: "Sonnet", effort: "medium", ago: 30_000),
                run("6f1c2d8e-0000-4000-8000-00000000000b", "Faster search on substances", "feature", "Atlas", 20, "🧪", "acme/atlas", "done", "live",
                    branch: "feat/faster-search", commits: 6, files: 14, plus: 410, minus: 120, pr: 47, tests: true,
                    model: "Opus", effort: "xhigh", ago: 200_000),
                run("6f1c2d8e-0000-4000-8000-00000000000c", "Nightly export", "chore", "Cinder", 265, nil, "acme/cinder", "stopped", "failed",
                    branch: "chore/nightly-export", model: "Haiku", effort: "low", ago: 40_000,
                    note: "The clone failed: repository not found.", can: ["retry"]),
            ],
            repos: [
                BoardRepo(repo: "acme/atlas", project: "Atlas", hue: 20, emoji: "🧪", from: "dev", to: "main", count: 2, can: true, busy: nil),
                BoardRepo(repo: "acme/borealis", project: "Borealis", hue: 150, emoji: "🌿", from: "dev", to: "main", count: 1, can: false, busy: nil),
            ],
            waiting: [permission, question])
    }

    static var choices: BoardChoices {
        BoardChoices(
            version: "demo0001",
            projects: [
                BoardProject(id: atlas, name: "Atlas", emoji: "🧪", hue: 20,
                             repos: [BoardProjectRepo(repo: "acme/atlas", base: "dev"), BoardProjectRepo(repo: "acme/atlas-tools", base: nil)]),
                BoardProject(id: "7a000000-0000-4000-8000-000000000002", name: "Borealis", emoji: "🌿", hue: 150, repos: [BoardProjectRepo(repo: "acme/borealis", base: "dev")]),
                BoardProject(id: "7a000000-0000-4000-8000-000000000003", name: "Cinder", emoji: nil, hue: 265, repos: [BoardProjectRepo(repo: "acme/cinder", base: nil)]),
            ],
            models: [
                BoardModel(key: "haiku", label: "Haiku", tier: 1, hue: 160, thinking: true, source: nil),
                BoardModel(key: "sonnet", label: "Sonnet", tier: 2, hue: 200, thinking: true, source: nil),
                BoardModel(key: "opus", label: "Opus", tier: 3, hue: 265, thinking: true, source: nil),
                BoardModel(key: "fable", label: "Fable", tier: 4, hue: 320, thinking: true, source: nil),
                BoardModel(key: "m:1", label: "GPT", tier: 3, hue: 120, thinking: false, source: "Azure · North"),
            ],
            efforts: ["low", "medium", "high", "xhigh", "max"])
    }

    static var plan: ReleasePlan {
        ReleasePlan(
            repo: "acme/atlas", from: "dev", to: "main", ahead: 5,
            subject: "chore(release): quick actions on the home page, the login timeout",
            changes: [
                PlanChange(title: "Quick actions on the home page", n: 50, kind: "feature"),
                PlanChange(title: "The login timeout", n: 52, kind: "fix"),
                PlanChange(title: "Bump the linter", n: nil, kind: "other"),
            ],
            more: 0, version: "9f8e7d6c")
    }

    /// One run, with everything it doesn't have left out.
    private static func run(
        _ id: String, _ title: String, _ kind: String, _ project: String, _ hue: Int, _ emoji: String?, _ repo: String,
        _ lane: String, _ stage: String, branch: String, commits: Int? = nil, files: Int? = nil, plus: Int? = nil, minus: Int? = nil,
        pr: Int? = nil, tests: Bool? = nil, model: String, effort: String, rounds: Int = 1, ago: Double,
        note: String? = nil, can: [String] = [], off: [String]? = nil
    ) -> BoardRun {
        BoardRun(
            id: id, version: String(id.suffix(8)), title: title, kind: kind, project: project, hue: hue, emoji: emoji, repo: repo,
            lane: lane, stage: stage, branch: branch, base: "dev", commits: commits, files: files, plus: plus, minus: minus,
            pr: pr, tests: tests, model: model, effort: effort, rounds: rounds, since: Date().timeIntervalSince1970 - ago,
            note: note, busy: nil, can: can, off: off)
    }
}
