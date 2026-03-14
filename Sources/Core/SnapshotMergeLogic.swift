import Foundation
import SagasuShared

public enum SnapshotMergeLogic {
    public static func staleStatus(
        for dataset: ScrapeDataset,
        attemptAt: String,
        currentSuccessAt: String?,
        message: String
    ) -> DatasetStatus {
        DatasetStatus(
            dataset: dataset,
            state: currentSuccessAt == nil ? .failed : .stale,
            last_attempt_at: attemptAt,
            last_success_at: currentSuccessAt,
            message: message
        )
    }

    public static func mergeRooms(
        _ result: Result<ScrapedRoomsResponse, Error>?,
        current: ScrapedRoomsResponse?,
        fallback: ScrapedRoomsResponse?,
        attemptAt: String
    ) -> (payload: ScrapedRoomsResponse?, status: DatasetStatus) {
        switch result {
        case let .success(payload):
            return (
                payload,
                DatasetStatus(
                    dataset: .rooms,
                    state: .success,
                    last_attempt_at: attemptAt,
                    last_success_at: payload.metadata.scraped_at,
                    message: "Live native scrape completed."
                )
            )
        case let .failure(error):
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .rooms,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: error.localizedDescription
                )
            )
        case .none:
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .rooms,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: "The rooms scraper did not produce a result."
                )
            )
        }
    }

    public static func mergeBookings(
        _ result: Result<ScrapedBookingsResponse, Error>?,
        current: ScrapedBookingsResponse?,
        fallback: ScrapedBookingsResponse?,
        attemptAt: String
    ) -> (payload: ScrapedBookingsResponse?, status: DatasetStatus) {
        switch result {
        case let .success(payload):
            return (
                payload,
                DatasetStatus(
                    dataset: .bookings,
                    state: .success,
                    last_attempt_at: attemptAt,
                    last_success_at: payload.metadata.scraped_at,
                    message: "Live native scrape completed."
                )
            )
        case let .failure(error):
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .bookings,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: error.localizedDescription
                )
            )
        case .none:
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .bookings,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: "The bookings scraper did not produce a result."
                )
            )
        }
    }

    public static func mergeTasks(
        _ result: Result<ScrapedTasksResponse, Error>?,
        current: ScrapedTasksResponse?,
        fallback: ScrapedTasksResponse?,
        attemptAt: String
    ) -> (payload: ScrapedTasksResponse?, status: DatasetStatus) {
        switch result {
        case let .success(payload):
            return (
                payload,
                DatasetStatus(
                    dataset: .tasks,
                    state: .success,
                    last_attempt_at: attemptAt,
                    last_success_at: payload.metadata.scraped_at,
                    message: "Live native scrape completed."
                )
            )
        case let .failure(error):
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .tasks,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: error.localizedDescription
                )
            )
        case .none:
            let payload = current ?? fallback
            return (
                payload,
                staleStatus(
                    for: .tasks,
                    attemptAt: attemptAt,
                    currentSuccessAt: payload?.metadata.scraped_at,
                    message: "The tasks scraper did not produce a result."
                )
            )
        }
    }
}
