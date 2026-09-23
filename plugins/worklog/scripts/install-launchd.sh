#!/usr/bin/env bash
# install-launchd.sh [--uninstall] — 세 개의 LaunchAgent 등록
#   daily   : config.schedule.daily {hour,minute} 매일 + 로그인 시 → run.sh catchup
#   weekly  : config.schedule.weekly {weekday(0=일…5=금),hour,minute} → run.sh weekly
#   monthly : config.schedule.monthly {hour,minute} 평일마다 → run.sh monthly (마지막 영업일만 실행)
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
CFG="$WORKLOG_DIR/config.json"
BASE="com.hayyim0626.worklog"
DIR="$HOME/Library/LaunchAgents"
UID_=$(id -u)

if [ "${1:-}" = "--uninstall" ]; then
  for m in daily weekly monthly; do launchctl bootout "gui/$UID_" "$DIR/$BASE.$m.plist" 2>/dev/null || true; rm -f "$DIR/$BASE.$m.plist"; done
  echo "removed $BASE.{daily,weekly,monthly}"; exit 0
fi

mkdir -p "$DIR" "$HOME/Library/Logs"
write_plist(){ # name mode calendar-xml runatload
  local name="$1" mode="$2" cal="$3" ral="$4" plist="$DIR/$BASE.$1.plist"
  cat > "$plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$BASE.$name</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$PLUGIN_ROOT/scripts/run.sh</string><string>$mode</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$HOME</string>
    <key>WORKLOG_DIR</key><string>$WORKLOG_DIR</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartCalendarInterval</key>
  $cal
  <key>RunAtLoad</key><$ral/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/worklog.launchd.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/worklog.launchd.log</string>
</dict>
</plist>
PL
  launchctl bootout "gui/$UID_" "$plist" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_" "$plist"
}
DH=$(jq -r '.schedule.daily.hour // 9' "$CFG");   DM=$(jq -r '.schedule.daily.minute // 30' "$CFG")
WD=$(jq -r '.schedule.weekly.weekday // 5' "$CFG"); WH=$(jq -r '.schedule.weekly.hour // 18' "$CFG"); WM=$(jq -r '.schedule.weekly.minute // 0' "$CFG")
MH=$(jq -r '.schedule.monthly.hour // 18' "$CFG"); MM=$(jq -r '.schedule.monthly.minute // 0' "$CFG")

write_plist daily catchup "<dict><key>Hour</key><integer>$DH</integer><key>Minute</key><integer>$DM</integer></dict>" true
write_plist weekly weekly "<dict><key>Weekday</key><integer>$WD</integer><key>Hour</key><integer>$WH</integer><key>Minute</key><integer>$WM</integer></dict>" false
WEEKDAYS=""; for d in 1 2 3 4 5; do WEEKDAYS+="<dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$MH</integer><key>Minute</key><integer>$MM</integer></dict>"; done
write_plist monthly monthly "<array>$WEEKDAYS</array>" false
echo "installed: daily $DH:$(printf %02d "$DM") + login → catchup | weekly weekday=$WD $WH:$(printf %02d "$WM") | monthly weekdays $MH:$(printf %02d "$MM") (last business day only)"
echo "run.sh = $PLUGIN_ROOT/scripts/run.sh"
