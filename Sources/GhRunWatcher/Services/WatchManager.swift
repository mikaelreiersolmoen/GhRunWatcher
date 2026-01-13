import AppKit
import Foundation

@MainActor
final class WatchManager: ObservableObject {
    @Published private(set) var watches: [RunWatch] = []
    @Published private(set) var repositoryURL: URL?
    @Published private(set) var githubCLIPath: String?
    private var tasks: [UUID: WatchTask] = [:]
    private var terminationObserver: NSObjectProtocol?
    private static let repositoryURLKey = "RunWatcherRepositoryURL"
    private static let githubCLIPathKey = "RunWatcherGitHubCLIPath"

    init() {
        loadPersistedRepository()
        loadPersistedGitHubCLIPath()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelAllWatches()
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func promptForRepository() {
        let panel = NSOpenPanel()
        panel.title = "Select Git Repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        guard isGitRepository(url: url) else {
            showError(message: "Selected folder is not a Git repository.")
            return
        }

        setRepositoryURL(url)
    }

    func promptForRunId() {
        guard repositoryURL != nil else {
            showError(message: "Select a Git repository before starting a watch.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Watch GitHub Actions run"
        alert.informativeText = "Enter the run ID to watch."
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        input.bezelStyle = .roundedBezel
        input.placeholderString = "Run ID"
        alert.accessoryView = input
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let runId = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !runId.isEmpty else {
            showError(message: "Run ID cannot be empty.")
            return
        }
        guard runId.allSatisfy(\.isNumber) else {
            showError(message: "Run ID must contain only numbers.")
            return
        }

        startWatch(runId: runId)
    }

    func promptForGitHubCLIPath() {
        let alert = NSAlert()
        alert.messageText = "Select GitHub CLI Location"
        alert.informativeText = "Enter the folder containing gh. Tip: run `which gh` in Terminal."
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        input.bezelStyle = .roundedBezel
        input.placeholderString = "/opt/homebrew/bin"
        if let githubCLIPath {
            input.stringValue = githubCLIPath
        }
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let folderPath = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderPath.isEmpty else {
            showError(message: "GitHub CLI folder cannot be empty.")
            return
        }
        let ghPath = URL(fileURLWithPath: folderPath).appendingPathComponent("gh").path
        guard FileManager.default.isExecutableFile(atPath: ghPath) else {
            showError(message: "Selected folder does not contain an executable named gh.")
            return
        }

        setGitHubCLIPath(folderPath)
    }

    func clearGitHubCLIPath() {
        setGitHubCLIPath(nil)
    }

    func startWatch(runId: String) {
        guard let repositoryURL else {
            showError(message: "Select a Git repository before starting a watch.")
            return
        }

        let watch = RunWatch(runId: runId)
        watches.append(watch)

        do {
            let task = try WatchTask(
                runId: runId,
                repositoryURL: repositoryURL,
                githubCLIPath: githubCLIPath
            ) { [weak self] result in
                Task { @MainActor in
                    self?.handleWatchResult(watchId: watch.id, runId: runId, result: result)
                }
            }
            tasks[watch.id] = task
            task.start()
        } catch {
            removeWatch(id: watch.id)
            showError(message: error.localizedDescription)
        }
    }

    private func handleWatchResult(watchId: UUID, runId: String, result: WatchResult) {
        removeWatch(id: watchId)

        switch result {
        case .success(let exitCode, let lastLine):
            postNotification(
                title: "✅ Run #\(runId) succeeded",
                body: buildNotificationBody(exitCode: exitCode, lastLine: lastLine)
            )
        case .workflowFailed(let exitCode, let lastLine):
            postNotification(
                title: "❌ Run #\(runId) failed",
                body: buildNotificationBody(exitCode: exitCode, lastLine: lastLine)
            )
        case .failure(_, let message):
            showError(message: message)
        case .startFailure(let message):
            showError(message: message)
        }
    }

    private func removeWatch(id: UUID) {
        watches.removeAll { $0.id == id }
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
    }

    private func cancelAllWatches() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        watches.removeAll()
    }

    private func postNotification(title: String, body: String) {
        NotificationService.shared.post(title: title, body: body)
    }

    private func buildNotificationBody(exitCode: Int32, lastLine: String?) -> String {
        guard let lastLine, !lastLine.isEmpty else {
            return "Run finished with status \(exitCode)."
        }
        return lastLine
    }

    private func isGitRepository(url: URL) -> Bool {
        let gitPath = url.appendingPathComponent(".git").path
        return FileManager.default.fileExists(atPath: gitPath)
    }

    private func setRepositoryURL(_ url: URL?) {
        repositoryURL = url
        persistRepositoryURL(url)
    }

    func clearRepository() {
        setRepositoryURL(nil)
    }

    private func setGitHubCLIPath(_ path: String?) {
        githubCLIPath = path
        persistGitHubCLIPath(path)
    }

    private func persistRepositoryURL(_ url: URL?) {
        let defaults = UserDefaults.standard
        if let url {
            defaults.set(url.path, forKey: Self.repositoryURLKey)
        } else {
            defaults.removeObject(forKey: Self.repositoryURLKey)
        }
    }

    private func persistGitHubCLIPath(_ path: String?) {
        let defaults = UserDefaults.standard
        if let path {
            defaults.set(path, forKey: Self.githubCLIPathKey)
        } else {
            defaults.removeObject(forKey: Self.githubCLIPathKey)
        }
    }

    private func loadPersistedRepository() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: Self.repositoryURLKey) else { return }
        let url = URL(fileURLWithPath: path)
        guard isGitRepository(url: url) else {
            defaults.removeObject(forKey: Self.repositoryURLKey)
            return
        }
        repositoryURL = url
    }

    private func loadPersistedGitHubCLIPath() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: Self.githubCLIPathKey) else { return }
        let ghPath = URL(fileURLWithPath: path).appendingPathComponent("gh").path
        guard FileManager.default.isExecutableFile(atPath: ghPath) else {
            defaults.removeObject(forKey: Self.githubCLIPathKey)
            return
        }
        githubCLIPath = path
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "GhRunWatcher error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
