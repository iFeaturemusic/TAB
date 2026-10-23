import Combine
import CryptoKit
import Foundation
import Network
import OSLog
import Security

struct PairedPhone: Codable, Equatable, Identifiable {
    var deviceID: String
    var name: String
    var token: String?
    var sandbox: Bool
    var topic: String
    var teamID: String
    var lastSeen: Date

    var id: String { deviceID }
}

enum Keychain {
    static func save(_ data: Data, service: String, account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}

final class PhoneLink: ObservableObject {
    @Published private(set) var phones: [PairedPhone]
    @Published private(set) var pairingUntil: Date?
    @Published private(set) var keyID: String?
    @Published private(set) var lastPhoneUpdate: Date?
    @Published private(set) var error: String?

    let available = true

    private let engine: Engine
    private let prefs: Preferences
    private let store: HistoryStore
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "tab.phonelink")
    private let session = URLSession(configuration: .ephemeral)
    private let log = Logger(subsystem: "com.ifeature.TAB", category: "phone")
    private var listener: NWListener?
    private var bag = Set<AnyCancellable>()
    private var lastSent: MacFocus?
    private var jwt: (value: String, made: Date, team: String)?

    private static let keyService = "com.ifeature.TAB.apns"

    init(engine: Engine, prefs: Preferences, store: HistoryStore) {
        self.engine = engine
        self.prefs = prefs
        self.store = store
        if let data = defaults.data(forKey: "pairedPhones"),
           let saved = try? JSONDecoder().decode([PairedPhone].self, from: data) {
            phones = saved
        } else {
            phones = []
        }
        keyID = defaults.string(forKey: "apnsKeyID")
        lastPhoneUpdate = phones.map(\.lastSeen).max()
    }

    var macName: String { Host.current().localizedName ?? "Mac" }
    var isPairing: Bool { (pairingUntil ?? .distantPast) > Date() }

