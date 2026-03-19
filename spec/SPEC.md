# SPEC — openclaw-ollama-dev

## 참고 공식 문서

- openclaw: https://docs.openclaw.ai
- gogcli: https://github.com/steipete/gogcli

---

## 기술 스택

| 컴포넌트 | 역할 |
|---|---|
| OpenClaw | 멀티 에이전트 오케스트레이션 프레임워크 (npm 글로벌 패키지) |
| Ollama | 로컬 LLM 서버 (http://127.0.0.1:11434) |
| gogcli | Google API CLI 클라이언트 (GOG_ACCESS_TOKEN 방식) |
| Node.js | proxy.js 실행 환경 (내장 모듈만 사용) |
| Telegram Bot API | 사용자 인터페이스 채널 |

---

## 포트 구조

```
gcube 외부 HTTPS
    ↓ (443 → 8080 포워딩)
proxy.js (0.0.0.0:8080)
    ↓ HTTP 프록시 + WebSocket 터널
openclaw gateway (127.0.0.1:18789)
    ↓
에이전트 처리
```

- proxy.js는 node 내장 `http` + `net` 모듈만 사용 (npm install 불필요)
- HTTP 요청과 WebSocket Upgrade 요청 모두 처리
- openclaw gateway는 loopback(127.0.0.1)에만 바인딩

---

## openclaw.json gateway 설정

```json
"gateway": {
  "port": 18789,
  "mode": "local",
  "bind": "loopback",
  "trustedProxies": ["127.0.0.1"],
  "controlUi": {
    "dangerouslyAllowHostHeaderOriginFallback": true
  }
}
```

`dangerouslyAllowHostHeaderOriginFallback`: gcube URL이 배포마다 바뀌어 allowedOrigins 고정 불가.
개인 사용 환경이므로 허용. (→ spec/HANDOVER.md 참조)

---

## 멀티 에이전트 구조

```
orchestrator (qwen3:32b)
  ├─ mail      (qwen3:8b) → Gmail
  ├─ calendar  (qwen3:8b) → Google Calendar
  └─ drive     (qwen3:8b) → Google Drive/Docs/Sheets/Slides
```

- orchestrator가 Telegram 메시지 수신 → 분석 → 서브에이전트 위임
- 서브에이전트는 `sessions_spawn` 도구로 호출됨
- 서브에이전트끼리는 직접 통신하지 않음

---

## Google 인증 방식

gogcli v0.12.0+ 공식 지원 방식: `GOG_ACCESS_TOKEN` 환경변수.

```bash
# Access Token 발급
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=refresh_token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
export GOG_ACCESS_TOKEN=$ACCESS_TOKEN
```

- run.sh 기동 시 1회 발급, 이후 55분마다 백그라운드 루프에서 자동 갱신
- 갱신 실패 시 최대 3회 재시도

---

## 워크스페이스 구조

### orchestrator

```
~/.openclaw/workspace-orchestrator/
  ├── AGENTS.md      ← 역할, 위임 로직, 보안 규칙
  ├── SOUL.md        ← 페르소나 (클로)
  ├── TOOLS.md       ← 사용 가능한 도구 목록
  ├── IDENTITY.md    ← 자기소개 텍스트
  ├── USER.md        ← 사용자 정보 (setup-agent.sh가 주입)
  ├── HEARTBEAT.md   ← 상태 점검 루틴
  └── skills/
      └── gog/
          └── SKILL.md  ← gogcli 사용법
```

### mail / calendar / drive (서브에이전트)

```
~/.openclaw/workspace-{agent}/
  ├── AGENTS.md      ← 역할, API 지침, 보안 규칙
  ├── TOOLS.md       ← 사용 가능한 도구 목록
  └── skills/
      └── gog/
          └── SKILL.md  ← gogcli 사용법
```

서브에이전트는 AGENTS.md + TOOLS.md + skills/gog/SKILL.md 만 주입됨.

---

## 로그 스타일

ANSI 색상만 사용. 이모지 없음.

```bash
BOLD='\033[1m'
BOLD_BLUE='\033[1;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD_RED='\033[1;31m'
NC='\033[0m'

log_start()  { echo -e "${BOLD_BLUE}[ START ]${NC} $1"; }
log_doing()  { echo -e "${CYAN}[ DOING ]${NC} $1"; }
log_ok()     { echo -e "${GREEN}[  OK   ]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[ WARN  ]${NC} $1"; }
log_error()  { echo -e "${RED}[ ERROR ]${NC} $1"; }
log_stop()   { echo -e "${BOLD_RED}[ STOP  ]${NC} $1"; exit 1; }
log_done()   { echo -e "${BOLD_GREEN}[ DONE  ]${NC} $1"; }
log_next()   { echo -e "${BOLD_GREEN}[ NEXT  ]${NC} $1"; }
```

---

## 환경변수

| 변수 | 설명 |
|---|---|
| `TELEGRAM_BOT_TOKEN` | BotFather에서 발급한 봇 토큰 |
| `GOOGLE_CLIENT_ID` | Google Cloud Console OAuth 2.0 클라이언트 ID |
| `GOOGLE_CLIENT_SECRET` | Google Cloud Console OAuth 2.0 클라이언트 시크릿 |
| `GOOGLE_REFRESH_TOKEN` | Google OAuth Refresh Token |
| `GOOGLE_ACCOUNT` | Google 계정 이메일 (gogcli 연동용) |
| `OLLAMA_MODEL` | 오케스트레이터용 모델 (예: `qwen3:32b-q4_K_M`) |
| `OLLAMA_SUBAGENT_MODEL` | 서브에이전트용 모델 (예: `qwen3:8b`) |
| `OLLAMA_FALLBACK_MODEL` | 대체 모델 (예: `glm-4.7-flash`) |
