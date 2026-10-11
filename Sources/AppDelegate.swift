import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private let store = HistoryStore()
    private lazy var engine = Engine(prefs: prefs, store: store)
    private var statusBar: StatusBarController?
    private var lockScreen: LockScreenController?
    private var banners: BannerController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.enableOnFirstLaunch()

        let statusBar = StatusBarController(engine: engine, prefs: prefs, store: store)
        self.statusBar = statusBar
        lockScreen = LockScreenController(engine: engine, prefs: prefs)
        banners = BannerController(
            engine: engine,
            prefs: prefs,
            anchor: { [weak statusBar] in statusBar?.anchorFrame },
            panelVisibility: statusBar.panelVisibility
        )
        engine.start()

        if !UserDefaults.standard.bool(forKey: "welcomed") {
            UserDefaults.standard.set(true, forKey: "welcomed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { statusBar.showPanel() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.showPanel()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        engine.isScreenLocked && !engine.breakComplete ? .terminateCancel : .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.shutdown()
    }
}
