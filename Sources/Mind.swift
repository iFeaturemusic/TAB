import AppKit
import AVFoundation
import Combine

enum Breath {
    static let inhale = 2.5
    static let topUp = 1.0
    static let exhale = 6.0
    static var cycle: Double { inhale + topUp + exhale }

    enum Step: Int {
        case inhale
        case topUp
        case exhale

        var label: String {
            switch self {
            case .inhale: return "Breathe in through your nose"
            case .topUp: return "Sip in a little more"
            case .exhale: return "Long breath out through your mouth"
            }
        }
    }

    static func step(at t: Double) -> (step: Step, progress: Double) {
        let x = t.truncatingRemainder(dividingBy: cycle)
        if x < inhale { return (.inhale, x / inhale) }
        if x < inhale + topUp { return (.topUp, (x - inhale) / topUp) }
        return (.exhale, (x - inhale - topUp) / exhale)
    }

    static func scale(at t: Double) -> Double {
        let (step, p) = step(at: t)
        let eased = 0.5 - cos(p * .pi) / 2
        switch step {
        case .inhale: return 0.55 + 0.33 * eased
        case .topUp: return 0.88 + 0.12 * eased
        case .exhale: return 1.0 - 0.45 * eased
        }
    }

    static func cycles(minutes: Int) -> Int {
        minutes <= 1 ? 6 : Int((Double(minutes * 60) / cycle).rounded())
    }
}

struct Cue {
    let at: Double
    let text: String
}

enum Scripts {
    static let nsdr: [Cue] = [
        Cue(at: 0, text: "Welcome to your reset. Lie down or lean back, and let your eyes close."),
        Cue(at: 15, text: "Take a slow breath in through your nose, and let it out through your mouth."),
        Cue(at: 30, text: "Once more. Breathe in deeply, and let everything go as you breathe out."),
        Cue(at: 50, text: "Now let your breath find its own rhythm. There is nothing to do and nowhere to be."),
        Cue(at: 80, text: "Bring your attention to your right foot. Notice your toes, your heel, the sole of your foot."),
        Cue(at: 110, text: "Move up to your right lower leg and your knee. Let them be heavy."),
        Cue(at: 135, text: "Now your right thigh and your right hip. Let them sink down."),
        Cue(at: 165, text: "Bring your attention to your left foot. Your toes, your heel, the sole of your foot."),
        Cue(at: 195, text: "Your left lower leg and your knee. Heavy and relaxed."),
        Cue(at: 220, text: "Your left thigh and your left hip. Letting go."),
        Cue(at: 250, text: "Notice your lower back and your belly. Feel your belly rise and fall with each breath."),
        Cue(at: 285, text: "Move to your chest and your upper back. Let your shoulders melt away from your ears."),
        Cue(at: 320, text: "Bring your attention to your right hand. Your fingers, your palm, your wrist. Then up your arm to your shoulder."),
        Cue(at: 355, text: "Now your left hand. Your fingers, your palm, your wrist. Up your arm to your shoulder."),
        Cue(at: 390, text: "Notice your neck and your throat. Let your jaw soften and your tongue rest."),
        Cue(at: 420, text: "Relax your cheeks, your eyes and your forehead. Let your whole face become soft."),
        Cue(at: 450, text: "Now feel your whole body at once, from head to toe. Heavy, warm and still."),
        Cue(at: 490, text: "With every breath out, let yourself sink a little deeper."),
        Cue(at: 540, text: "Rest here for a moment."),
        Cue(at: 565, text: "Slowly start to come back. Wiggle your fingers and your toes."),
        Cue(at: 585, text: "Take a deep breath in. And when you're ready, open your eyes."),
    ]

    static let meditation: [Cue] = [
        Cue(at: 0, text: "Sit comfortably and let your eyes close."),
        Cue(at: 15, text: "Notice your breath. The air coming in, and the air going out."),
        Cue(at: 45, text: "You don't need to change anything. Just follow each breath."),
        Cue(at: 150, text: "If your mind has wandered, that's okay. Gently come back to the breath."),
        Cue(at: 270, text: "Notice the breath at your nose, your chest or your belly. Rest your attention there."),
        Cue(at: 390, text: "Thoughts will come and go. Let them pass like clouds, and return to your breath."),
        Cue(at: 510, text: "Just this breath. And this one."),
        Cue(at: 570, text: "Slowly let your attention widen to the room around you."),
        Cue(at: 590, text: "When you're ready, open your eyes."),
    ]

