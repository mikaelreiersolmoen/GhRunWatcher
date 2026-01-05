import Foundation

final class WatchTask {
    private static let maxBufferSize = 1024 * 1024 // 1 MB max per buffer

    private let runId: String
    private let repositoryURL: URL
    private let process: Process
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let completion: (WatchResult) -> Void
    private let dataLock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()

    init(
        runId: String,
        repositoryURL: URL,
        githubCLIPath: String?,
        completion: @escaping (WatchResult) -> Void
    ) throws {
        self.runId = runId
        self.repositoryURL = repositoryURL
        self.completion = completion
        self.process = Process()

        if let githubCLIPath {
            let ghPath = URL(fileURLWithPath: githubCLIPath).appendingPathComponent("gh").path
            process.executableURL = URL(fileURLWithPath: ghPath)
            process.arguments = ["run", "watch", "--exit-status", runId]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gh", "run", "watch", "--exit-status", runId]
        }
        process.currentDirectoryURL = repositoryURL
        process.environment = Self.buildEnvironment()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.dataLock.lock()
            defer { self.dataLock.unlock() }
            if self.stdoutData.count < Self.maxBufferSize {
                let remaining = Self.maxBufferSize - self.stdoutData.count
                self.stdoutData.append(data.prefix(remaining))
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.dataLock.lock()
            defer { self.dataLock.unlock() }
            if self.stderrData.count < Self.maxBufferSize {
                let remaining = Self.maxBufferSize - self.stderrData.count
                self.stderrData.append(data.prefix(remaining))
            }
        }

        process.terminationHandler = { [weak self] process in
            self?.finish(process: process)
        }
    }

    private static let allowedEnvVars: Set<String> = [
        // Required for gh CLI to function
        "PATH", "HOME", "USER", "SHELL",
        // GitHub authentication
        "GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN",
        "GH_HOST", "GH_CONFIG_DIR",
        // SSH authentication
        "SSH_AUTH_SOCK", "SSH_AGENT_PID",
        // Locale/terminal
        "LANG", "LC_ALL", "LC_CTYPE", "TERM",
        // Proxy settings (may be needed for corporate environments)
        "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY",
        "http_proxy", "https_proxy", "no_proxy",
        // XDG directories
        "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME",
        // Git configuration
        "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"
    ]

    private static func buildEnvironment() -> [String: String] {
        let parentEnv = ProcessInfo.processInfo.environment
        var environment = parentEnv.filter { allowedEnvVars.contains($0.key) }

        let existingPath = environment["PATH"] ?? ""
        let standardPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let merged = ([existingPath] + standardPaths)
            .flatMap { $0.split(separator: ":") }
            .map(String.init)
        var seen = Set<String>()
        let deduped = merged.filter { seen.insert($0).inserted }
        environment["PATH"] = deduped.joined(separator: ":")
        return environment
    }

    func start() {
        do {
            try process.run()
        } catch {
            clearHandlers()
            completion(.startFailure(message: "Failed to start gh: \(error.localizedDescription)"))
        }
    }

    func cancel() {
        clearHandlers()
        if process.isRunning {
            process.terminate()
        }
    }

    private func clearHandlers() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
    }

    private func finish(process: Process) {
        clearHandlers()

        dataLock.lock()
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        dataLock.unlock()

        let exitCode = process.terminationStatus
        if exitCode == 0 {
            let lastLine = WatchTask.lastNonEmptyLine(from: stdoutText)
            completion(.success(exitCode: exitCode, lastLine: lastLine))
        } else if stderrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No stderr means the workflow itself failed (not a gh error)
            let lastLine = WatchTask.lastNonEmptyLine(from: stdoutText)
            completion(.workflowFailed(exitCode: exitCode, lastLine: lastLine))
        } else {
            // stderr present means gh encountered an error
            let message = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(.failure(exitCode: exitCode, message: message))
        }
    }

    private static func lastNonEmptyLine(from text: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return lines.last
    }
}
