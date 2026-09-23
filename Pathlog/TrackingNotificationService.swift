import UserNotifications

enum TrackingReminderSetupResult {
    case scheduled
    case permissionDenied
    case failed
}

@MainActor
final class TrackingNotificationService {
    private static let reminderIdentifier = "pathlog.tracking-reminder"
    private static let reminderInterval: TimeInterval = 2 * 60 * 60

    private let center = UNUserNotificationCenter.current()

    func scheduleTrackingReminder() async -> TrackingReminderSetupResult {
        let currentSettings = await center.notificationSettings()

        if currentSettings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert])
            } catch {
                return .failed
            }
        }

        let settings = await center.notificationSettings()
        guard isAuthorized(settings.authorizationStatus) else {
            return .permissionDenied
        }

        let pendingRequests = await center.pendingNotificationRequests()
        if pendingRequests.contains(where: { $0.identifier == Self.reminderIdentifier }) {
            return .scheduled
        }

        let content = UNMutableNotificationContent()
        content.title = "Pathlog tracking is active"
        content.body = "Your route is still being recorded. Open Pathlog to stop tracking."
        content.threadIdentifier = "pathlog-tracking"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.reminderInterval,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return .scheduled
        } catch {
            return .failed
        }
    }

    func cancelTrackingReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.reminderIdentifier])
    }

    private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
