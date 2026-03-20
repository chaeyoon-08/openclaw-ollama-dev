---
name: gog
description: Google Workspace CLI (Gmail, Calendar, Drive)
---

# gog — Google Workspace CLI
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수로 인증한다. run.sh가 발급 및 자동 갱신을 담당한다.

```bash
export GOG_ACCESS_TOKEN=<access_token>
```

---

## gog gmail

```bash
# 메일 검색
gog gmail search "<query>"
# 예: gog gmail search "from:kim@example.com is:unread"

# 메일 조회
gog gmail get <messageId>

# 메일 전송
gog gmail send --to <email> --subject "<subject>" --body "<body>"

# 초안 작성
gog gmail draft --to <email> --subject "<subject>" --body "<body>"

# 메일 답장
gog gmail reply <messageId> --body "<body>"
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
```

---

## gog drive

```bash
# 파일 목록
gog drive ls

# 파일 검색 (이름 필터링)
gog drive ls --name "<name>"
# 또는: gog drive ls | grep "<keyword>"

# 파일 업로드
gog drive upload <file>

# 파일 다운로드
gog drive download <fileId>
```
