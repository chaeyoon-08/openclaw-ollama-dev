---
description: Google OAuth 인증 문제 진단 및 SKILL.md 수정
---

## 목적

Gmail, Google Calendar, Google Drive API 연동이 실패하는 원인을 진단하고,
SKILL.md 파일에 OAuth2 Access Token 교환 절차를 추가해 수정한다.

## 사전 조건

- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` 환경변수 설정 완료
- Refresh Token 발급 시 필요한 스코프를 모두 포함해야 함:
  - `https://www.googleapis.com/auth/gmail.readonly`
  - `https://www.googleapis.com/auth/gmail.compose`
  - `https://www.googleapis.com/auth/gmail.send`
  - `https://www.googleapis.com/auth/calendar`
  - `https://www.googleapis.com/auth/drive`
  - `https://www.googleapis.com/auth/documents`

## 실행 절차

### 1단계: Refresh Token 유효성 검증

```bash
source ~/.openclaw/.env

curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token"
```

응답에 `"access_token"` 필드가 있으면 정상. 에러 응답 시:

| 에러 코드 | 원인 | 조치 |
|---|---|---|
| `invalid_client` | CLIENT_ID/SECRET 오류 | Google Cloud Console에서 재확인 |
| `invalid_grant` | Refresh Token 만료 또는 폐기 | OAuth 재인증으로 새 Refresh Token 발급 |
| `unauthorized_client` | 앱이 승인되지 않음 | Google Cloud Console에서 OAuth 동의 화면 확인 |

### 2단계: Access Token으로 Gmail API 직접 테스트

```bash
source ~/.openclaw/.env

# Access Token 발급
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "Access Token: ${ACCESS_TOKEN:0:20}..."

# Gmail API 호출
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/profile" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

`emailAddress` 필드가 반환되면 Gmail 인증 정상.

### 3단계: 스코프 확인

```bash
# Access Token의 스코프 목록 확인
curl -s "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${ACCESS_TOKEN}" \
  | grep -o '"scope":"[^"]*"'
```

필요한 스코프 6개가 모두 포함되어 있는지 확인.
누락된 스코프가 있으면 Refresh Token을 해당 스코프를 포함해서 재발급해야 한다.

### 4단계: SKILL.md에 OAuth2 토큰 교환 절차 추가

`skills/gmail/SKILL.md`, `skills/calendar/SKILL.md`, `skills/drive/SKILL.md` 각각의
`## 인증` 섹션 아래에 다음 내용을 추가한다:

```markdown
### Access Token 발급 (API 호출 전 필수)

모든 API 호출 전에 Refresh Token으로 Access Token을 교환해야 한다.

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

client_id=<GOOGLE_CLIENT_ID>
&client_secret=<GOOGLE_CLIENT_SECRET>
&refresh_token=<GOOGLE_REFRESH_TOKEN>
&grant_type=refresh_token
```

응답의 `access_token` 값을 추출해서 이후 모든 API 요청 헤더에 사용:

```
Authorization: Bearer <access_token>
```

Access Token은 약 3600초(1시간) 유효하다.
```

### 5단계: 수정 반영

```bash
# 에이전트 워크스페이스에 수정된 스킬 재배포
./setup-agent.sh

# 또는 수동으로 복사
cp skills/gmail/SKILL.md ~/.openclaw/workspace-mail/skills/gmail/SKILL.md
cp skills/calendar/SKILL.md ~/.openclaw/workspace-calendar/skills/calendar/SKILL.md
cp skills/drive/SKILL.md ~/.openclaw/workspace-drive/skills/drive/SKILL.md

# 게이트웨이 재시작
openclaw gateway restart
```

### 6단계: E2E 검증

Telegram 봇에 다음 메시지 전송:
- "내 Gmail 주소가 뭐야?" → Gmail API 인증 확인
- "오늘 일정 있어?" → Calendar API 인증 확인
- "내 Drive에 파일 몇 개 있어?" → Drive API 인증 확인

## 예상 결과 및 확인 방법

- 1단계: `{"access_token": "ya29.xxxx", "expires_in": 3599, ...}` 응답
- 2단계: `{"emailAddress": "cy.lim.da@gmail.com", ...}` 응답
- 3단계: 스코프 6개 모두 포함
- 6단계: Telegram 봇이 실제 Gmail/Calendar/Drive 데이터로 응답

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| 1단계 `invalid_grant` | Refresh Token 만료 | Google OAuth 재인증 |
| 2단계 `403 Forbidden` | 스코프 누락 | Refresh Token 재발급 (스코프 포함) |
| 2단계 `401 Unauthorized` | Access Token 없이 요청 | 토큰 교환 절차 확인 |
| API 응답 느림 | 모델이 토큰 교환을 반복 | 세션 내 토큰 캐싱 고려 |
