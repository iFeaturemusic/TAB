import Foundation

final class HistoryStore: ObservableObject {
    @Published private(set) var days: [String: DayLog] = [:]

    private let fileURL: URL?
    private var savePending = false

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TAB", isDirectory: true).appendingPathComponent("history.json")
    }

    init(fileURL: URL? = HistoryStore.defaultURL) {
        self.fileURL = fileURL
        load()
    }

    init(preview days: [DayLog]) {
        fileURL = nil
        self.days = Dictionary(uniqueKeysWithValues: days.map { ($0.key, $0) })
    }

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    func log(_ date: Date = Date()) -> DayLog {
        let k = Self.key(date)
        return days[k] ?? DayLog(key: k)
    }

    var today: DayLog { log() }

    func update(_ date: Date = Date(), _ change: (inout DayLog) -> Void) {
        let k = Self.key(date)
        var day = days[k] ?? DayLog(key: k)
        change(&day)
        days[k] = day
        scheduleSave()
    }

    func logs(from start: Date, to end: Date) -> [DayLog] {
        let cal = Calendar.current
        var result: [DayLog] = []
        var cursor = cal.startOfDay(for: start)
        while cursor < end {
            if let day = days[Self.key(cursor)] { result.append(day) }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    var firstDate: Date? {
        days.keys.sorted().first.flatMap(Self.date(fromKey:))
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let list = try? decoder.decode([DayLog].self, from: data) {
            days = Dictionary(list.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        }
    }

    private func scheduleSave() {
        guard fileURL != nil, !savePending else { return }
        savePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.save()
        }
    }

    func save() {
        savePending = false
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let list = days.values.sorted { $0.key < $1.key }
        guard let data = try? encoder.encode(list) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    func eraseAll() {
        days = [:]
        save()
    }

    func csv() -> String {
        var rows = ["date,focus_minutes,breaks,break_minutes,skipped_breaks,water_ml,water_goal_ml,stand_ups,longest_sit_minutes,health_score"]
        for day in days.values.sorted(by: { $0.key < $1.key }) {
            let fields: [String] = [
                day.key,
                String(day.focusSeconds / 60),
                String(day.breakCount),
                String(day.breakSeconds / 60),
                String(day.skippedBreaks),
                String(day.waterML),
                String(day.waterGoal),
                String(day.standCount),
                String(day.longestSit / 60),
                day.healthScore.map(String.init) ?? "",
            ]
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }
}
