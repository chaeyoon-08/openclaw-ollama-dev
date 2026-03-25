#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup-agent.sh
# 에이전트 워크스페이스 구성 및 Google 연동 확인 스크립트
#
# 사전 조건: setup.sh 완료
#
# 참고 문서:
#   OpenClaw  : https://docs.openclaw.ai
#   gogcli    : https://github.com/steipete/gogcli
#   Google OAuth: https://developers.google.com/identity/protocols/oauth2
# =============================================================

set -eo pipefail

# ── 로그 함수 ──────────────────────────────────────────────
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"

log_start "에이전트 워크스페이스 설정 시작"

# ── 1. ~/.openclaw/.env 로드 ──────────────────────────────
log_doing "~/.openclaw/.env 로드"

if [ ! -f "$OPENCLAW_DIR/.env" ]; then
  log_stop "~/.openclaw/.env 없음. 먼저 setup.sh 를 실행해 주세요."
fi

set -a
# shellcheck source=/dev/null
source "$OPENCLAW_DIR/.env"
set +a

for _VAR in ORCHESTRATOR_MODEL FALLBACK_MODEL; do
  if [ -z "${!_VAR}" ]; then
    log_stop "${_VAR} 미설정. setup.sh 를 먼저 실행해 주세요."
  fi
done

log_ok "orchestrator: $ORCHESTRATOR_MODEL"
log_ok "fallback:     $FALLBACK_MODEL"

# ── 2. 워크스페이스 파일 복사 ─────────────────────────────
log_doing "워크스페이스 파일 복사"

SRC="$SCRIPT_DIR/config/workspace-orchestrator"
DEST="$OPENCLAW_DIR/workspace-orchestrator"

if [ -d "$SRC" ]; then
  mkdir -p "$DEST"
  cp -r "$SRC/." "$DEST/"
  log_ok "  orchestrator: 복사 완료 → $DEST"
else
  log_stop "config/workspace-orchestrator/ 없음"
fi

# ── 3. USER.md {{GOOGLE_ACCOUNT}} 치환 ───────────────────
log_doing "USER.md Google 계정 주입"

USER_MD="$OPENCLAW_DIR/workspace-orchestrator/USER.md"
if [ -f "$USER_MD" ]; then
  sed -i "s/{{GOOGLE_ACCOUNT}}/${GOOGLE_ACCOUNT:-}/g" "$USER_MD"
  if [ -n "$GOOGLE_ACCOUNT" ]; then
    log_ok "USER.md 치환 완료: $GOOGLE_ACCOUNT"
  else
    log_warn "GOOGLE_ACCOUNT 미설정 — USER.md의 계정 정보가 비어 있습니다."
  fi
else
  log_warn "USER.md 없음: $USER_MD"
fi

# ── 4. Access Token 발급 ──────────────────────────────────
log_doing "Google Access Token 발급"

RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=refresh_token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN")

ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)

if [ -z "$ACCESS_TOKEN" ]; then
  ERROR_MSG=$(echo "$RESPONSE" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('error_description', d.get('error','알 수 없는 오류')))" 2>/dev/null || echo "응답 파싱 실패")
  log_error "Access Token 발급 실패: $ERROR_MSG"
  log_stop "Google OAuth 설정(.env의 GOOGLE_CLIENT_ID/SECRET/REFRESH_TOKEN)을 확인하세요."
fi

export GOG_ACCESS_TOKEN=$ACCESS_TOKEN
log_ok "Access Token 발급 완료"

# ── 5. gog 연동 확인 ──────────────────────────────────────
log_doing "gog Gmail 연동 확인"

if ! command -v gog &>/dev/null; then
  log_stop "gog 명령어를 찾을 수 없습니다. setup.sh 를 먼저 실행해 주세요."
fi

if gog gmail search 'is:unread' --max 1 &>/dev/null; then
  log_ok "gog Gmail 연동 정상"
else
  log_stop "gog Gmail 연동 실패. .env의 GOOGLE_REFRESH_TOKEN이 유효한지, OAuth Playground에서 gmail 스코프를 포함해서 발급했는지 확인하세요."
fi

# ── 6. openclaw.json 설정 확인 ────────────────────────────
# gateway 기동은 run.sh에서만 담당 — 이 스크립트에서 기동하지 않음
log_doing "openclaw.json 설정 확인"

OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"
if [ ! -f "$OPENCLAW_JSON" ]; then
  log_warn "openclaw.json 없음. setup.sh 를 먼저 실행해 주세요."
else
  python3 << PYEOF
import json, sys

with open("$OPENCLAW_JSON") as f:
    c = json.load(f)

ok = True

# agents.list에 orchestrator 확인
agent_ids = [a["id"] for a in c.get("agents", {}).get("list", [])]
if "orchestrator" not in agent_ids:
    print(f"\033[1;33m[ WARN  ]\033[0m agents.list에 orchestrator 없음 → setup.sh 재실행 필요")
    ok = False
else:
    print(f"\033[0;32m[  OK   ]\033[0m agents.list: orchestrator 확인")

# bindings 확인
bindings = c.get("bindings", [])
has_binding = any(
    b.get("agentId") == "orchestrator" and
    b.get("match", {}).get("channel") == "telegram"
    for b in bindings
)
if not has_binding:
    print(f"\033[1;33m[ WARN  ]\033[0m orchestrator → telegram 바인딩 없음 → setup.sh 재실행 필요")
    ok = False
else:
    print(f"\033[0;32m[  OK   ]\033[0m bindings: orchestrator → telegram 확인")

# channels.telegram.botToken 확인
bot_token = c.get("channels", {}).get("telegram", {}).get("botToken", "")
if not bot_token:
    print(f"\033[1;33m[ WARN  ]\033[0m channels.telegram.botToken 없음 → TELEGRAM_BOT_TOKEN 확인")
    ok = False
else:
    masked = bot_token[:6] + "****"
    print(f"\033[0;32m[  OK   ]\033[0m channels.telegram.botToken: {masked}")

if ok:
    print(f"\033[1;32m[ DONE  ]\033[0m openclaw.json 설정 검증 완료")
PYEOF
fi

# ── 7. 등록 결과 출력 ─────────────────────────────────────
log_doing "에이전트 등록 결과 확인"

echo ""
openclaw agents list   2>/dev/null || log_warn "openclaw agents list 실패 — gateway가 실행 중이 아닙니다."
echo ""
openclaw agents bindings 2>/dev/null || log_warn "openclaw agents bindings 실패 — gateway가 실행 중이 아닙니다."

# ── 완료 ──────────────────────────────────────────────────
echo ""
log_done "에이전트 설정 완료"
log_next "다음 단계: bash run.sh"
