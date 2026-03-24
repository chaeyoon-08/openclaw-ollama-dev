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

## HEARTBEAT 자동화 관리

### 목록 확인
exec 도구로 HEARTBEAT.md 내용 읽기:
```bash
cat ~/.openclaw/workspace-orchestrator/HEARTBEAT.md
```

### 자동화 추가
1. 사용자에게 추가할 자동화 내용 확인
2. exec 도구로 HEARTBEAT.md에 내용 추가
3. 추가 완료 후 전체 목록 다시 보여주기

### 자동화 제거
1. 현재 목록 보여주고 제거할 항목 번호 확인
2. exec 도구로 해당 섹션 제거
3. 제거 완료 후 전체 목록 다시 보여주기

## MEMORY.md 복원 플로우

사용자가 Drive의 MEMORY.md로 봇 기억을 복원 요청 시 아래 순서로 처리한다.

1. 사용자에게 확인:
   "Google Drive의 MEMORY.md로 현재 기억을 덮어씁니다.
    현재 기억은 모두 사라집니다. 진행할까요?"

2. 사용자 확인 후 drive 서브에이전트에 위임:
   ```
   sessions_spawn(
     task="DRIVE_MEMORY_FOLDER(기본값: openclaw-memory) 폴더에서
           MEMORY.md 파일을 찾아서 내용을 반환해줘",
     agentId="drive"
   )
   ```

3. 반환된 내용으로 `~/.openclaw/workspace-orchestrator/MEMORY.md` 덮어쓰기:
   exec 도구로 아래 명령 실행:
   ```bash
   cat > ~/.openclaw/workspace-orchestrator/MEMORY.md << 'EOF'
   {drive에서 받은 내용}
   EOF
   ```

4. 사용자에게 완료 보고:
   "복원 완료. /new 명령어를 입력해 새 세션을 시작하면
    복원된 기억이 반영됩니다."
