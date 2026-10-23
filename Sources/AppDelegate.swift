import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private let store = HistoryStore()
    private lazy var engine = Engine(prefs: prefs, store: store)
    private lazy var mind = Mind(prefs: prefs, store: store, engine: engine)
    private var statusBar: StatusBarController?
    private var lockScreen: LockScreenController?
    private var banners: BannerController?
    private var mindOverlay: MindOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.enableOnFirstLaunch()

        let statusBar = StatusBarController(engine: engine, prefs: prefs, store: store, mind: mind)
        self.statusBar = statusBar
        lockScreen = LockScreenController(engine: engine, prefs: prefs, mind: mind)
        mindOverlay = MindOverlayController(mind: mind)
        banners = BannerController(
            engine: engine,
            prefs: prefs,
            mind: mind,
            anchor: { [weak statusBar] in statusBar?.anchorFrame },
            panelVisibility: statusBar.panelVisibility
        )
        engine.start()
        mind.start()

        if !UserDefaults.standard.bool(forKey: "welcomed") {
            UserDefaults.standard.set(true, forKey: "welcomed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { statusBar.showPanel() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "takeabreak" {
            switch url.host ?? "" {
            case "breathe": mind.begin(.breathing, minutes: Int(url.lastPathComponent) ?? 1)
            case "nsdr": mind.begin(.nsdr, minutes: Int(url.lastPathComponent) ?? prefs.mindGoal)
            case "meditate": mind.begin(.meditation, minutes: Int(url.lastPathComponent) ?? prefs.mindGoal)
            case "break": engine.beginBreak(.manual)
            case "back": engine.endBreak()
            case "water": engine.logWater(Int(url.lastPathComponent))
            case "stand": engine.logStand()
            case "pause": engine.pause(minutes: Int(url.lastPathComponent) ?? 60)
            case "resume": engine.resume()
            case "end": mind.finish(completed: false)
            case "log":
                let parts = url.pathComponents.filter { $0 != "/" }
                let kind = parts.first.flatMap { name in MindKind.allCases.first { $0.rawValue == name || (name == "sigh" && $0 == .breathing) } } ?? prefs.mindKind
                let minutes = parts.dropFirst().first.flatMap { Int($0) } ?? prefs.mindGoal
                mind.log(kind, minutes: minutes)
            default: statusBar?.showPanel()
            }
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
        mind.shutdown()
        engine.shutdown()
    }
}
