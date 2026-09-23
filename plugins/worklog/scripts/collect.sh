#!/usr/bin/env bash
# collect.sh SINCE UNTIL [--status] [--no-sessions]
#   SINCE/UNTIL: YYYY-MM-DD (양끝 포함, 로컬 시간)
#   설정: $WORKLOG_DIR/config.json (기본 ~/worklog)
set -uo pipefail
SINCE="${1:?usage: collect.sh SINCE UNTIL [--status] [--no-sessions]}"
UNTIL="${2:?usage: collect.sh SINCE UNTIL [--status] [--no-sessions]}"
shift 2
WITH_STATUS=0; WITH_SESSIONS=1
for a in "$@"; do
  case "$a" in
    --status) WITH_STATUS=1 ;;
    --no-sessions) WITH_SESSIONS=0 ;;
  esac
done
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
CFG="$WORKLOG_DIR/config.json"
[ -f "$CFG" ] || { echo "config not found: $CFG" >&2; exit 2; }

AUTHOR=$(jq -r '.git_author' "$CFG")
DOC_DIRS=$(jq -r '.doc_dirs // [] | join(" ")' "$CFG")
SINCE_TS="$SINCE 00:00"; UNTIL_TS="$UNTIL 23:59:59"

echo "##### RANGE $SINCE ~ $UNTIL"

jq -r '.repos[] | "\(.path)\t\(.project)\t\(.doc_dirs // [] | join(" "))"' "$CFG" | while IFS=$'\t' read -r path project repo_docs; do
  dir="${path/#\~/$HOME}"
  docs="${repo_docs:-$DOC_DIRS}"
  echo
  echo "##### REPO $project ($path)"
  if [ ! -d "$dir/.git" ]; then echo "MISSING"; continue; fi
  cd "$dir" || continue
  echo "=== COMMITS ==="
  git log --all --author="$AUTHOR" --since="$SINCE_TS" --until="$UNTIL_TS" \
    --format="%h %ad %s" --date=short --no-merges 2>/dev/null
  echo "=== DIRS ==="
  git log --all --author="$AUTHOR" --since="$SINCE_TS" --until="$UNTIL_TS" \
    --no-merges --name-only --format="" 2>/dev/null \
    | awk -F/ 'NF>1{print $1"/"$2} NF==1{print $1}' | sort | uniq -c | sort -rn | head -15
  if [ -n "$docs" ]; then
    echo "=== DOCS ==="
    # shellcheck disable=SC2086
    git -c core.quotepath=false log --all --author="$AUTHOR" --since="$SINCE_TS" --until="$UNTIL_TS" \
      --no-merges --name-status --format="" -- $docs 2>/dev/null | sort -u
  fi
  if [ "$WITH_STATUS" = 1 ]; then
    echo "=== STATUS ==="
    git -c core.quotepath=false status --short 2>/dev/null | head -20
  fi
done

if [ "$WITH_SESSIONS" = 1 ] && [ "$(jq -r '.sessions.enabled // true' "$CFG")" = "true" ]; then
  echo
  echo "##### SESSIONS"
  LIMIT=$(jq -r '.sessions.per_session_limit // 60' "$CFG")
  find "$HOME/.claude/projects" -name "*.jsonl" -newermt "$SINCE_TS" -size +8k 2>/dev/null \
    | grep -v "/subagents/" \
    | WL_CFG="$CFG" WL_SINCE="$SINCE" WL_UNTIL="$UNTIL" WL_LIMIT="$LIMIT" python3 "$(dirname "${BASH_SOURCE[0]}")/sessions.py"
fi
