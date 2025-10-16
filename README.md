Raycast Memory Monitor

A lightweight macOS shell script that automatically monitors and manages Raycast’s memory usage.
If Raycast consumes more than a defined memory threshold (default: 500 MB), the script will automatically restart the app and notify the user.

🚀 Features

Monitors Raycast’s memory usage periodically

Automatically restarts Raycast when memory exceeds threshold

Sends macOS system notifications on restart

Writes detailed logs for each check

Runs automatically via macOS LaunchAgent (no manual execution needed)

⚙️ Configuration
Setting	Description	Default
APP_NAME	Application name to monitor	Raycast
MEM_THRESHOLD_MB	Memory threshold (in MB) before restart	500
LOG_FILE	Path to the log file	~/raycast_mem_monitor.log
🧩 Installation

Copy the script

nano ~/raycast_mem_monitor.sh


Paste the script content and save.

Make it executable

chmod +x ~/raycast_mem_monitor.sh


Create the LaunchAgent

nano ~/Library/LaunchAgents/com.user.raycastmem.plist


Add:

<key>ProgramArguments</key>
<array>
    <string>/Users/YOUR_USERNAME/raycast_mem_monitor.sh</string>
</array>
<key>StartInterval</key>
<integer>1800</integer>


(1800 = 30 minutes)

Load the task

launchctl load ~/Library/LaunchAgents/com.user.raycastmem.plist

🪵 Logs

All activity is logged to:

~/raycast_mem_monitor.log


Each entry includes a timestamp, current memory usage, and restart actions.

🧠 Notes

Modify StartInterval to change the check frequency (e.g., 3600 = 1 hour).

macOS notifications require Raycast.app to be installed in /Applications.

To stop the service:

launchctl unload ~/Library/LaunchAgents/com.user.raycastmem.plist

📄 License

MIT License — free to use and modify.
Developed with ❤️ for a smoother Raycast experience.
