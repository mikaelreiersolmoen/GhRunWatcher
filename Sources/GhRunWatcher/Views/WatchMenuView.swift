import AppKit
import SwiftUI

struct WatchMenuView: View {
    @EnvironmentObject private var watchManager: WatchManager

    var body: some View {
        VStack(alignment: .leading) {
            if watchManager.watches.isEmpty {
                Text("No active watches")
            } else {
                ForEach(watchManager.watches) { watch in
                    Text("#\(watch.runId)")
                        .padding(.vertical, 2)
                }
            }

            Divider()

            Button("Add Run Watch...") {
                watchManager.promptForRunId()
            }

            Divider()

            Menu("Settings") {
                if let repositoryURL = watchManager.repositoryURL {
                    Text(repositoryURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No repository selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(watchManager.repositoryURL == nil ? "Select Repository..." : "Change Repository...") {
                    watchManager.promptForRepository()
                }
                if watchManager.repositoryURL != nil {
                    Button("Clear Repository") {
                        watchManager.clearRepository()
                    }
                }
                Divider()
                if let githubCLIPath = watchManager.githubCLIPath {
                    Text(githubCLIPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Using gh from PATH")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(watchManager.githubCLIPath == nil ? "Select GitHub CLI Location..." : "Change GitHub CLI Location...") {
                    watchManager.promptForGitHubCLIPath()
                }
                if watchManager.githubCLIPath != nil {
                    Button("Clear GitHub CLI Location") {
                        watchManager.clearGitHubCLIPath()
                    }
                }
            }

            Divider()

            Button("Help...") {
                showHelp()
            }

            Button("Quit GhRunWatcher") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 280)
    }

    private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "GhRunWatcher"
        alert.informativeText = """
            GhRunWatcher monitors GitHub Actions workflow runs and notifies you when they complete.

            Requirements:
            • GitHub CLI (gh) must be installed and authenticated. Install it from https://cli.github.com or via Homebrew: brew install gh

            Setup:
            1. Go to Settings and select a local Git repository folder that is hosted on GitHub.
            2. Optionally set a custom GitHub CLI location if gh is not in your PATH.

            Usage:
            • Click "Add Run Watch..." and enter a workflow run ID from GitHub Actions.
            • You'll receive a notification when the run completes.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
