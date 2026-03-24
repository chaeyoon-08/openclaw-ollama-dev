# TOOLS.md — mail
# ref: https://docs.openclaw.ai/concepts/agent-workspace
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수가 설정된 상태에서 gog 명령어를 실행한다.
run.sh가 기동 시 발급하고 55분마다 자동 갱신한다.

## gog gmail 명령어

### 메일 검색
```bash
gog gmail search "<query>"
# 예: gog gmail search "from:kim@example.com"
# 예: gog gmail search "subject:회의 is:unread"
```

### 메일 조회
```bash
gog gmail get <messageId>
```

### 메일 전송
```bash
gog gmail send --to <email> --subject "<subject>" --body "<body>"
# 예: gog gmail send --to kim@example.com --subject "안녕하세요" --body "내용"
```

### 초안 작성
```bash
gog gmail draft --to <email> --subject "<subject>" --body "<body>"
```

### 메일 답장
```bash
gog gmail reply <messageId> --body "<body>"
```

### 메일 라벨/보관
```bash
gog gmail label <messageId> <labelName>
# 예: gog gmail label abc123 IMPORTANT

gog gmail archive <messageId>
# 메일을 받은편지함에서 보관처리

gog gmail trash <messageId>
# 메일을 휴지통으로 이동
```
