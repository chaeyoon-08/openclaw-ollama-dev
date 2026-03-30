#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup.sh
# Node.js + Ollama + OpenClaw 설치 및 openclaw.json 생성 스크립트
#
# 대상 환경: unsloth Docker 이미지 (apt 권한 없음)
# → Node.js / Ollama 바이너리 직접 설치
#
# 참고 문서:
#   OpenClaw  : https://docs.openclaw.ai
#   Node.js   : https://nodejs.org/dist
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_BIN="/workspace"

log_start "OpenClaw 설치 시작"

# ── 1. .env 로드 및 필수 변수 검증 ────────────────────────
log_doing "환경변수 확인"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
  log_ok ".env 로드 완료"
fi

MISSING=()
for VAR in TELEGRAM_BOT_TOKEN OLLAMA_MODEL; do
  [ -z "${!VAR}" ] && MISSING+=("$VAR")
done

if [ ${#MISSING[@]} -gt 0 ]; then
  log_error "미설정 환경변수:"
  for V in "${MISSING[@]}"; do
    echo "        - $V"
  done
  log_stop ".env 파일을 확인하고 모든 필수 변수를 설정하세요."
fi

log_ok "환경변수 확인 완료"
log_ok "  model: $OLLAMA_MODEL"

# ── 2. Node.js 22 설치 확인 ───────────────────────────────
log_doing "Node.js 확인"

NODE_OK=false
if command -v node &>/dev/null; then
  NODE_MAJOR=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
  if [ "$NODE_MAJOR" -ge 22 ]; then
    NODE_OK=true
    log_ok "Node.js $(node --version) 확인됨"
  else
    log_warn "Node.js $(node --version) — 22 미만, 재설치합니다."
  fi
else
  log_warn "Node.js 미설치"
fi

if [ "$NODE_OK" = false ]; then
  log_doing "Node.js 22 바이너리 설치 중 (/workspace/node)..."

  # LTS 최신 22.x 버전 가져오기
  NODE_VERSION=$(curl -sf https://nodejs.org/dist/latest-v22.x/ \
    | grep -oP 'node-v\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x64\.tar\.xz)' \
    | head -1)
  [ -z "$NODE_VERSION" ] && NODE_VERSION="22.15.0"

  NODE_TAR="node-v${NODE_VERSION}-linux-x64.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"
  NODE_DEST="${WORKSPACE_BIN}/node"

  log_doing "다운로드: $NODE_URL"
  curl -fL "$NODE_URL" -o "/tmp/${NODE_TAR}" \
    || log_stop "Node.js 다운로드 실패"

  rm -rf "${WORKSPACE_BIN}"/node-v*-linux-x64 "$NODE_DEST"
  mkdir -p "$WORKSPACE_BIN"
  tar -xJf "/tmp/${NODE_TAR}" -C "$WORKSPACE_BIN"
  mv "${WORKSPACE_BIN}/node-v${NODE_VERSION}-linux-x64" "$NODE_DEST"
  rm -f "/tmp/${NODE_TAR}"

  export PATH="${NODE_DEST}/bin:$PATH"
  log_ok "Node.js $(node --version) 설치 완료 → ${NODE_DEST}/bin"
fi

# ── 3. Ollama 설치 확인 ────────────────────────────────────
log_doing "Ollama 확인"

OLLAMA_BIN_DIR="${WORKSPACE_BIN}/ollama/bin"

if command -v ollama &>/dev/null; then
  log_ok "Ollama 이미 설치됨: $(ollama --version 2>/dev/null | head -1)"
else
  log_doing "Ollama 바이너리 직접 설치 중 (${OLLAMA_BIN_DIR})..."

  OLLAMA_VERSION=$(curl -sf "https://api.github.com/repos/ollama/ollama/releases/latest" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null || echo "v0.6.8")

  OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64"
  log_doing "다운로드: ${OLLAMA_URL}"

  mkdir -p "$OLLAMA_BIN_DIR"
  curl -fL "$OLLAMA_URL" -o "${OLLAMA_BIN_DIR}/ollama" \
    || log_stop "Ollama 다운로드 실패"
  chmod +x "${OLLAMA_BIN_DIR}/ollama"

  export PATH="${OLLAMA_BIN_DIR}:$PATH"
  log_ok "Ollama 설치 완료: $(ollama --version 2>/dev/null | head -1) → ${OLLAMA_BIN_DIR}"
fi

# ── 4. OpenClaw 설치 ──────────────────────────────────────
log_doing "OpenClaw 확인"

if ! command -v openclaw &>/dev/null; then
  log_doing "OpenClaw 설치 중..."
  npm install -g openclaw || log_stop "OpenClaw 설치 실패"
  log_ok "OpenClaw 설치 완료: $(openclaw --version)"
else
  log_ok "OpenClaw 이미 설치됨: $(openclaw --version)"
fi

# ── 5. Python 패키지 설치 ─────────────────────────────────
log_doing "Python 패키지 설치 (python-docx, openpyxl, python-pptx, lxml)"

pip install --quiet python-docx openpyxl python-pptx lxml \
  || log_warn "pip install 실패 — 수동으로 설치하세요: pip install python-docx openpyxl python-pptx lxml"
log_ok "Python 패키지 설치 완료"

# ── 6. openclaw.json 생성 ─────────────────────────────────
# ref: https://docs.openclaw.ai
log_doing "openclaw.json 생성 중..."

mkdir -p "$OPENCLAW_DIR"
GW_TOKEN=$(openssl rand -hex 24)
WORK_DIR="/workspace/work"
mkdir -p "$WORK_DIR"

cat > "$OPENCLAW_DIR/openclaw.json" << EOF
{
  "models": {
    "mode": "merge",
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions",
        "models": [
          {
            "id": "${OLLAMA_MODEL}:latest",
            "name": "${OLLAMA_MODEL}:latest",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 32768,
            "maxTokens": 8192,
            "compat": { "supportsDeveloperRole": false }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "ollama/${OLLAMA_MODEL}:latest" },
      "workspace": "${OPENCLAW_DIR}/workspace"
    }
  },
  "tools": {
    "profile": "full",
    "deny": ["session_status"],
    "web": { "search": { "enabled": true, "provider": "duckduckgo" } },
    "exec": {
      "host": "gateway",
      "security": "full",
      "ask": "off",
      "pathPrepend": ["/workspace/ollama/bin", "/workspace/node/bin", "/opt/conda/bin"]
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "streaming": "partial"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "controlUi": { "allowInsecureAuth": true },
    "auth": { "mode": "token", "token": "${GW_TOKEN}" }
  },
  "plugins": {
    "entries": { "duckduckgo": { "enabled": true, "config": {} } }
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": { "session-memory": { "enabled": true } }
    }
  },
  "env": {
    "vars": {
      "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY:-}",
      "OUTPUT_DIR": "/workspace/work",
      "OPENCLAW_CONFIG": "${OPENCLAW_DIR}/openclaw.json",
      "OPENCLAW_WORKSPACE": "${OPENCLAW_DIR}/workspace"
    }
  },
  "session": { "dmScope": "per-channel-peer" }
}
EOF

log_ok "openclaw.json 생성 완료: $OPENCLAW_DIR/openclaw.json"

# ── 7. ~/.openclaw/.env 생성 ──────────────────────────────
log_doing "~/.openclaw/.env 생성 중..."

{
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "${TELEGRAM_BOT_TOKEN}"
  printf 'OLLAMA_MODEL=%s\n'       "${OLLAMA_MODEL}"
  printf 'ANTHROPIC_API_KEY=%s\n'  "${ANTHROPIC_API_KEY:-}"
} > "$OPENCLAW_DIR/.env"
chmod 600 "$OPENCLAW_DIR/.env"

log_ok "~/.openclaw/.env 생성 완료 (chmod 600)"

# ── 완료 ──────────────────────────────────────────────────
echo ""
log_done "설치 완료"
log_next "다음 단계: bash setup-agent.sh"
