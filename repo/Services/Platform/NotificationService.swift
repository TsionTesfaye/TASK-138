import Foundation

// UserNotifications is Apple-only. On Linux this class is unavailable entirely;
// no tests exercise notifications, so this is safe.
#if canImport(UserNotifications)
import UserNotifications

/// Real UNUserNotificationCenter wrapper for SLA alerts and reminders.
/// Fully offline — no push notifications, local only.
final class NotificationService {

    static let shared = NotificationService()

    /// Request notification permission on first use.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }

    /// Schedule a local notification for an SLA violation on a lead.
    func scheduleLeadSLAAlert(leadId: UUID, customerName: String, deadline: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Lead SLA Violation"
        content.body = "Lead for \(customerName) has exceeded the 2-hour SLA deadline."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "sla-lead-\(leadId.uuidString)",
            content: content, trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a local notification for an unconfirmed appointment.
    func scheduleAppointmentSLAAlert(appointmentId: UUID, startTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Appointment Not Confirmed"
        content.body = "An appointment starting at \(startTime) has not been confirmed."
        content.sound = .default

        // Alert 30 minutes before start
        let alertTime = startTime.addingTimeInterval(-30 * 60)
        let interval = max(1, alertTime.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: "sla-appt-\(appointmentId.uuidString)",
            content: content, trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a reminder notification.
    func scheduleReminderNotification(reminderId: UUID, dueAt: Date, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = message
        content.sound = .default

        let interval = max(1, dueAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: "reminder-\(reminderId.uuidString)",
            content: content, trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule an immediate local notification (fires within 1 second).
    /// Used by SLA violation detection to alert on first detection.
    func scheduleImmediateNotification(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a specific notification.
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }
}
#else
/// Linux stub for NotificationService.
/// The real implementation wraps UNUserNotificationCenter, which is Apple-only.
/// On Linux (CI) all methods are no-ops so call sites in platform-agnostic code
/// (e.g. SLAService) compile and run without needing `#if canImport` guards.
final class NotificationService {
    static let shared = NotificationService()
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func scheduleLeadSLAAlert(leadId: UUID, customerName: String, deadline: Date) {}
    func scheduleAppointmentSLAAlert(appointmentId: UUID, startTime: Date) {}
    func scheduleReminderNotification(reminderId: UUID, dueAt: Date, message: String) {}
    func scheduleImmediateNotification(identifier: String, title: String, body: String) {}
    func cancelNotification(identifier: String) {}
}
#endif
