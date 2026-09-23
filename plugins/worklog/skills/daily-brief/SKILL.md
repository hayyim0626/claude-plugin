---
name: daily-brief
description: 어제 한 작업과 오늘 할 작업을 정리하고, Google Calendar 일정을 포함하여 Slack용 데일리 브리프를 생성합니다. 트리거 - /worklog:daily-brief, "데일리 브리프"
argument-hint: [YYYY-MM-DD]
allowed-tools: Bash, Read, Glob, Grep, Write, AskUserQuestion, Agent, ToolSearch, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Google_Calendar__list_events
---

# Daily Brief — 데일리 브리프 생성

어제 한 작업(git 기반)과 오늘 할 작업(추천)을 정리하고, Google Calendar 일정을 포함하여 Slack에 바로 붙여넣을 수 있는 데일리 브리프를 생성합니다.

## 사용 방법

```
/worklog:daily-brief
```

**인자**: $ARGUMENTS (없으면 오늘 날짜 기준으로 자동 실행)

---

## 데이터 소스

### 1. Git History (어제 작업)
- 어제 날짜의 커밋 로그 (author 기준)
- 현재 스테이징/언스테이징된 변경사항 (진행 중인 작업)

### 2. Google Calendar (어제 + 오늘 일정)
- **도구**: `gcalcli` (실행 불가 시 Google Calendar MCP `list_events`로 대체)
- 어제 미팅: 참석한 회의 목록
- 오늘 미팅: 예정된 회의 목록
- **`config.json` 의 `calendar` 값으로 캘린더를 1개로 한정한다** (회의실 / 공유 캘린더의 이벤트가 끼어드는 것을 방지)

### 3. 프로젝트 문서 (오늘 추천)
- `context/history/` — 최근 변경 이력
- 체크리스트/TODO 파일 — 미완료 항목

---

## 설정 — `$WORKLOG_DIR/config.json`

설정은 worklog 플러그인 공통으로 **`$WORKLOG_DIR/config.json` 한 파일**에 있다(`WORKLOG_DIR` 기본값 `~/worklog`). 플러그인 안에는 개인 설정을 두지 않는다.

- 최상위 `git_author`, `calendar` 를 쓴다.
- 이 스킬 전용 키는 `daily_brief` 객체 아래: `path_mapping`, `keyword_mapping`, `todo_sources`, `exclude_events`, `slack{channel_id, channel_name, thread_keyword}`.
- 파일이 없으면 `${CLAUDE_PLUGIN_ROOT}/config.example.json` 을 복사해 채우라고 안내하고 종료한다.

```bash
CFG="${WORKLOG_DIR:-$HOME/worklog}/config.json"; jq '{git_author, calendar, daily_brief}' "$CFG"
```

매핑에 없는 경로는 커밋 메시지와 변경 내용을 기반으로 AI가 자동 추론한다.

---

## 수행 절차

### Step 1: 날짜 확인

- 오늘 날짜와 어제 날짜를 계산한다.
- `$ARGUMENTS`에 날짜가 있으면 해당 날짜를 "오늘"로 사용한다.

### Step 2: 설정 파일 로드

위 "설정" 절의 명령으로 `$WORKLOG_DIR/config.json` 을 읽는다. 아래에서 `config.X` 는 최상위 키, `config.daily_brief.X` 는 이 스킬 전용 키다.

### Step 3: 어제 작업 수집 (병렬 실행)

아래를 **병렬로** 실행한다:

#### 3-1. Git 커밋 로그

```bash
# 어제 커밋 (모든 브랜치)
git log --all --author="$(git config user.name)" --since="{어제} 00:00" --until="{오늘} 00:00" --format="%h %s" --no-merges

# 각 커밋의 변경 파일
git diff-tree --no-commit-id --name-only -r {commit_hash}
```

#### 3-2. 현재 로컬 변경사항 (진행 중인 작업)

```bash
git status --short
git diff --name-only
git diff --cached --name-only
```

#### 3-3. Google Calendar 어제 일정

```bash
gcalcli --calendar "{config.calendar}" agenda "{어제} 00:00" "{어제} 23:59" --nocolor --nodeclined
```

