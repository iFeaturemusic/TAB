import Foundation

final class Preferences: ObservableObject {
    private let defaults: UserDefaults

    @Published var breakStyle: BreakStyle { didSet { defaults.set(breakStyle.rawValue, forKey: "breakStyle") } }
    @Published var workMinutes: Int { didSet { defaults.set(workMinutes, forKey: "workMinutes") } }
    @Published var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: "breakMinutes") } }
    @Published var allowSkip: Bool { didSet { defaults.set(allowSkip, forKey: "allowSkip") } }

    @Published var waterGoal: Int { didSet { defaults.set(waterGoal, forKey: "waterGoal") } }
    @Published var glassSize: Int { didSet { defaults.set(glassSize, forKey: "glassSize") } }
    @Published var waterReminders: Bool { didSet { defaults.set(waterReminders, forKey: "waterReminders") } }
    @Published var waterMinutes: Int { didSet { defaults.set(waterMinutes, forKey: "waterMinutes") } }
    @Published var useOunces: Bool { didSet { defaults.set(useOunces, forKey: "useOunces") } }

    @Published var standReminders: Bool { didSet { defaults.set(standReminders, forKey: "standReminders") } }
    @Published var ageGroup: AgeGroup { didSet { defaults.set(ageGroup.rawValue, forKey: "ageGroup") } }
    @Published var customStand: Bool { didSet { defaults.set(customStand, forKey: "customStand") } }
    @Published var customStandMinutes: Int { didSet { defaults.set(customStandMinutes, forKey: "customStandMinutes") } }

    @Published var detectAway: Bool { didSet { defaults.set(detectAway, forKey: "detectAway") } }
    @Published var showTimer: Bool { didSet { defaults.set(showTimer, forKey: "showTimer") } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var soundName: String { didSet { defaults.set(soundName, forKey: "soundName") } }
    @Published var customSoundPath: String { didSet { defaults.set(customSoundPath, forKey: "customSoundPath") } }

    @Published var mindGoal: Int { didSet { defaults.set(mindGoal, forKey: "mindGoal") } }
    @Published var mindKind: MindKind { didSet { defaults.set(mindKind.rawValue, forKey: "mindKind") } }
    @Published var mindReminder: Bool { didSet { defaults.set(mindReminder, forKey: "mindReminder") } }
    @Published var mindReminderAt: Int { didSet { defaults.set(mindReminderAt, forKey: "mindReminderAt") } }
    @Published var voiceGuidance: Bool { didSet { defaults.set(voiceGuidance, forKey: "voiceGuidance") } }
    @Published var mindInScore: Bool { didSet { defaults.set(mindInScore, forKey: "mindInScore") } }

    @Published var socialTracking: Bool { didSet { defaults.set(socialTracking, forKey: "socialTracking") } }
    @Published var socialLimit: Int { didSet { defaults.set(socialLimit, forKey: "socialLimit") } }
    @Published var trackWebsites: Bool { didSet { defaults.set(trackWebsites, forKey: "trackWebsites") } }
    @Published var socialApps: [String] { didSet { defaults.set(socialApps, forKey: "socialApps") } }
    @Published var socialSites: [String] { didSet { defaults.set(socialSites, forKey: "socialSites") } }
    @Published var scrollNudge: Bool { didSet { defaults.set(scrollNudge, forKey: "scrollNudge") } }
    @Published var silenceWhileFocus: Bool { didSet { defaults.set(silenceWhileFocus, forKey: "silenceWhileFocus") } }
    @Published var lockPhone: Bool { didSet { defaults.set(lockPhone, forKey: "lockPhone") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func int(_ key: String, _ fallback: Int, legacy: String? = nil) -> Int {
            if defaults.object(forKey: key) != nil { return defaults.integer(forKey: key) }
            if let legacy, defaults.object(forKey: legacy) != nil { return defaults.integer(forKey: legacy) }
            return fallback
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }

        breakStyle = BreakStyle(rawValue: defaults.string(forKey: "breakStyle") ?? "") ?? .gentle
        workMinutes = min(180, max(5, int("workMinutes", 45, legacy: "workDurationMinutes")))
        breakMinutes = min(60, max(1, int("breakMinutes", 5, legacy: "breakDurationMinutes")))
        allowSkip = bool("allowSkip", true)

        waterGoal = int("waterGoal", 2000)
        glassSize = int("glassSize", 250)
        waterReminders = bool("waterReminders", true)
        waterMinutes = int("waterMinutes", 60)
        useOunces = bool("useOunces", Locale.current.measurementSystem == .us)

        standReminders = bool("standReminders", true)
        ageGroup = AgeGroup(rawValue: defaults.string(forKey: "ageGroup") ?? "") ?? .adults
        customStand = bool("customStand", false)
        customStandMinutes = int("customStandMinutes", 30)

        detectAway = bool("detectAway", true)
        showTimer = bool("showTimer", true)
        soundEnabled = bool("soundEnabled", true)
        soundName = defaults.string(forKey: "soundName") ?? defaults.string(forKey: "selectedSound") ?? "Glass"
        customSoundPath = defaults.string(forKey: "customSoundPath") ?? ""

        mindGoal = min(30, max(5, int("mindGoal", 10)))
        mindKind = MindKind(rawValue: defaults.string(forKey: "mindKind") ?? "") ?? .nsdr
        mindReminder = bool("mindReminder", true)
        mindReminderAt = int("mindReminderAt", 14 * 60)
        voiceGuidance = bool("voiceGuidance", true)
        mindInScore = bool("mindInScore", true)

        socialTracking = bool("socialTracking", true)
        socialLimit = int("socialLimit", 30)
        trackWebsites = bool("trackWebsites", false)
        socialApps = defaults.stringArray(forKey: "socialApps") ?? Distractions.defaultApps
        socialSites = defaults.stringArray(forKey: "socialSites") ?? Distractions.defaultSites
        scrollNudge = bool("scrollNudge", true)
        silenceWhileFocus = bool("silenceWhileFocus", false)
        lockPhone = bool("lockPhone", true)
    }

    var standMinutes: Int { customStand ? customStandMinutes : ageGroup.standEvery }
    var scoredMindGoal: Int { mindInScore ? mindGoal : 0 }
    var scoredSocialLimit: Int { socialTracking ? socialLimit : 0 }

    func bool(_ key: String) -> Bool { defaults.bool(forKey: key) }
    func set(_ value: Bool, _ key: String) { defaults.set(value, forKey: key) }
}
