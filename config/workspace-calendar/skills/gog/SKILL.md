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

## 주의사항

**잘못된 플래그 사용 금지:**
- `--start-time`, `--end-time` 은 존재하지 않는 플래그
- 올바른 플래그: `--start`, `--end` (형식: `2026-03-25T14:00:00`)
- 일정 이동 시에도 `update` 명령에 `--start`, `--end` 변경으로 처리

---

## gog calendar

```bash
# 일정 조회 (기본: 오늘)
gog calendar list
gog calendar list --days 7

# 일정 등록 (플래그: --title, --start, --end)
gog calendar create --title "<title>" --start "<datetime>" --end "<datetime>"
# datetime 형식: 2026-03-25T14:00:00
# 주의: --start-time, --end-time은 존재하지 않는 플래그 — 사용 금지

# 일정 수정 / 이동 (플래그: --title, --start, --end)
gog calendar update <eventId> --title "<title>" --start "<datetime>" --end "<datetime>"
# 일정 이동 시 --start, --end 값을 변경해서 update 사용
# 주의: --start-time, --end-time은 존재하지 않는 플래그 — 사용 금지

# 일정 삭제
gog calendar delete <eventId>
```
