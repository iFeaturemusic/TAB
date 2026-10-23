import AppKit
import Combine
import SwiftUI

struct MindView: View {
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var store: HistoryStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                RestCard()
                BreathCard()
                DigitalCard()
                ForEach(MindResearch.notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.faint)
                            .padding(.top, 2)
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

struct MindCardHeader: View {
    var symbol: String
    var tint: Color
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

struct RestCard: View {
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var store: HistoryStore

    var body: some View {
        let done = store.today.restSeconds
        let goal = prefs.mindGoal * 60
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RingView(progress: Double(done) / Double(max(1, goal)), color: Theme.mind, lineWidth: 6)
                    MascotView(mood: .sleepy, size: 34)
                }
                .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily reset")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(done / 60) of \(prefs.mindGoal) min today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.mind)
                    let streak = mind.streak
                    Text(streak > 0 ? "\(streak) day streak" : "Start a streak today")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                Chip(title: "NSDR", selected: prefs.mindKind == .nsdr, tint: Theme.mind) { prefs.mindKind = .nsdr }
                Chip(title: "Meditation", selected: prefs.mindKind == .meditation, tint: Theme.mind) { prefs.mindKind = .meditation }
            }
            HStack(spacing: 4) {
                ForEach([5, 10, 20], id: \.self) { m in
                    Chip(title: "\(m) min", selected: prefs.mindGoal == m, tint: Theme.mind) { prefs.mindGoal = m }
                }
            }
            Button {
                mind.begin(prefs.mindKind, minutes: prefs.mindGoal)
            } label: {
                Label("Start \(prefs.mindGoal) min \(prefs.mindKind.title)", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle(filled: true, tint: Theme.mind, height: 34))
            Text(prefs.mindKind == .nsdr ? MindResearch.nsdr : MindResearch.meditation)
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 12, radius: 18)
    }
}

struct BreathCard: View {
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var store: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MindCardHeader(
                symbol: "wind",
                tint: Theme.breath,
                title: "Physiological sigh",
                subtitle: store.today.breathCount == 0 ? "Not yet today" : "\(store.today.breathCount)× today"
            )
            HStack(spacing: 6) {
                BreathStepPill(text: "In", detail: "nose", tint: Theme.breath)
                BreathStepPill(text: "In again", detail: "nose", tint: Theme.breath)
                BreathStepPill(text: "Long out", detail: "mouth", tint: Theme.breath, wide: true)
            }
            HStack(spacing: 6) {
                Button { mind.begin(.breathing, minutes: 1) } label: { Label("1 min reset", systemImage: "wind") }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.breath, height: 32))
                Button { mind.begin(.breathing, minutes: 5) } label: { Text("5 min practice") }
                    .buttonStyle(PillButtonStyle(filled: false, height: 32))
            }
            Text(MindResearch.sigh)
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 12, radius: 18)
    }
}

struct BreathStepPill: View {
    var text: String
    var detail: String
    var tint: Color
    var wide = false

    var body: some View {
        VStack(spacing: 1) {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(wide ? 0.16 : 0.08)))
    }
}

struct DigitalCard: View {
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var store: HistoryStore

    var body: some View {
        let today = store.today
        let limit = prefs.socialLimit * 60
        let over = limit > 0 && today.socialSeconds > limit
        VStack(alignment: .leading, spacing: 12) {
            MindCardHeader(
                symbol: "iphone.gen3.radiowaves.left.and.right",
                tint: Theme.digital,
                title: "Digital hygiene",
                subtitle: mind.socialNow.map { "Right now: \($0)" } ?? (prefs.socialTracking ? "Social media today" : "Tracking is off")
            )
            if prefs.socialTracking {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.duration(today.socialSeconds))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(over ? Theme.alert : .white)
                        Text("of \(prefs.socialLimit) min")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.dim)
                        Spacer()
                    }
                    BarView(progress: Double(today.socialSeconds) / Double(max(1, limit)), color: over ? Theme.alert : Theme.digital)
                    let top = today.socialApps.sorted { $0.value > $1.value }.prefix(3)
                    if !top.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(top), id: \.key) { app in
                                Text("\(app.key) \(Fmt.duration(app.value))")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.dim)
                                    .padding(.horizontal, 8)
                                    .frame(height: 20)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            Divider().overlay(Theme.stroke)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications only in breaks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text(silenceStatus)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                PillToggle(isOn: $prefs.silenceWhileFocus, tint: Theme.digital)
            }
            if prefs.silenceWhileFocus && !mind.shortcutsReady {
                ShortcutSetup()
            }
            Text(MindResearch.digital)
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 12, radius: 18)
    }

    private var silenceStatus: String {
        if !prefs.silenceWhileFocus { return "Turns on Do Not Disturb while you focus" }
        return mind.shortcutsReady ? "Do Not Disturb is on while you focus" : "Needs two shortcuts, see below"
    }
}