    static func cues(for kind: MindKind, length: Int) -> [Cue] {
        let base: [Cue]
        switch kind {
        case .nsdr: base = nsdr
        case .meditation: base = meditation
        case .breathing: return []
        }
        let scale = Double(length) / 600
        return base.map { Cue(at: $0.at * scale, text: $0.text) }
    }
}

struct GuidedSession: Equatable {
    let id = UUID()
    let kind: MindKind
    let start: Date
    let length: Int
    let inline: Bool
    let cues: [Cue]

    static func == (a: GuidedSession, b: GuidedSession) -> Bool { a.id == b.id }
}

struct SessionSummary: Equatable {
    let kind: MindKind
    let seconds: Int
    let streak: Int
}

enum Distractions {
    static let knownApps: [String: String] = [
        "com.hnc.Discord": "Discord",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "desktop.WhatsApp": "WhatsApp",
        "ru.keepcoder.Telegram": "Telegram",
        "org.telegram.desktop": "Telegram",
        "com.facebook.archon": "Messenger",
        "com.facebook.archon.developerID": "Messenger",
        "com.burbn.instagram": "Instagram",
        "com.zhiliaoapp.musically": "TikTok",
        "com.atebits.Tweetie2": "X",
        "com.tapbots.Ivory": "Ivory",
        "com.toyopagroup.picaboo": "Snapchat",
        "com.reddit.Reddit": "Reddit",
        "pinterest": "Pinterest",
    ]

    static var defaultApps: [String] { Array(knownApps.keys).sorted() }

    static let defaultSites = [
        "instagram.com", "tiktok.com", "facebook.com", "x.com", "twitter.com", "reddit.com",
        "youtube.com", "snapchat.com", "pinterest.com", "threads.net", "bsky.app", "twitch.tv",
    ]

    static let browsers: [String: String] = [
        "com.apple.Safari": "URL of front document",
        "com.google.Chrome": "URL of active tab of front window",
        "com.brave.Browser": "URL of active tab of front window",
        "com.microsoft.edgemac": "URL of active tab of front window",
        "com.vivaldi.Vivaldi": "URL of active tab of front window",
        "company.thebrowser.Browser": "URL of active tab of front window",
        "org.chromium.Chromium": "URL of active tab of front window",
    ]

    static func name(for bundleID: String) -> String {
        if let known = knownApps[bundleID] { return known }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    static func site(in urlString: String?, matching sites: [String]) -> String? {
        guard let urlString, let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        return sites.first { host == $0 || host.hasSuffix("." + $0) }
    }
}

final class DistractionTracker {
    private var scripts: [String: NSAppleScript] = [:]
    private var lastCheck = Date.distantPast
    private var lastSite: String?
    private(set) var websitesDenied = false

    func current(prefs: Preferences) -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else { return nil }
        if prefs.socialApps.contains(id) { return Distractions.name(for: id) }
        guard prefs.trackWebsites, let property = Distractions.browsers[id] else { return nil }
        if Date().timeIntervalSince(lastCheck) >= 3 {
            lastCheck = Date()
            lastSite = Distractions.site(in: url(browser: id, property: property), matching: prefs.socialSites)
        }
        return lastSite
    }

    private func url(browser id: String, property: String) -> String? {
        let script = scripts[id] ?? NSAppleScript(source: "tell application id \"\(id)\" to return \(property)")
        scripts[id] = script
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let code = error?[NSAppleScript.errorNumber] as? Int, code == -1743 { websitesDenied = true }
        return result?.stringValue
    }
}

enum FocusShortcuts {
    static let on = "TAB Focus On"
    static let off = "TAB Focus Off"

    static func installed() -> Set<String> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return Set(text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    static func run(_ name: String, wait: Bool = false) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return }
        if wait {
            let deadline = Date().addingTimeInterval(4)
            while task.isRunning && Date() < deadline { usleep(50_000) }
        }
    }
}

final class Mind: ObservableObject {
    @Published private(set) var session: GuidedSession?
    @Published private(set) var elapsed = 0
    @Published private(set) var cue = ""
    @Published private(set) var summary: SessionSummary?
    @Published private(set) var socialNow: String?
    @Published private(set) var shortcutsReady = false
    @Published private(set) var websitesDenied = false

    let prefs: Preferences
    let store: HistoryStore
    let engine: Engine

    private let synth = AVSpeechSynthesizer()
    private let tracker = DistractionTracker()
    private var ticker: AnyCancellable?
    private var breathTicker: AnyCancellable?
    private var bag = Set<AnyCancellable>()
    private var spokenCue = -1
    private var spokenStep = -1
    private var startedBreak = false
    private var nextOffer = Date.distantPast
    private var skippedDay = ""
    private var warnedDay = ""
    private var scrollRun = 0
    private var scrollWarned = false
    private var silenced: Bool?

