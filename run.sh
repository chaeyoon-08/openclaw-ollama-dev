#!/bin/bash
# =============================================================
# openclaw-ollama-dev / run.sh
# 서비스 기동 스크립트 (Ollama + openclaw gateway)
#
# 사전 조건: setup.sh → setup-agent.sh 완료
#
# 참고 문서:
#   OpenClaw     : https://docs.openclaw.ai
#   gogcli       : https://github.com/steipete/gogcli
#   Google OAuth : https://developers.google.com/identity/protocols/oauth2
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
OLLAMA_LOG="$OPENCLAW_DIR/ollama.log"
GATEWAY_LOG="$OPENCLAW_DIR/gateway.log"

log_start "OpenClaw 서비스 기동"

# ── .env 로드 ──────────────────────────────────────────────
if [ ! -f "$OPENCLAW_DIR/.env" ]; then
  log_stop "~/.openclaw/.env 없음. 먼저 setup.sh 를 실행해 주세요."
fi
set -a
# shellcheck source=/dev/null
source "$OPENCLAW_DIR/.env"
set +a

for VAR in GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN ORCHESTRATOR_MODEL FALLBACK_MODEL; do
  [ -z "${!VAR}" ] && log_stop "$VAR 미설정. setup.sh 를 먼저 실행해 주세요."
done

log_ok "환경변수 로드 완료 / orchestrator: $ORCHESTRATOR_MODEL / fallback: $FALLBACK_MODEL"

# ── 1. 기존 프로세스 정리 ─────────────────────────────────
log_doing "기존 프로세스 정리"

# 프로세스명으로 종료
pkill -f 'openclaw' 2>/dev/null || true
pkill -f 'ollama serve' 2>/dev/null || true
# 좀비 프로세스 무시하고 실제 프로세스만 대기
sleep 1
# 살아있는 프로세스가 있으면 추가 대기
pgrep -f 'openclaw|ollama serve' > /dev/null 2>&1 && sleep 2 || true

# 포트 점유 프로세스 종료 (fuser 우선, 없으면 /proc/net/tcp 방식)
kill_port() {
  local port=$1
  if command -v fuser &>/dev/null; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  else
    # /proc/net/tcp: 로컬 주소 컬럼(2번째)에서 포트 hex 검색 후 inode → pid 매핑
    local hex_port
    hex_port=$(printf '%04X' "$port")
    local inodes
    inodes=$(awk -v p=":${hex_port}" '$2 ~ p {print $10}' /proc/net/tcp /proc/net/tcp6 2>/dev/null)
    for inode in $inodes; do
      local pid
      pid=$(find /proc -maxdepth 4 -name 'fd' -type d 2>/dev/null \
            | xargs -I{} find {} -type l 2>/dev/null \
            | xargs ls -la 2>/dev/null \
            | grep "socket:\[${inode}\]" \
            | awk -F'/' '{print $3}' | head -1)
      [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    done
  fi
}

for PORT in 18789 11434; do
  kill_port "$PORT"
done
sleep 1

log_ok "프로세스 정리 완료"

# ── 2. Access Token 발급 ──────────────────────────────────
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
    "import sys,json; d=json.load(sys.stdin); print(d.get('error_description', d.get('error','')))" 2>/dev/null || echo "응답 파싱 실패")
  log_error "Access Token 발급 실패: $ERROR_MSG"
  log_stop "GOOGLE_REFRESH_TOKEN이 유효한지 확인하세요."
fi

export GOG_ACCESS_TOKEN=$ACCESS_TOKEN

# openclaw.json env.GOG_ACCESS_TOKEN 업데이트 (서브에이전트는 셸 환경변수를 상속받지 않으므로)
python3 -c "
import json
with open('/root/.openclaw/openclaw.json', 'r') as f:
    d = json.load(f)
d['env']['GOG_ACCESS_TOKEN'] = '${ACCESS_TOKEN}'
with open('/root/.openclaw/openclaw.json', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || log_warn "openclaw.json GOG_ACCESS_TOKEN 업데이트 실패"

log_ok "Access Token 발급 완료"

# ── 3. 55분마다 자동 갱신 루프 ────────────────────────────
token_refresh_loop() {
  while true; do
    sleep 3300

    RETRY=0
    NEW_TOKEN=""
    while [ "$RETRY" -lt 3 ]; do
      NEW_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
        -d "grant_type=refresh_token" \
        -d "client_id=$GOOGLE_CLIENT_ID" \
        -d "client_secret=$GOOGLE_CLIENT_SECRET" \
        -d "refresh_token=$GOOGLE_REFRESH_TOKEN" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)

      if [ -n "$NEW_TOKEN" ]; then
        export GOG_ACCESS_TOKEN=$NEW_TOKEN
        # .env 파일에도 갱신해 새 프로세스가 최신 토큰을 사용하도록 함
        sed -i "s|^GOG_ACCESS_TOKEN=.*|GOG_ACCESS_TOKEN=${NEW_TOKEN}|" "$OPENCLAW_DIR/.env" 2>/dev/null || true
        # openclaw.json env.GOG_ACCESS_TOKEN 업데이트 (서브에이전트는 셸 환경변수를 상속받지 않으므로)
        python3 -c "
import json
with open('/root/.openclaw/openclaw.json', 'r') as f:
    d = json.load(f)
d['env']['GOG_ACCESS_TOKEN'] = '${NEW_TOKEN}'
with open('/root/.openclaw/openclaw.json', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
        echo -e "${GREEN}[  OK   ]${NC} Access Token 갱신 완료"
        break
      fi

      RETRY=$((RETRY + 1))
      echo -e "${RED}[ ERROR ]${NC} Access Token 갱신 실패 (${RETRY}/3)"
      [ "$RETRY" -lt 3 ] && sleep 10
    done

    if [ -z "$NEW_TOKEN" ]; then
      echo -e "${YELLOW}[ WARN  ]${NC} Access Token 갱신 3회 실패 — 다음 주기까지 기존 토큰 유지"
    fi
  done
}

token_refresh_loop &
log_ok "Access Token 자동 갱신 루프 시작 (55분 주기)"

# ── 4. exec-approvals.json 설정 ───────────────────────────
cat > ~/.openclaw/exec-approvals.json << 'EOF'
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "off",
    "askFallback": "full",
    "autoAllowSkills": true
  }
}
EOF
log_ok "exec-approvals.json 설정 완료"

