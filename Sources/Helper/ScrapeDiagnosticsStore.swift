import Foundation
import SagasuShared

struct ScrapeDiagnosticMetadata: Codable {
    let dataset: String
    let stage: String
    let recorded_at: String
    let current_url: String?
    let error: String
    let extra: [String: String]
}

final class ScrapeDiagnosticsStore {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let maxRetainedDirectories: Int

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        maxRetainedDirectories: Int = 25
    ) throws {
        self.fileManager = fileManager
        self.maxRetainedDirectories = maxRetainedDirectories
        let baseDirectory = try rootDirectory ?? AppSupportPaths.baseDirectory(fileManager: fileManager)
        self.rootDirectory = baseDirectory.appendingPathComponent("diagnostics", isDirectory: true)
        try fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func diagnosticsRootURL() -> URL {
        rootDirectory
    }

    @discardableResult
    func recordFailure(
        dataset: ScrapeDataset?,
        stage: String,
        error: Error,
        currentURL: String?,
        pageHTML: String?,
        screenshotPNG: Data?,
        extra: [String: String] = [:]
    ) throws -> URL {
        let directory = rootDirectory.appendingPathComponent(directoryName(dataset: dataset, stage: stage), isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let metadata = ScrapeDiagnosticMetadata(
            dataset: dataset?.rawValue ?? "session",
            stage: stage,
            recorded_at: Date().iso8601String,
            current_url: currentURL,
            error: error.localizedDescription,
            extra: extra
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: directory.appendingPathComponent("metadata.json"), options: .atomic)

        if let pageHTML, !pageHTML.isEmpty {
            try Data(pageHTML.utf8).write(to: directory.appendingPathComponent("page.html"), options: .atomic)
        }

        if let screenshotPNG, !screenshotPNG.isEmpty {
            try screenshotPNG.write(to: directory.appendingPathComponent("page.png"), options: .atomic)
        }

        try pruneRetainedDirectories()
        return directory
    }

    private func directoryName(dataset: ScrapeDataset?, stage: String) -> String {
        let datasetName = dataset?.rawValue ?? "session"
        let timestamp = Date().iso8601String.replacingOccurrences(of: ":", with: "-")
        return "\(timestamp)-\(sanitize(datasetName))-\(sanitize(stage))"
    }

    private func sanitize(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(mapped)
    }

    private func pruneRetainedDirectories() throws {
        guard maxRetainedDirectories >= 0 else { return }

        let directories = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        guard directories.count > maxRetainedDirectories else { return }
        for directory in directories.dropFirst(maxRetainedDirectories) {
            try fileManager.removeItem(at: directory)
        }
    }
}
