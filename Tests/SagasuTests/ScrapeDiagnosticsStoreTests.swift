import Foundation
import XCTest
@testable import SagasuCore
@testable import SagasuShared

final class ScrapeDiagnosticsStoreTests: XCTestCase {
    func testRecordFailurePersistsMetadataAndArtifacts() throws {
        let rootDirectory = temporaryDirectory()
        let store = try ScrapeDiagnosticsStore(rootDirectory: rootDirectory, maxRetainedDirectories: 10)

        let directory = try store.recordFailure(
            dataset: .rooms,
            stage: "rooms-attempt-1",
            error: DummyDiagnosticsError(message: "boom"),
            currentURL: "https://example.com",
            pageHTML: "<html>diagnostic</html>",
            screenshotPNG: Data([0x89, 0x50, 0x4E, 0x47]),
            extra: ["attempt": "1"]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("metadata.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("page.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("page.png").path))

        let metadataData = try Data(contentsOf: directory.appendingPathComponent("metadata.json"))
        let metadata = try JSONDecoder().decode(ScrapeDiagnosticMetadata.self, from: metadataData)
        XCTAssertEqual(metadata.dataset, "rooms")
        XCTAssertEqual(metadata.stage, "rooms-attempt-1")
        XCTAssertEqual(metadata.current_url, "https://example.com")
        XCTAssertEqual(metadata.error, "boom")
        XCTAssertEqual(metadata.extra["attempt"], "1")
    }

    func testRecordFailurePrunesDirectoriesBeyondRetentionLimit() throws {
        let rootDirectory = temporaryDirectory()
        let store = try ScrapeDiagnosticsStore(rootDirectory: rootDirectory, maxRetainedDirectories: 2)

        _ = try store.recordFailure(
            dataset: .rooms,
            stage: "first",
            error: DummyDiagnosticsError(message: "one"),
            currentURL: nil,
            pageHTML: nil,
            screenshotPNG: nil
        )
        Thread.sleep(forTimeInterval: 1.1)
        _ = try store.recordFailure(
            dataset: .rooms,
            stage: "second",
            error: DummyDiagnosticsError(message: "two"),
            currentURL: nil,
            pageHTML: nil,
            screenshotPNG: nil
        )
        Thread.sleep(forTimeInterval: 1.1)
        _ = try store.recordFailure(
            dataset: .rooms,
            stage: "third",
            error: DummyDiagnosticsError(message: "three"),
            currentURL: nil,
            pageHTML: nil,
            screenshotPNG: nil
        )

        let directories = try FileManager.default.contentsOfDirectory(
            at: store.diagnosticsRootURL(),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .map(\.lastPathComponent)
        .sorted()

        XCTAssertEqual(directories.count, 2)
        XCTAssertFalse(directories.contains(where: { $0.contains("first") }))
        XCTAssertTrue(directories.contains(where: { $0.contains("second") }))
        XCTAssertTrue(directories.contains(where: { $0.contains("third") }))
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }
}

private struct DummyDiagnosticsError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
