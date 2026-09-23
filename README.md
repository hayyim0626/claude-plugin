# claude-plugin

hayyim0626 의 Claude Code 플러그인 마켓플레이스. 개인 설정·기록은 여기 두지 않는다.

```
/plugin marketplace add hayyim0626/claude-plugin
/plugin install worklog@claude-plugin
```

## worklog

git 이력·문서(ADR·PRD·report)·Claude 세션에서 "한 일"과 "내린 판단"을 모아 개인 저장소에 daily / weekly / monthly / projects(결정 로그) 로 쌓는다. 목적은 보고가 아니라 기억의 외부화 — 포트폴리오·이력서 재료.

| 스킬 | 역할 |
|---|---|
| `/worklog:worklog daily\|weekly\|monthly\|projects\|catchup` | 기록 생성. `catchup` 은 마지막 기록 이후 빈 날·주·달을 채운다 |
| `/worklog:daily-brief` | 어제·오늘 요약 + 캘린더 → Slack 데일리 스레드 |
| `/worklog:weekly-brief` | 주간 한 줄 요약 → 캘린더 종일 이벤트 또는 worklog 기록 |

### 설정

1. 기록 저장소를 만들고 클론한다(예: `~/worklog`, private 권장). 다른 경로면 `WORKLOG_DIR` 환경변수.
2. `plugins/worklog/config.example.json` 을 `~/worklog/config.json` 으로 복사해 채운다 — `repos[]`(훑을 저장소와 표시 이름), `git_author`, `doc_dirs`, `allowed_emails`, `daily_brief.*`.
3. 기록 규칙(구조·태그·공개 경계)은 저장소의 `README.md` 에 둔다. 스킬이 첫 실행 때 읽는다.

### 자동 실행 (macOS launchd)

```
bash ~/.claude/plugins/.../worklog/scripts/install-launchd.sh   # 또는 클론한 plugins/worklog/scripts/install-launchd.sh
```

매일 `config.schedule`(기본 19:00)과 로그인 시 `run.sh` 가 돈다: `claude -p "/worklog:worklog catchup --headless"` → `redact-check.sh`(URL·키·이메일 패턴) → 커밋·푸시. 맥북이 꺼져 있던 날은 다음 실행 때 최대 14일까지 따라잡는다. 로그는 `~/Library/Logs/worklog.log`. 제거는 `install-launchd.sh --uninstall`.

plist 는 설치 시점의 `run.sh` 경로를 박아 넣으므로, 마켓플레이스 설치본이 아니라 **클론한 디렉토리**에서 설치하는 편이 플러그인 업데이트에 안전하다.

### 스크립트

| 파일 | 역할 |
|---|---|
| `scripts/collect.sh SINCE UNTIL [--status] [--no-sessions]` | 저장소별 커밋·디렉토리 분포·문서 변경 + 세션 사용자 메시지 |
| `scripts/sessions.py` | collect.sh 가 부르는 세션 파서 |
| `scripts/redact-check.sh [files]` | 공개 경계 검사, 위반 시 exit 1 |
| `scripts/run.sh` | 헤드리스 catchup·커밋·푸시 |
| `scripts/install-launchd.sh [--uninstall]` | launchd 등록 |
