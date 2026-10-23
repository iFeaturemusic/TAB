import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

@main
struct TABReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayReport { summary in
            TodayReportView(summary: summary)
        }
    }
}

struct AppTime: Identifiable {
    let name: String
    let token: ApplicationToken?
    let seconds: TimeInterval
    var id: String { name }
}

struct TodaySummary {
    var total: TimeInterval = 0
    var pickups = 0
    var apps: [AppTime] = []
}

struct TodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .today
    let content: (TodaySummary) -> TodayReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TodaySummary {
        var summary = TodaySummary()
        var apps: [String: (token: ApplicationToken?, seconds: TimeInterval)] = [:]
        for await device in data {
            for await segment in device.activitySegments {
                summary.total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "App"
                        summary.pickups += app.numberOfPickups
                        let current = apps[name] ?? (app.application.token, 0)
                        apps[name] = (current.token ?? app.application.token, current.seconds + app.totalActivityDuration)
                    }
                }
            }
        }
        summary.apps = apps
            .map { AppTime(name: $0.key, token: $0.value.token, seconds: $0.value.seconds) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(6)
            .map { $0 }
        return summary
    }
}

struct TodayReportView: View {
    let summary: TodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.duration(Int(summary.total)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("on your iPhone")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.dim)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(summary.pickups)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("pickups")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
            }
            let top = summary.apps.first?.seconds ?? 1
            ForEach(summary.apps) { app in
                HStack(spacing: 10) {
                    if let token = app.token {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(width: 26, height: 26)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(app.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(Fmt.duration(Int(app.seconds)))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(Theme.dim)
                        }
                        BarView(progress: app.seconds / max(1, top), color: Theme.digital)
                    }
                }
            }
            if summary.apps.isEmpty {
                Text("Nothing yet today. Nice.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
    }
}