# ── 5. Ollama 기동 ────────────────────────────────────────
log_doing "Ollama 기동"

ollama serve > "$OLLAMA_LOG" 2>&1 &

# API 응답까지 대기 (최대 30초)
READY=false
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
    READY=true
    break
  fi
  sleep 1
done

if [ "$READY" = false ]; then
  log_error "Ollama 기동 타임아웃 (30초)"
  log_stop "로그 확인: tail -f $OLLAMA_LOG"
fi
log_ok "Ollama 기동 완료 (PID: $(pgrep -x ollama | head -1))"

# ── 6. openclaw gateway 기동 ──────────────────────────────
log_doing "openclaw gateway 기동"

openclaw gateway > "$GATEWAY_LOG" 2>&1 &

# 포트 18789 응답까지 대기 (최대 30초)
READY=false
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:18789/ &>/dev/null; then
    READY=true
    break
  fi
  sleep 1
done

if [ "$READY" = false ]; then
  log_warn "gateway 기동 실패 — doctor --fix 실행 중..."
  openclaw doctor --fix 2>&1 | tee -a "$GATEWAY_LOG" || true
  sleep 5

  # gateway 재시도
  pkill -f 'openclaw gateway' 2>/dev/null || true
  sleep 1
  openclaw gateway >> "$GATEWAY_LOG" 2>&1 &

  READY=false
  for i in $(seq 1 30); do
    if curl -sf http://127.0.0.1:18789/ &>/dev/null; then
      READY=true
      break
    fi
    sleep 1
  done

  if [ "$READY" = false ]; then
    log_error "openclaw gateway 재기동 타임아웃 (30초)"
    log_stop "로그 확인: tail -f $GATEWAY_LOG"
  fi
fi
log_ok "openclaw gateway 기동 완료"

# ── 7. MEMORY.md 자동 백업 ────────────────────────────────
# MEMORY.md 자동 백업 (30분 주기, 에이전트와 독립적으로 동작)
(
  while true; do
    sleep 1800
    MEMORY_FILE="$HOME/.openclaw/workspace-orchestrator/MEMORY.md"
    if [ -f "$MEMORY_FILE" ]; then
      ACCESS_TOKEN=$(python3 -c "
import json, sys
try:
    d = json.load(open('/root/.openclaw/openclaw.json'))
    print(d['env']['GOG_ACCESS_TOKEN'])
except:
    sys.exit(1)
" 2>/dev/null)
      ACCOUNT=$(python3 -c "
import json, sys
try:
    d = json.load(open('/root/.openclaw/openclaw.json'))
    print(d['env']['GOG_ACCOUNT'])
except:
    sys.exit(1)
" 2>/dev/null)
      if [ -n "$ACCESS_TOKEN" ] && [ -n "$ACCOUNT" ]; then
        GOG_ACCESS_TOKEN="$ACCESS_TOKEN" GOG_ACCOUNT="$ACCOUNT" \
          gog drive upload "$MEMORY_FILE" \
          > /dev/null 2>&1 \
          && log_ok "MEMORY.md 백업 완료" \
          || log_warn "MEMORY.md 백업 실패 — 다음 주기에 재시도"
      fi
    fi
  done
) &
log_ok "MEMORY.md 자동 백업 시작 (30분 주기)"

# ── 8. 완료 메시지 ────────────────────────────────────────
echo ""
log_done "모든 서비스 기동 완료"
echo ""
echo -e "${BOLD_GREEN}  Telegram 봇에 메시지를 보내 서비스를 사용하세요.${NC}"
echo ""
echo "  gcube Control UI 접속:"
echo "  1) gcube 대시보드에서 이 컨테이너의 서비스 URL 확인"
echo "  2) URL 접속 후 Gateway Token 입력:"
GATEWAY_TOKEN=$(python3 -c "import json; d=json.load(open('/root/.openclaw/openclaw.json')); print(d['gateway']['auth']['token'])" 2>/dev/null || echo "openclaw.json 확인 필요")
echo "     $GATEWAY_TOKEN"
echo "  3) 처음 접속 시 기기 승인 필요"
echo "     - 대기 중인 기기 확인: openclaw devices list"
echo "     - 승인: openclaw devices approve <requestId>"
echo ""
echo "  로그 확인:"
echo "  tail -f $GATEWAY_LOG"
echo "  tail -f $OLLAMA_LOG"
echo ""
echo "  서비스 종료:"
echo "  pkill -f openclaw; pkill -f 'ollama serve'"
