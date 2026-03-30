#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup-agent.sh
# 에이전트 워크스페이스 구성 및 스킬 설치 스크립트
#
# 사전 조건: setup.sh 완료
#
# 참고 문서:
#   OpenClaw  : https://docs.openclaw.ai
#   clawhub   : https://docs.openclaw.ai/skills
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
GATEWAY_LOG="$OPENCLAW_DIR/gateway-setup.log"

log_start "에이전트 워크스페이스 설정 시작"

# ── 1. PATH 설정 ──────────────────────────────────────────
export PATH="/workspace/node/bin:/workspace/ollama/bin:$PATH"

# ── 2. ~/.openclaw/.env 로드 ──────────────────────────────
log_doing "~/.openclaw/.env 로드"

if [ ! -f "$OPENCLAW_DIR/.env" ]; then
  log_stop "~/.openclaw/.env 없음. 먼저 setup.sh 를 실행해 주세요."
fi

set -a
# shellcheck source=/dev/null
source "$OPENCLAW_DIR/.env"
set +a

for _VAR in TELEGRAM_BOT_TOKEN OLLAMA_MODEL; do
  if [ -z "${!_VAR}" ]; then
    log_stop "${_VAR} 미설정. setup.sh 를 먼저 실행해 주세요."
  fi
done

log_ok "model: $OLLAMA_MODEL"

# ── 3. openclaw.json 설정 검증 ────────────────────────────
log_doing "openclaw.json 설정 확인"

OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"
if [ ! -f "$OPENCLAW_JSON" ]; then
  log_stop "openclaw.json 없음. setup.sh 를 먼저 실행해 주세요."
fi

python3 << PYEOF
import json, sys

with open("$OPENCLAW_JSON") as f:
    c = json.load(f)

ok = True

# channels.telegram.botToken 확인
bot_token = c.get("channels", {}).get("telegram", {}).get("botToken", "")
if not bot_token:
    print(f"\033[1;33m[ WARN  ]\033[0m channels.telegram.botToken 없음 — TELEGRAM_BOT_TOKEN 확인")
    ok = False
else:
    masked = bot_token[:6] + "****"
    print(f"\033[0;32m[  OK   ]\033[0m channels.telegram.botToken: {masked}")

# gateway.auth.token 확인
gw_token = c.get("gateway", {}).get("auth", {}).get("token", "")
if not gw_token:
    print(f"\033[1;33m[ WARN  ]\033[0m gateway.auth.token 없음 → setup.sh 재실행 필요")
    ok = False
else:
    print(f"\033[0;32m[  OK   ]\033[0m gateway.auth.token: {gw_token[:6]}****")

# agents.defaults.model.primary 확인
primary = c.get("agents", {}).get("defaults", {}).get("model", {}).get("primary", "")
if not primary:
    print(f"\033[1;33m[ WARN  ]\033[0m agents.defaults.model.primary 없음 → setup.sh 재실행 필요")
    ok = False
else:
    print(f"\033[0;32m[  OK   ]\033[0m agents.defaults.model.primary: {primary}")

if ok:
    print(f"\033[1;32m[ DONE  ]\033[0m openclaw.json 설정 검증 완료")
else:
    sys.exit(1)
PYEOF

# ── 4. 워크스페이스 파일 복사 ─────────────────────────────
log_doing "워크스페이스 파일 복사"

SRC="$SCRIPT_DIR/config/workspace"
DEST="$OPENCLAW_DIR/workspace"

if [ ! -d "$SRC" ]; then
  log_stop "config/workspace/ 없음 — 레포를 최신 버전으로 업데이트하세요."
fi

mkdir -p "$DEST"
cp -r "$SRC/." "$DEST/"
log_ok "워크스페이스 복사 완료 → $DEST"

# ── 4-1. skills 폴더 복사 ─────────────────────────────────
log_doing "skills 폴더 복사"

SKILLS_SRC="$SCRIPT_DIR/config/workspace/skills"
SKILLS_DEST="$OPENCLAW_DIR/workspace/skills"

