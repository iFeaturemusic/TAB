import AppKit
import Combine

final class Engine: ObservableObject {
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var focusLeft: Int
    @Published private(set) var standLeft: Int
    @Published private(set) var waterLeft: Int
    @Published private(set) var breakElapsed = 0
    @Published private(set) var breakSource: BreakSource = .manual
    @Published private(set) var isScreenLocked = false
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var nudge: Nudge?
    @Published private(set) var stretch = Stretch.random()
    @Published private(set) var sittingFor = 0
    @Published private(set) var awayFor = 0
    @Published private(set) var loggedWaterThisBreak = false
    @Published private(set) var stretchedThisBreak = false

    let prefs: Preferences
    let store: HistoryStore
    let keyboard = KeyboardBlocker()

    private var ticker: AnyCancellable?
    private var bag = Set<AnyCancellable>()
    private var lastTick = Date()
    private var breakStart: Date?
    private var awayStart: Date?
    private var breakDoneAnnounced = false
    private var breakIdlePeak: TimeInterval = 0
    private var nudgeShownAt = Date()
    private var known: (work: Int, stand: Int, water: Int)

    init(prefs: Preferences, store: HistoryStore) {
        self.prefs = prefs
        self.store = store
        focusLeft = prefs.workMinutes * 60
        standLeft = prefs.standMinutes * 60
        waterLeft = prefs.waterMinutes * 60
        known = (prefs.workMinutes, prefs.standMinutes, prefs.waterMinutes)
    }

    var workLength: Int { prefs.workMinutes * 60 }
    var breakLength: Int { prefs.breakMinutes * 60 }
    var standLength: Int { prefs.standMinutes * 60 }
    var waterLength: Int { prefs.waterMinutes * 60 }
    var breakLeft: Int { max(0, breakLength - breakElapsed) }
    var breakComplete: Bool { breakElapsed >= breakLength }
    var focusProgress: Double { 1 - Double(focusLeft) / Double(max(1, workLength)) }
    var breakProgress: Double { min(1, Double(breakElapsed) / Double(max(1, breakLength))) }
    var lockFinished: Bool { isScreenLocked && breakComplete }

    private var awayThreshold: TimeInterval {
        TimeInterval(max(180, min(breakLength, 600)))
    }

    func start() {
        lastTick = Date()
        ticker = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.tick(now) }

