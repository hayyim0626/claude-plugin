#!/usr/bin/env bash
# redact-check.sh [file...]  — 인자가 없으면 $WORKLOG_DIR 의 스테이징된 .md 전부
# 공개 경계(README "공개 경계") 위반 패턴이 있으면 목록을 찍고 1 로 종료
set -uo pipefail
WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"
CFG="$WORKLOG_DIR/config.json"
cd "$WORKLOG_DIR"
if [ $# -gt 0 ]; then FILES=("$@"); else
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM -- '*.md')
fi
[ ${#FILES[@]} -eq 0 ] && exit 0
ALLOWED=$(jq -r '.allowed_emails // [] | join("|")' "$CFG" 2>/dev/null | sed 's/\./\\./g')
PATTERNS='https?://|AKIA[0-9A-Z]{16}|sk_(live|test)_|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|xox[abp]-|-----BEGIN|password|passwd|secret_key|api[_-]?key\s*[:=]'
FAIL=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  hits=$(grep -nEi "$PATTERNS" "$f" || true)
  emails=$(grep -nEo '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$f" | { if [ -n "$ALLOWED" ]; then grep -vE "$ALLOWED"; else cat; fi; } || true)
  if [ -n "$hits$emails" ]; then
    FAIL=1
    echo "!! $f"
    [ -n "$hits" ] && echo "$hits" | sed 's/^/   /'
    [ -n "$emails" ] && echo "$emails" | sed 's/^/   email: /'
  fi
done
exit $FAIL
