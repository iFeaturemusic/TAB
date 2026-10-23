import DeviceActivity
import Foundation

final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .focus { Lock.refresh() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .focus {
            Lock.focusEnded()
        } else if activity == .pass {
            Lock.endPass()
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if activity == .pass {
            Lock.passUsedUp()
        } else {
            Usage.record(event)
        }
    }
}
