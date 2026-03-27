# Raycast Memory Monitor

A lightweight macOS shell script that automatically monitors and manages Raycast’s memory usage.
If Raycast consumes more than a defined memory threshold (default: 420 MB), the script will automatically restart the app and notify the user.


## Features

- Monitors Raycast’s memory usage periodically

- Automatically restarts Raycast when memory exceeds threshold

- Sends macOS system notifications on restart (optional if IBM Notifier is installed)

- Writes detailed logs for each check

- Runs automatically via macOS LaunchAgent (no manual execution needed)


## Configuration

| Setting | Description | Default |
|----------|--------------|----------|
| `APP_NAME` | Application name to monitor | `Raycast` |
| `MEM_THRESHOLD_MB` | Memory threshold (in MB) before restart | `420` |
| `LOG_FILE` | Path to the log file | `~/raycast_mem_monitor.log` |
| `StartInterval` | Memory check frequency | `300` |


## Installation

```bash
chmod +x ./deploy.sh
./deploy.sh
```

This command will:

- copy `raycast_mem_monitor.sh` into `~/Library/Application Support/raycast_mem_monitor/`
- render `com.user.raycastmem.plist` with the real script path
- install the LaunchAgent into `~/Library/LaunchAgents/`
- reload the user LaunchAgent immediately

## Updating

```bash
./deploy.sh
```

Any time you change either `raycast_mem_monitor.sh` or `com.user.raycastmem.plist`, run the same command again to sync the latest version into macOS.

## Management

Useful commands:

```bash
./deploy.sh dry-run
./deploy.sh status
./deploy.sh uninstall
```


## Logs

All activity is logged to:
```bash
~/raycast_mem_monitor.log
```
Each entry includes a timestamp, current memory usage, and restart actions.


## Notifications

If you want to use system notification, please install [IBM Notifier](https://github.com/IBM/mac-ibm-notifications).

**English Notification:** <br>
<img src="assets/notification_EN.png" alt="English Notification" width="400">

**Chinese Notification:** <br>
<img src="assets/notification_zh.png" alt="Chinese Notification" width="400">

## Notes

- Modify `StartInterval` in `com.user.raycastmem.plist`, then run `./deploy.sh` again.

- Modify `MEM_THRESHOLD_MB` in `raycast_mem_monitor.sh`, then run `./deploy.sh` again.

- To stop the service:
```bash
./deploy.sh uninstall
```

## License

MIT License — free to use and modify.
Developed with ❤️ for a smoother Raycast experience.
