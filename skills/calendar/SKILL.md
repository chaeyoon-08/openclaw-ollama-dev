---
name: calendar
description: Google 캘린더 일정 조회·생성·수정·삭제 (Google OAuth 필요)
metadata: {"openclaw": {"requires": {"env": ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REFRESH_TOKEN"]}, "emoji": "📅"}}
---

# Google Calendar 스킬

Google Calendar API를 통해 일정을 조회·생성·수정·삭제하는 방법을 안내합니다.

## 인증

- 방식: Google OAuth2 (Refresh Token → Access Token 교환)
- 필요 환경변수: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`
- API 엔드포인트: `https://www.googleapis.com/calendar/v3`
- 필요 스코프: `https://www.googleapis.com/auth/calendar`

### Step 1: Access Token 발급 (모든 API 호출 전 필수)

Calendar API를 호출하기 전에 반드시 Refresh Token으로 Access Token을 발급받아야 한다.
환경변수 `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`을 사용한다.

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id={GOOGLE_CLIENT_ID}
&client_secret={GOOGLE_CLIENT_SECRET}
&refresh_token={GOOGLE_REFRESH_TOKEN}
```

응답 예시:
```json
{
  "access_token": "ya29.a0AfH6SM...",
  "expires_in": 3599,
  "token_type": "Bearer"
}
```

### Step 2: API 호출 시 헤더 사용

발급받은 `access_token`을 모든 API 요청의 Authorization 헤더에 포함한다:

```
Authorization: Bearer {access_token}
```

### 에러 처리

- `401 Unauthorized`: Access Token 만료 → Step 1부터 재시도
- `403 Forbidden`: 스코프 부족 → 사용자에게 Refresh Token 재발급 필요 안내 (`https://www.googleapis.com/auth/calendar` 스코프 포함 필요)

## 사용 가능한 작업

### 일정 조회
```
GET /calendars/primary/events?timeMin=...&timeMax=...&orderBy=startTime
GET /calendars/primary/events/{eventId}
```
날짜 형식: RFC3339 — `2024-03-15T09:00:00+09:00` (KST = UTC+9)

### 일정 생성
```
POST /calendars/primary/events
{
  "summary": "제목",
  "start": { "dateTime": "...", "timeZone": "Asia/Seoul" },
  "end":   { "dateTime": "...", "timeZone": "Asia/Seoul" },
  "location": "장소",
  "attendees": [{ "email": "..." }]
}
```

### 일정 수정
```
PATCH /calendars/primary/events/{eventId}   부분 수정
PUT   /calendars/primary/events/{eventId}   전체 교체
```

### 일정 삭제
```
DELETE /calendars/primary/events/{eventId}
```
삭제 전 반드시 사용자 확인.

## 주의사항

- 반복 일정 수정 시 `?sendUpdates=all` 파라미터로 참석자 알림 여부 제어
- 시간대는 항상 `Asia/Seoul` 명시