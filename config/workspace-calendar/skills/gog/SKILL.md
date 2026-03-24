---
name: gog
description: Google Workspace CLI (Calendar)
---

# gog — Google Workspace CLI
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수로 인증한다. run.sh가 발급 및 자동 갱신을 담당한다.

```bash
export GOG_ACCESS_TOKEN=<access_token>
```

---

## gog calendar

```bash
# 일정 조회 (기본: 오늘)
gog calendar list
gog calendar list --days 7

# 일정 등록
gog calendar create --title "<title>" --start "<datetime>" --end "<datetime>"
# datetime 형식: 2026-03-25T14:00:00

# 일정 수정
gog calendar update <eventId> --title "<title>" --start "<datetime>" --end "<datetime>"

# 일정 삭제
gog calendar delete <eventId>
```
