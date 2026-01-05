import AppKit
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    func ensureAuthorization(interactive: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if interactive && !granted {
                        self.showInfo(message: "Notifications are disabled. Enable them in System Settings.")
                    }
                }
            case .denied:
                if interactive {
                    self.showInfo(message: "Notifications are disabled. Enable them in System Settings.")
                }
            case .authorized, .provisional, .ephemeral:
                if interactive {
                    self.showInfo(message: "Notifications are enabled for GhRunWatcher.")
                }
            @unknown default:
                break
            }
        }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func showInfo(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "GhRunWatcher"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