- **반드시 `--calendar "{config.calendar}"` 를 붙여 내 캘린더 1개만 조회한다.** 옵션을 빼면 회의실(WB-8-*) / 공유 캘린더의 이벤트가 전부 끼어든다.
- `config.json` 에 `calendar` 가 없으면: 사용자에게 "config.json 의 `calendar` 키에 본인 이메일을 넣어주세요" 안내 후, 일단 옵션 없이 실행하고 결과에 회의실 이벤트가 섞일 수 있음을 명시한다.
- `gcalcli`가 없거나 실행 오류가 나면(예: truststore 버그): **Google Calendar MCP로 대체한다.** ToolSearch로 `mcp__claude_ai_Google_Calendar__list_events` 스키마를 로드한 뒤 `calendarId: {config.calendar}`, `startTime`/`endTime`을 KST(+09:00) ISO 8601로 지정해 호출. MCP도 사용 불가할 때만 캘린더 없이 나머지 섹션만 생성하고 사용자에게 안내한다.
- `config.daily_brief.exclude_events` 배열에 포함된 이벤트명은 결과에서 제외한다.

### Step 4: 오늘 계획 수집 (병렬 실행)

#### 4-1. Google Calendar 오늘 일정

```bash
gcalcli --calendar "{config.calendar}" agenda "{오늘} 00:00" "{오늘} 23:59" --nocolor --nodeclined
```

- **3-3 과 동일하게 `--calendar "{config.calendar}"` 필수.**
- `config.daily_brief.exclude_events` 배열에 포함된 이벤트명은 결과에서 제외한다.

#### 4-2. 오늘 작업 추천 소스

- 어제 커밋에서 이어지는 작업 흐름 분석
- `context/history/` 최근 파일에서 미완료 항목 확인
- 프로젝트 내 체크리스트/TODO 파일 확인:
  - `**/todo.md`, `**/*checklist*`, `**/TODO`

### Step 5: 작업 그룹핑 및 분류

수집된 데이터를 프로젝트-팀 매핑을 기반으로 그룹핑한다:

1. 각 커밋의 변경 파일 경로를 `config.daily_brief.path_mapping`과 매칭
2. 매칭되지 않는 항목은 커밋 메시지 + 파일 경로로 AI가 추론
3. 동일 프로젝트 내 관련 커밋들을 하나의 작업 단위로 묶기
4. 각 작업 단위에 대해 **구체적이지만 간결한** 설명 생성

**그룹핑 규칙**:
- 최상위: 프로젝트명 (예: `Partner API`, `Figma to Code`)
- 최하위: 작업 항목 (커밋 기반 요약)
- 팀명은 출력에 포함하지 않는다

### Step 6: 오늘 작업 추천 생성

어제 작업 흐름과 수집된 TODO/체크리스트를 기반으로 오늘 할 작업을 추천한다:

- 어제 작업의 자연스러운 다음 단계
- 체크리스트에서 미완료(unchecked) 항목 중 연관된 것
- 진행 중인 로컬 변경사항이 있으면 해당 작업 포함

### Step 7: 사용자에게 초안 확인

생성된 브리프 초안을 사용자에게 보여주고 수정 여부를 확인한다.

**AskUserQuestion**:
- "데일리 브리프 초안을 확인해주세요. 수정할 내용이 있나요?"
- 옵션: `이대로 사용` / `수정 필요`

### Step 8: Slack 전송 (Slack MCP)

확정된 브리프를 **claude.ai Slack MCP**로 오늘 날짜의 FE Daily 리마인더 스레드에 답글로 전송한다.
(구 방식이었던 Slack 앱 User OAuth Token + curl 은 폐기됨 — 토큰이 revoke되었고 재발급에 워크스페이스 관리자 승인이 필요하다.)

#### 8-1. 설정 로드

`config.daily_brief.slack` 에서 읽는다:
- `channel_id` — 채널 ID
- `thread_keyword` — 리마인더 메시지 검색 키워드 (예: `FE Daily`)

#### 8-2. MCP 도구 로드 및 연결 확인

ToolSearch로 스키마를 로드한다:
`select:mcp__claude_ai_Slack__slack_read_channel,mcp__claude_ai_Slack__slack_send_message`

