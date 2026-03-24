# TOOLS.md — calendar
# ref: https://docs.openclaw.ai/concepts/agent-workspace
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수가 설정된 상태에서 gog 명령어를 실행한다.
run.sh가 기동 시 발급하고 55분마다 자동 갱신한다.

## gog calendar 명령어

### 일정 조회
```bash
gog calendar list
gog calendar list --days 7
# 예: 향후 7일간 일정 조회
```

### 일정 등록
```bash
gog calendar create --title "<title>" --start "<datetime>" --end "<datetime>"
# 예: gog calendar create --title "팀 회의" --start "2026-03-25T14:00:00" --end "2026-03-25T15:00:00"
```

### 일정 수정
```bash
gog calendar update <eventId> --title "<title>" --start "<datetime>" --end "<datetime>"
```

### 일정 삭제
```bash
gog calendar delete <eventId>
# 예: gog calendar delete abc123
```
