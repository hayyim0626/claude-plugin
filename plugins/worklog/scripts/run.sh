#!/usr/bin/env bash
# run.sh [catchup|weekly|monthly] — launchd 가 부르는 헤드리스 실행. 기본 catchup.
#   catchup : 어제까지 빠진 daily(최대 14일) + 끝난 주·달 중 빠진 weekly·monthly
#   weekly  : 이번 주(월~오늘) weekly — 금요일 저녁 스케줄
#   monthly : 오늘이 이 달의 마지막 영업일일 때만 이번 달 monthly — 평일 저녁 스케줄
# 환경: WORKLOG_DIR(기본 ~/worklog). claude 경로는 config.claude_bin 또는 nvm 최신 버전.
set -uo pipefail
MODE="${1:-catchup}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
export WORKLOG_DIR
CFG="$WORKLOG_DIR/config.json"
LOG="$HOME/Library/Logs/worklog.log"
STATE="$WORKLOG_DIR/.state"
mkdir -p "$STATE" "$(dirname "$LOG")"
log(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODE" "$*" >> "$LOG"; }
notify(){ osascript -e "display notification \"$1\" with title \"worklog\"" >/dev/null 2>&1 || true; }

CLAUDE_BIN=$(jq -r '.claude_bin // empty' "$CFG" 2>/dev/null)
[ -n "$CLAUDE_BIN" ] || CLAUDE_BIN=$(ls -1 "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | sort -V | tail -1)
[ -x "${CLAUDE_BIN:-}" ] || CLAUDE_BIN=$(command -v claude || true)
[ -n "$CLAUDE_BIN" ] || { log "error: claude not found"; notify "claude 실행 파일을 찾지 못함"; exit 1; }
export PATH="$(dirname "$CLAUDE_BIN"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

TODAY=$(date +%F); YESTERDAY=$(date -v-1d +%F)
case "$MODE" in
  catchup)
    LAST=$(cat "$STATE/last_checked" 2>/dev/null || echo "")
    if [ -n "$LAST" ] && [ ! "$LAST" \< "$YESTERDAY" ]; then log "skip: up to date ($LAST)"; exit 0; fi
    PROMPT="/worklog:worklog catchup --headless"; LABEL="catchup(${LAST:-처음}→$YESTERDAY)" ;;
  weekly)
    PROMPT="/worklog:worklog weekly this --headless"; LABEL="weekly $(python3 -c "import datetime as d;y,w,_=d.date.today().isocalendar();print(f'{y}-W{w:02d}')")" ;;
  monthly)
    # 오늘이 이 달의 마지막 영업일(월~금)인가: 다음 영업일이 다른 달이면 참
    if ! python3 - <<'PY'
import datetime as d, sys
t=d.date.today()
if t.weekday()>4: sys.exit(1)
n=t+d.timedelta(days=1)
while n.weekday()>4: n+=d.timedelta(days=1)
sys.exit(0 if n.month!=t.month else 1)
PY
    then exit 0; fi
    M=$(date +%Y-%m); PROMPT="/worklog:worklog monthly $M --headless"; LABEL="monthly $M" ;;
  *) echo "usage: run.sh [catchup|weekly|monthly]" >&2; exit 2 ;;
esac

if ! mkdir "$STATE/lock" 2>/dev/null; then log "skip: lock held"; exit 0; fi
trap 'rmdir "$STATE/lock" 2>/dev/null' EXIT

cd "$WORKLOG_DIR" || exit 1
git pull --rebase -q 2>>"$LOG" || log "warn: pull failed"
log "start $LABEL"
"$CLAUDE_BIN" -p "$PROMPT" --permission-mode bypassPermissions --output-format text >> "$LOG" 2>&1
log "claude exit=$?"

git add -A
if git diff --cached --quiet; then log "nothing to commit"; exit 0; fi
if ! "$PLUGIN_ROOT/scripts/redact-check.sh" >> "$LOG" 2>&1; then
  git reset -q
  log "blocked: redact-check failed — 변경은 워킹 트리에 남김"
  notify "공개 경계 위반으로 커밋을 건너뜀 — worklog.log 확인"
  exit 1
fi
FILES=$(git diff --cached --name-only -- 'daily/*' 'weekly/*' 'monthly/*' 'projects/*' | sed 's#.*/##; s/\.md$//' | tr '\n' ' ')
git commit -q -m "worklog: $LABEL" && git push -q origin HEAD 2>>"$LOG" \
  && { log "pushed: $FILES"; notify "기록됨: $FILES"; } \
  || { log "push failed"; notify "worklog push 실패"; }