    init(prefs: Preferences, store: HistoryStore, engine: Engine) {
        self.prefs = prefs
        self.store = store
        self.engine = engine
    }

    var remaining: Int { max(0, (session?.length ?? 0) - elapsed) }
    var progress: Double {
        guard let session, session.length > 0 else { return 0 }
        return min(1, Double(elapsed) / Double(session.length))
    }

    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        let goal = prefs.mindGoal * 60
        if store.log(day).restSeconds < goal {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while store.log(day).restSeconds >= goal {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    func start() {
        ticker = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.tick(now) }

        engine.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.applySilence(phase) }
            .store(in: &bag)

        prefs.$silenceWhileFocus
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] on in
                guard let self else { return }
                if on {
                    self.refreshShortcuts()
                } else if self.silenced == true {
                    self.silenced = false
                    DispatchQueue.global(qos: .utility).async { FocusShortcuts.run(FocusShortcuts.off) }
                }
            }
            .store(in: &bag)

        refreshShortcuts()
    }

    func shutdown() {
        if session != nil { finish(completed: false) }
        if silenced == true { FocusShortcuts.run(FocusShortcuts.off, wait: true) }
    }

    func refreshShortcuts() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let names = FocusShortcuts.installed()
            let ready = names.contains(FocusShortcuts.on) && names.contains(FocusShortcuts.off)
            DispatchQueue.main.async {
                guard let self else { return }
                self.shortcutsReady = ready
                self.silenced = nil
                self.applySilence(self.engine.phase)
            }
        }
    }

    private func applySilence(_ phase: Phase) {
        guard prefs.silenceWhileFocus, shortcutsReady else { return }
        let resting = session.map { $0.kind != .breathing } ?? false
        let want: Bool
        switch phase {
        case .focus: want = true
        case .onBreak, .paused: want = resting
        case .away: return
        }
        guard silenced != want else { return }
        silenced = want
        let name = want ? FocusShortcuts.on : FocusShortcuts.off
        DispatchQueue.global(qos: .utility).async { FocusShortcuts.run(name) }
    }

    func begin(_ kind: MindKind, minutes: Int? = nil, inline: Bool = false) {
        guard session == nil else { return }
        summary = nil
        let length: Int
        if kind == .breathing {
            length = Int((Double(Breath.cycles(minutes: minutes ?? 1)) * Breath.cycle).rounded())
        } else {
            length = (minutes ?? prefs.mindGoal) * 60
        }
        if kind != .breathing && (engine.phase == .focus || engine.phase == .away) {
            engine.beginBreak(.manual)
            startedBreak = true
        }
        engine.isGuided = true
        engine.clearNudge()
        spokenCue = -1
        spokenStep = -1
        elapsed = 0
        cue = kind == .breathing ? Breath.Step.inhale.label : ""
        session = GuidedSession(kind: kind, start: Date(), length: length, inline: inline,
                                cues: Scripts.cues(for: kind, length: length))
        applySilence(engine.phase)
        if kind == .breathing {
            breathTicker = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] now in self?.breathTick(now) }
            breathTick(Date())
        } else {
            sessionTick(Date())
        }
    }

    func finish(completed: Bool) {
        guard let s = session else { return }
        let seconds = min(s.length, Int(Date().timeIntervalSince(s.start)))
        synth.stopSpeaking(at: .word)
        breathTicker = nil
        let counts = s.kind == .breathing ? Double(seconds) >= Breath.cycle : seconds >= 60
        if counts {
            let goal = prefs.scoredMindGoal
            let limit = prefs.scoredSocialLimit
            store.update(s.start) { day in
                day.mindSessions.append(MindSession(start: s.start, seconds: seconds, kind: s.kind))
                day.mindGoal = goal
                day.socialLimit = limit
            }
            if s.kind == .breathing && engine.phase == .onBreak { engine.markBreathed() }
        }
        session = nil
        engine.isGuided = false
        if startedBreak {
            startedBreak = false
            engine.endBreak()
        } else {
            applySilence(engine.phase)
        }
        if completed {
            SoundPlayer.playSystem("Glass", volume: 0.45)
            if !s.inline { summary = SessionSummary(kind: s.kind, seconds: seconds, streak: streak) }
        }
    }

    func closeSummary() {
        summary = nil
    }

    func log(_ kind: MindKind, minutes: Int, endedMinutesAgo: Int = 0) {
        let seconds = max(1, minutes) * 60
        let end = Date().addingTimeInterval(-Double(max(0, endedMinutesAgo) * 60))
        let start = end.addingTimeInterval(-Double(seconds))
        let goal = prefs.scoredMindGoal
        let limit = prefs.scoredSocialLimit
        store.update(start) { day in
            day.mindSessions.append(MindSession(start: start, seconds: seconds, kind: kind, manual: true))
            day.mindSessions.sort { $0.start < $1.start }
            day.mindGoal = goal
            day.socialLimit = limit
        }
        if engine.nudge == .mindPractice && store.today.restSeconds >= prefs.mindGoal * 60 {
            engine.clearNudge()
        }
    }

    func remove(_ session: MindSession) {
        store.update(session.start) { day in
            if let index = day.mindSessions.firstIndex(of: session) { day.mindSessions.remove(at: index) }
        }
    }

    func skipToday() {
        skippedDay = HistoryStore.key(Date())
        engine.clearNudge()
    }

    func remindLater() {
        nextOffer = Date().addingTimeInterval(3600)
        engine.clearNudge()
    }

    private func tick(_ now: Date) {
        if session?.kind != .breathing, session != nil { sessionTick(now) }
        socialTick(now)
        reminderTick(now)
    }

    private func sessionTick(_ now: Date) {
        guard let s = session else { return }
        elapsed = Int(now.timeIntervalSince(s.start))
        if let index = s.cues.lastIndex(where: { $0.at <= Double(elapsed) }), index != spokenCue {
            spokenCue = index
            cue = s.cues[index].text
            speak(cue, rate: 0.4)
        }
        if elapsed >= s.length { finish(completed: true) }
    }

    private func breathTick(_ now: Date) {
        guard let s = session else { return }
        let t = now.timeIntervalSince(s.start)
        let newElapsed = Int(t)
        if newElapsed != elapsed { elapsed = newElapsed }
        if t >= Double(s.length) {
            finish(completed: true)
            return
        }
        let cycle = Int(t / Breath.cycle)
        let step = Breath.step(at: t).step
        let key = cycle * 3 + step.rawValue
        guard key != spokenStep else { return }
        spokenStep = key
        cue = step.label
        if cycle < 2 {
            speak(step.label, rate: 0.46)
        } else {
            switch step {
            case .inhale: speak("in", rate: 0.4)
            case .topUp: speak("and in", rate: 0.45)
            case .exhale: speak("out, slowly", rate: 0.36)
            }
        }
    }

    private func speak(_ text: String, rate: Float) {
        guard prefs.voiceGuidance, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        utterance.rate = rate
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.9
        synth.speak(utterance)
    }

    private static let voice: AVSpeechSynthesisVoice? = {
        let preferred = ["Ava", "Zoe", "Samantha", "Allison", "Serena", "Susan"]
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let ranked = voices.sorted { a, b in
            if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
            let ia = preferred.firstIndex { a.name.contains($0) } ?? 99
            let ib = preferred.firstIndex { b.name.contains($0) } ?? 99
            return ia < ib
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    private func socialTick(_ now: Date) {
        guard prefs.socialTracking, session == nil, engine.phase != .away, IdleMonitor.seconds < 60,
              let label = tracker.current(prefs: prefs) else {
            if socialNow != nil { socialNow = nil }
            scrollRun = 0
            scrollWarned = false
            if tracker.websitesDenied != websitesDenied { websitesDenied = tracker.websitesDenied }
            return
        }
        if socialNow != label { socialNow = label }
        let hour = Calendar.current.component(.hour, from: now)
        let limit = prefs.scoredSocialLimit
        store.update(now) { day in
            day.socialSeconds += 1
            day.hourlySocial[hour] += 1
            day.socialApps[label, default: 0] += 1
            day.socialLimit = limit
        }
        scrollRun += 1

        let key = HistoryStore.key(now)
        if prefs.socialLimit > 0, warnedDay != key, store.today.socialSeconds >= prefs.socialLimit * 60 {
            if engine.offer(.socialLimit) { warnedDay = key }
        } else if prefs.scrollNudge, !scrollWarned, scrollRun >= 300, engine.phase == .focus {
            if engine.offer(.scrolling) { scrollWarned = true }
        }
    }

    private func reminderTick(_ now: Date) {
        guard prefs.mindReminder, session == nil, now >= nextOffer, engine.phase == .focus else { return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        guard minutes >= prefs.mindReminderAt, minutes < 22 * 60 else { return }
        guard skippedDay != HistoryStore.key(now), store.today.restSeconds < prefs.mindGoal * 60 else { return }
        if engine.offer(.mindPractice) { nextOffer = now.addingTimeInterval(3600) }
    }
}