    func start() {
        if let path = defaults.string(forKey: "importKeyPath") {
            defaults.removeObject(forKey: "importKeyPath")
            do {
                try importKey(from: URL(fileURLWithPath: path))
            } catch {
                self.error = error.localizedDescription
            }
        }
        startListener()
        engine.objectWillChange
            .merge(with: prefs.objectWillChange)
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.sendIfNeeded() }
            .store(in: &bag)
        sendIfNeeded(force: true)
    }

    func shutdown() {
        let targets = phones.filter { $0.token != nil }
        guard prefs.lockPhone, !targets.isEmpty else { return }
        let group = DispatchGroup()
        let off = MacFocus(state: .off, until: Date(), lockPhone: false)
        for phone in targets {
            group.enter()
            push(off, to: phone, onMain: false) { group.leave() }
        }
        _ = group.wait(timeout: .now() + 3)
    }

    func beginPairing() {
        pairingUntil = Date().addingTimeInterval(300)
    }

    func cancelPairing() {
        pairingUntil = nil
    }

    func forget(_ phone: PairedPhone) {
        phones.removeAll { $0.deviceID == phone.deviceID }
        savePhones()
    }

    func importKey(from url: URL) throws {
        let pem = try String(contentsOf: url, encoding: .utf8)
        _ = try P256.Signing.PrivateKey(pemRepresentation: pem)
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("AuthKey_"), name.count == 18 else {
            throw NSError(domain: "TAB", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose the AuthKey_XXXXXXXXXX.p8 file from your developer account."])
        }
        let id = String(name.dropFirst(8))
        guard Keychain.save(Data(pem.utf8), service: Self.keyService, account: id) else {
            throw NSError(domain: "TAB", code: 2, userInfo: [NSLocalizedDescriptionKey: "TAB couldn't save the key in your keychain."])
        }
        defaults.set(id, forKey: "apnsKeyID")
        keyID = id
        jwt = nil
        error = nil
        log.info("push key \(id, privacy: .public) imported")
        sendIfNeeded(force: true)
    }

    private var current: MacFocus {
        switch engine.phase {
        case .focus where engine.nudge != .breakTime:
            return MacFocus(state: .focus, until: Date().addingTimeInterval(TimeInterval(engine.focusLeft)), lockPhone: prefs.lockPhone)
        case .focus, .onBreak, .away:
            return MacFocus(state: .rest, until: Date(), lockPhone: prefs.lockPhone)
        case .paused:
            return MacFocus(state: .off, until: Date(), lockPhone: prefs.lockPhone)
        }
    }

    private func sendIfNeeded(force: Bool = false) {
        let state = current
        if !force, let last = lastSent, last.state == state.state, last.lockPhone == state.lockPhone,
           state.state != .focus || abs(last.until.timeIntervalSince(state.until)) < 45 {
            return
        }
        lastSent = state
        for phone in phones where phone.token != nil {
            push(state, to: phone)
        }
    }

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: macName, type: LinkProtocol.service)
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    self?.log.error("listener failed: \(String(describing: error), privacy: .public)")
                    listener.cancel()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.startListener() }
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            log.error("listener: \(String(describing: error), privacy: .public)")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        Framing.receive(PhoneHello.self, on: connection) { [weak self] hello in
            guard let self, let hello else {
                connection.cancel()
                return
            }
            DispatchQueue.main.async {
                let reply = self.handle(hello)
                Framing.send(reply, on: connection) { _ in
                    self.queue.asyncAfter(deadline: .now() + 1) { connection.cancel() }
                }
            }
        }
    }

    private func handle(_ hello: PhoneHello) -> MacReply {
        let existing = phones.firstIndex { $0.deviceID == hello.deviceID }
        guard existing != nil || isPairing else {
            return MacReply(accepted: false, macName: macName, focus: nil,
                            message: "On your Mac, open TAB › Settings › Digital hygiene and click Pair.")
        }
        var phone = existing.map { phones[$0] } ?? PairedPhone(
            deviceID: hello.deviceID, name: hello.name, token: nil, sandbox: hello.sandbox,
            topic: hello.topic, teamID: hello.teamID, lastSeen: Date()
        )
        let tokenChanged = hello.pushToken != nil && hello.pushToken != phone.token
        phone.name = hello.name
        if let token = hello.pushToken { phone.token = token }
        phone.sandbox = hello.sandbox
        phone.topic = hello.topic
        phone.teamID = hello.teamID
        phone.lastSeen = Date()
        if let existing { phones[existing] = phone } else { phones.append(phone) }
        if existing == nil {
            pairingUntil = nil
            log.info("paired \(phone.name, privacy: .public)")
        }
        savePhones()
        if tokenChanged { lastSent = nil }

        for (key, summary) in hello.days {
            guard let date = HistoryStore.date(fromKey: key) else { continue }
            store.update(date) { day in
                day.phoneMinutes = summary.minutes
                day.phoneApps = summary.apps
                day.phonePasses = summary.passes
                day.phonePassMinutes = summary.passMinutes
            }
        }
        lastPhoneUpdate = Date()
        error = nil
        return MacReply(accepted: true, macName: macName, focus: current, message: nil)
    }

    private func savePhones() {
        if let data = try? JSONEncoder().encode(phones) { defaults.set(data, forKey: "pairedPhones") }
    }

    private func push(_ state: MacFocus, to phone: PairedPhone, onMain: Bool = true, completion: (() -> Void)? = nil) {
        guard let token = phone.token, let jwt = makeJWT(team: phone.teamID),
              let url = URL(string: "https://\(phone.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com")/3/device/\(token)") else {
            if keyID == nil { error = "Add your push key so TAB can lock your iPhone instantly." }
            completion?()
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue(phone.topic, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue("tab-state", forHTTPHeaderField: "apns-collapse-id")
        let expires = state.state == .focus ? state.until : Date().addingTimeInterval(3600)
        request.setValue(String(Int(expires.timeIntervalSince1970)), forHTTPHeaderField: "apns-expiration")
        request.httpBody = payload(state)

        let deviceID = phone.deviceID
        session.dataTask(with: request) { [weak self] data, response, failure in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let reason = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["reason"] as? String
            let finish = {
                self?.handlePush(status: status, reason: reason, failed: failure != nil, state: state, deviceID: deviceID)
                completion?()
            }
            if onMain { DispatchQueue.main.async(execute: finish) } else { completion?() }
        }.resume()
    }

    private func handlePush(status: Int, reason: String?, failed: Bool, state: MacFocus, deviceID: String) {
        if status == 200 {
            log.info("pushed \(state.state.rawValue, privacy: .public)")
            error = nil
            return
        }
        log.error("push \(status, privacy: .public) \(reason ?? "no reply", privacy: .public)")
        switch reason {
        case "BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic":
            if let index = phones.firstIndex(where: { $0.deviceID == deviceID }) {
                phones[index].token = nil
                savePhones()
            }
            error = "Open TAB on your iPhone once so it can reconnect."
        case "InvalidProviderToken", "ExpiredProviderToken":
            jwt = nil
            error = "Your push key doesn't fit this app. Choose the AuthKey file from the same developer team."
        default:
            error = failed ? "No internet connection." : "Couldn't reach your iPhone (\(reason ?? "\(status)"))."
        }
    }

    private func payload(_ state: MacFocus) -> Data {
        let time = Fmt.time(state.until)
        let title: String
        let body: String
        switch state.state {
        case .focus where state.lockPhone:
            title = "Focus time"
            body = "Your iPhone is locked until \(time)."
        case .focus:
            title = "Focus time"
            body = "Your Mac is focusing until \(time)."
        case .rest:
            title = "Break time"
            body = "Your iPhone is free. Enjoy your break."
        case .off:
            title = "TAB is paused"
            body = "Your iPhone is free."
        }
        let tab = (try? LinkProtocol.encoder.encode(state)).flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? [String: Any]()
        let json: [String: Any] = [
            "aps": [
                "alert": ["title": title, "body": body],
                "mutable-content": 1,
                "interruption-level": "passive",
                "thread-id": "tab",
            ] as [String: Any],
            "tab": tab,
        ]
        return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    }

    private func makeJWT(team: String) -> String? {
        if let jwt, jwt.team == team, Date().timeIntervalSince(jwt.made) < 40 * 60 { return jwt.value }
        guard let keyID, !team.isEmpty,
              let data = Keychain.read(service: Self.keyService, account: keyID),
              let pem = String(data: data, encoding: .utf8),
              let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else { return nil }

        func encode(_ object: [String: Any]) -> String {
            base64url((try? JSONSerialization.data(withJSONObject: object)) ?? Data())
        }
        let input = encode(["alg": "ES256", "kid": keyID]) + "." + encode(["iss": team, "iat": Int(Date().timeIntervalSince1970)])
        guard let signature = try? key.signature(for: Data(input.utf8)) else { return nil }
        let token = input + "." + base64url(signature.rawRepresentation)
        jwt = (token, Date(), team)
        return token
    }

    private func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
