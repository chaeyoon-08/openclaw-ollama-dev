---
description: Slack 채널 연동 추가 (Telegram과 병렬 운영)
---

## 목적

기존 Telegram 채널과 함께 Slack 채널을 추가한다.
동일한 orchestrator 에이전트가 두 채널을 모두 수신한다.

## 사전 조건

- `setup.sh`와 `setup-agent.sh` 완료 상태
- Slack App 생성 및 Bot Token 발급 완료
  - Slack API (api.slack.com)에서 앱 생성
  - `chat:write`, `im:read`, `im:history` 스코프 필요
  - Bot User OAuth Token (`xoxb-...`) 확보
- OpenClaw가 Slack 어댑터를 지원하는지 버전 확인: `openclaw --version`

## 실행 절차

### 1단계: Slack Bot Token 환경변수 추가

```bash
# 프로젝트 루트 .env에 추가
echo "SLACK_BOT_TOKEN=xoxb-your-token-here" >> .env

# 런타임 .env에도 추가
echo "SLACK_BOT_TOKEN=xoxb-your-token-here" >> ~/.openclaw/.env
```

### 2단계: setup.sh 수정 — SLACK_BOT_TOKEN 처리 추가

`setup.sh`의 환경변수 확인 섹션에 다음 내용을 추가한다:

```bash
# 기존 status_var 호출 목록 아래에 추가
status_var SLACK_BOT_TOKEN partial
```

`~/.openclaw/.env` 생성 블록에 추가:

```bash
printf 'SLACK_BOT_TOKEN=%s\n' "${SLACK_BOT_TOKEN}"
```

### 3단계: setup.sh 수정 — openclaw.json channels 섹션에 Slack 추가

`setup.sh`의 `cat > "$OPENCLAW_DIR/openclaw.json"` 블록에서
`"channels"` 섹션을 다음과 같이 수정한다:

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

### 4단계: setup-agent.sh 수정 — Slack 바인딩 추가

`setup-agent.sh`의 Telegram 바인딩 섹션 아래에 추가:

```bash
info "orchestrator ↔ Slack 연결 중..."
openclaw agents bind --agent orchestrator --bind slack \
  2>/dev/null \
  || warn "Slack 바인딩 등록 실패 (OpenClaw Slack 어댑터 미지원 가능)"
```

### 5단계: 재설치 및 검증

```bash
# setup.sh 재실행 (모델 재다운로드 없이 openclaw.json만 갱신하려면 --skip-model 옵션 확인)
./setup.sh

# 에이전트 재등록
./setup-agent.sh

# 바인딩 확인
openclaw agents bindings
```

`orchestrator`가 `telegram`과 `slack` 두 채널에 모두 바인딩되어 있어야 함.

## 예상 결과 및 확인 방법

```
openclaw agents bindings 출력:
  orchestrator ↔ telegram
  orchestrator ↔ slack
```

Slack DM으로 "안녕"을 보내면 orchestrator가 응답.

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| Slack 바인딩 실패 | OpenClaw Slack 어댑터 미지원 | `openclaw --version` 확인, 최신 버전으로 업데이트 |
| 봇이 Slack 응답 안 함 | 스코프 누락 | Slack App 설정에서 `chat:write` 추가 |
| Telegram 작동 중단 | channels 섹션 JSON 오류 | `openclaw.json` 문법 확인 |

## 주의사항

- Slack 어댑터 지원 여부는 OpenClaw 버전에 따라 다를 수 있다.
  지원하지 않을 경우 GitHub Issues 또는 공식 문서에서 확인.
- `SLACK_BOT_TOKEN`을 `.env`에 추가한 경우 `.gitignore`에 `.env`가 포함되어 있는지 반드시 확인.
