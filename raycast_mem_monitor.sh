#!/bin/bash

# Configuration
APP_NAME="Raycast"
MEM_THRESHOLD_MB=500
LOG_FILE="$HOME/raycast_mem_monitor.log"

# Acquire Raycast PID
PID=$(pgrep -x "$APP_NAME")

if [ -z "$PID" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $APP_NAME 未运行" >> "$LOG_FILE"
  exit 0
fi

# Acquire memory usage (KB as unit)
MEM_KB=$(ps -o rss= -p "$PID")
MEM_MB=$((MEM_KB / 1024))

echo "$(date '+%Y-%m-%d %H:%M:%S') - 当前内存占用: ${MEM_MB}MB" >> "$LOG_FILE"

# Determine if memory usage overeach the threshold
if [ "$MEM_MB" -gt "$MEM_THRESHOLD_MB" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 超过阈值(${MEM_MB}MB > ${MEM_THRESHOLD_MB}MB)，重启 Raycast" >> "$LOG_FILE"
  kill "$PID"
  # wait for 3 sec.
  sleep 3
  open -a "$APP_NAME"
fi

