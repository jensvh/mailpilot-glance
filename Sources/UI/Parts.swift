import SwiftUI

// The small pieces every screen is built from. Each one shows a state as a shape, an icon or a colour first, and
// takes plain values, so it draws the same in the app and on the build machine.

/// A thing's identity: a rounded square in its hue, holding its emoji or its first letters. With a ring in the colour
/// of what it is at; the ring turns while it works.
struct Orb: View {
    var emoji: String?
    var name: String?
    var hue: Int
    var ring: Color?
    var live = false
    var size: CGFloat = 40

    @State private var turning = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Theme.fill(hue))
            if let emoji, !emoji.isEmpty, emoji != "📁" {
                Text(emoji).font(.system(size: size * 0.46))
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.tint(hue))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if let ring {
                let shape = RoundedRectangle(cornerRadius: size * 0.3 + 3, style: .continuous)
                if live {
                    // While it works a piece of the ring travels round it; the rest of the ring is faint.
                    shape.stroke(ring.opacity(0.25), lineWidth: 2)
                        .padding(-3.5)
                    shape.stroke(ring, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [around * 0.28, around * 0.72], dashPhase: turning ? -around : 0))
                        .padding(-3.5)
                        .animation(.linear(duration: 2.2).repeatForever(autoreverses: false), value: turning)
                } else {
                    shape.stroke(ring, lineWidth: 2)
                        .padding(-3.5)
                }
            }
        }
        .onAppear { turning = true }
        .accessibilityHidden(true)
    }

    /// About how long the ring is: a square's four sides, less what its round corners cut off.
    private var around: CGFloat {
        let side = size + 7
        let corner = size * 0.3 + 3
        return 4 * side - (8 - 2 * .pi) * corner
    }

    private var initials: String {
        let words = (name ?? "").split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.count >= 2 { return String(words[0].prefix(1) + words[1].prefix(1)).uppercased() }
        return String((words.first ?? "·").prefix(2)).uppercased()
    }
}

/// A small status: an icon and a word or two, in the colour of what it says.
struct Pill: View {
    var text: String
    var icon: String?
    var color: Color
    var filled = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(filled ? Theme.bg : color)
        .background(Capsule().fill(filled ? color : color.opacity(0.16)))
    }
}

/// One of the four counts at the top: an icon and a number in its lane's colour. A tap shows only that lane.
struct CountChip: View {
    var look: LaneLook
    var count: Int
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: look.icon).font(.system(size: 13, weight: .semibold))
                Text("\(count)").font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(count > 0 ? look.color : Theme.faint)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(count > 0 ? look.color.opacity(selected ? 0.30 : 0.13) : Theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .stroke(selected ? look.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(look.name): \(count)")
    }
}

/// Progress as dots: how many of them are behind it.
struct StepDots: View {
    var total: Int
    var done: Int
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < done ? color : Theme.line)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A code run's way from code to main: five steps joined by a line, with where it is now.
struct Track: View {
    var stage: String

    private static let steps = ["code", "test", "PR", "dev", "main"]

    var body: some View {
        let at = StageLook.step(stage)
        let color = StageLook.of(stage).color
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<Self.steps.count, id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(reached(index, at) ? Theme.lime.opacity(0.7) : Theme.line)
                            .frame(height: 2)
                    }
                    dot(index, at, color)
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<Self.steps.count, id: \.self) { index in
                    Text(Self.steps[index])
                        .font(.system(size: 11, weight: isNow(index, at) ? .semibold : .regular))
                        .foregroundStyle(isNow(index, at) ? color : Theme.faint)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : index == Self.steps.count - 1 ? .trailing : .center)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StageLook.of(stage).label)
    }

    private func reached(_ index: Int, _ at: (done: Int, active: Bool)?) -> Bool {
        guard let at else { return false }
        return index <= at.done - 1 || (index == at.done && at.active)
    }

    private func isNow(_ index: Int, _ at: (done: Int, active: Bool)?) -> Bool {
        guard let at else { return false }
        return at.active ? index == at.done : index == at.done - 1 && at.done == Self.steps.count
    }

    @ViewBuilder
    private func dot(_ index: Int, _ at: (done: Int, active: Bool)?, _ color: Color) -> some View {
        if let at, index < at.done {
            Circle().fill(Theme.lime).frame(width: 10, height: 10)
        } else if let at, at.active, index == at.done {
            Circle().fill(color).frame(width: 12, height: 12)
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 4).padding(-3))
        } else {
            Circle().fill(Theme.line).frame(width: 10, height: 10)
        }
    }
}

/// The thinking level as five rising bars. With an action it is the picker; without, it only shows the level.
struct EffortBars: View {
    /// 0 … 4, or nil for none chosen.
    var level: Int?
    var color: Color = Theme.cyan
    var height: CGFloat = 16
    var pick: ((Int) -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: pick == nil ? 3 : 8) {
            ForEach(0..<5, id: \.self) { index in
                let bar = RoundedRectangle(cornerRadius: pick == nil ? 1.5 : 4, style: .continuous)
                    .fill((level.map { index <= $0 } ?? false) ? color : Theme.line)
                    .frame(height: height * (0.4 + 0.15 * CGFloat(index)))
                if let pick {
                    Button { pick(index) } label: { bar.frame(maxWidth: .infinity).contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.names[index])
                } else {
                    bar.frame(width: 4)
                }
            }
        }
        .frame(height: height, alignment: .bottom)
    }

    static let names = ["Low", "Medium", "High", "Extra high", "Max"]
    static let keys = ["low", "medium", "high", "xhigh", "max"]
}

