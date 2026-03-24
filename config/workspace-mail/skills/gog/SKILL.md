---
name: gog
description: Google Workspace CLI (Gmail)
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

# 메일 라벨 지정
gog gmail label <messageId> <labelName>
# 예: gog gmail label abc123 IMPORTANT

# 메일 보관처리
gog gmail archive <messageId>

# 메일 휴지통 이동
gog gmail trash <messageId>
```
