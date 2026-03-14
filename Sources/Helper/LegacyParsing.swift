import Foundation
import SagasuShared

enum LegacyScraperLogic {
    private static let buildingMap: [String: String] = [
        "KGC": "Kwa Geok Choo Law Library",
        "YPHSL": "Yong Pung How School of Law",
        "LKCSB": "Lee Kong Chian School of Business",
        "SOA": "School of Accountancy",
        "SCIS": "School of Computing & Information Systems",
        "SOE": "School of Economics",
        "SOSS": "School of Social Sciences",
        "CIS": "College of Integrative Studies",
        "LKSL": "Li Ka Shing Library",
        "AB": "Administration Building",
        "SMUC": "SMU Connexion"
    ]

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

    static func mapTimeslotsToRooms(rawRooms: [String], rawTimeslots: [String]) -> [String: [ScrapedRoomsResponse.Room.TimeSlot]] {
        var result: [String: [ScrapedRoomsResponse.Room.TimeSlot]] = [:]
        let roomStartPattern = try? NSRegularExpression(pattern: #"^\(00:00-\d{2}:\d{2}\) \(not available\)$"#)

        var currentRoomIndex = 0
        var accumulator: [String] = []

        for timeslot in rawTimeslots {
            let isRoomStart = roomStartPattern.map {
                $0.firstMatch(in: timeslot, options: [], range: NSRange(timeslot.startIndex..<timeslot.endIndex, in: timeslot)) != nil
            } ?? false

            if isRoomStart, !accumulator.isEmpty, currentRoomIndex < rawRooms.count {
                result[rawRooms[currentRoomIndex]] = generateTimeslots(from: accumulator)
                currentRoomIndex += 1
                accumulator = []
            }

            accumulator.append(timeslot)
        }

        if !accumulator.isEmpty, currentRoomIndex < rawRooms.count {
            result[rawRooms[currentRoomIndex]] = generateTimeslots(from: accumulator)
            currentRoomIndex += 1
        }

        while currentRoomIndex < rawRooms.count {
            result[rawRooms[currentRoomIndex]] = [
                .init(start: "00:00", end: "24:00", status: "free")
            ]
            currentRoomIndex += 1
        }

        return result
    }

    static func extractRoomMetadata(
        roomName: String,
        filters: ScrapeConfiguration.Filters
    ) -> (buildingCode: String, building: String, floor: String, facilityType: String, equipment: [String]) {
        let buildingCode = roomName.split(separator: "-").first.map(String.init) ?? ""

        let floor: String = {
            guard let match = roomName.range(of: #"\-(\d+|B\d+)\."#, options: .regularExpression) else {
                return "Unknown"
            }

            let fragment = String(roomName[match]).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ".", with: "")
            if fragment.hasPrefix("B") {
                return "Basement \(fragment.dropFirst())"
            }

            return "Level \(fragment)"
        }()

        let building = buildingMap[buildingCode] ?? filters.buildings.first ?? "Unknown"
        let facilityType = filters.facilityTypes.first ?? "Unknown"

        return (buildingCode, building, floor, facilityType, filters.equipment)
    }

    static func calculateAvailabilitySummary(
        timeslots: [ScrapedRoomsResponse.Room.TimeSlot],
        now: Date = Date()
    ) -> ScrapedRoomsResponse.Room.AvailabilitySummary {
        let currentMinutes = Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)

        var freeCount = 0
        var freeDuration = 0
        var isAvailableNow = false
        var nextAvailableAt: String?

        for slot in timeslots where slot.status == "free" {
            freeCount += 1
            let start = toMinutes(slot.start)
            let end = toMinutes(slot.end)
            freeDuration += max(0, end - start)

            if start <= currentMinutes && currentMinutes < end {
                isAvailableNow = true
            }

            if !isAvailableNow, start > currentMinutes, nextAvailableAt == nil {
                let nextDate = Calendar.current.date(
                    bySettingHour: start / 60,
                    minute: start % 60,
                    second: 0,
                    of: now
                )
                nextAvailableAt = nextDate?.iso8601String
            }
        }

