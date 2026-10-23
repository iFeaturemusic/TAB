import UserNotifications

final class NotifyExtension: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        self.content = content

        guard let focus = MacFocus(userInfo: request.content.userInfo) else {
            contentHandler(content)
            return
        }
        Lock.follow(focus)

        let config = PhoneStore.shared.config
        if focus.locksNow && !config.ready {
            content.body = "Finish setting up TAB on your iPhone so it can lock with your Mac."
        } else if focus.locksNow && !config.lockWithMac {
            content.body = "Your Mac is focusing. Locking is turned off on this iPhone."
        }

        Task {
            _ = await MacLink.shared.sync(timeout: 5)
            self.deliver()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        deliver()
    }

    private func deliver() {
        guard let handler, let content else { return }
        self.handler = nil
        handler(content)
    }
}
