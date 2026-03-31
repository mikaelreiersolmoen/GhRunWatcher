<p align="center">
  <img src="Resources/app_icon.png" alt="GhRunWatcher" width="128">
</p>

# GhRunWatcher

A lightweight macOS menu bar app that monitors GitHub Actions workflow runs and notifies you when they complete.

## Features

- Lives in your menu bar for quick access
- Monitors GitHub Actions runs by ID
- Desktop notifications when runs finish
- MCP server for AI agent integration

## Requirements

- macOS 13 or later
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

## Installation

### Download

Download the latest `.zip` from [Releases](../../releases), extract it, and move `GhRunWatcher.app` to your Applications folder.

### Build from source

```bash
./scripts/build_app.sh
```

The app will be created at `build/GhRunWatcher.app`. Move it to your Applications folder.

## Setup

1. Install and authenticate GitHub CLI:
   ```bash
   brew install gh
   gh auth login
   ```

2. Launch GhRunWatcher
3. Click the menu bar icon and select **Settings** to configure your repository

## Usage

1. Start a GitHub Actions workflow in your configured repository
2. Copy the run ID from the GitHub URL
3. Click the GhRunWatcher menu bar icon -> Add Run Watch...
4. Enter the run ID and click Add
5. You'll receive a notification when the run completes

## MCP Server

GhRunWatcher includes a bundled [MCP](https://modelcontextprotocol.io/) server that lets AI agents (such as Claude Code) add and manage run watches programmatically.

### Setup

The app must be running for the MCP server to work.

**Claude Code:**

```bash
claude mcp add ghrunwatcher -- /Applications/GhRunWatcher.app/Contents/MacOS/GhRunWatcherMCP
```

**Codex:**

```bash
codex mcp add ghrunwatcher -- /Applications/GhRunWatcher.app/Contents/MacOS/GhRunWatcherMCP
```

### Available tools

| Tool | Description |
|------|-------------|
| `add_watch` | Watch a GitHub Actions run. Accepts `run_id` (required) and `repo` in `OWNER/REPO` format (optional). |
| `list_watches` | List all active watches. |
| `remove_watch` | Remove a watch by its `watch_id`. |

The `repo` parameter lets agents watch runs from any repository without needing one configured in the app.

## License

MIT