/// A choice among a few: a word, maybe an icon, in a hue when it has one. The chosen one is outlined.
struct ChoiceChip: View {
    var text: String
    var icon: String?
    var emoji: String?
    var color: Color = Theme.accent
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji, !emoji.isEmpty { Text(emoji).font(.system(size: 13)) }
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(text).font(.system(size: 14, weight: .medium)).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? color : Theme.muted)
            .background(Capsule().fill(selected ? color.opacity(0.18) : Theme.panel))
            .overlay(Capsule().stroke(selected ? color : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A round button that is only an icon: the quick action on a row.
struct IconButton: View {
    var icon: String
    var color: Color
    var filled = false
    /// Shown, but switched off in MailPilot.
    var locked = false
    var label: String
    var size: CGFloat = 38
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: locked ? "lock.fill" : icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(locked ? Theme.faint : filled ? Theme.bg : color)
                .background(Circle().fill(locked ? Theme.panel : filled ? color : color.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(label), switched off in MailPilot" : label)
    }
}

/// A fact as a tile: a number or a mark, with one word under it.
struct FactTile: View {
    var value: Text
    var label: String

    var body: some View {
        VStack(spacing: 3) {
            value.font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.panel))
    }
}

/// A slide instead of a tap, for what can't be taken back: the knob has to travel to the end.
struct SlideToConfirm: View {
    var label: String
    var icon: String
    var color: Color
    var action: () -> Void

    @State private var offset: CGFloat = 0
    @State private var done = false

    private let knob: CGFloat = 50
    private let inset: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - knob - inset * 2)
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule().fill(color.opacity(0.22)).frame(width: offset + knob + inset * 2)
                HStack(spacing: 6) {
                    Text(label).font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right.2").font(.system(size: 12, weight: .bold)).opacity(0.6)
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.leading, knob)
                .opacity(travel > 0 ? 1 - Double(offset / travel) : 1)
                Circle()
                    .fill(color)
                    .frame(width: knob, height: knob)
                    .overlay(Image(systemName: done ? "checkmark" : icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.bg))
                    .offset(x: inset + offset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !done else { return }
                                offset = min(max(0, value.translation.width), travel)
                            }
                            .onEnded { _ in
                                guard !done else { return }
                                if travel > 0, offset >= travel * 0.9 {
                                    done = true
                                    offset = travel
                                    action()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: knob + inset * 2)
        .sensoryFeedback(.success, trigger: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            guard !done else { return }
            done = true
            action()
        }
    }
}

/// What just happened, for a moment, at the bottom of the screen.
struct ToastView: View {
    var text: String
    var ok: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Theme.lime : Theme.amber)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text).lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color(red: 0.11, green: 0.115, blue: 0.14)))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 20)
    }
}

/// The drawing for quiet moments: a small planet with its satellites on their orbits. No words in it.
struct OrbitArt: View {
    var size: CGFloat = 150
    var color: Color = Theme.violet

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.22), .clear], center: .center, startRadius: 2, endRadius: size * 0.5))
            Ellipse()
                .stroke(Theme.line, lineWidth: 1)
                .frame(width: size * 0.92, height: size * 0.36)
                .rotationEffect(.degrees(-18))
            Ellipse()
                .stroke(Theme.line, lineWidth: 1)
                .frame(width: size * 0.66, height: size * 0.62)
                .rotationEffect(.degrees(24))
            Circle()
                .fill(LinearGradient(colors: [Theme.violet, Theme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.26, height: size * 0.26)
            Circle().fill(Theme.amber).frame(width: 9, height: 9).offset(x: size * 0.40, y: -size * 0.10)
            Circle().fill(Theme.lime).frame(width: 7, height: 7).offset(x: -size * 0.24, y: size * 0.22)
            Circle().fill(Theme.cyan).frame(width: 6, height: 6).offset(x: -size * 0.36, y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A section's name over its rows: small, in its lane's colour, with its count.
struct LaneHeader: View {
    var look: LaneLook
    var count: Int?
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: look.icon).font(.system(size: 11, weight: .semibold))
            Text(look.name).font(.system(size: 12, weight: .semibold))
            if let count { Text("\(count)").font(.system(size: 12, weight: .semibold)).opacity(0.6) }
            Spacer(minLength: 0)
            if let trailing { Text(trailing).font(.system(size: 12)).foregroundStyle(Theme.faint) }
        }
        .foregroundStyle(look.color)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }
}

/// A row's own surface: the quiet panel everything in a list sits on.
struct RowSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))
    }
}

extension View {
    func rowSurface() -> some View { modifier(RowSurface()) }
}
