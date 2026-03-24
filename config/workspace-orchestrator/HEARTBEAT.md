# HEARTBEAT.md — orchestrator
# ref: https://docs.openclaw.ai/concepts/agent-workspace
# 30분마다 실행되는 주기적 작업 지침

## 실행 순서

1. `mail` 서브에이전트에 미읽은 중요 메일 확인 요청
   - 중요 메일(발신자가 알려진 사람 또는 제목에 긴급/중요/FWD 포함)이 있으면 제목·발신자·한 줄 요약을 Telegram으로 전송
   - 없으면 넘어감

2. `calendar` 서브에이전트에 오늘 남은 일정 확인 요청
   - 남은 일정이 있으면 시간·제목 목록을 Telegram으로 전송
   - 없으면 넘어감

3. 위 두 항목 모두 해당 없으면 `HEARTBEAT_OK` 응답

## MEMORY.md 백업 (30분마다, 위 작업과 동일 주기)

`drive` 서브에이전트에 아래 작업 요청:
- `~/.openclaw/workspace-orchestrator/MEMORY.md` 파일이 존재하는지 확인
- 존재하면: `DRIVE_MEMORY_FOLDER` 환경변수(기본값: `openclaw-memory`) 폴더에
  `MEMORY.md` 파일명으로 업로드 (덮어쓰기)
- 폴더가 없으면 먼저 생성
- 성공/실패 여부를 HEARTBEAT 로그에 기록
- 파일이 없으면 건너뜀

## 주의

- 중요하지 않은 마케팅 메일, 뉴스레터는 요약하지 않는다
- Telegram 메시지는 간결하게 유지한다
