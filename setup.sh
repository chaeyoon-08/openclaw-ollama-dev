#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup.sh
# Ollama + OpenClaw 설치 및 초기 설정 스크립트
#
# 필수 환경변수:
#   TELEGRAM_BOT_TOKEN    — Telegram 봇 토큰 (BotFather에서 발급)
#   GOOGLE_CLIENT_ID      — Google Cloud Console OAuth 클라이언트 ID
#   GOOGLE_CLIENT_SECRET  — Google Cloud Console OAuth 클라이언트 시크릿
#   GOOGLE_REFRESH_TOKEN  — Google OAuth Refresh Token
#
#   OLLAMA_MODEL          — 오케스트레이터용 모델 (예: qwen3:32b-q4_K_M)
#   OLLAMA_SUBAGENT_MODEL — 서브에이전트용 모델 (예: qwen3:8b)
#   OLLAMA_FALLBACK_MODEL — 기본 모델 실패 시 대체 모델 (예: glm-4.7-flash)
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

echo ""
echo "=================================================="
echo "  OpenClaw Ollama 버전 설치 스크립트"
echo "  (오케스트레이션 멀티 에이전트 구조)"
echo "=================================================="
echo ""

# ── 1. 환경변수 확인 ──────────────────────────────────────
section "환경변수 확인"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
  info ".env 파일 로드 완료"
else
  info ".env 파일 없음 — 환경변수에서 값을 사용합니다."
fi

