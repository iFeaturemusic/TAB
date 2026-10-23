import SwiftUI

struct TodayView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: HistoryStore
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        let today = store.today
        VStack(spacing: 12) {
            if let nudge = engine.nudge, nudge != .welcomeBack {
                NudgeStrip(nudge: nudge)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                HeroRing()
            }
            if engine.nudge != .breakTime && engine.nudge != .lockSoon {
                PrimaryAction()
            }
            HStack(spacing: 8) {
                WaterCard(day: today)
                MoveCard(day: today)
                BreaksCard(day: today)
            }
            ScoreStrip(day: today)
            MindStrip(day: today)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.nudge)
    }
}

struct HeroRing: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        ZStack {
            RingView(progress: progress, color: color, lineWidth: 9)
            VStack(spacing: 5) {
                MascotView(mood: mood, size: 40)
                Text(big)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text(caption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.dim)
            }
        }
        .frame(width: 172, height: 172)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var progress: Double {
        switch engine.phase {
        case .focus: return engine.focusProgress
        case .onBreak: return engine.breakProgress
        case .away, .paused: return 0
        }
    }

    private var color: Color {
        switch engine.phase {
        case .focus: return .white
        case .onBreak: return Theme.rest
        case .away, .paused: return Theme.faint
        }
    }

    private var mood: Mood {
        switch engine.phase {
        case .focus: return .happy
        case .onBreak: return engine.breakComplete ? .wink : .sleepy
        case .away: return .sleepy
        case .paused: return .calm
        }
    }

    private var big: String {
        switch engine.phase {
        case .focus: return Fmt.clock(engine.focusLeft)
        case .onBreak: return engine.breakComplete ? Fmt.clock(engine.breakElapsed) : Fmt.clock(engine.breakLeft)
        case .away: return Fmt.clock(engine.awayFor)
        case .paused: return "Paused"
        }
    }

    private var caption: String {
        switch engine.phase {
        case .focus: return "until your next break"
        case .onBreak: return engine.breakComplete ? "break done, welcome back" : "of rest left"
        case .away: return "you're away"
        case .paused:
            guard let until = engine.pausedUntil else { return "reminders are off" }
            return Calendar.current.isDateInToday(until) ? "until \(Fmt.time(until))" : "until tomorrow"
        }
    }
}

struct NudgeStrip: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    var nudge: Nudge

    var body: some View {
        VStack(spacing: 14) {
            MascotView(mood: .alert, size: 64)
            VStack(spacing: 5) {
                Text(NudgeCopy.title(nudge, engine: engine))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(NudgeCopy.message(nudge, engine: engine, prefs: prefs))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.dim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NudgeButtons(nudge: nudge)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .card(padding: 14, radius: 20)
    }
}

struct PrimaryAction: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        switch engine.phase {
        case .onBreak:
            Button { engine.endBreak() } label: {
                Label("I'm back", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest))
        case .paused:
            Button { engine.resume() } label: {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle(filled: true))
        default:
            Button { engine.beginBreak(.manual) } label: {
                Label("Take a break", systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(PillButtonStyle(filled: false))
        }
    }
}

struct TrackerCard<Footer: View>: View {
    var symbol: String
    var tint: Color
    var value: String
    var caption: String
    var onAdd: () -> Void
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.15)))
                Spacer(minLength: 0)
                Button(action: onAdd) { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle(size: 22, tint: tint))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 10, radius: 16)
    }
}

struct WaterCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    var day: DayLog

    var body: some View {
        TrackerCard(
            symbol: "drop.fill",
            tint: Theme.water,
            value: Fmt.water(day.waterML, ounces: prefs.useOunces),
            caption: "of \(Fmt.water(prefs.waterGoal, ounces: prefs.useOunces))",
            onAdd: { engine.logWater() }
        ) {
            BarView(progress: Double(day.waterML) / Double(max(1, prefs.waterGoal)), color: Theme.water)
                .padding(.vertical, 3)
        }
        .contextMenu {
            ForEach([150, 250, 330, 500, 750], id: \.self) { ml in
                Button("Add \(Fmt.water(ml, ounces: prefs.useOunces))") { engine.logWater(ml) }
            }
            Divider()
            Button("Undo last glass") { engine.undoWater() }
        }
        .help("Click + to log a glass. Right-click for other sizes.")
    }
}

struct MoveCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    var day: DayLog

    var body: some View {
        TrackerCard(
            symbol: "figure.walk",
            tint: Theme.move,
            value: "\(day.standCount)",
            caption: day.standCount == 1 ? "stand-up" : "stand-ups",
            onAdd: { engine.logStand() }
        ) {
            Text(prefs.standReminders ? "next in \(Fmt.short(engine.standLeft))" : "reminders off")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.move.opacity(0.9))
                .lineLimit(1)
        }
        .help("Click + after you stood up and stretched.")
    }
}

