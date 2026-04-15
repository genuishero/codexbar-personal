import Foundation
import UserNotifications

enum CodexBarNotificationCenter {
    static func deliver(
        title: String,
        subtitle: String? = nil,
        body: String,
        identifier: String = UUID().uuidString,
        sound: Bool = true
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let enqueue = {
                self.enqueue(
                    center: center,
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    identifier: identifier,
                    sound: sound
                )
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                enqueue()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    enqueue()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private static func enqueue(
        center: UNUserNotificationCenter,
        title: String,
        subtitle: String?,
        body: String,
        identifier: String,
        sound: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle, subtitle.isEmpty == false {
            content.subtitle = subtitle
        }
        content.body = body
        if sound {
            content.sound = .default
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }
}
