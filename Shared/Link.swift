import Foundation
import Network

enum LinkProtocol {
    static let service = "_tabsync._tcp"

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

struct MacFocus: Codable, Equatable {
    enum State: String, Codable {
        case focus
        case rest
        case off
    }

    var state: State
    var until: Date
    var lockPhone: Bool
    var updated: Date

    init(state: State, until: Date, lockPhone: Bool, updated: Date = Date()) {
        self.state = state
        self.until = until
        self.lockPhone = lockPhone
        self.updated = updated
    }

    var locksNow: Bool { state == .focus && lockPhone && until > Date() }

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["tab"],
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let focus = try? LinkProtocol.decoder.decode(MacFocus.self, from: data) else { return nil }
        self = focus
    }
}

struct PhoneDaySummary: Codable, Equatable {
    var minutes = 0
    var apps: [String: Int] = [:]
    var passes = 0
    var passMinutes = 0
    var updated = Date.distantPast

    var socialMinutes: Int { apps.values.reduce(0, +) }
}

struct PhoneHello: Codable {
    var deviceID: String
    var name: String
    var pushToken: String?
    var sandbox: Bool
    var topic: String
    var teamID: String
    var pairing: Bool
    var days: [String: PhoneDaySummary]
}

struct MacReply: Codable {
    var accepted: Bool
    var macName: String
    var focus: MacFocus?
    var message: String?
}

enum Framing {
    static func send<T: Encodable>(_ value: T, on connection: NWConnection, completion: @escaping (Bool) -> Void) {
        guard let body = try? LinkProtocol.encoder.encode(value) else { return completion(false) }
        var length = UInt32(body.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { error in completion(error == nil) })
    }

    static func receive<T: Decodable>(_ type: T.Type, on connection: NWConnection, completion: @escaping (T?) -> Void) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { header, _, _, error in
            guard error == nil, let header, header.count == 4 else { return completion(nil) }
            let length = header.reduce(0) { ($0 << 8) | Int($1) }
            guard length > 0, length < 1_000_000 else { return completion(nil) }
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { body, _, _, error in
                guard error == nil, let body else { return completion(nil) }
                completion(try? LinkProtocol.decoder.decode(T.self, from: body))
            }
        }
    }
}
