# validate.md — 전체 서비스 연동 검증

## 준비

```bash
source ~/.openclaw/.env

# Access Token 발급 (이후 테스트에서 반복 사용)
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "Access Token: ${ACCESS_TOKEN:0:20}..."
```

---

## 1. Google OAuth 토큰 교환 테스트

```bash
curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token"
```

**기대 응답**: `{"access_token": "ya29.xxxx", "expires_in": 3599, "token_type": "Bearer"}`

**실패 시**: `.claude/commands/fix-google-auth.md` 참고

---

## 2. Gmail API 테스트

### 2-1. 프로필 조회 (인증 기본 확인)

```bash
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/profile" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

**기대 응답**: `{"emailAddress": "cy.lim.da@gmail.com", ...}`

### 2-2. 읽지 않은 메일 목록 조회

```bash
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread&maxResults=5" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

**기대 응답**: `{"messages": [...], "resultSizeEstimate": N}`

### 2-3. 라벨 목록 조회

```bash
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/labels" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

---

## 3. Google Calendar API 테스트

### 3-1. 캘린더 목록 조회

```bash
curl -s "https://www.googleapis.com/calendar/v3/users/me/calendarList" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

**기대 응답**: `{"items": [{"id": "primary", ...}]}`

### 3-2. 오늘 일정 조회

```bash
TODAY=$(date -u +"%Y-%m-%dT00:00:00Z")
TOMORROW=$(date -u -d "+1 day" +"%Y-%m-%dT00:00:00Z" 2>/dev/null \
  || date -u -v+1d +"%Y-%m-%dT00:00:00Z")  # macOS 호환

curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${TODAY}&timeMax=${TOMORROW}&orderBy=startTime&singleEvents=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

---

## 4. Google Drive API 테스트

### 4-1. Drive 사용량 조회

```bash
curl -s "https://www.googleapis.com/drive/v3/about?fields=storageQuota,user" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

**기대 응답**: `{"storageQuota": {...}, "user": {"emailAddress": "..."}}`

### 4-2. 최근 파일 목록 조회

```bash
curl -s "https://www.googleapis.com/drive/v3/files?pageSize=5&orderBy=modifiedTime+desc&fields=files(id,name,mimeType,modifiedTime)" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

### 4-3. Google Docs API 접근 확인

```bash
# 임의의 문서 ID로 테스트 (404가 나와도 인증은 성공)
curl -s -o /dev/null -w "%{http_code}" \
  "https://docs.googleapis.com/v1/documents/nonexistent_id" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
# 404 = 문서 없음 (인증 OK), 401/403 = 인증 문제
```

---

## 5. Telegram 수신 테스트

```bash
# 봇이 수신 중인지 확인 (최근 업데이트 조회)
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?limit=5" \
  | python3 -m json.tool 2>/dev/null || cat
```

**기대 응답**: `{"ok": true, "result": [...]}`
`"ok": false` 또는 `401` 응답이면 `TELEGRAM_BOT_TOKEN` 오류.

---

## 6. Ollama 로컬 모델 테스트

```bash
# 서비스 상태 확인
curl -s http://127.0.0.1:11434/api/tags | grep -o '"name":"[^"]*"'

# 간단한 추론 테스트
curl -s -X POST http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${OLLAMA_SUBAGENT_MODEL}\", \"prompt\": \"1+1=\", \"stream\": false}" \
  | grep -o '"response":"[^"]*"'
```

---

## 7. OpenClaw 게이트웨이 상태 테스트

```bash
openclaw status
openclaw agents list
openclaw agents bindings
```

---

## E2E 체크리스트

| # | 항목 | 명령 | 기대 결과 | 상태 |
|---|---|---|---|---|
| 1 | Ollama 실행 | `pgrep -x ollama` | PID 출력 | |
| 2 | 오케스트레이터 모델 존재 | `ollama list` | `$OLLAMA_MODEL` 포함 | |
| 3 | 서브에이전트 모델 존재 | `ollama list` | `$OLLAMA_SUBAGENT_MODEL` 포함 | |
| 4 | OpenClaw 게이트웨이 실행 | `openclaw status` | `Gateway: running` | |
| 5 | 에이전트 4개 등록 | `openclaw agents list` | orchestrator, mail, calendar, drive | |
| 6 | Telegram 바인딩 | `openclaw agents bindings` | `orchestrator ↔ telegram` | |
| 7 | OAuth 토큰 교환 | 섹션 1 curl | `access_token` 포함 응답 | |
| 8 | Gmail API 접근 | 섹션 2-1 curl | 이메일 주소 응답 | |
| 9 | Calendar API 접근 | 섹션 3-1 curl | 캘린더 목록 응답 | |
| 10 | Drive API 접근 | 섹션 4-1 curl | 스토리지 정보 응답 | |
| 11 | Telegram 봇 유효 | 섹션 5 curl | `"ok": true` | |
| 12 | E2E 메시지 테스트 | Telegram DM | orchestrator 응답 수신 | |

모든 항목 통과 시 전체 서비스 정상.
