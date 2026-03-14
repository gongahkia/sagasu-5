import Foundation
import SagasuShared

enum LegacyScraperLogic {
    static func toMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }

    static func minutesToTimeString(_ minutes: Int) -> String {
        let hours = max(0, minutes / 60)
        let mins = max(0, minutes % 60)
        return String(format: "%02d:%02d", hours, mins)
    }

    static func parseTimeRange(_ timeRange: String) -> (Int, Int)? {
        let parts = timeRange.split(separator: "-").map(String.init)
        guard parts.count == 2 else { return nil }
        return (toMinutes(parts[0]), toMinutes(parts[1]))
    }

    static func extractBookingTime(_ raw: String) -> String? {
        let pattern = #"Booking Time: (\d{2}:\d{2}-\d{2}:\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard
            let match = regex.firstMatch(in: raw, options: [], range: range),
            let bookingRange = Range(match.range(at: 1), in: raw)
        else {
            return nil
        }

        return String(raw[bookingRange])
    }

    static func parseBookingDetails(_ details: String) -> ScrapedRoomsResponse.Room.TimeSlot.BookingDetails? {
        guard !details.isEmpty else { return nil }

        func value(for field: String) -> String? {
            let pattern = "\(NSRegularExpression.escapedPattern(for: field)):\\s*(.*)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                return nil
            }

            let range = NSRange(details.startIndex..<details.endIndex, in: details)
            guard
                let match = regex.firstMatch(in: details, options: [], range: range),
                let fieldRange = Range(match.range(at: 1), in: details)
            else {
                return nil
            }

            return String(details[fieldRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return .init(
            reference: value(for: "Booking Reference Number"),
            status: value(for: "Booking Status"),
            booker_name: value(for: "Booked for User Name"),
            booker_email: value(for: "Booked for User Email Address"),
            booker_org: value(for: "Booked for User Org Unit"),
            purpose: value(for: "Purpose of Booking"),
            use_type: value(for: "Use Type")
        )
    }

    static func generateTimeslots(from rawTimeslots: [String]) -> [ScrapedRoomsResponse.Room.TimeSlot] {
        struct RawSlot {
            let range: String
            let status: String
            let details: String
            let startMinutes: Int
            let endMinutes: Int
        }

        let notAvailablePattern = #"\((\d{2}:\d{2}-\d{2}:\d{2})\) \(not available\)"#

        var rawSlots: [RawSlot] = []

        for entry in rawTimeslots {
            if let regex = try? NSRegularExpression(pattern: notAvailablePattern),
               let match = regex.firstMatch(
                in: entry,
                options: [],
                range: NSRange(entry.startIndex..<entry.endIndex, in: entry)
               ),
               let slotRange = Range(match.range(at: 1), in: entry),
               let timeRange = parseTimeRange(String(entry[slotRange]))
            {
                rawSlots.append(
                    RawSlot(
                        range: String(entry[slotRange]),
                        status: "unavailable",
                        details: "Outside scrape window",
                        startMinutes: timeRange.0,
                        endMinutes: timeRange.1
                    )
                )
                continue
            }

            if let bookingRange = extractBookingTime(entry), let timeRange = parseTimeRange(bookingRange) {
                rawSlots.append(
                    RawSlot(
                        range: bookingRange,
                        status: "booked",
                        details: entry,
                        startMinutes: timeRange.0,
                        endMinutes: timeRange.1
                    )
                )
            }
        }

        rawSlots.sort { $0.startMinutes < $1.startMinutes }

        var output: [ScrapedRoomsResponse.Room.TimeSlot] = []
        var cursor = 0

        for slot in rawSlots {
            if slot.startMinutes > cursor {
                output.append(
                    .init(
                        start: minutesToTimeString(cursor),
                        end: minutesToTimeString(slot.startMinutes),
                        status: "free"
                    )
                )
            }

            let parts = slot.range.split(separator: "-").map(String.init)
            output.append(
                .init(
                    start: parts.first ?? "",
                    end: parts.last ?? "",
                    status: slot.status,
                    reason: slot.status == "unavailable" ? slot.details : nil,
                    booking: slot.status == "booked" ? parseBookingDetails(slot.details) : nil
                )
            )
            cursor = slot.endMinutes
        }

        if cursor < (24 * 60) {
            output.append(
                .init(
                    start: minutesToTimeString(cursor),
                    end: minutesToTimeString(24 * 60),
                    status: "free"
                )
            )
        }

        return output
    }
}
