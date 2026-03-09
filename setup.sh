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
#   GITHUB_TOKEN          — GitHub Personal Access Token
#   GITHUB_USER_EMAIL     — GitHub 계정 이메일
#   GITHUB_USER_NAME      — GitHub 계정 이름 (실명, git log에 표시)
#   GITHUB_LOGIN          — GitHub 로그인 아이디 (공백 없음, 예: johndoe)
#
# 선택 환경변수:
#   OLLAMA_MODEL          — 기본값: qwen3-coder:32b
#   OLLAMA_FALLBACK_MODEL — 기본값: glm-4.7
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

: "${TELEGRAM_BOT_TOKEN:?'TELEGRAM_BOT_TOKEN 이 설정되지 않았습니다 (@BotFather에서 발급)'}"
: "${GOOGLE_CLIENT_ID:?'GOOGLE_CLIENT_ID 가 설정되지 않았습니다'}"
: "${GOOGLE_CLIENT_SECRET:?'GOOGLE_CLIENT_SECRET 이 설정되지 않았습니다'}"
: "${GOOGLE_REFRESH_TOKEN:?'GOOGLE_REFRESH_TOKEN 이 설정되지 않았습니다'}"
: "${GITHUB_TOKEN:?'GITHUB_TOKEN 이 설정되지 않았습니다'}"
: "${GITHUB_USER_EMAIL:?'GITHUB_USER_EMAIL 이 설정되지 않았습니다'}"
: "${GITHUB_USER_NAME:?'GITHUB_USER_NAME 이 설정되지 않았습니다'}"
: "${GITHUB_LOGIN:?'GITHUB_LOGIN 이 설정되지 않았습니다 (GitHub 로그인 아이디, 공백 없음, 예: johndoe)'}"

OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3-coder:32b}"
OLLAMA_FALLBACK_MODEL="${OLLAMA_FALLBACK_MODEL:-glm-4.7}"
OLLAMA_ORIGINAL_MODEL="$OLLAMA_MODEL"

info "환경변수 확인 완료"
info "목표 모델: $OLLAMA_MODEL  /  fallback: $OLLAMA_FALLBACK_MODEL"

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

# ── 3. Git 설정 ───────────────────────────────────────────
section "Git 전역 설정"

git config --global user.email "$GITHUB_USER_EMAIL"
git config --global user.name "$GITHUB_USER_NAME"
git config --global credential.helper store
echo "https://${GITHUB_LOGIN}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
info "Git 설정 완료"

# ── 4. Ollama 설치 ────────────────────────────────────────
section "Ollama 설치"

if ! command -v ollama &>/dev/null; then
  info "Ollama 설치 중..."
  curl -fsSL https://ollama.ai/install.sh | sh
  info "Ollama 설치 완료"
else
  info "Ollama 이미 설치됨: $(ollama --version)"
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
  warn "$OLLAMA_MODEL 다운로드 실패."
  warn "Fallback 모델 시도 중: $OLLAMA_FALLBACK_MODEL"
  ollama pull "$OLLAMA_FALLBACK_MODEL" \
    || error "Fallback 모델($OLLAMA_FALLBACK_MODEL) 다운로드도 실패했습니다."
  OLLAMA_MODEL="$OLLAMA_FALLBACK_MODEL"
  FALLBACK_USED=true
  info "$OLLAMA_FALLBACK_MODEL 다운로드 완료"
fi

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
  printf 'OLLAMA_FALLBACK_MODEL=%s\n'  "${OLLAMA_FALLBACK_MODEL}"
} > "$OPENCLAW_DIR/.env"
chmod 600 "$OPENCLAW_DIR/.env"
info ".env 생성 완료"

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
        "api": "openai-completions"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/${OLLAMA_MODEL}",
        "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
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
    "mode": "local"
  }
}
EOF
info "openclaw.json 생성 완료"

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