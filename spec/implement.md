# implement.md — Google 연동 문제 해결 구현 계획서

---

## 1. 문제 진단

### 현재 SKILL.md 인증 섹션의 문제

현재 3개 SKILL.md(`skills/gmail/SKILL.md`, `skills/calendar/SKILL.md`, `skills/drive/SKILL.md`)의 인증 섹션은 다음과 같이 기술되어 있다:

```
## 인증
- 방식: Google OAuth2
- 필요 환경변수: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN
- API 엔드포인트: https://gmail.googleapis.com/...
```

**이것만으로는 에이전트가 Google API를 호출할 수 없다.**

Google API는 `Authorization: Bearer <access_token>` 헤더를 요구한다.
그런데 환경변수로 제공되는 것은 **Refresh Token**이지 Access Token이 아니다.
Refresh Token을 Access Token으로 교환하는 **구체적인 HTTP 요청 절차**가 SKILL.md에 없기 때문에,
에이전트(LLM)는 다음 중 하나의 오류를 범한다:

1. Refresh Token을 그대로 `Authorization: Bearer` 헤더에 넣어 `401 Unauthorized` 발생
2. 인증 단계를 아예 생략하고 API를 호출해 `401 Unauthorized` 발생
3. 토큰 교환 방법을 모르기 때문에 "인증 실패" 메시지를 반환하고 작업을 포기

### 에이전트 입장에서 빠져있는 정보

| 항목 | 현재 상태 | 필요한 상태 |
|---|---|---|
| 토큰 교환 엔드포인트 | 없음 | `POST https://oauth2.googleapis.com/token` |
| 요청 파라미터 | 없음 | `grant_type`, `client_id`, `client_secret`, `refresh_token` |
| 응답에서 추출할 필드 | 없음 | `access_token` |
| 헤더 사용법 | 없음 | `Authorization: Bearer {access_token}` |
| 에러 처리 방법 | 없음 | 401 → 재발급, 403 → 스코프 문제 안내 |
| 필요 스코프 | 없음 | 서비스별 스코프 목록 |

---

## 2. 해결 방법

### 2-1. skills/gmail/SKILL.md 수정

기존 `## 인증` 섹션(11~15행)을 아래 내용으로 교체한다:

```markdown
## 인증

- 방식: Google OAuth2 (Refresh Token → Access Token 교환)
- 필요 환경변수: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`
- API 엔드포인트: `https://gmail.googleapis.com/gmail/v1/users/me`
- 필요 스코프: `gmail.readonly`, `gmail.compose`, `gmail.send`

### Access Token 발급 (모든 API 호출 전 필수)

Gmail API를 호출하기 전에 반드시 Refresh Token으로 Access Token을 발급받아야 한다.

요청:
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id={GOOGLE_CLIENT_ID}
&client_secret={GOOGLE_CLIENT_SECRET}
&refresh_token={GOOGLE_REFRESH_TOKEN}

응답 예시:
{
  "access_token": "ya29.a0AfH6SM...",
  "expires_in": 3599,
  "token_type": "Bearer"
}

### API 호출 시 헤더

발급받은 access_token을 모든 API 요청에 포함:
Authorization: Bearer {access_token}

### 에러 처리

- 401 Unauthorized: Access Token 만료 → 위 절차로 재발급 후 재시도
- 403 Forbidden: 스코프 부족 → 사용자에게 Refresh Token 재발급 필요 안내
  (gmail.readonly, gmail.compose, gmail.send 스코프 포함 필요)
```

### 2-2. skills/calendar/SKILL.md 수정

기존 `## 인증` 섹션(11~15행)을 교체. 구조는 동일하되:
- 필요 스코프: `https://www.googleapis.com/auth/calendar`
- 403 에러 시 안내할 스코프: `calendar`

### 2-3. skills/drive/SKILL.md 수정

기존 `## 인증` 섹션(11~16행)을 교체. 구조는 동일하되:
- 필요 스코프: `https://www.googleapis.com/auth/drive`, `https://www.googleapis.com/auth/documents`
- 403 에러 시 안내할 스코프: `drive`, `documents`

### 2-4. Refresh Token 스코프 확인 방법

현재 발급된 Refresh Token에 필요한 스코프가 포함되어 있는지 확인:

```bash
source ~/.openclaw/.env

# Step 1: Access Token 발급
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Step 2: 스코프 확인
curl -s "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${ACCESS_TOKEN}"
```

응답의 `scope` 필드에 아래 6개가 모두 포함되어야 한다:

```
https://www.googleapis.com/auth/gmail.readonly
https://www.googleapis.com/auth/gmail.compose
https://www.googleapis.com/auth/gmail.send
https://www.googleapis.com/auth/calendar
https://www.googleapis.com/auth/drive
https://www.googleapis.com/auth/documents
```

### 2-5. Refresh Token 재발급이 필요한 경우

스코프가 누락되어 있으면 Refresh Token을 재발급해야 한다.

