---
name: worklog
description: 개인 작업 기록 — git 이력·문서·Claude 세션에서 "한 일"과 "내린 판단"을 모아 ~/worklog 에 daily/weekly/monthly/projects 로 쌓는다. 트리거 - /worklog:worklog, "워크로그", "오늘 기록", "결정 로그"
argument-hint: daily [YYYY-MM-DD] | weekly [YYYY-MM-DD|this] | monthly [YYYY-MM] | projects [SINCE UNTIL] | catchup [--headless]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# worklog — 개인 작업 기록

목적은 보고가 아니라 **기억의 외부화**다. 나중에 포트폴리오·이력서를 쓸 때 "무엇을 했나"보다 "왜 그렇게 판단했나"가 필요하므로, 한 일 옆에 반드시 **판단**을 남긴다.

## 위치와 설정

- 기록 저장소: `$WORKLOG_DIR` (기본 `~/worklog`). 설정은 `$WORKLOG_DIR/config.json` — `repos[]`(경로·프로젝트명), `doc_dirs`, `sessions`, `allowed_emails`.
- 스크립트: `${CLAUDE_PLUGIN_ROOT}/scripts/collect.sh SINCE UNTIL [--status] [--no-sessions]`, `${CLAUDE_PLUGIN_ROOT}/scripts/redact-check.sh [files]`.
- 상태: `$WORKLOG_DIR/.state/last_checked` — catchup 이 마지막으로 검사한 날짜(YYYY-MM-DD).
- 파일 규칙은 `$WORKLOG_DIR/README.md` 가 정답이다. 처음 실행이면 먼저 읽는다.

## 인자

`$ARGUMENTS` 의 첫 단어가 모드다. 없으면 `daily`.
`--headless` 가 있으면 **질문 없이 파일만 쓰고 끝낸다**(커밋은 run.sh 몫). 없으면 초안을 보여 주고 확인 뒤 커밋·푸시한다.

## 공통 규칙

### 공개 경계 (README "공개 경계")

- 쓰지 않는다: 소스코드·코드 블록·설정값·URL·키·토큰·고객 개인정보·`allowed_emails` 외 이메일.
- 쓴다: 기관명·프로젝트명·기술 스택·결정과 근거·커밋 메시지 수준의 산문. 파일 경로는 디렉토리 수준까지(`apps/portal-be`).
- 저장 전 `redact-check.sh` 를 돌리고, 걸리면 그 줄을 고친 뒤 다시 돌린다.

### 프로젝트와 태그

- 프로젝트 이름은 `config.repos[].project` 를 그대로 쓴다. 세션 힌트의 디렉토리와 커밋 내용이 다르면 **내용**을 따른다(예: canton-poc 디렉토리에서 PADO 작업을 했으면 PADO).
- 같은 커밋(제목·날짜 동일, 해시만 다름)이 두 저장소에 보이면 하나로 센다.
- 항목마다 태그를 붙인다: `fe` `be` `chain` `infra` `data` `research` `product-decision` `vendor` `ai-workflow` `tooling`. 여러 개가 정상. 백틱으로 감싸 줄 끝에 둔다.

### 판단 추출 (가장 중요)

세 출처에서 뽑는다. 우선순위 순.

1. **ADR** — collect 의 `=== DOCS ===` 에 `docs/adr/*.md` 가 A 또는 M 으로 있으면 **그 저장소에서 파일을 직접 읽는다**(`Read {repo}/{path}`). "결정" 절과 버전 이력 마지막 행에서 그날 추가된 결정을 요약한다. "검토한 대안" 절이 있으면 기각 이유를 한 줄 챙긴다. ADR 이 없는 저장소는 PRD·report·plan 문서가 그 역할이다 — "결정"·"고려 사항"·"Open Question"·"대안" 절을 읽는다. 문서가 많으면 그 기간에 **추가(A)된 것** 위주로 읽고 수정(M)은 제목만 본다.
2. **세션 사용자 메시지** — `##### SESSIONS` 에서 방향을 정하거나 기각한 문장만 고른다: "~로 하자", "~는 빼자/삭제", "~말고 ~", "우선 ~부터", "왜 ~?" 뒤에 이어진 선택, 순서·범위·배포 결정. UI 잔손질("버튼 줄여", "색 진해")은 원칙이 드러날 때만(예: "이메일은 굳이 안 넣어도" → 노출 정보 최소화).
3. **커밋 메시지의 " — " 뒤** — 이유가 붙은 커밋은 그 이유가 판단이다.

형식: `- (프로젝트) 무엇을 어떻게 하기로 — 이유. (ADR-NNNN vX.Y)` 한 줄. 이유를 모르면 이유 없이 쓴다. 지어내지 않는다.

### AI 활용 추출