Slack MCP가 미인증 상태면(authenticate 도구만 보이거나 호출 시 인증 오류):
사용자에게 **"`/mcp` 실행 → `claude.ai Slack` 선택 → 브라우저에서 승인"**을 안내하고,
인증 완료를 기다렸다가 재시도한다. 사용자가 인증을 진행하지 않으면 `pbcopy` fallback.

#### 8-3. 오늘 리마인더 스레드 찾기

`slack_read_channel`을 `channel_id`, `response_format: "detailed"`, `limit: 10`으로 호출한다.
(detailed 형식이어야 각 메시지의 `Message TS` 값이 나온다.)

결과에서 **오늘 날짜(KST)이면서 `thread_keyword`를 포함하는 Slackbot 리마인더 메시지**의 `Message TS`를 추출한다.
리마인더를 찾지 못하면 사용자에게 알리고 `pbcopy` fallback.

#### 8-4. 전송

`slack_send_message`를 호출한다:
- `channel_id`: config의 채널 ID
- `thread_ts`: 8-3에서 찾은 리마인더 TS
- `message`: 확정된 브리프 마크다운 그대로 (4칸 들여쓰기 dash 리스트 — MCP가 Slack rich text 리스트로 변환해준다. Block Kit 수동 변환 불필요)

전송 성공 시: 응답의 `message_link`와 함께 "Slack FE Daily 스레드에 전송 완료!" 메시지 출력.
전송 실패 시: 에러 내용 표시 후 `pbcopy` fallback.

---

## 출력 형식 (마크다운 리스트)

```
- 어제 한 일
    - {프로젝트명}
        - {작업 항목}
            - {작업 상세}
    - {프로젝트명2}
        - {작업 항목}
    - {미팅 제목} ({HH:MM}~{HH:MM})
- 오늘 계획
    - {프로젝트명}
        - {작업 항목}
    - {미팅 제목} ({HH:MM}~{HH:MM})
```

### 출력 형식 규칙

1. `- ` (dash + space)로 항목 시작
2. 하위 항목은 **4칸 공백** 들여쓰기
3. `*` (별표) 사용 금지 (Slack에서 이탤릭으로 렌더링됨)
4. 회의가 없으면 회의 항목을 포함하지 않음
5. 작업 상세는 부가 설명이 필요한 경우에만 포함
6. 계층: 섹션 → 프로젝트명 → 작업 항목 → 작업 상세 (팀명 계층 없음)

---

## 출력 예시

```
- 어제 한 일
    - Partner API
        - Table 컴포넌트를 packages/ui로 공통화 및 import 경로 전환
        - Storybook 의존성 설치 및 전체 컴포넌트 스토리 추가
        - Button, CopyButton 클릭 시 포커스 링 제거 (focus → focus-visible)
    - Figma to Code
        - Tokens Studio for Figma 플러그인 설치 및 Bitbucket 연동
        - Style Dictionary 토큰 파이프라인 구축
            - tokens.json → tailwind.config.ts 자동 변환, 하드코딩 제거
        - 토큰 동기화 자동화
            - husky pre-commit 기반 검증
            - Bitbucket CI verify:tokens 파이프라인 추가
    - AI TF 정기회의 (10:30)
- 오늘 계획
    - Figma to Code
        - Figma에서 Button 컴포넌트 작업 (variant/size 정의 + 디자인 토큰 적용)
        - Figma에서 Input 컴포넌트 작업 (state 정의 + 디자인 토큰 적용)
        - components.json 스키마 설계 (컴포넌트 → 코드 매핑 구조)
    - Dolfin KR 프로덕트 데일리 (10:30)
    - 디자인시스템 관련 협의 (14:00)
```

---

## 설정 예시

`${CLAUDE_PLUGIN_ROOT}/config.example.json` 의 `daily_brief` 객체 참조. `calendar` 는 `gcalcli list` 의 owner 캘린더 ID(보통 본인 이메일) — 없으면 회의실/공유 캘린더 이벤트가 전부 섞인다.

매핑 우선순위: `path_mapping`(파일 경로 prefix, 구체적인 것 우선) → `keyword_mapping`(커밋 메시지 키워드) → AI 추론.
