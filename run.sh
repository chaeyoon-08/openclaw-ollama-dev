#!/bin/bash
# =============================================================
# openclaw-ollama-dev / run.sh
# 게이트웨이 + Ollama 실행 스크립트 (설치 완료 후 사용)
#
# 사전 조건: setup.sh → setup-agent.sh 완료
# =============================================================

set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}▶ $1${NC}"; }

OPENCLAW_DIR="$HOME/.openclaw"
OLLAMA_LOG="$OPENCLAW_DIR/ollama.log"
GATEWAY_LOG="$OPENCLAW_DIR/gateway.log"

# ── 1. 사전 조건 확인 ─────────────────────────────────────
section "사전 조건 확인"

[ -f "$OPENCLAW_DIR/openclaw.json" ] \
  || error "openclaw.json이 없습니다. 먼저 ./setup.sh 를 실행해 주세요."

[ -f "$OPENCLAW_DIR/.env" ] \
  || error ".env 파일이 없습니다. 먼저 ./setup.sh 를 실행해 주세요."

set -a; source "$OPENCLAW_DIR/.env"; set +a
info ".env 로드 완료"

[ -n "$OLLAMA_MODEL" ]          || error "OLLAMA_MODEL이 설정되지 않았습니다."
[ -n "$OLLAMA_SUBAGENT_MODEL" ] || error "OLLAMA_SUBAGENT_MODEL이 설정되지 않았습니다."
[ -n "$OLLAMA_FALLBACK_MODEL" ] || error "OLLAMA_FALLBACK_MODEL이 설정되지 않았습니다."

info "오케스트레이터: $OLLAMA_MODEL"
info "서브에이전트:   $OLLAMA_SUBAGENT_MODEL"
info "Fallback:      $OLLAMA_FALLBACK_MODEL"

# ── 2. 기존 프로세스 정리 ──────────────────────────────────
section "기존 프로세스 정리"

echo "🔄 기존 프로세스 정리 중..."
pkill -9 -f "openclaw" 2>/dev/null && info "openclaw 프로세스 종료" || info "openclaw 실행 중 아님"
pkill -9 -f "openclaw.mjs" 2>/dev/null && info "openclaw.mjs 프로세스 종료" || true
pkill -9 -f "ollama" 2>/dev/null && info "ollama 프로세스 종료" || info "ollama 실행 중 아님"
sleep 3
info "프로세스 정리 완료"

# ── 3. Ollama 시작 ────────────────────────────────────────
section "Ollama 시작"

ollama serve > "$OLLAMA_LOG" 2>&1 &
sleep 3

if pgrep -x "ollama" > /dev/null; then
  info "Ollama 시작됨 (PID: $(pgrep -x ollama))"
else
  error "Ollama 시작 실패. 로그 확인: $OLLAMA_LOG"
fi

# ── 4. 모델 로드 ──────────────────────────────────────────
section "모델 로드"

for MODEL in "$OLLAMA_MODEL" "$OLLAMA_SUBAGENT_MODEL" "$OLLAMA_FALLBACK_MODEL"; do
  if ollama list 2>/dev/null | grep -q "$MODEL"; then
    info "$MODEL — 이미 존재"
  else
    info "$MODEL — pull 중..."
    ollama pull "$MODEL" || warn "$MODEL pull 실패"
  fi
done

# ── 5. OpenClaw 게이트웨이 시작 ───────────────────────────
section "OpenClaw 게이트웨이 시작"

openclaw gateway --port 8080 > "$GATEWAY_LOG" 2>&1 &
sleep 5

if openclaw status &>/dev/null; then
  info "게이트웨이 시작됨"
else
  warn "게이트웨이 상태 확인 실패. 로그 확인: $GATEWAY_LOG"
fi

# ── 6. 에이전트 바인딩 확인 ───────────────────────────────
section "에이전트 바인딩 확인"

if openclaw agents bindings 2>/dev/null | grep -q "orchestrator"; then
  info "orchestrator ↔ Telegram 바인딩 정상"
else
  warn "orchestrator 바인딩이 없습니다. ./setup-agent.sh 를 다시 실행해 주세요."
fi

# ── 7. 게이트웨이 토큰 출력 ──────────────────────────────
section "게이트웨이 정보"

GW_TOKEN=$(python3 -c "import json; d=json.load(open('$OPENCLAW_DIR/openclaw.json')); print(d['gateway']['auth']['token'])")

# ── 완료 ──────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 오케스트레이터: ${OLLAMA_MODEL}"
echo "🤖 서브에이전트:   ${OLLAMA_SUBAGENT_MODEL}"
echo ""
echo "🌐 gcube URL로 접속 후 Overview 페이지에서:"
echo "   Gateway Token 필드에 아래 토큰 입력 후 Connect"
echo ""
echo "🔑 토큰: ${GW_TOKEN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 다음 단계:"
echo ""
echo "  1) Telegram 봇에 아무 메시지 보내기"
echo "     → Pairing 코드 수신"
echo ""
echo "  2) Device 승인"
echo "     $ openclaw devices list"
echo "     $ openclaw devices approve <requestId>"
echo ""
echo "  3) Pairing 승인"
echo "     $ openclaw pairing approve telegram <코드>"
echo ""
echo "  4) 대화 시작"
echo "     → Telegram에서 봇에게 메시지 보내기"
echo ""
echo "  5) 로그 확인 (문제 발생 시)"
echo "     $ tail -f ~/.openclaw/gateway.log"
echo "     $ tail -f ~/.openclaw/ollama.log"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [종료]  $ pkill -9 -f 'openclaw'; pkill -9 -f 'ollama'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
