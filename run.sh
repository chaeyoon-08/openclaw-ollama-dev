#!/bin/bash
# =============================================================
# openclaw-ollama-dev / run.sh
# 서비스 기동 스크립트 (Ollama + openclaw gateway)
#
# 사전 조건: setup.sh → setup-agent.sh 완료
#
# 참고 문서:
#   OpenClaw  : https://docs.openclaw.ai
#   Ollama    : https://github.com/ollama/ollama/releases
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

OPENCLAW_DIR="$HOME/.openclaw"
OLLAMA_LOG="$OPENCLAW_DIR/ollama.log"
GATEWAY_LOG="$OPENCLAW_DIR/gateway.log"

log_start "OpenClaw 서비스 기동"

# ── 0. PATH 설정 ──────────────────────────────────────────
export PATH=$PATH:/workspace/node/bin:/workspace/ollama/bin
export OLLAMA_MODELS=/workspace/ollama/models

# ── 1. 환경변수 검증 ──────────────────────────────────────
: "${TELEGRAM_BOT_TOKEN:?오류: TELEGRAM_BOT_TOKEN 환경변수를 설정해주세요 (gcube 워크로드 배포 시 컨테이너 환경변수로 입력)}"
: "${OLLAMA_MODEL:=qwen3:14b}"

log_ok "환경변수 확인 완료 / model: $OLLAMA_MODEL"

# ── 2. 기존 프로세스 정리 ─────────────────────────────────
log_doing "기존 프로세스 정리"

pkill -f 'openclaw' 2>/dev/null || true
pkill -f 'ollama serve' 2>/dev/null || true
sleep 1
pgrep -f 'openclaw|ollama serve' > /dev/null 2>&1 && sleep 2 || true

log_ok "프로세스 정리 완료"

# ── 3. 바이너리 확인 ──────────────────────────────────────
log_doing "바이너리 확인"

# node / ollama 경로 확인
if ! command -v node &>/dev/null; then
  log_stop "node 명령어를 찾을 수 없습니다. setup.sh 를 먼저 실행해 주세요."
fi
if ! command -v ollama &>/dev/null; then
  log_stop "ollama 명령어를 찾을 수 없습니다. setup.sh 를 먼저 실행해 주세요."
fi
if ! command -v openclaw &>/dev/null; then
  log_stop "openclaw 명령어를 찾을 수 없습니다. setup.sh 를 먼저 실행해 주세요."
fi

log_ok "node: $(node --version) / ollama: $(ollama --version 2>/dev/null | head -1)"

# ── 4. OLLAMA_MODELS 환경변수 설정 ────────────────────────
log_doing "Ollama 모델 디렉토리 설정"

export OLLAMA_MODELS="/workspace/ollama/models"
mkdir -p "$OLLAMA_MODELS"
log_ok "OLLAMA_MODELS: $OLLAMA_MODELS"

# ── 5. Ollama 기동 ────────────────────────────────────────
log_doing "Ollama 기동"

ollama serve > "$OLLAMA_LOG" 2>&1 &

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

# ── 7. 완료 메시지 ────────────────────────────────────────
echo ""
log_done "모든 서비스 기동 완료"
echo ""
echo -e "${BOLD_GREEN}  Telegram 봇에 메시지를 보내 서비스를 사용하세요.${NC}"
echo ""
echo "  gcube Control UI 접속:"
echo "  1) gcube 대시보드에서 이 컨테이너의 서비스 URL 확인"
echo "  2) URL 접속 후 Gateway Token 입력:"
GATEWAY_TOKEN=$(python3 -c "import json; d=json.load(open('${OPENCLAW_DIR}/openclaw.json')); print(d['gateway']['auth']['token'])" 2>/dev/null || echo "openclaw.json 확인 필요")
echo "     $GATEWAY_TOKEN"
echo ""
echo "  로그 확인:"
echo "  tail -f $GATEWAY_LOG"
echo "  tail -f $OLLAMA_LOG"
echo ""
echo "  서비스 종료:"
echo "  pkill -f openclaw; pkill -f 'ollama serve'"
