import Foundation

struct Study: Identifiable {
    let id = UUID()
    let name: String
    let ages: String
    let interval: Int
    let finding: String
}

enum Research {
    static let studies: [Study] = [
        Study(name: "Dunstan et al. 2012, Diabetes Care", ages: "45–65", interval: 20,
              finding: "2 min of walking every 20 min lowered blood sugar and insulin."),
        Study(name: "Duran, Diaz et al. 2023, Med Sci Sports Exerc", ages: "Middle-aged and older", interval: 30,
              finding: "5 min of walking every 30 min was the only schedule that lowered blood sugar."),
        Study(name: "Diaz et al. 2017, Annals of Internal Medicine", ages: "45+", interval: 30,
              finding: "People who mostly sat for less than 30 min at a time had the lowest risk of death."),
        Study(name: "Hedge, Cornell University Ergonomics", ages: "Office workers", interval: 30,
              finding: "In every 30 min: sit 20, stand 8, move 2."),
        Study(name: "Belcher et al. 2015, J Clin Endocrinol Metab", ages: "7–11", interval: 30,
              finding: "3 min of walking every 30 min cut insulin by 32%."),
        Study(name: "Yates et al. 2020, J Gerontol A", ages: "65–79", interval: 30,
              finding: "5 min of light walking every 30 min helped. Standing alone did not."),
        Study(name: "Penning et al. 2017, BMC Public Health", ages: "13–14", interval: 20,
              finding: "Sitting for no more than 20 min at a time improved a blood-fat marker."),
    ]

    static var averageInterval: Double {
        Double(studies.reduce(0) { $0 + $1.interval }) / Double(studies.count)
    }
}

enum AgeGroup: String, CaseIterable, Identifiable {
    case kids
    case teens
    case adults
    case midlife
    case seniors

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kids: return "6–12"
        case .teens: return "13–17"
        case .adults: return "18–39"
        case .midlife: return "40–64"
        case .seniors: return "65+"
        }
    }

    var standEvery: Int {
        switch self {
        case .kids: return 30
        case .teens: return 25
        case .adults: return 27
        case .midlife: return 27
        case .seniors: return 30
        }
    }

    var moveFor: String {
        switch self {
        case .kids: return "3 min of brisk walking"
        case .teens: return "2–5 min of moving around"
        case .adults: return "2–5 min of light walking"
        case .midlife: return "2–5 min of light walking"
        case .seniors: return "5 min of light walking"
        }
    }

    var reason: String {
        switch self {
        case .kids:
            return "Kids who walked for 3 min every 30 min had much better insulin levels (Belcher 2015)."
        case .teens:
            return "Teen studies used 20 min, guidelines for kids use 30 min. TAB uses the average."
        case .adults:
            return "No trials exist for this age range yet, so TAB uses the average of all studies."
        case .midlife:
            return "Average of Dunstan 2012 (20 min), Duran 2023 (30 min) and Diaz 2017 (30 min)."
        case .seniors:
            return "Walk, don't just stand. Standing alone showed no benefit (Yates 2020)."
        }
    }
}

enum Tips {
    static let all = [
        "Walking beats standing. 5 min of light walking every 30 min lowered blood sugar in a 2023 Columbia study.",
        "Across \(Research.studies.count) studies, the average advice was to get up every \(Int(Research.averageInterval.rounded())) minutes.",
        "Every 20 min, look at something 20 feet away for 20 seconds. Your eyes will thank you.",
        "Even 2 minutes count. Short walks every 20 min helped in a 2012 study.",
        "In a study of 7,985 adults, people who sat less than 30 min at a time had the lowest risk.",
    ]

    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return all[day % all.count]
    }
}

struct Stretch: Equatable {
    let title: String
    let detail: String
    let symbol: String

    static let all: [Stretch] = [
        Stretch(title: "Reach for the sky", detail: "Stand tall, lace your fingers and stretch your arms up for 10 seconds.", symbol: "figure.arms.open"),
        Stretch(title: "Shoulder rolls", detail: "Roll your shoulders back 10 times, then forward 10 times.", symbol: "figure.cooldown"),
        Stretch(title: "Neck release", detail: "Tilt one ear toward your shoulder and hold for 15 seconds. Switch sides.", symbol: "figure.mind.and.body"),
        Stretch(title: "Hip opener", detail: "Step into a gentle lunge and hold for 20 seconds on each side.", symbol: "figure.flexibility"),
        Stretch(title: "Little walk", detail: "Walk around for two minutes and refill your glass on the way.", symbol: "figure.walk"),
        Stretch(title: "Calf raises", detail: "Rise up onto your toes 15 times to get the blood flowing.", symbol: "figure.stand"),
        Stretch(title: "Rest your eyes", detail: "Look at something far away for 20 seconds. Blink slowly.", symbol: "eye"),
        Stretch(title: "Chest opener", detail: "Clasp your hands behind your back and gently lift your arms.", symbol: "figure.arms.open"),
        Stretch(title: "Forward fold", detail: "Soften your knees and let your upper body hang for 20 seconds.", symbol: "figure.flexibility"),
        Stretch(title: "Wrist stretch", detail: "Hold one arm out and gently pull your fingers back. Then switch.", symbol: "hand.raised"),
    ]

    static func random(excluding current: Stretch? = nil) -> Stretch {
        let pool = all.filter { $0 != current }
        return pool.randomElement() ?? all[0]
    }
}
