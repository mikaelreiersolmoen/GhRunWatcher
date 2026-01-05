<p align="center">
  <img src="Resources/app_icon.png" alt="GhRunWatcher" width="128">
</p>

# GhRunWatcher

A lightweight macOS menu bar app that monitors GitHub Actions workflow runs and notifies you when they complete.

## Features

- Lives in your menu bar for quick access
- Monitors GitHub Actions runs by ID
- Desktop notifications when runs finish

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

### Setup

1. Install and authenticate GitHub CLI:
   ```bash
   brew install gh
   gh auth login
   ```

2. Launch GhRunWatcher
3. Click the menu bar icon and select **Settings** to configure your repository

## Usage

1. Start a GitHub Actions workflow in your configured repository
2. Copy the run ID from the GitHub UI or CLI
3. Click the GhRunWatcher menu bar icon
4. Enter the run ID to start monitoring
5. You'll receive a notification when the run completes

## License

MIT