세션에서 **작업 방식**이 드러난 것만 적는다 — 아티팩트로 UI 시안을 돌린 것, 브라우저 자동화로 외부 서비스 설정, 딥리서치 워크플로, 서브에이전트 검증, 스킬·플러그인 제작. 그날 특별한 게 없으면 절을 생략한다.

### 문체

한국어. 한 항목 한 줄. 마침표 없음. `*` 금지. 커밋 해시 없음. 수는 근거 절에만.

## 날짜 계산

```bash
TODAY=$(date +%F); YESTERDAY=$(date -v-1d +%F)
python3 -c "import datetime as d; x=d.date.fromisoformat('$D'); y,w,_=x.isocalendar(); print(f'{y}-W{w:02d}')"        # ISO 주
python3 -c "import datetime as d; x=d.date.fromisoformat('$D'); m=x-d.timedelta(days=x.weekday()); print(m, m+d.timedelta(days=6))"  # 월·일
```

요일 표기: `(월)` … `(일)`.

## 모드

### daily [YYYY-MM-DD] (기본 어제)

1. `collect.sh D D --status` 실행. (`--status` 는 D 가 오늘일 때만 의미 있으니 어제면 빼도 된다.)
2. 커밋·문서·세션이 전부 비어 있으면 **파일을 만들지 않고** "활동 없음"만 알린다.
3. ADR 변경이 있으면 판단 추출 규칙 1 대로 파일을 읽는다.
4. `daily/YYYY/MM/YYYY-MM-DD.md` 를 아래 형식으로 쓴다.
5. `projects` 모드를 같은 날짜 범위로 이어서 수행한다(ADR 변경이 있을 때만).

```markdown
# 2026-09-21 (월)

## 한 일

### PADO
- XRPL 지갑 입출금 슬랙 알림 — portal-be 상주 루프로 원장 폴링, DB 커서, 채널별 웹훅 카드 `be` `chain`
- 집금 지갑 어드민 관리 — 포털 DB 설정, WB 상세 집금 카드, 램프 XRP 송금 `fe` `be` `chain`

### Wallet
- Turnkey 답변 검토 — 키 통제권·콜드월렛 요구가 충족되는지 판단 `vendor`

## 판단
- (PADO) 입출금 감시 기동 알림은 커서 없는 첫 기동에만 — 재배포마다 채널에 뜨는 잡음 차단 (ADR-0055)
- (PADO) 게이트웨이와 포털 BE 를 동시에 배포 — 서로 의존 없음을 확인한 뒤

## AI 활용
- 어드민 집금 화면을 아티팩트 시안으로 3회 반복한 뒤 실제 코드에 반영
- 브라우저 자동화로 GemWallet 트러스트라인 등록 테스트

## 근거
- PADO 커밋 8개 (apps/portal-be, apps/portal-fe, gateway), ADR-0055 신규, ADR-0047 v1.7, ADR-0052 v1.1, PRD·report 4건
- 세션: PADO 3건, Wallet 1건
```

한 일은 커밋 하나하나가 아니라 **기능·주제 단위**로 묶는다(PRD·report 제목이 있으면 그 제목이 출발점). 잔손질 fix 는 상위 작업에 흡수.

### weekly [YYYY-MM-DD | this] (기본 지난주)

기간: 인자 없음 → 직전 월~일. 날짜 → 그 날짜가 속한 월~일. `this` → 이번 주 월~오늘.

1. 그 주의 `daily/` 파일을 모두 읽는다(Glob). 이것이 1차 재료다.
2. `collect.sh 월 일 --no-sessions` 로 daily 가 놓친 커밋·문서를 보정한다. daily 가 하나도 없으면 세션까지 포함해 수집하고, 판단 하이라이트는 판단 추출 규칙(문서·커밋 이유)으로 직접 뽑는다. 커밋·문서·세션이 전부 비어 있으면 파일을 만들지 않는다.
3. 작업 단위로 묶는다 — **3~7개**. 이름은 `{무엇}({핵심 수단·범위})` 꼴 명사구. 회의·잔손질·다른 사람 커밋은 뺀다. 코드 없어도 결정·검증·문의는 넣는다. 8개가 넘으면 상위 주제로 다시 묶는다.
4. `weekly/YYYY/YYYY-Www.md`:

```markdown
# 2026-W38 · 09-14(월) ~ 09-20(일)

- XRPL 기관 서명·재무 지갑 운영 정비 (WB 기관 참여·KMS 전환·서명 속도·입출금 내역) `chain` `be` `fe`
- PADO prod Mainnet 전환 (원칙 ADR·점검·공개노드 배너 제거) `infra` `product-decision`

## 판단 하이라이트
- (PADO) 재무 지갑은 Fireblocks 로, 램프 계좌는 KMS 1키로 — 운영 키와 정산 키의 책임 분리 (ADR-0047 v1.3)

## 근거
- 기관 서명·재무 지갑 — PADO 커밋 10개, ADR-0047 v1.2~v1.6
- 저장소 활동 없음: Partner API, WB Pages
```