        return .init(
            is_available_now: isAvailableNow,
            next_available_at: nextAvailableAt,
            free_slots_count: freeCount,
            free_duration_minutes: freeDuration
        )
    }

    static func parseBookingRow(_ cells: [String]) -> ScrapedBookingsResponse.Booking? {
        guard cells.count >= 9 else { return nil }

        let dateTimeRaw = cells[2]
        let components = splitDateTime(dateTimeRaw)
        return .init(
            reference_number: cells[1],
            date: components.date,
            day_of_week: components.dayOfWeek,
            start_time: components.startTime,
            end_time: components.endTime,
            duration_hours: components.durationHours,
            building: cells[3],
            room_name: cells[4],
            booked_by: cells[5],
            booking_type: cells[6],
            price: Double(cells[7]) ?? 0,
            status: cells[8],
            raw_datetime: dateTimeRaw
        )
    }

    static func parseTaskRow(_ cells: [String]) -> ScrapedTasksResponse.Task? {
        guard cells.count >= 8 else { return nil }

        let dateTimeRaw = cells[2]
        let components = splitDateTime(dateTimeRaw)
        return .init(
            reference_number: cells[1],
            date: components.date,
            start_time: components.startTime,
            end_time: components.endTime,
            duration_hours: components.durationHours,
            building: cells[3],
            room_name: cells[4],
            task_type: cells[5],
            requested_by: cells[6],
            status: cells[7],
            raw_datetime: dateTimeRaw
        )
    }

    static func bookingStatistics(from bookings: [ScrapedBookingsResponse.Booking]) -> ScrapedBookingsResponse.Statistics {
        .init(
            total_bookings: bookings.count,
            confirmed_bookings: bookings.filter { $0.status == "Confirmed" }.count,
            pending_bookings: bookings.filter { $0.status == "Pending Confirmation" }.count,
            total_price: bookings.reduce(0) { $0 + $1.price }
        )
    }

    static func taskStatistics(from tasks: [ScrapedTasksResponse.Task]) -> ScrapedTasksResponse.Statistics {
        .init(
            total_tasks: tasks.count,
            pending_tasks: tasks.filter { $0.status == "Pending Confirmation" }.count,
            approved_tasks: tasks.filter { $0.status == "Approved" }.count,
            rejected_tasks: tasks.filter { $0.status == "Rejected" }.count
        )
    }

    static func roomStatistics(from rooms: [ScrapedRoomsResponse.Room]) -> ScrapedRoomsResponse.Statistics {
        let available = rooms.filter { $0.availability_summary.is_available_now }.count
        let partiallyAvailable = rooms.filter { $0.availability_summary.free_slots_count > 0 }.count
        let booked = rooms.filter { $0.availability_summary.free_slots_count == 0 }.count

        return .init(
            total_rooms: rooms.count,
            available_rooms: available,
            booked_rooms: booked,
            partially_available_rooms: partiallyAvailable
        )
    }

    private static func splitDateTime(_ raw: String) -> (date: String, dayOfWeek: String?, startTime: String, endTime: String, durationHours: Double) {
        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        let datePart = lines.first ?? ""
        let timePart = lines.dropFirst().first ?? ""

        let date = firstMatch(in: datePart, pattern: #"(\d{2}-[A-Za-z]{3}-\d{4})"#) ?? ""
        let dayOfWeek = firstMatch(in: datePart, pattern: #"\(([A-Za-z]{3})\)"#)

        let timeMatch = firstMatches(in: timePart, pattern: #"(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})"#)
        let durationMatch = firstMatch(in: timePart, pattern: #"\((\d+(?:\.\d+)?)hrs?\)"#)

        return (
            date: date,
            dayOfWeek: dayOfWeek,
            startTime: timeMatch.first ?? "",
            endTime: timeMatch.dropFirst().first ?? "",
            durationHours: Double(durationMatch ?? "") ?? 0
        )
    }

    private static func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard
            let match = regex.firstMatch(in: value, options: [], range: range),
            let captureRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        return String(value[captureRange])
    }

    private static func firstMatches(in value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range) else {
            return []
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let captureRange = Range(match.range(at: index), in: value) else { return nil }
            return String(value[captureRange])
        }
    }
}