struct ShortcutSetup: View {
    @EnvironmentObject var mind: Mind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create two shortcuts in the Shortcuts app:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 4) {
                step("1", "\u{201C}\(FocusShortcuts.on)\u{201D} with the action Set Focus › Do Not Disturb › On")
                step("2", "\u{201C}\(FocusShortcuts.off)\u{201D} with the action Set Focus › Do Not Disturb › Off")
            }
            HStack(spacing: 6) {
                Button("Open Shortcuts") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                .buttonStyle(PillButtonStyle(filled: true, tint: Theme.digital, height: 28))
                Button("Check again") { mind.refreshShortcuts() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 28))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.digital.opacity(0.08)))
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(n)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 15, height: 15)
                .background(Circle().fill(Theme.digital))
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MindStrip: View {
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var nav: PanelNav
    var day: DayLog

    var body: some View {
        HStack(spacing: 6) {
            stripButton(symbol: prefs.mindKind.symbol, tint: Theme.mind, text: "\(day.restSeconds / 60)/\(prefs.mindGoal)m") {
                mind.begin(prefs.mindKind, minutes: prefs.mindGoal)
            }
            .help("Start your daily \(prefs.mindKind.title)")
            stripButton(symbol: "wind", tint: Theme.breath, text: "Sigh") {
                mind.begin(.breathing, minutes: 1)
            }
            .help("1 minute physiological sigh")
            stripButton(symbol: "iphone", tint: overLimit ? Theme.alert : Theme.digital, text: Fmt.short(day.socialSeconds)) {
                nav.tab = .mind
            }
            .help("Social media today")
        }
    }

    private var overLimit: Bool {
        prefs.socialLimit > 0 && day.socialSeconds > prefs.socialLimit * 60
    }

    private func stripButton(symbol: String, tint: Color, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Text(text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Capsule().fill(tint.opacity(0.1)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.18)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct BreathingGuide: View {
    var start: Date
    var size: CGFloat = 220
    var tint: Color = Theme.breath

    var body: some View {
        TimelineView(.animation) { context in
            let t = max(0, context.date.timeIntervalSince(start))
            let scale = Breath.scale(at: t)
            ZStack {
                Circle()
                    .fill(tint.opacity(0.08))
                    .frame(width: size, height: size)
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.15)], center: .center, startRadius: 0, endRadius: size / 2))
                    .frame(width: size * scale, height: size * scale)
                Circle()
                    .strokeBorder(tint.opacity(0.6), lineWidth: 2)
                    .frame(width: size * scale, height: size * scale)
                MascotView(mood: Breath.step(at: t).step == .exhale ? .sleepy : .happy, size: size * 0.3, animated: false)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MindSessionView: View {
    @EnvironmentObject var mind: Mind

    var body: some View {
        ZStack {
            Color(hex: 0x07080B).opacity(0.97).ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            if let session = mind.session {
                VStack(spacing: 34) {
                    Text(session.kind.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(tint)
                    if session.kind == .breathing {
                        BreathingGuide(start: session.start, size: 260)
                    } else {
                        ZStack {
                            RingView(progress: mind.progress, color: tint, lineWidth: 6, track: Color.white.opacity(0.05))
                            CalmMascot(start: session.start)
                        }
                        .frame(width: 240, height: 240)
                    }
                    Text(mind.cue)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560, minHeight: 64)
                        .animation(.easeInOut(duration: 0.6), value: mind.cue)
                    Text("\(Fmt.clock(mind.remaining)) left")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Theme.dim)
                    Button("End session") { mind.finish(completed: false) }
                        .buttonStyle(PillButtonStyle(filled: false, tint: Theme.dim, height: 32))
                        .frame(width: 150)
                }
            } else if let summary = mind.summary {
                VStack(spacing: 22) {
                    MascotView(mood: .happy, size: 96)
                    Text("Nice reset")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(summaryText(summary))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.dim)
                        .multilineTextAlignment(.center)
                    Button("Back to it") { mind.closeSummary() }
                        .buttonStyle(PillButtonStyle(filled: true, tint: tint, height: 44))
                        .frame(width: 200)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var tint: Color {
        let kind = mind.session?.kind ?? mind.summary?.kind ?? .nsdr
        return kind == .breathing ? Theme.breath : Theme.mind
    }

    private func summaryText(_ s: SessionSummary) -> String {
        if s.kind == .breathing {
            return "You took \(Int(Double(s.seconds) / Breath.cycle)) calm breaths. Notice how your body feels now."
        }
        let streak = s.streak > 1 ? " That's a \(s.streak) day streak." : ""
        return "You rested for \(Fmt.duration(s.seconds)) with \(s.kind.title).\(streak)"
    }
}

struct CalmMascot: View {
    var start: Date

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let s = 1 + 0.05 * sin(t * 2 * .pi / 10)
            MascotView(mood: .sleepy, size: 110, animated: false)
                .scaleEffect(s)
        }
    }
}

final class MindOverlayController {
    private let mind: Mind
    private var window: LockWindow?
    private var bag = Set<AnyCancellable>()

    init(mind: Mind) {
        self.mind = mind
        mind.$session
            .combineLatest(mind.$summary)
            .receive(on: RunLoop.main)
            .sink { [weak self] session, summary in
                let visible = (session != nil && session?.inline == false) || summary != nil
                visible ? self?.show() : self?.hide()
            }
            .store(in: &bag)
    }

    private func show() {
        guard window == nil else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        let window = LockWindow(screen: screen)
        window.onEscape = { [weak self] in
            guard let self else { return }
            if self.mind.session != nil { self.mind.finish(completed: false) } else { self.mind.closeSummary() }
        }
        window.contentView = FirstMouseHostingView(rootView: MindSessionView().environmentObject(mind))
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            window.animator().alphaValue = 1
        }
        self.window = window
    }

    private func hide() {
        guard let window else { return }
        self.window = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}
