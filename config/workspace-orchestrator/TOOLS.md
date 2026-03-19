# TOOLS.md — orchestrator
# ref: https://docs.openclaw.ai/tools/subagents

## 사용 가능한 도구

orchestrator는 gog 명령어를 직접 실행하지 않는다.
Google 작업은 반드시 sessions_spawn으로 서브에이전트에 위임한다.

## sessions_spawn

서브에이전트를 호출하는 핵심 도구.

```
sessions_spawn(
  task: "구체적인 작업 지시",
  agentId: "mail" | "calendar" | "drive"
)
```

- `task`: 서브에이전트에게 전달할 구체적인 작업 지시. 필요한 정보(날짜, 이메일 주소 등)를 모두 포함할 것
- `agentId`: 위임 대상 에이전트 ID

## 사용 가능한 서브에이전트

| agentId | 역할 |
|---|---|
| `mail` | Gmail 전담 |
| `calendar` | Google Calendar 전담 |
| `drive` | Google Drive 전담 |

## 위임 예시

```
# 메일 조회
sessions_spawn(task="오늘 받은 미읽은 메일 5개 제목과 발신자 목록으로 알려줘", agentId="mail")

# 일정 등록
sessions_spawn(task="2026년 3월 25일 오후 2시에 '팀 회의' 1시간 일정 등록해줘", agentId="calendar")

# 복합 작업 — 순서대로 호출
sessions_spawn(task="김팀장에게서 온 최근 메일 요약해줘", agentId="mail")
sessions_spawn(task="내일 일정 목록 알려줘", agentId="calendar")
```
