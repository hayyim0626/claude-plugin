---
name: weekly-brief
description: 그 주의 worklog weekly 기록을 공유용으로 바꾼다 — Confluence 주간 보고 형식(프로젝트 → 작업 → 세부 불릿)과 종이 캘린더용 한 줄 요약. 트리거 - /worklog:weekly-brief, "주간 브리프", "컨플루언스 주간", "지난주에 뭐 했지".
argument-hint: [YYYY-MM-DD | this]
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

# Weekly Brief — 주간 기록을 공유용으로

`/worklog:worklog weekly` 가 만든 `weekly/YYYY/YYYY-Www.md` 를 읽어 두 가지 형식으로 바꿔 **대화에 출력**한다. 파일을 만들지도 커밋하지도 않는다 — Confluence 와 캘린더가 정본이고 같은 내용이 weekly 파일에 이미 있다.

## 사용

```
/worklog:weekly-brief            # 지난주
/worklog:weekly-brief 2026-10-06 # 그 날짜가 속한 주
/worklog:weekly-brief this       # 이번 주
```

## 절차

1. 기간 계산: 인자 없음 → 직전 월~일, 날짜 → 그 주, `this` → 이번 주. ISO 주차로 `$WORKLOG_DIR/weekly/YYYY/YYYY-Www.md` 를 찾는다(`WORKLOG_DIR` 기본 `~/worklog`).
2. weekly 파일이 없으면 그 주의 `daily/` 파일들을 읽어 같은 형식으로 만든다. daily 도 없으면 "그 주 기록이 없습니다 — `/worklog:worklog weekly {날짜}` 를 먼저 실행" 으로 안내하고 끝낸다.
3. 아래 **Confluence 형식**으로 변환해 출력하고, 그 아래에 weekly 파일 상단의 **한 줄 요약**(캘린더용)을 그대로 붙인다.
4. AskUserQuestion — `이대로 사용` / `수정 필요` / `캘린더에 적기`. 캘린더는 그 주 월요일 종일 이벤트로 한 줄 요약을 제목 삼아 `gcalcli --calendar "{config.calendar}" add --title "…" --when "{월요일}" --allday --noprompt`, 실패하면 `pbcopy`.

## Confluence 형식

팀 주간 보고 페이지의 형식이다. 복사해서 그대로 붙일 수 있어야 한다.

```
- Shop @Your Name
    - 재고 잠금 수량 단위 전환 (백엔드)
        - 상품 단위 잠금을 수량 단위로 바꾸고 해제 시점을 장바구니 만료에서 주문 종료로 이동
        - staging·prod 실주문 검증
    - 정기 배송 구현
        - 정기 배송을 독립 상품 유형으로 추가, 확정 조건 게시(주기·할인·건너뛰기 규칙)
        - 갱신 자동 실행(스케줄러 → 결제 지시), 실패 시 재시도·보류
    - 결제사 후보 리서치(A사·B사)
- Billing @Your Name
    - 구독 상태 용어 전환(active/paused)
    - 결제사 샌드박스 계정 승인 대기
- Design System @Your Name
    - 스토리북 배포 경로 사무실 IP 제한(보안 점검 조치)
```

규칙:
- 1단계 = 프로젝트명 + 멘션(config 의 `confluence.mention`, 없으면 `@Your Name`). 활동 없는 프로젝트는 넣지 않는다.
- 2단계 = weekly 의 항목 제목에서 영역 대괄호를 떼고 **명사구로** 줄인 것. 괄호로 핵심 수단을 붙여도 된다.
- 3단계 = 그 항목의 설명 문장에서 **무엇을 했는지만** 1~3줄. "왜"와 판단은 넣지 않는다(Confluence 독자는 팀이고 이유는 ADR 에 있다). 한 줄이면 3단계를 생략하고 2단계에 괄호로 넣는다.
- 들여쓰기 4칸, `-` 불릿, 마침표 없음, `*` 금지, 커밋 해시·수치 없음.
- 회의·행사·외부 대응처럼 git 에 없는 항목(예: "컨퍼런스 부스 운영")은 자동으로 못 잡으므로 출력 끝에 "git 에 없는 항목(행사·회의·외부 대응)은 직접 추가" 한 줄을 남긴다.
- 전주 Confluence 페이지와 중복되는 "대기 중" 항목(외부 승인 대기 등)은 상태가 그대로면 그대로 적는다 — 진행 중임을 보이는 용도다.

## 한 줄 요약 (캘린더)

weekly 파일 3행의 `> …` 인용문을 그대로. 없으면 Confluence 2단계 항목들을 쉼표로 이어 만든다. 마침표 없음, `*` 금지.
