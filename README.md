# Raycast Memory Monitor

A lightweight macOS shell tool that monitors Raycast memory usage in the background.
When Raycast exceeds the configured memory threshold, the monitor restarts the app and can optionally send an IBM Notifier banner.

## Features

- Periodically checks Raycast memory usage
- Restarts Raycast automatically when it exceeds the configured threshold
- Supports IBM Notifier banners after restart
- Writes monitor activity to `~/raycast_mem_monitor.log`
- Supports both Homebrew service mode and direct LaunchAgent mode

## How It Works

The monitor has two tunable settings:

| Setting | Description | Default |
|----------|-------------|---------|
| `MEM_THRESHOLD_MB` | Restart Raycast when memory usage exceeds this value | `420` |
| `START_INTERVAL` | Check interval in seconds | `300` |

These values are stored in:

```bash
~/Library/Application Support/raycast_mem_monitor/raycast_mem_monitor.conf
```

Changing either value with `rmm` updates the config file immediately.
If the monitor service is already running, `rmm` also restarts it immediately so the new config takes effect at once.

## Recommended Installation

The recommended path is Homebrew.

```bash
brew tap --custom-remote ManicEuphoria/raycast-mem-monitor https://github.com/ManicEuphoria/raycast_mem_monitor
brew install maniceuphoria/raycast-mem-monitor/raycast-mem-monitor
brew services start raycast-mem-monitor
```

What these commands do:

- `brew tap ...`: registers this repository as a custom Homebrew tap
- `brew install ...`: installs the `rmm` command
- `brew services start ...`: starts the background monitor as a Homebrew-managed service

## Homebrew Workflow

Install and start:

```bash
brew tap --custom-remote ManicEuphoria/raycast-mem-monitor https://github.com/ManicEuphoria/raycast_mem_monitor
brew install maniceuphoria/raycast-mem-monitor/raycast-mem-monitor
brew services start raycast-mem-monitor
```

Common management commands:

| Command | What It Does |
|---------|--------------|
| `brew services start raycast-mem-monitor` | Start the background service |
| `brew services restart raycast-mem-monitor` | Restart the service manually |
| `brew services stop raycast-mem-monitor` | Stop the service |
| `brew uninstall raycast-mem-monitor` | Remove the Homebrew package |
| `rmm status` | Show config values, notifier status, and service state |
| `rmm check` | Run one immediate memory check without waiting for the next interval |
| `rmm -cm 500` | Set `MEM_THRESHOLD_MB=500` |
| `rmm -ct 200` | Set `START_INTERVAL=200` |
| `rmm -c -m 500 -t 200` | Update both values in one command |
| `rmm install-notifier` | Install IBM Notifier |

Notes:

- In Homebrew mode, use `brew services ...` to control the running service.
- `rmm uninstall` is not the uninstall command for Homebrew mode. Use `brew uninstall raycast-mem-monitor` instead.

## Direct Installation

If you do not want to use Homebrew, you can still install the monitor directly:

```bash
./deploy.sh
```

This path:

- copies the monitor files into `~/Library/Application Support/raycast_mem_monitor/`
- renders and installs `~/Library/LaunchAgents/com.user.raycastmem.plist`
- loads the LaunchAgent immediately

Direct-install management commands:

| Command | What It Does |
|---------|--------------|
| `./deploy.sh` | Install or update the direct LaunchAgent version |
| `./deploy.sh status` | Show direct-install status |
| `./deploy.sh uninstall` | Remove the direct LaunchAgent install |
| `rmm install` | Long form of direct install |
| `rmm -i` | Short form of direct install |
| `rmm dry-run` | Validate install rendering without writing files |
| `rmm uninstall` | Remove the direct LaunchAgent install |
| `rmm status` | Show config values, notifier status, and service state |
| `rmm check` | Run one immediate memory check |
| `rmm -cm 500` | Set `MEM_THRESHOLD_MB=500` |
| `rmm -ct 200` | Set `START_INTERVAL=200` |
| `rmm install-notifier` | Install IBM Notifier |

Notes:

- `rmm install` and `rmm -i` are equivalent to the direct-install path.
- In direct mode, the background process is managed by `launchd`, not `brew services`.

## Command Reference

This section explains each `rmm` command in more detail.

### Installation Commands

| Command | Scope | Description | Example |
|---------|-------|-------------|---------|
| `rmm install` | Direct install | Install or update the direct LaunchAgent version | `rmm install` |
| `rmm -i` | Direct install | Short form of `rmm install` | `rmm -i` |
| `rmm uninstall` | Direct install | Remove the direct LaunchAgent install from your user account | `rmm uninstall` |
| `rmm dry-run` | Direct install | Render and validate the LaunchAgent without writing system files | `rmm dry-run` |

### Runtime Commands

| Command | Scope | Description | Example |
|---------|-------|-------------|---------|
| `rmm status` | Both | Show config values, notifier installation status, and whether direct/brew services are loaded | `rmm status` |
| `rmm check` | Both | Run one immediate memory check right now | `rmm check` |
| `rmm daemon` | Internal | Continuous loop used by LaunchAgent or Homebrew service; normally you do not run this manually | `rmm daemon` |

### Configuration Commands

| Command | Scope | Description | Example |
|---------|-------|-------------|---------|
| `rmm -cm 500` | Both | Set `MEM_THRESHOLD_MB` to `500` | `rmm -cm 500` |
| `rmm -ct 200` | Both | Set `START_INTERVAL` to `200` seconds | `rmm -ct 200` |
| `rmm -c -m 500 -t 200` | Both | Update threshold and interval in one command | `rmm -c -m 500 -t 200` |

Behavior after config changes:

- If the monitor service is running, `rmm` refreshes it immediately.
- If the service is not running, only the config file is updated.

### Notification Commands

| Command | Scope | Description | Example |
|---------|-------|-------------|---------|
| `rmm install-notifier` | Both | Install IBM Notifier from the latest official GitHub release | `rmm install-notifier` |
| `rmm -n` | Both | Short form of `rmm install-notifier` | `rmm -n` |

## IBM Notifier

IBM Notifier is optional, but recommended if you want a banner after Raycast is restarted.

Install it with:

```bash
rmm install-notifier
```

Or:

```bash
rmm -n
```

Installation behavior:

- installs to `/Applications` when writable
- otherwise installs to `~/Applications`
- skips reinstallation if IBM Notifier is already present

Project source:

- [IBM/mac-ibm-notifications](https://github.com/IBM/mac-ibm-notifications)

**English Notification:** <br>
<img src="assets/notification_EN.png" alt="English Notification" width="400">

**Chinese Notification:** <br>
<img src="assets/notification_zh.png" alt="Chinese Notification" width="400">

## Logs

The monitor writes runtime logs to:

```bash
~/raycast_mem_monitor.log
```

These logs include current memory readings, restart actions, and other monitor activity.
To avoid keeping stale logs forever, the file is automatically truncated when it grows beyond `256 KB`, keeping the most recent `200` lines.

## Testing

Run the local test suite with:

```bash
bash tests/test_rmm.sh
```

This covers:

- config updates
- notifier installation flow
- notifier download fallback flow

## License

MIT License.