status_var() {
  local var="$1" mode="$2"
  local val="${!var}"
  if [ -z "$val" ]; then
    info "${var}: 미설정"
    return
  fi
  case "$mode" in
    full)    info "${var}: ${val}" ;;
    partial) info "${var}: ${val:0:4}$(printf '%*s' "$(( ${#val} > 4 ? ${#val} - 4 : 0 ))" '' | tr ' ' '*')" ;;
  esac
}
status_var TELEGRAM_BOT_TOKEN    partial
status_var GOOGLE_CLIENT_ID      partial
status_var GOOGLE_CLIENT_SECRET  partial
status_var GOOGLE_REFRESH_TOKEN  partial
status_var OLLAMA_MODEL          full
status_var OLLAMA_SUBAGENT_MODEL full
status_var OLLAMA_FALLBACK_MODEL full

MISSING_MODEL=false
if [ -z "$OLLAMA_MODEL" ]; then
  info "OLLAMA_MODEL이 설정되지 않았습니다. 워크로드의 환경변수를 추가하거나, .env.example을 참고해서 .env 파일을 작성해주세요."
  MISSING_MODEL=true
fi
if [ -z "$OLLAMA_SUBAGENT_MODEL" ]; then
  info "OLLAMA_SUBAGENT_MODEL이 설정되지 않았습니다. 워크로드의 환경변수를 추가하거나, .env.example을 참고해서 .env 파일을 작성해주세요."
  MISSING_MODEL=true
fi
if [ -z "$OLLAMA_FALLBACK_MODEL" ]; then
  info "OLLAMA_FALLBACK_MODEL이 설정되지 않았습니다. 워크로드의 환경변수를 추가하거나, .env.example을 참고해서 .env 파일을 작성해주세요."
  MISSING_MODEL=true
fi
[ "$MISSING_MODEL" = true ] && exit 1
OLLAMA_ORIGINAL_MODEL="$OLLAMA_MODEL"

info "환경변수 확인 완료"
info "오케스트레이터 모델: $OLLAMA_MODEL  /  서브에이전트 모델: $OLLAMA_SUBAGENT_MODEL  /  fallback: $OLLAMA_FALLBACK_MODEL"

# ── 2. Node.js 확인 ───────────────────────────────────────
section "Node.js 확인"

if ! command -v node &>/dev/null; then
  error "Node.js 18 이상이 필요합니다. https://nodejs.org 에서 설치해 주세요."
fi

NODE_MAJOR=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
if [ "$NODE_MAJOR" -lt 18 ]; then
  error "Node.js 18 이상이 필요합니다. 현재 버전: $(node --version)"
fi
info "Node.js $(node --version) 확인됨"

# ── 3. Ollama 설치 ────────────────────────────────────────
section "Ollama 설치"

if ! command -v ollama &>/dev/null; then
  info "Ollama 설치 중..."
  curl -fsSL https://ollama.ai/install.sh | sh
  info "Ollama 설치 완료"
else
  OLLAMA_VERSION=$(ollama --version 2>/dev/null | grep -o 'version is [0-9.]*' | awk '{print $3}')
  info "Ollama 이미 설치됨 (서비스 실행 전) — client version: ${OLLAMA_VERSION:-unknown}"
fi

# ── 5. Ollama 서비스 시작 ─────────────────────────────────
section "Ollama 서비스 시작"

if ! pgrep -x "ollama" > /dev/null; then
  ollama serve &>/dev/null &
  sleep 3
  info "Ollama 서비스 시작됨"
else
  info "Ollama 서비스 이미 실행 중"
fi

# ── 6. 모델 Pull ──────────────────────────────────────────
section "LLM 모델 다운로드"

info "다운로드 시작: $OLLAMA_MODEL"
info "(모델 크기에 따라 10~30분 소요될 수 있습니다)"

FALLBACK_USED=false
if ollama pull "$OLLAMA_MODEL"; then
  info "$OLLAMA_MODEL 다운로드 완료"
else
  warn "$OLLAMA_MODEL 다운로드 실패 — fallback 모델로 대체합니다."
  OLLAMA_MODEL="$OLLAMA_FALLBACK_MODEL"
  FALLBACK_USED=true
fi

info "서브에이전트 모델 다운로드 중: $OLLAMA_SUBAGENT_MODEL"
if ollama pull "$OLLAMA_SUBAGENT_MODEL"; then
  info "$OLLAMA_SUBAGENT_MODEL 다운로드 완료"
else
  warn "$OLLAMA_SUBAGENT_MODEL 다운로드 실패 — 서브에이전트 실행 시 문제가 발생할 수 있습니다."
fi

info "Fallback 모델 다운로드 중: $OLLAMA_FALLBACK_MODEL"
if ollama pull "$OLLAMA_FALLBACK_MODEL"; then
  info "$OLLAMA_FALLBACK_MODEL 다운로드 완료"
else
  warn "$OLLAMA_FALLBACK_MODEL 다운로드 실패 — 타임아웃 시 404 에러가 발생할 수 있습니다."
fi

FINAL_MODEL="$OLLAMA_MODEL"

# ── 7. OpenClaw 설치 ──────────────────────────────────────
section "OpenClaw 설치"

if ! command -v openclaw &>/dev/null; then
  npm install -g openclaw
  info "OpenClaw 설치 완료"
else
  info "OpenClaw 이미 설치됨: $(openclaw --version)"
fi

# ── 8. OpenClaw 디렉터리 초기화 ───────────────────────────
section "OpenClaw 초기 설정"

OPENCLAW_DIR="$HOME/.openclaw"
mkdir -p "$OPENCLAW_DIR"

# .env 생성 (Google OAuth + 봇 토큰 + 최종 모델명)
# printf '%s' 사용 — 값에 $, `, \ 등 특수문자가 있어도 안전하게 기록
{
  printf 'GOOGLE_CLIENT_ID=%s\n'       "${GOOGLE_CLIENT_ID}"
  printf 'GOOGLE_CLIENT_SECRET=%s\n'   "${GOOGLE_CLIENT_SECRET}"
  printf 'GOOGLE_REFRESH_TOKEN=%s\n'   "${GOOGLE_REFRESH_TOKEN}"
  printf 'TELEGRAM_BOT_TOKEN=%s\n'     "${TELEGRAM_BOT_TOKEN}"
  printf 'OLLAMA_API_KEY=%s\n'         "ollama-local"
  printf 'OLLAMA_MODEL=%s\n'           "${OLLAMA_MODEL}"
  printf 'OLLAMA_SUBAGENT_MODEL=%s\n'  "${OLLAMA_SUBAGENT_MODEL}"
  printf 'OLLAMA_FALLBACK_MODEL=%s\n'  "${OLLAMA_FALLBACK_MODEL}"
  printf 'NODE_OPTIONS=%s\n'          "--dns-result-order=ipv4first"
} > "$OPENCLAW_DIR/.env"
chmod 600 "$OPENCLAW_DIR/.env"
info ".env 파일 생성 완료: $OPENCLAW_DIR/.env"

# openclaw.json 생성
# - agents.list 와 bindings 는 setup-agent.sh 에서 CLI로 등록 (중복 방지)
# - 채널 설정(botToken)은 여기서 정의, channels add 는 실행하지 않음
cat > "$OPENCLAW_DIR/openclaw.json" << EOF
{
  "models": {
    "mode": "merge",
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434",
        "apiKey": "ollama-local",
        "api": "ollama",
        "models": [
          {
            "id": "ollama/${FINAL_MODEL}",
            "name": "${FINAL_MODEL}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          },
          {
            "id": "ollama/${OLLAMA_SUBAGENT_MODEL}",
            "name": "${OLLAMA_SUBAGENT_MODEL}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          },
          {
            "id": "ollama/${OLLAMA_FALLBACK_MODEL}",
            "name": "${OLLAMA_FALLBACK_MODEL}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/${FINAL_MODEL}",
        "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
      },
      "compaction": {
        "mode": "safeguard"
      }
    }
  },
  "channels": {
    "telegram": {
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "open",
      "allowFrom": ["*"]
    }
  },
  "env": {
    "GOOGLE_CLIENT_ID": "${GOOGLE_CLIENT_ID}",
    "GOOGLE_CLIENT_SECRET": "${GOOGLE_CLIENT_SECRET}",
    "GOOGLE_REFRESH_TOKEN": "${GOOGLE_REFRESH_TOKEN}"
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "$(openssl rand -hex 24)"
    }
  }
}
EOF
info "openclaw.json 생성 완료: $OPENCLAW_DIR/openclaw.json"

# ── 완료 요약 ─────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  기본 설치 완료!"
echo ""
if [ "$FALLBACK_USED" = true ]; then
  echo "  ✅ 최종 사용 모델 : ${OLLAMA_MODEL}"
  echo "  ⚠️  주의: 기본 모델(${OLLAMA_ORIGINAL_MODEL}) pull 실패"
  echo "       → fallback 모델(${OLLAMA_MODEL})로 대체됨"
else
  echo "  ✅ 최종 사용 모델 : ${OLLAMA_MODEL}"
fi
echo ""
echo "  다음 단계: ./setup-agent.sh 실행"
echo "=================================================="
echo ""