import Foundation
import EventKit

/// Tool for adding reminders to Apple Reminders.
class AppleRemindersAddTool: Tool {
    let name = "add_reminder"
    let description = "Add a new reminder to Apple Reminders"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "title": [
                "type": "string",
                "description": "Reminder title"
            ],
            "due_date": [
                "type": "string",
                "description": "Due date and time (ISO 8601 format, optional)"
            ],
            "notes": [
                "type": "string",
                "description": "Reminder notes (optional)"
            ],
            "list": [
                "type": "string",
                "description": "Reminders list name (optional, defaults to default list)"
            ]
        ],
        "required": ["title"]
    ]

    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else {
            throw ToolError.missingRequiredParameter("title")
        }

        let eventStore = EKEventStore()

        // Request access (iOS 17+)
        let granted: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToReminders { granted, error in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else {
            throw ToolError.executionFailed("Reminders access denied")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title

        if let dueDateStr = arguments["due_date"] as? String,
           let dueDate = ISO8601DateFormatter().date(from: dueDateStr) {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        if let notes = arguments["notes"] as? String {
            reminder.notes = notes
        }

        if let listName = arguments["list"] as? String {
            if let list = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) {
                reminder.calendar = list
            } else {
                reminder.calendar = eventStore.defaultCalendarForNewReminders()
            }
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        try eventStore.save(reminder, commit: true)

        return "Reminder '\(title)' added successfully"
    }
}

/// Tool for getting reminders from Apple Reminders.
class AppleRemindersGetTool: Tool {
    let name = "get_reminders"
    let description = "Get reminders from Apple Reminders"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "list": [
                "type": "string",
                "description": "Reminders list name (optional, defaults to all lists)"
            ],
            "completed": [
                "type": "boolean",
                "description": "Include completed reminders (optional, defaults to false)"
            ]
        ],
        "required": []
    ]

    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        let eventStore = EKEventStore()

        // Request access (iOS 17+)
        let granted: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToReminders { granted, error in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else {
            throw ToolError.executionFailed("Reminders access denied")
        }

        var calendars: [EKCalendar] = []
        if let listName = arguments["list"] as? String {
            if let list = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) {
                calendars = [list]
            } else {
                calendars = eventStore.calendars(for: .reminder)
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let includeCompleted = arguments["completed"] as? Bool ?? false

        var reminders: [EKReminder] = []
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            let calendarReminders = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                    continuation.resume(returning: fetchedReminders ?? [])
                }
            }

            let filteredReminders = calendarReminders.filter { reminder in
                if includeCompleted {
                    return true
                } else {
                    return !(reminder.isCompleted)
                }
            }
            reminders.append(contentsOf: filteredReminders)
        }

        if reminders.isEmpty {
            return "No reminders found"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var result = "Reminders:\n"
        for (index, reminder) in reminders.enumerated() {
            result += "\(index + 1). \(reminder.title ?? "Untitled")\n"
            if let dueDate = reminder.dueDateComponents {
                let date = Calendar.current.date(from: dueDate)
                if let date = date {
                    result += "   Due: \(formatter.string(from: date))\n"
                }
            }
            if let notes = reminder.notes {
                result += "   Notes: \(notes)\n"
            }
            result += "   Completed: \(reminder.isCompleted)\n\n"
        }

        return result
    }
}
