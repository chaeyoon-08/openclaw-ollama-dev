# CLAUDE.md — openclaw-ollama-dev

Telegram 하나로 Gmail/Calendar/Drive를 AI가 자동 처리하는 개인 업무 비서.
OpenClaw + Ollama 기반 멀티 에이전트 구조. API 비용 없음.

---

## 핵심 규칙

- **공식 문서 확인 필수**: 확인되지 않은 API/CLI 옵션 사용 금지
  - openclaw: https://docs.openclaw.ai
  - gogcli: https://github.com/steipete/gogcli
- **파일 상단에 참고 URL 주석 추가**: 스크립트 작성 시 참고한 공식 문서 URL을 주석으로 명시
- **이모지 금지**: 스크립트 출력에 이모지 사용 금지. ANSI 색상만 사용
- **sh 파일 무단 수정 금지**: 커맨드(/setup, /agent, /run)로 명시적으로 요청된 경우에만 수정

---

## 스펙 문서 참조

| 문서 | 내용 |
|---|---|
| `spec/PRD.md` | 프로젝트 목표, 배포 환경, 사용 흐름 |
| `spec/SPEC.md` | 기술 스펙 (포트 구조, 인증 방식, 워크스페이스 구조, 로그 스타일) |
| `spec/HANDOVER.md` | 검증된 사항, 미해결 이슈, 주요 설정값 |

---

## 포트 구조

```
gcube 외부 HTTPS
    ↓
proxy.js (0.0.0.0:8080)   ← node 내장 http+net, WebSocket 터널 포함
    ↓
openclaw gateway (127.0.0.1:18789)
```

---

## Google 인증 방식

GOG_ACCESS_TOKEN 방식 (gogcli v0.12.0 공식 지원):

```bash
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=refresh_token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
export GOG_ACCESS_TOKEN=$ACCESS_TOKEN
```

run.sh 기동 시 발급 → 55분마다 백그라운드 루프에서 자동 갱신.

---

## 로그 함수

모든 스크립트에서 동일하게 사용. ANSI 색상만, 이모지 없음.

```bash
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
