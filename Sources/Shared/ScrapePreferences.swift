import Foundation

public struct ScrapePreferences: Codable, Sendable, Equatable {
    public var date: String
    public var start_time: String
    public var end_time: String
    public var buildings: [String]
    public var floors: [String]
    public var facility_types: [String]
    public var equipment: [String]
    public var capacity: String

    public init(
        date: String = "TODAY",
        start_time: String = "08:00",
        end_time: String = "22:00",
        buildings: [String] = [],
        floors: [String] = [],
        facility_types: [String] = [],
        equipment: [String] = [],
        capacity: String = ""
    ) {
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.buildings = buildings
        self.floors = floors
        self.facility_types = facility_types
        self.equipment = equipment
        self.capacity = capacity
    }
}

public actor ScrapePreferencesStore {
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.baseDirectory = try baseDirectory ?? AppSupportPaths.baseDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    public func preferencesURL() -> URL {
        baseDirectory.appendingPathComponent("scrape-preferences.json")
    }

    public func load() throws -> ScrapePreferences {
        try Self.loadStoredPreferences(fileManager: fileManager, baseDirectory: baseDirectory)
    }

    public func save(_ preferences: ScrapePreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preferences)
        try data.write(to: preferencesURL(), options: .atomic)
    }

    public static func loadStoredPreferences(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws -> ScrapePreferences {
        let resolvedBaseDirectory = try baseDirectory ?? AppSupportPaths.baseDirectory(fileManager: fileManager)
        let url = resolvedBaseDirectory.appendingPathComponent("scrape-preferences.json")
        guard fileManager.fileExists(atPath: url.path) else {
            return ScrapePreferences()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScrapePreferences.self, from: data)
    }
}
