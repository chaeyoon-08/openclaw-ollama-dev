---
name: gog-gmail
description: Google Gmail CLI
---

# === Gmail Skills ===
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수로 인증한다. run.sh가 발급 및 자동 갱신을 담당한다.

---

## gog gmail

```bash
# 메일 검색 (기본 출력: 제목·발신자·messageId 목록)
gog gmail search "<query>"
# 예: gog gmail search "from:kim@example.com is:unread"
# 예: gog gmail search "is:unread"
#
# 출력 예시:
#   [abc123] 제목: 회의 일정 안내 | from: kim@example.com
#   [def456] 제목: 견적서 요청 드립니다 | from: park@example.com
#
# messageId: 대괄호 안의 값 (예: abc123) → gog gmail get에 사용

# 메일 조회 (messageId로 전체 내용 확인)
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
