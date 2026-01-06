import Foundation

enum GitHubEndpoints {
    static let scrapedLog = URL(string: "https://raw.githubusercontent.com/gongahkia/sagasu-4/main/backend/log/scraped_log.json")!
    static let scrapedBookings = URL(string: "https://raw.githubusercontent.com/gongahkia/sagasu-4/main/backend/log/scraped_bookings.json")!
    static let scrapedTasks = URL(string: "https://raw.githubusercontent.com/gongahkia/sagasu-4/main/backend/log/scraped_tasks.json")!
}