        prefs.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncIntervals() }
            .store(in: &bag)

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            center.publisher(for: name)
                .sink { [weak self] _ in self?.wentAway(at: Date()) }
                .store(in: &bag)
        }
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("com.apple.screenIsLocked"))
            .sink { [weak self] _ in self?.wentAway(at: Date()) }
            .store(in: &bag)
    }

    func shutdown() {
        if phase == .onBreak { endBreak() }
        keyboard.stop()
        store.save()
    }

    private func syncIntervals() {
        if prefs.workMinutes != known.work {
            known.work = prefs.workMinutes
            focusLeft = workLength
        }
        if prefs.standMinutes != known.stand {
            known.stand = prefs.standMinutes
            standLeft = standLength
        }
        if prefs.waterMinutes != known.water {
            known.water = prefs.waterMinutes
            waterLeft = waterLength
        }
        if prefs.breakStyle == .gentle && nudge == .lockSoon { nudge = nil }
    }

    private func tick(_ now: Date) {
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now
        if gap > 90 && phase == .focus {
            awayStart = now.addingTimeInterval(-gap)
            phase = .away
        }

        switch phase {
        case .focus: focusTick(now)
        case .away: awayTick(now)
        case .onBreak: breakTick(now)
        case .paused: pausedTick(now)
        }
    }

    private func focusTick(_ now: Date) {
        let idle = IdleMonitor.seconds
        if prefs.detectAway && idle >= awayThreshold && !IdleMonitor.mediaIsPlaying {
            awayStart = now.addingTimeInterval(-idle)
            awayFor = Int(idle)
            phase = .away
            if nudge == .stand || nudge == .water { nudge = nil }
            return
        }

        countFocus(now)
        if nudge == .breakTime { return }

        focusLeft = max(0, focusLeft - 1)
        if prefs.standReminders { standLeft = max(0, standLeft - 1) }
        if prefs.waterReminders { waterLeft = max(0, waterLeft - 1) }

        if focusLeft == 0 {
            fireBreak()
        } else if prefs.breakStyle == .lock && focusLeft == 30 && nudge == nil {
            show(.lockSoon)
            SoundPlayer.play(prefs, volume: 0.5)
        } else if nudge == nil && focusLeft > 120 {
            if prefs.standReminders && standLeft == 0 {
                stretch = Stretch.random(excluding: stretch)
                show(.stand)
                SoundPlayer.play(prefs, volume: 0.6)
            } else if prefs.waterReminders && waterLeft == 0 {
                show(.water)
                SoundPlayer.play(prefs, volume: 0.6)
            }
        }

        if (nudge == .stand || nudge == .water) && now.timeIntervalSince(nudgeShownAt) > 120 {
            later()
        }
    }

    private func awayTick(_ now: Date) {
        guard let start = awayStart else {
            phase = .focus
            return
        }
        awayFor = Int(now.timeIntervalSince(start))
        let idle = IdleMonitor.seconds
        guard idle < 3 else { return }

        let end = now.addingTimeInterval(-idle)
        let length = end.timeIntervalSince(start)
        if length >= awayThreshold {
            if length <= 4 * 3600 && Calendar.current.isDate(start, inSameDayAs: end) {
                store.update(end) { $0.breaks.append(BreakEntry(start: start, end: end, source: .away)) }
            }
            refreshAfterBreak()
        }
        awayStart = nil
        awayFor = 0
        phase = pausedUntil == nil ? .focus : .paused
    }

    private func breakTick(_ now: Date) {
        guard let start = breakStart else { return }
        breakElapsed = Int(now.timeIntervalSince(start))

        if breakComplete && !breakDoneAnnounced {
            breakDoneAnnounced = true
            if isScreenLocked {
                keyboard.stop()
            } else {
                show(.welcomeBack)
            }
            SoundPlayer.play(prefs, volume: 0.6)
        }

        if !isScreenLocked {
            let idle = IdleMonitor.seconds
            breakIdlePeak = max(breakIdlePeak, idle)
            if idle < 2 && breakIdlePeak >= 60 && nudge == nil {
                breakIdlePeak = 0
                show(.welcomeBack)
            }
        }

        if breakElapsed > 4 * 3600 { endBreak() }
    }

    private func pausedTick(_ now: Date) {
        if let until = pausedUntil, now >= until {
            resume()
            return
        }
        if IdleMonitor.seconds < 300 { countFocus(now) }
    }

    private func countFocus(_ now: Date) {
        sittingFor += 1
        let hour = Calendar.current.component(.hour, from: now)
        let sit = sittingFor
        let goal = prefs.waterGoal
        let work = workLength
        let stand = standLength
        store.update(now) { day in
            day.focusSeconds += 1
            day.hourlyFocus[hour] += 1
            day.longestSit = max(day.longestSit, sit)
            day.waterGoal = goal
            day.workInterval = work
            day.standInterval = stand
        }
    }

    private func show(_ kind: Nudge) {
        nudgeShownAt = Date()
        nudge = kind
    }

    private func wentAway(at date: Date) {
        guard phase == .focus else { return }
        awayStart = date
        phase = .away
        if nudge != .breakTime { nudge = nil }
    }

    private func fireBreak() {
        SoundPlayer.play(prefs)
        if prefs.breakStyle == .lock {
            beginBreak(.scheduled)
        } else {
            show(.breakTime)
        }
    }

    private func refreshAfterBreak() {
        focusLeft = workLength
        standLeft = standLength
        waterLeft = waterLength
        sittingFor = 0
        if nudge != .welcomeBack { nudge = nil }
    }

    func beginBreak(_ source: BreakSource) {
        guard phase != .onBreak else { return }
        nudge = nil
        breakSource = source
        breakStart = Date()
        breakElapsed = 0
        breakDoneAnnounced = false
        breakIdlePeak = 0
        loggedWaterThisBreak = false
        stretchedThisBreak = false
        stretch = Stretch.random(excluding: stretch)
        pausedUntil = nil
        phase = .onBreak
        if source == .scheduled && prefs.breakStyle == .lock {
            isScreenLocked = true
            keyboard.start()
        }
    }

    func endBreak() {
        guard phase == .onBreak, let start = breakStart else { return }
        let end = Date()
        if end.timeIntervalSince(start) >= 30 {
            let source = breakSource
            store.update(start) { $0.breaks.append(BreakEntry(start: start, end: end, source: source)) }
        }
        breakStart = nil
        breakElapsed = 0
        if isScreenLocked {
            isScreenLocked = false
            keyboard.stop()
        }
        nudge = nil
        phase = .focus
        refreshAfterBreak()
    }

    func emergencySkip() {
        guard isScreenLocked else { return }
        store.update { $0.skippedBreaks += 1 }
        isScreenLocked = false
        keyboard.stop()
        breakStart = nil
        breakElapsed = 0
        nudge = nil
        phase = .focus
        focusLeft = workLength
    }

    func startBreakNow() {
        beginBreak(nudge == .breakTime || nudge == .lockSoon ? .scheduled : .manual)
    }

    func snoozeBreak(minutes: Int = 5) {
        store.update { $0.snoozes += 1 }
        focusLeft = minutes * 60
        nudge = nil
    }

    func skipBreak() {
        store.update { $0.skippedBreaks += 1 }
        focusLeft = workLength
        nudge = nil
    }

    func stayOnBreak() {
        breakIdlePeak = 0
        nudge = nil
    }

    func logStand() {
        store.update { $0.standUps.append(Date()) }
        standLeft = standLength
        sittingFor = 0
        if phase == .onBreak { stretchedThisBreak = true }
        if nudge == .stand { nudge = nil }
    }

    func logWater(_ ml: Int? = nil) {
        let amount = ml ?? prefs.glassSize
        store.update { $0.water.append(WaterEntry(time: Date(), ml: amount)) }
        waterLeft = waterLength
        if phase == .onBreak { loggedWaterThisBreak = true }
        if nudge == .water { nudge = nil }
    }

    func undoWater() {
        store.update { day in
            if !day.water.isEmpty { day.water.removeLast() }
        }
    }

    func later() {
        switch nudge {
        case .stand: standLeft = 5 * 60
        case .water: waterLeft = 10 * 60
        default: break
        }
        nudge = nil
    }

    func dismissNudge() {
        switch nudge {
        case .breakTime: snoozeBreak()
        case .lockSoon: nudge = nil
        case .stand, .water: later()
        case .welcomeBack: stayOnBreak()
        case nil: break
        }
    }

    func pause(minutes: Int?) {
        if phase == .onBreak { endBreak() }
        if let minutes {
            pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
            pausedUntil = tomorrow
        }
        nudge = nil
        phase = .paused
    }

    func resume() {
        pausedUntil = nil
        phase = .focus
        focusLeft = workLength
        standLeft = standLength
        waterLeft = waterLength
    }
}