판단 하이라이트는 그 주 daily 의 판단 중 **이력서에 남을 만한 것 3개 이내**.

### monthly [YYYY-MM] (기본 지난달)

git 을 다시 훑지 않는다. 그 달의 `weekly/` 파일과 `projects/*.md` 에서 그 달 날짜의 항목을 읽어 `monthly/YYYY/YYYY-MM.md` 를 쓴다.

```markdown
# 2026-09

## PADO
XRPL 레일을 TestNet 에서 Mainnet 으로 올리는 달이었다. … (2~5문장 서사: 무엇을 왜 했고 어디까지 갔는지)

## Canton
…

## 이 달의 결정
- (PADO) 자산 유형과 정산 레일을 분리해 상품×레일 매트릭스로 — 주식을 Canton 에도 태우기 위해 (ADR-0053)

## 수치
- 커밋 약 90개 (PADO 80, Canton 6, Tooling 4), ADR 신규 6개·개정 9개
```

### projects [SINCE UNTIL] (기본 어제)

collect 의 `=== DOCS ===` 에서 `docs/adr/` 의 A·M 파일마다(ADR 이 없는 저장소는 PRD·plan 문서의 **A** 파일마다 — 제목이 곧 결정 단위이고 report 는 그 PRD 의 결과라 따로 항목을 만들지 않는다):

1. 저장소에서 문서를 읽어 번호·제목·버전(버전 이력 마지막 행, 없으면 v1.0)을 얻는다. `README.md`(인덱스)는 건너뛴다. 실질적인 결정이 없는 문서(단순 작업 목록)는 항목을 만들지 않는다.
2. 대상 파일 `projects/{slug}.md` — slug 는 프로젝트명을 소문자·공백은 `-` 로(`pado`, `canton`, `wallet`, `partner-api`, `wb-pages`, `tooling`). 없으면 만든다:

```markdown
# PADO

기관 간 채권·주식 마켓플레이스 — 포털·어드민·XRPL 레일·서명 게이트웨이 (한 줄 소개)

## 결정 로그
```

3. 같은 `ADR-NNNN` 과 같은 버전이 이미 있으면 건너뛴다(Grep). 없으면 **파일 끝에** 추가:

```markdown
### 2026-09-21 · ADR-0055 XRPL 지갑 입출금 슬랙 알림 (v1.0) `be` `chain`
(ADR 이 없는 프로젝트는 `### 2026-01-21 · PRD 파트너 API 게이트웨이 구조 (v1.0)` 처럼 문서 종류+제목)
- 문제: 기관 입출금을 운영자가 원장을 직접 보지 않고 알 방법이 없었다
- 결정: portal-be 상주 루프가 원장 트랜잭션을 폴링하고 DB 커서로 중복을 막으며 채널별 웹훅으로 카드를 보낸다
- 기각한 대안: 게이트웨이에 두는 안 — 서명 전용 프로세스에 조회 책임을 섞지 않기 위해
- 내 판단: 기동 알림은 첫 기동에만 — 재배포 잡음이 신호를 가린다
```

"내 판단"은 세션·커밋 이유에서 드러난 것만. 없으면 줄을 뺀다.

### catchup [--headless]

맥북이 꺼져 있던 기간을 메운다. 순서:

1. `LAST=$(cat $WORKLOG_DIR/.state/last_checked)` — 없으면 어제 하루만. `START=LAST+1`, `END=어제`. `START` 가 `END-13` 보다 이르면 `END-13` 으로 자른다(최대 14일).
2. `START..END` 각 날짜에 대해 `daily/…/날짜.md` 가 없으면 **daily** 를 수행한다(활동 없는 날은 파일 없이 넘어간다). 이미 있으면 건너뛴다.
3. `START` 가 속한 주부터 `END` 까지, **일요일이 END 이하인 주**마다 `weekly/…/YYYY-Www.md` 가 없으면 **weekly**.
4. 같은 방식으로 **말일이 END 이하인 달**마다 `monthly/…` 가 없으면 **monthly**.
5. `.state/last_checked` 에 `END` 를 쓴다.
6. 마지막에 만든 파일 목록을 한 줄씩 출력한다. 채울 게 없었으면 "채울 것 없음 (last_checked=…)".

`--headless` 에서는 AskUserQuestion 을 절대 쓰지 않는다. 커밋도 하지 않는다.

## 마무리 (대화형일 때)

1. 만든/고친 파일의 내용을 보여 준다.
2. AskUserQuestion — "이대로 저장할까요?" `저장` / `수정 필요`.
3. 저장이면 `redact-check.sh {files}` → 통과 시 `cd $WORKLOG_DIR && git add -A && git commit -m "worklog: {모드} {기간}" && git push`.
4. `.state/last_checked` 는 catchup 만 갱신한다(daily 를 직접 돌린 날짜가 `last_checked` 보다 뒤면 그 날짜로 올린다).
