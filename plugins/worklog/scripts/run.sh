#!/usr/bin/env bash
# run.sh — launchd 가 부르는 헤드리스 실행: catchup → 공개 경계 검사 → commit·push
# 환경: WORKLOG_DIR(기본 ~/worklog). node/claude 경로는 config.claude_bin 또는 nvm 최신 버전에서 찾는다.
set -uo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
export WORKLOG_DIR
CFG="$WORKLOG_DIR/config.json"
LOG="$HOME/Library/Logs/worklog.log"
STATE="$WORKLOG_DIR/.state"
mkdir -p "$STATE" "$(dirname "$LOG")"
log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
notify(){ osascript -e "display notification \"$1\" with title \"worklog\"" >/dev/null 2>&1 || true; }

if ! mkdir "$STATE/lock" 2>/dev/null; then log "skip: lock held"; exit 0; fi
trap 'rmdir "$STATE/lock" 2>/dev/null' EXIT

CLAUDE_BIN=$(jq -r '.claude_bin // empty' "$CFG" 2>/dev/null)
if [ -z "$CLAUDE_BIN" ]; then
  CLAUDE_BIN=$(ls -1 "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | sort -V | tail -1)
fi
[ -x "${CLAUDE_BIN:-}" ] || CLAUDE_BIN=$(command -v claude || true)
[ -n "$CLAUDE_BIN" ] || { log "error: claude not found"; notify "claude 실행 파일을 찾지 못함"; exit 1; }
export PATH="$(dirname "$CLAUDE_BIN"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# 어제까지 이미 검사했으면 즉시 종료 (로그인 시 중복 실행 방지)
YESTERDAY=$(date -v-1d +%F)
LAST=$(cat "$STATE/last_checked" 2>/dev/null || echo "")
if [ "$LAST" = "$YESTERDAY" ] || [ "$LAST" \> "$YESTERDAY" ]; then log "skip: up to date ($LAST)"; exit 0; fi

cd "$WORKLOG_DIR" || exit 1
git pull --rebase -q 2>>"$LOG" || log "warn: pull failed"

log "start catchup (last_checked=$LAST)"
"$CLAUDE_BIN" -p "/worklog:worklog catchup --headless" \
  --plugin-dir "$PLUGIN_ROOT" \
  --permission-mode bypassPermissions \
  --output-format text >> "$LOG" 2>&1
RC=$?
log "claude exit=$RC"

cd "$WORKLOG_DIR"
git add -A
if git diff --cached --quiet; then log "nothing to commit"; exit 0; fi
if ! "$PLUGIN_ROOT/scripts/redact-check.sh" >> "$LOG" 2>&1; then
  git reset -q
  log "blocked: redact-check failed — 변경은 워킹 트리에 남김"
  notify "공개 경계 위반으로 커밋을 건너뜀 — worklog.log 확인"
  exit 1
fi
git commit -q -m "worklog: 자동 기록 $(date +%F)" && git push -q origin HEAD 2>>"$LOG" \
  && log "pushed" || { log "push failed"; notify "worklog push 실패"; }