1. Google Cloud Console에서 OAuth 동의 화면 → 스코프 추가
2. OAuth 2.0 Playground 또는 직접 인증 URL로 재인증:

```
https://accounts.google.com/o/oauth2/v2/auth?
  client_id={GOOGLE_CLIENT_ID}
  &redirect_uri=urn:ietf:wg:oauth:2.0:oob
  &response_type=code
  &scope=https://www.googleapis.com/auth/gmail.readonly+https://www.googleapis.com/auth/gmail.compose+https://www.googleapis.com/auth/gmail.send+https://www.googleapis.com/auth/calendar+https://www.googleapis.com/auth/drive+https://www.googleapis.com/auth/documents
  &access_type=offline
  &prompt=consent
```

3. 받은 authorization code로 Refresh Token 교환:

```bash
curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "code={AUTHORIZATION_CODE}" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "redirect_uri=urn:ietf:wg:oauth:2.0:oob" \
  -d "grant_type=authorization_code"
```

4. 응답의 `refresh_token`을 `.env`의 `GOOGLE_REFRESH_TOKEN`에 설정
5. `./setup.sh` 재실행

---

## 3. 수정 후 검증 절차

### 3-1. 토큰 교환 직접 테스트

```bash
source ~/.openclaw/.env

curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token"
```

기대 결과: `{"access_token": "ya29.xxxx", "expires_in": 3599, ...}`

### 3-2. 각 Google API 호출 테스트

```bash
# Access Token 저장
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${GOOGLE_REFRESH_TOKEN}&grant_type=refresh_token" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Gmail 테스트
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/profile" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
# 기대: {"emailAddress": "cy.lim.da@gmail.com", ...}

# Calendar 테스트
curl -s "https://www.googleapis.com/calendar/v3/users/me/calendarList" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
# 기대: {"items": [...]}

# Drive 테스트
curl -s "https://www.googleapis.com/drive/v3/about?fields=user" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
# 기대: {"user": {"emailAddress": "cy.lim.da@gmail.com", ...}}
```

### 3-3. SKILL.md 배포 및 E2E 검증

```bash
# 수정된 스킬을 워크스페이스에 배포
./setup-agent.sh
# 또는 수동 복사 + 게이트웨이 재시작
cp skills/gmail/SKILL.md ~/.openclaw/workspace-mail/skills/gmail/SKILL.md
cp skills/calendar/SKILL.md ~/.openclaw/workspace-calendar/skills/calendar/SKILL.md
cp skills/drive/SKILL.md ~/.openclaw/workspace-drive/skills/drive/SKILL.md
openclaw gateway restart
```

Telegram 봇에 테스트 메시지 전송:

| 테스트 | 메시지 | 기대 결과 |
|---|---|---|
| Gmail | "내 이메일 주소가 뭐야?" | cy.lim.da@gmail.com 응답 |
| Gmail | "안 읽은 메일 3개만 보여줘" | 메일 목록 응답 |
| Calendar | "오늘 일정 있어?" | 일정 목록 또는 "없습니다" 응답 |
| Drive | "최근 수정한 파일 3개 알려줘" | 파일 목록 응답 |
| 복합 | "김팀장 메일 확인하고 미팅 잡아줘" | mail → calendar 순차 처리 |

---

## 4. 추후 작업: Slack 채널 추가

### 4-1. openclaw.json channels 섹션 수정

`setup.sh`에서 `openclaw.json`을 생성하는 부분(약 276~282행)의 `"channels"` 섹션에 Slack을 추가한다:

```json
"channels": {
  "telegram": {
    "botToken": "${TELEGRAM_BOT_TOKEN}",
    "dmPolicy": "open",
    "allowFrom": ["*"]
  },
  "slack": {
    "botToken": "${SLACK_BOT_TOKEN}",
    "dmPolicy": "open",
    "allowFrom": ["*"]
  }
}
```

필요 환경변수: `SLACK_BOT_TOKEN` (Slack API에서 Bot User OAuth Token 발급)

`.env.example`에도 추가:
```
SLACK_BOT_TOKEN=
```

### 4-2. setup.sh 수정

- 환경변수 출력에 `status_var SLACK_BOT_TOKEN partial` 추가
- `~/.openclaw/.env` 생성 블록에 `printf 'SLACK_BOT_TOKEN=%s\n' "${SLACK_BOT_TOKEN}"` 추가

### 4-3. setup-agent.sh 수정

Telegram 바인딩 섹션 아래에 Slack 바인딩 추가:

```bash
info "orchestrator <-> Slack 연결 중..."
openclaw agents bind --agent orchestrator --bind slack \
  2>/dev/null \
  || warn "Slack 바인딩 등록 실패"
```

### 4-4. 주의사항

- OpenClaw의 Slack 어댑터 지원 여부를 먼저 확인해야 한다 (`openclaw --version`)
- Slack App 스코프: `chat:write`, `im:read`, `im:history`, `im:write`
- 두 채널이 동시에 동작하므로 orchestrator가 동일 메시지를 양쪽에 응답하지 않도록 바인딩 확인