if [ -d "$SKILLS_SRC" ]; then
  mkdir -p "$SKILLS_DEST"
  cp -r "$SKILLS_SRC/." "$SKILLS_DEST/"
  log_ok "skills 복사 완료 → $SKILLS_DEST"
else
  log_warn "config/workspace/skills/ 없음 — 스킵"
fi

# ── 4-2. Python 패키지 확인 ───────────────────────────────
log_doing "Python 패키지 확인 (python-docx, openpyxl, python-pptx)"

if ! python3 -c "import docx, openpyxl, pptx" 2>/dev/null; then
  log_doing "Python 패키지 설치 중..."
  pip install --quiet python-docx openpyxl python-pptx lxml \
    || log_warn "pip install 실패 — 수동으로 실행: pip install python-docx openpyxl python-pptx lxml"
  log_ok "Python 패키지 설치 완료"
else
  log_ok "Python 패키지 확인 완료"
fi

# ── 4-3. OUTPUT_DIR 생성 ──────────────────────────────────
log_doing "출력 디렉토리 생성 (/workspace/work)"
mkdir -p /workspace/work
log_ok "/workspace/work 생성 완료"

# ── 5. openclaw gateway 임시 기동 (스킬 설치용) ───────────
log_doing "openclaw gateway 임시 기동 (스킬 설치용)"

# 기존 gateway 종료
pkill -f 'openclaw gateway' 2>/dev/null || true
sleep 1

openclaw gateway > "$GATEWAY_LOG" 2>&1 &
GATEWAY_PID=$!

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
  log_warn "gateway 기동 실패 — openclaw doctor --fix 실행 중..."
  openclaw doctor --fix 2>&1 | tee -a "$GATEWAY_LOG" || true
  sleep 3

  pkill -f 'openclaw gateway' 2>/dev/null || true
  sleep 1
  openclaw gateway >> "$GATEWAY_LOG" 2>&1 &
  GATEWAY_PID=$!

  READY=false
  for i in $(seq 1 30); do
    if curl -sf http://127.0.0.1:18789/ &>/dev/null; then
      READY=true
      break
    fi
    sleep 1
  done

  if [ "$READY" = false ]; then
    log_stop "openclaw gateway 기동 실패. 로그 확인: $GATEWAY_LOG"
  fi
fi

log_ok "openclaw gateway 임시 기동 완료 (PID: $GATEWAY_PID)"

# ── 6. 스킬 설치 ──────────────────────────────────────────
log_doing "스킬 설치: felo-slides"
npx clawhub@latest install felo-slides \
  || log_warn "felo-slides 설치 실패 — 수동으로 재시도: npx clawhub@latest install felo-slides"
log_ok "felo-slides 설치 완료"

log_doing "스킬 설치: office-document-specialist-suite"
npx clawhub@latest install office-document-specialist-suite \
  || log_warn "office-document-specialist-suite 설치 실패 — 수동으로 재시도: npx clawhub@latest install office-document-specialist-suite"
log_ok "office-document-specialist-suite 설치 완료"

# ── 7. gateway 종료 ───────────────────────────────────────
log_doing "임시 gateway 종료"
kill "$GATEWAY_PID" 2>/dev/null || true
wait "$GATEWAY_PID" 2>/dev/null || true
pkill -f 'openclaw gateway' 2>/dev/null || true
sleep 1
log_ok "gateway 종료 완료"

# ── 8. 예시 파일 생성 ────────────────────────────────────
log_doing "예시 파일 생성 중..."

OPENCLAW_WORKSPACE="$OPENCLAW_DIR/workspace" \
OUTPUT_DIR="/workspace/work" \
python3 "$OPENCLAW_DIR/workspace/skills/office-document-specialist-suite/make_examples.py" \
  && log_ok "예시 파일 생성 완료" \
  || log_warn "예시 파일 생성 실패 (선택사항)"

# ── 완료 ──────────────────────────────────────────────────
echo ""
log_done "에이전트 설정 완료"
log_next "다음 단계: bash run.sh"