struct BreaksCard: View {
    @EnvironmentObject var engine: Engine
    var day: DayLog

    var body: some View {
        TrackerCard(
            symbol: "cup.and.saucer.fill",
            tint: Theme.rest,
            value: "\(day.breakCount)",
            caption: day.breakCount == 1 ? "break" : "breaks",
            onAdd: { engine.beginBreak(.manual) }
        ) {
            Text("\(Fmt.duration(day.breakSeconds)) rested")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.rest.opacity(0.9))
                .lineLimit(1)
        }
        .help("Click + to start a break now.")
    }
}

struct ScoreStrip: View {
    var day: DayLog

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RingView(progress: Double(day.healthScore ?? 0) / 100, color: Theme.score, lineWidth: 5)
                Text(day.healthScore.map(String.init) ?? "–")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Health score")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(Fmt.scoreLabel(day.healthScore))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Fmt.duration(day.focusSeconds)) at the desk")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("longest sit \(Fmt.duration(day.longestSit))")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
        }
        .card(padding: 10, radius: 16)
    }
}

enum NudgeCopy {
    static func title(_ nudge: Nudge, engine: Engine) -> String {
        switch nudge {
        case .breakTime: return "Time for a break"
        case .lockSoon: return "Break in 30 seconds"
        case .stand: return engine.stretch.title
        case .water: return "Sip, sip"
        case .welcomeBack: return engine.breakComplete ? "Break complete" : "Welcome back"
        case .mindPractice: return "Time for your daily reset"
        case .socialLimit: return "Social media check"
        case .scrolling: return "Still scrolling?"
        }
    }

    static func message(_ nudge: Nudge, engine: Engine, prefs: Preferences) -> String {
        switch nudge {
        case .breakTime:
            return "You've been at it for \(Fmt.duration(engine.sittingFor)). Stand up, drink some water and rest your eyes."
        case .lockSoon:
            return "Save what you're doing. Your screen locks for \(prefs.breakMinutes) min."
        case .stand:
            return "Time to stand up. \(engine.stretch.detail)"
        case .water:
            let had = Fmt.water(engine.store.today.waterML, ounces: prefs.useOunces)
            let goal = Fmt.water(prefs.waterGoal, ounces: prefs.useOunces)
            return "Grab a glass of water. You're at \(had) of \(goal) today."
        case .welcomeBack:
            return engine.breakComplete
                ? "You rested for \(Fmt.duration(engine.breakElapsed)). Ready to get back to it?"
                : "You've been on a break for \(Fmt.duration(engine.breakElapsed))."
        case .mindPractice:
            return "\(prefs.mindGoal) min of \(prefs.mindKind.title). Find a comfy spot, close your eyes and let TAB guide you."
        case .socialLimit:
            return "You've spent \(Fmt.duration(engine.store.today.socialSeconds)) on social media today. That's your \(prefs.socialLimit) min limit."
        case .scrolling:
            return "You've been scrolling for 5 minutes. One calm breath, then back to what matters?"
        }
    }
}

struct NudgeButtons: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var mind: Mind
    var nudge: Nudge

    var body: some View {
        HStack(spacing: 6) {
            switch nudge {
            case .breakTime:
                Button("Start break") { engine.startBreakNow() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest, height: 30))
                Button("+5 min") { engine.snoozeBreak() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30, expand: false))
                Button("Skip") { engine.skipBreak() }
                    .buttonStyle(PillButtonStyle(filled: false, tint: Theme.dim, height: 30, expand: false))
            case .lockSoon:
                Button("Start now") { engine.startBreakNow() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest, height: 30))
                Button("5 more min") { engine.snoozeBreak() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            case .stand:
                Button("Done") { engine.logStand() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.move, height: 30))
                Button("Later") { engine.later() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            case .water:
                Button("+ \(Fmt.water(prefs.glassSize, ounces: prefs.useOunces))") { engine.logWater() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.water, height: 30))
                Button("Later") { engine.later() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            case .welcomeBack:
                Button("I'm back") { engine.endBreak() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest, height: 30))
                Button("Still resting") { engine.stayOnBreak() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            case .mindPractice:
                Button("Start") { mind.begin(prefs.mindKind, minutes: prefs.mindGoal) }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.mind, height: 30))
                Button("In 1 hour") { mind.remindLater() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30, expand: false))
                Button("Not today") { mind.skipToday() }
                    .buttonStyle(PillButtonStyle(filled: false, tint: Theme.dim, height: 30, expand: false))
            case .socialLimit:
                Button("Got it") { engine.clearNudge() }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.digital, height: 30))
                Button("Breathe") { mind.begin(.breathing, minutes: 1) }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            case .scrolling:
                Button("Breathe") { mind.begin(.breathing, minutes: 1) }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.breath, height: 30))
                Button("Back to work") { engine.clearNudge() }
                    .buttonStyle(PillButtonStyle(filled: false, height: 30))
            }
        }
    }
}
