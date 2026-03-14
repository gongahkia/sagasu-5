import Foundation

enum HelperRunMode: String, CaseIterable, Identifiable {
    case xpcService = "xpc-service"
    case scheduledService = "service"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xpcService:
            return "XPC"
        case .scheduledService:
            return "Scheduler"
        }
    }
}

struct HelperLaunchError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

@MainActor
final class HelperLifecycleController {
    private(set) var activeMode: HelperRunMode?
    private var process: Process?
    private let launchAgentManager = HelperLaunchAgentManager()

    func start(mode: HelperRunMode) throws {
        if process?.isRunning == true, activeMode == mode {
            return
        }

        stop()

        guard let executableURL = Self.locateHelperExecutable() else {
            throw HelperLaunchError(message: "The helper executable could not be located.")
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [mode.rawValue]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()

        self.process = process
        self.activeMode = mode
    }

    func stop() {
        process?.terminate()
        process = nil
        activeMode = nil
    }

    func isRunning(_ mode: HelperRunMode) -> Bool {
        process?.isRunning == true && activeMode == mode
    }

    func launchAgentStatus() throws -> HelperLaunchAgentStatus {
        try launchAgentManager.status()
    }

    @discardableResult
    func installLaunchAgent() throws -> HelperLaunchAgentStatus {
        try launchAgentManager.install()
    }

    @discardableResult
    func startLaunchAgent() throws -> HelperLaunchAgentStatus {
        try launchAgentManager.startInstalledService()
    }

    @discardableResult
    func stopLaunchAgent() throws -> HelperLaunchAgentStatus {
        try launchAgentManager.stopInstalledService()
    }

    func uninstallLaunchAgent() throws {
        try launchAgentManager.uninstall()
    }

    static func locateHelperExecutable() -> URL? {
        let fileManager = FileManager.default
        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let bundleBinary = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/sagasu-helper")
        let resourceBinary = Bundle.main.resourceURL?
            .appendingPathComponent("sagasu-helper")

        let candidates = [
            bundleBinary,
            resourceBinary,
            current.appendingPathComponent("build/sagasu-helper"),
            current.appendingPathComponent(".build/debug/sagasu-helper"),
            current.appendingPathComponent(".build/release/sagasu-helper")
        ].compactMap { $0 }

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }
}
