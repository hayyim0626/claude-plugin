#!/usr/bin/env bash
# install-launchd.sh [--uninstall] — 매일 config.schedule 시각 + 로그인 시 run.sh 실행
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
LABEL="com.hayyim0626.worklog"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"; echo "removed $PLIST"; exit 0
fi
HOUR=$(jq -r '.schedule.hour // 19' "$WORKLOG_DIR/config.json")
MIN=$(jq -r '.schedule.minute // 0' "$WORKLOG_DIR/config.json")
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$PLUGIN_ROOT/scripts/run.sh</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$HOME</string>
    <key>WORKLOG_DIR</key><string>$WORKLOG_DIR</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>$HOUR</integer><key>Minute</key><integer>$MIN</integer></dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/worklog.launchd.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/worklog.launchd.log</string>
</dict>
</plist>
PL
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed $LABEL — daily ${HOUR}:$(printf %02d "$MIN") + at login, run.sh=$PLUGIN_ROOT/scripts/run.sh"
