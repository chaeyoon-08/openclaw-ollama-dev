#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup.sh
# Ollama + gogcli + OpenClaw 설치 및 초기 설정 스크립트
#
# 참고 문서:
#   OpenClaw  : https://docs.openclaw.ai
#   gogcli    : https://github.com/steipete/gogcli
#   Ollama    : https://ollama.ai
#   NodeSource: https://github.com/nodesource/distributions
#   Go        : https://go.dev/dl
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

log_start "OpenClaw Ollama 설치 시작"

# ── 1. .env 검증 ──────────────────────────────────────────
log_doing "환경변수 확인"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
  log_ok ".env 로드 완료"
fi

MISSING=()
for VAR in TELEGRAM_BOT_TOKEN GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET \
           GOOGLE_REFRESH_TOKEN OLLAMA_MODEL OLLAMA_SUBAGENT_MODEL OLLAMA_FALLBACK_MODEL; do
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
log_ok "  오케스트레이터: $OLLAMA_MODEL"
log_ok "  서브에이전트:   $OLLAMA_SUBAGENT_MODEL"
log_ok "  Fallback:      $OLLAMA_FALLBACK_MODEL"

# ── 2. Node.js 확인 ───────────────────────────────────────
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
  log_doing "Node.js 22 설치 중..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
  log_ok "Node.js $(node --version) 설치 완료"
fi

# ── 3. Ollama 설치 ────────────────────────────────────────
log_doing "Ollama 확인"

if ! command -v ollama &>/dev/null; then
  log_doing "Ollama 설치 중..."
  curl -fsSL https://ollama.ai/install.sh | sh
  log_ok "Ollama 설치 완료"
else
  log_ok "Ollama 이미 설치됨: $(ollama --version 2>/dev/null | head -1)"
fi

# ── 4. gogcli 설치 ────────────────────────────────────────
log_doing "gogcli 확인"

if ! command -v gog &>/dev/null; then
  # go.mod에서 요구 Go 버전 동적으로 읽기
  log_doing "gogcli 요구 Go 버전 확인 중..."
  GO_REQUIRED=$(curl -s https://raw.githubusercontent.com/steipete/gogcli/main/go.mod \
    | grep '^go ' | awk '{print $2}')

  [ -z "$GO_REQUIRED" ] && log_stop "gogcli go.mod에서 Go 버전을 읽지 못했습니다."
  log_ok "gogcli 요구 Go 버전: $GO_REQUIRED"

  # 공식 Go 바이너리 설치
  log_doing "Go $GO_REQUIRED 설치 중..."
  GO_TAR="go${GO_REQUIRED}.linux-amd64.tar.gz"
  curl -fOL "https://go.dev/dl/${GO_TAR}" \
    || log_stop "Go $GO_REQUIRED 다운로드 실패"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$GO_TAR"
  rm -f "$GO_TAR"
  export PATH=$PATH:/usr/local/go/bin
  log_ok "Go $(go version) 설치 완료"

  # 빌드 의존성 및 gogcli 빌드
  log_doing "빌드 의존성 설치 중..."
  apt-get install -y make build-essential -qq

  log_doing "gogcli 빌드 중..."
  cd /tmp
  rm -rf gogcli
  git clone https://github.com/steipete/gogcli.git
  cd gogcli
  make || log_stop "gogcli make 실패"
  cp bin/gog /usr/local/bin/gog
  chmod +x /usr/local/bin/gog
  cd "$SCRIPT_DIR"
  log_ok "gogcli 설치 완료: $(gog --version)"
else
  log_ok "gogcli 이미 설치됨: $(gog --version)"
fi

# ── 5. OpenClaw 설치 ──────────────────────────────────────
log_doing "OpenClaw 확인"

if ! command -v openclaw &>/dev/null; then
  log_doing "OpenClaw 설치 중..."
  npm install -g openclaw || log_stop "OpenClaw 설치 실패"
  log_ok "OpenClaw 설치 완료: $(openclaw --version)"
else
  log_ok "OpenClaw 이미 설치됨: $(openclaw --version)"
fi

# ── 6. openclaw.json 생성 ─────────────────────────────────
# ref: https://docs.openclaw.ai
log_doing "openclaw.json 생성 중..."

mkdir -p "$OPENCLAW_DIR"
GW_TOKEN=$(openssl rand -hex 24)

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
            "id": "ollama/${OLLAMA_MODEL}",
            "name": "${OLLAMA_MODEL}",
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
      "compaction": {
        "mode": "safeguard"
      },
      "subagents": {
        "runTimeoutSeconds": 120
      }
    },
    "list": [
      {
        "id": "orchestrator",
        "workspace": "${OPENCLAW_DIR}/workspace-orchestrator",
        "model": {
          "primary": "ollama/${OLLAMA_MODEL}",
          "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
        },
        "subagents": {
          "allowAgents": ["mail", "calendar", "drive"]
        }
      },
      {
        "id": "mail",
        "workspace": "${OPENCLAW_DIR}/workspace-mail",
        "model": {
          "primary": "ollama/${OLLAMA_SUBAGENT_MODEL}",
          "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
        }
      },
      {
        "id": "calendar",
        "workspace": "${OPENCLAW_DIR}/workspace-calendar",
        "model": {
          "primary": "ollama/${OLLAMA_SUBAGENT_MODEL}",
          "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
        }
      },
      {
        "id": "drive",
        "workspace": "${OPENCLAW_DIR}/workspace-drive",
        "model": {
          "primary": "ollama/${OLLAMA_SUBAGENT_MODEL}",
          "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
        }
      }
    ]
  },
  "bindings": [
    { "agentId": "orchestrator", "match": { "channel": "telegram" } }
  ],
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
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "trustedProxies": ["127.0.0.1"],
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    },
    "auth": {
      "mode": "token",
      "token": "${GW_TOKEN}"
    }
  }
}
EOF

log_ok "openclaw.json 생성 완료: $OPENCLAW_DIR/openclaw.json"

# ── 7. ~/.openclaw/.env 생성 ──────────────────────────────
log_doing "~/.openclaw/.env 생성 중..."

{
  printf 'TELEGRAM_BOT_TOKEN=%s\n'    "${TELEGRAM_BOT_TOKEN}"
  printf 'GOOGLE_CLIENT_ID=%s\n'      "${GOOGLE_CLIENT_ID}"
  printf 'GOOGLE_CLIENT_SECRET=%s\n'  "${GOOGLE_CLIENT_SECRET}"
  printf 'GOOGLE_REFRESH_TOKEN=%s\n'  "${GOOGLE_REFRESH_TOKEN}"
  printf 'GOOGLE_ACCOUNT=%s\n'        "${GOOGLE_ACCOUNT:-}"
  printf 'OLLAMA_MODEL=%s\n'          "${OLLAMA_MODEL}"
  printf 'OLLAMA_SUBAGENT_MODEL=%s\n' "${OLLAMA_SUBAGENT_MODEL}"
  printf 'OLLAMA_FALLBACK_MODEL=%s\n' "${OLLAMA_FALLBACK_MODEL}"
  printf 'OLLAMA_API_KEY=%s\n'        "ollama-local"
} > "$OPENCLAW_DIR/.env"
chmod 600 "$OPENCLAW_DIR/.env"

log_ok "~/.openclaw/.env 생성 완료 (chmod 600)"

# ── 완료 ──────────────────────────────────────────────────
echo ""
log_done "설치 완료"
log_next "다음 단계: bash setup-agent.sh"
