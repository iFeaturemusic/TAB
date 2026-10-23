import BackgroundTasks
import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

@main
struct TABPhoneApp: App {
    @UIApplicationDelegateAdaptor(PhoneAppDelegate.self) private var delegate
    @StateObject private var model = PhoneModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await model.sync() } }
        }
    }
}

final class PhoneAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let refreshTask = "com.ifeature.TAB.mobile.refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MacLink.shared.sandbox = MacLink.detectSandbox()
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTask, using: nil) { task in
            Self.scheduleRefresh()
            let work = Task {
                _ = await MacLink.shared.sync()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
        Self.scheduleRefresh()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard token != MacLink.shared.pushToken else { return }
        MacLink.shared.pushToken = token
        Task { await PhoneModel.shared.sync() }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let focus = MacFocus(userInfo: notification.request.content.userInfo) {
            Lock.follow(focus)
            await MainActor.run { PhoneModel.shared.reload() }
        }
        return [.list]
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date().addingTimeInterval(20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

@MainActor
final class PhoneModel: ObservableObject {
    static let shared = PhoneModel()

    @Published var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @Published var config: PhoneConfig {
        didSet {
            guard config != oldValue else { return }
            PhoneStore.shared.config = config
            Lock.refresh()
            if config.social != oldValue.social || config.everything != oldValue.everything {
                scheduleUsageRestart()
            } else if config.names != oldValue.names {
                Usage.updateNames()
            }
        }
    }
    @Published private(set) var focus = PhoneStore.shared.focus
    @Published private(set) var today = PhoneStore.shared.day()
    @Published private(set) var syncing = false
    @Published private(set) var macName = MacLink.shared.macName
    @Published private(set) var lastSync = MacLink.shared.lastSync
    @Published private(set) var message: String?
    @Published private(set) var notificationsAllowed = true

    private var restartTask: Task<Void, Never>?

    init() {
        config = PhoneStore.shared.config
        if authorized && PhoneStore.shared.usageStarted == nil {
            Usage.restart()
        }
        Task { await checkNotifications() }
    }

    var paired: Bool { macName != nil }

    func requestAccess() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            message = error.localizedDescription
        }
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if authorized {
            Usage.restart()
            await sync()
        }
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        await checkNotifications()
        UIApplication.shared.registerForRemoteNotifications()
    }

    func checkNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAllowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func sync(pairing: Bool = false) async {
        guard !syncing else { return }
        syncing = true
        let reply = await MacLink.shared.sync(pairing: pairing)
        if let reply {
            message = reply.accepted ? nil : reply.message
        } else if pairing || !paired {
            message = "Can't find your Mac. Make sure TAB is running on it and both are on the same Wi-Fi."
        } else {
            message = nil
        }
        macName = MacLink.shared.macName
        lastSync = MacLink.shared.lastSync
        reload()
        syncing = false
    }

    func reload() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        focus = PhoneStore.shared.focus
        today = PhoneStore.shared.day()
    }

    private func scheduleUsageRestart() {
        restartTask?.cancel()
        restartTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            Usage.restart()
        }
    }
}
