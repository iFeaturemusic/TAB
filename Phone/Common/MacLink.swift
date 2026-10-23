import Foundation
import Network
import UIKit

final class MacLink {
    static let shared = MacLink()

    private let defaults = UserDefaults(suiteName: PhoneStore.group) ?? .standard
    private let queue = DispatchQueue(label: "tab.maclink")

    var deviceID: String {
        if let id = defaults.string(forKey: "deviceID") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "deviceID")
        return id
    }

    var pushToken: String? {
        get { defaults.string(forKey: "pushToken") }
        set { defaults.set(newValue, forKey: "pushToken") }
    }

    var macName: String? {
        get { defaults.string(forKey: "macName") }
        set { defaults.set(newValue, forKey: "macName") }
    }

    var lastSync: Date? {
        get { defaults.object(forKey: "lastSync") as? Date }
        set { defaults.set(newValue, forKey: "lastSync") }
    }

    var sandbox: Bool {
        get { defaults.object(forKey: "sandbox") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "sandbox") }
    }

    static func detectSandbox() -> Bool {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>") else { return false }
        let xml = Data(text[start.lowerBound..<end.upperBound].utf8)
        let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any]
        let entitlements = plist?["Entitlements"] as? [String: Any]
        return (entitlements?["aps-environment"] as? String) == "development"
    }

    private func hello(pairing: Bool) -> PhoneHello {
        let days = PhoneStore.shared.days
        var summaries: [String: PhoneDaySummary] = [:]
        for offset in 0..<7 {
            let key = LinkProtocol.dayKey(Date().addingTimeInterval(-Double(offset) * 86400))
            guard let day = days[key] ?? (offset == 0 ? PhoneDay() : nil) else { continue }
            summaries[key] = PhoneDaySummary(
                minutes: day.minutes,
                apps: day.apps,
                passes: day.passes,
                passMinutes: day.passMinutes,
                updated: offset == 0 ? Date() : day.updated
            )
        }
        return PhoneHello(
            deviceID: deviceID,
            name: UIDevice.current.name,
            pushToken: pushToken,
            sandbox: sandbox,
            topic: Bundle.main.object(forInfoDictionaryKey: "TABPushTopic") as? String ?? "",
            teamID: Bundle.main.object(forInfoDictionaryKey: "TABTeamID") as? String ?? "",
            pairing: pairing,
            days: summaries
        )
    }

    func sync(pairing: Bool = false, timeout: TimeInterval = 6) async -> MacReply? {
        let message = hello(pairing: pairing)
        let wanted = macName
        let reply: MacReply? = await withCheckedContinuation { continuation in
            let state = SyncState()
            let browser = NWBrowser(for: .bonjour(type: LinkProtocol.service, domain: nil), using: .tcp)

            func finish(_ reply: MacReply?) {
                guard !state.done else { return }
                state.done = true
                browser.cancel()
                state.connection?.cancel()
                continuation.resume(returning: reply)
            }

            browser.browseResultsChangedHandler = { results, _ in
                guard state.connection == nil else { return }
                let match = results.first { result in
                    if case .service(let name, _, _, _) = result.endpoint { return name == wanted }
                    return false
                }
                guard let result = match ?? (wanted == nil || pairing ? results.first : nil) else { return }
                let connection = NWConnection(to: result.endpoint, using: .tcp)
                state.connection = connection
                connection.stateUpdateHandler = { status in
                    switch status {
                    case .ready:
                        Framing.send(message, on: connection) { ok in
                            guard ok else { return finish(nil) }
                            Framing.receive(MacReply.self, on: connection) { finish($0) }
                        }
                    case .failed, .cancelled:
                        finish(nil)
                    default:
                        break
                    }
                }
                connection.start(queue: self.queue)
            }
            browser.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }

        if let reply, reply.accepted {
            macName = reply.macName
            lastSync = Date()
            Lock.follow(reply.focus)
        }
        return reply
    }
}

private final class SyncState {
    var done = false
    var connection: NWConnection?
}
