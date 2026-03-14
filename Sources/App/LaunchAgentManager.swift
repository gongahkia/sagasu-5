import Foundation
import SagasuShared

struct HelperLaunchAgentStatus: Equatable {
    let label: String
    let plistURL: URL
    let helperURL: URL?
    let isInstalled: Bool
    let isLoaded: Bool
    let logURL: URL

    var summary: String {
        if isLoaded {
            return "Loaded"
        }

        if isInstalled {
            return "Installed"
        }

        return "Not installed"
    }
}

struct LaunchAgentError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class HelperLaunchAgentManager {
    static let label = "com.gongahkia.sagasu.helper.agent"

    private let fileManager: FileManager
    private let executableLocator: () -> URL?

    init(
        fileManager: FileManager = .default,
        executableLocator: @escaping () -> URL?
    ) {
        self.fileManager = fileManager
        self.executableLocator = executableLocator
    }

    convenience init(fileManager: FileManager = .default) {
        self.init(fileManager: fileManager, executableLocator: HelperLifecycleController.locateHelperExecutable)
    }

    func status() throws -> HelperLaunchAgentStatus {
        let plistURL = try launchAgentURL()
        return HelperLaunchAgentStatus(
            label: Self.label,
            plistURL: plistURL,
            helperURL: executableLocator(),
            isInstalled: fileManager.fileExists(atPath: plistURL.path),
            isLoaded: isLoaded(),
            logURL: try logURL()
        )
    }

    @discardableResult
    func install() throws -> HelperLaunchAgentStatus {
        guard let helperURL = executableLocator() else {
            throw LaunchAgentError(message: "The helper executable could not be located for launch-agent install.")
        }

        try ensureLaunchAgentsDirectoryExists()
        try ensureLogDirectoryExists()
        let plistURL = try launchAgentURL()
        let logURL = try logURL()
        try writeLaunchAgentPlist(helperURL: helperURL, plistURL: plistURL, logURL: logURL)

        if isLoaded() {
            _ = try? runLaunchctl(arguments: ["bootout", domainTarget(), plistURL.path])
        }

        _ = try runLaunchctl(arguments: ["bootstrap", domainTarget(), plistURL.path])
        _ = try runLaunchctl(arguments: ["kickstart", "-k", "\(domainTarget())/\(Self.label)"])
        return try status()
    }

    @discardableResult
    func startInstalledService() throws -> HelperLaunchAgentStatus {
        let current = try status()
        guard current.isInstalled else {
            return try install()
        }

        if !current.isLoaded {
            _ = try runLaunchctl(arguments: ["bootstrap", domainTarget(), current.plistURL.path])
        }

        _ = try runLaunchctl(arguments: ["kickstart", "-k", "\(domainTarget())/\(Self.label)"])
        return try status()
    }

    @discardableResult
    func stopInstalledService() throws -> HelperLaunchAgentStatus {
        let current = try status()
        guard current.isInstalled else { return current }

        if current.isLoaded {
            _ = try runLaunchctl(arguments: ["bootout", domainTarget(), current.plistURL.path])
        }

        return try status()
    }

    func uninstall() throws {
        let current = try status()
        if current.isLoaded {
            _ = try? runLaunchctl(arguments: ["bootout", domainTarget(), current.plistURL.path])
        }

        if fileManager.fileExists(atPath: current.plistURL.path) {
            try fileManager.removeItem(at: current.plistURL)
        }
    }

    private func launchAgentURL() throws -> URL {
        let libraryDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        let launchAgentsDirectory = libraryDirectory.appendingPathComponent("LaunchAgents", isDirectory: true)
        return launchAgentsDirectory.appendingPathComponent("\(Self.label).plist")
    }

    private func logURL() throws -> URL {
        let baseDirectory = try AppSupportPaths.baseDirectory(fileManager: fileManager)
        return baseDirectory.appendingPathComponent("helper.launchd.log")
    }

    private func ensureLaunchAgentsDirectoryExists() throws {
        let launchAgentsDirectory = try launchAgentURL().deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private func ensureLogDirectoryExists() throws {
        let baseDirectory = try logURL().deletingLastPathComponent()
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private func writeLaunchAgentPlist(helperURL: URL, plistURL: URL, logURL: URL) throws {
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [helperURL.path, HelperRunMode.scheduledService.rawValue],
            "RunAtLoad": true,
            "KeepAlive": false,
            "WorkingDirectory": helperURL.deletingLastPathComponent().path,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
            "ProcessType": "Background"
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func isLoaded() -> Bool {
        do {
            _ = try runLaunchctl(arguments: ["print", "\(domainTarget())/\(Self.label)"])
            return true
        } catch {
            return false
        }
    }

    private func domainTarget() -> String {
        "gui/\(getuid())"
    }

    private func runLaunchctl(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let output = String(
            decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw LaunchAgentError(
                message: output.isEmpty
                    ? "launchctl \(arguments.joined(separator: " ")) failed."
                    : output
            )
        }

        return output
    }
}
