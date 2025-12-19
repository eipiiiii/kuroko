import Foundation
import EventKit

/// Tool for adding events to Apple Calendar.
class AppleCalendarAddTool: Tool {
    let name = "add_calendar_event"
    let description = "Add a new event to Apple Calendar"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "title": [
                "type": "string",
                "description": "Event title"
            ],
            "start_date": [
                "type": "string",
                "description": "Start date and time (ISO 8601 format, e.g., 2023-12-25T10:00:00)"
            ],
            "end_date": [
                "type": "string",
                "description": "End date and time (ISO 8601 format, e.g., 2023-12-25T11:00:00)"
            ],
            "description": [
                "type": "string",
                "description": "Event description (optional)"
            ],
            "calendar": [
                "type": "string",
                "description": "Calendar name (optional, defaults to default calendar)"
            ]
        ],
        "required": ["title", "start_date", "end_date"]
    ]

    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else {
            throw ToolError.missingRequiredParameter("title")
        }

        guard let startDateStr = arguments["start_date"] as? String,
              let startDate = ISO8601DateFormatter().date(from: startDateStr) else {
            throw ToolError.invalidArguments(toolName: name, details: "Invalid start_date format")
        }

        guard let endDateStr = arguments["end_date"] as? String,
              let endDate = ISO8601DateFormatter().date(from: endDateStr) else {
            throw ToolError.invalidArguments(toolName: name, details: "Invalid end_date format")
        }

        let eventStore = EKEventStore()

        // Request access (iOS 17+)
        let granted: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else {
            throw ToolError.executionFailed("Calendar access denied")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate

        if let description = arguments["description"] as? String {
            event.notes = description
        }

        if let calendarName = arguments["calendar"] as? String {
            if let calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarName }) {
                event.calendar = calendar
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        try eventStore.save(event, span: .thisEvent)

        return "Event '\(title)' added to calendar successfully"
    }
}

/// Tool for getting calendar events.
class AppleCalendarGetTool: Tool {
    let name = "get_calendar_events"
    let description = "Get calendar events for a specific date"
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "date": [
                "type": "string",
                "description": "Date (ISO 8601 format, e.g., 2023-12-25)"
            ],
            "calendar": [
                "type": "string",
                "description": "Calendar name (optional, defaults to all calendars)"
            ]
        ],
        "required": ["date"]
    ]

    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let dateStr = arguments["date"] as? String,
              let date = ISO8601DateFormatter().date(from: dateStr) else {
            throw ToolError.invalidArguments(toolName: name, details: "Invalid date format")
        }

        let eventStore = EKEventStore()

        // Request access (iOS 17+)
        let granted: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else {
            throw ToolError.executionFailed("Calendar access denied")
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        var calendars: [EKCalendar] = []
        if let calendarName = arguments["calendar"] as? String {
            if let calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarName }) {
                calendars = [calendar]
            } else {
                calendars = eventStore.calendars(for: .event)
            }
        } else {
            calendars = eventStore.calendars(for: .event)
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        if events.isEmpty {
            return "No events found for \(dateStr)"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var result = "Events for \(dateStr):\n"
        for (index, event) in events.enumerated() {
            result += "\(index + 1). \(event.title ?? "Untitled")\n"
            result += "   Start: \(formatter.string(from: event.startDate))\n"
            result += "   End: \(formatter.string(from: event.endDate))\n"
            if let notes = event.notes {
                result += "   Notes: \(notes)\n"
            }
            result += "\n"
        }

        return result
    }
}
