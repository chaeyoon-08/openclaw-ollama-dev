#!/bin/bash
# =============================================================
# openclaw-ollama-dev / setup-agent.sh
# 오케스트레이터 + 전문가 에이전트 3개 등록 스크립트
#
# 실행 전 setup.sh 를 먼저 완료해야 합니다.
#
# 등록되는 에이전트:
#   orchestrator  — 요청 분석 + 전문가 에이전트 위임 총괄
#   mail          — Gmail 전담
#   calendar      — Google Calendar 전담
#   drive         — Google Drive/Docs 전담
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"

echo ""
echo "=================================================="
echo "  AI 업무 비서팀 에이전트 등록 스크립트"
echo "=================================================="
echo ""

# ── 1. .env 로드 ──────────────────────────────────────────
section ".env 로드"

[ -f "$OPENCLAW_DIR/.env" ] \
  || error ".env 파일이 없습니다. 먼저 setup.sh 를 실행해 주세요."

set -a; source "$OPENCLAW_DIR/.env"; set +a

OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3-coder:32b}"
info "사용 모델: $OLLAMA_MODEL"

# ── 2. 워크스페이스 준비 ──────────────────────────────────
section "에이전트 워크스페이스 준비"

# 에이전트 이름 → 연결할 스킬 디렉터리 매핑
agent_skill() {
  case "$1" in
    orchestrator) echo "" ;;        # 오케스트레이터는 스킬 없음 (하위 에이전트에 위임)
    mail)         echo "gmail" ;;
    calendar)     echo "calendar" ;;
    drive)        echo "drive" ;;
  esac
}

for AGENT in orchestrator mail calendar drive; do
  WS_DIR="$OPENCLAW_DIR/workspace-${AGENT}"
  mkdir -p "$WS_DIR/skills"

  # AGENTS.md 복사
  SRC="$SCRIPT_DIR/agents/${AGENT}/AGENTS.md"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$WS_DIR/AGENTS.md"
    info "  ${AGENT}: AGENTS.md 복사 완료"
  else
    warn "  ${AGENT}: agents/${AGENT}/AGENTS.md 없음 — OpenClaw 기본값 사용"
  fi

  # 스킬 디렉터리 복사 (오케스트레이터 제외)
  SKILL_NAME=$(agent_skill "$AGENT")
  if [ -n "$SKILL_NAME" ]; then
    SRC_SKILL="$SCRIPT_DIR/skills/${SKILL_NAME}"
    if [ -d "$SRC_SKILL" ]; then
      cp -r "$SRC_SKILL" "$WS_DIR/skills/"
      info "  ${AGENT}: skills/${SKILL_NAME} 복사 완료"
    else
      warn "  ${AGENT}: skills/${SKILL_NAME} 디렉터리 없음"
    fi
  fi

done

info "워크스페이스 준비 완료"

# ── 3. 게이트웨이 시작 ────────────────────────────────────
section "OpenClaw 게이트웨이 시작"

if ! openclaw gateway status &>/dev/null; then
  info "게이트웨이 시작 중..."
  openclaw gateway start --background
  sleep 5
  info "게이트웨이 시작 완료"
else
  info "게이트웨이 이미 실행 중"
fi

# ── 4. 에이전트 등록 ──────────────────────────────────────
# openclaw.json 의 agents.list 와 중복되지 않도록
# 에이전트 등록은 CLI(agents add)로만 처리
section "에이전트 등록"

for AGENT in orchestrator mail calendar drive; do
  WS_DIR="$OPENCLAW_DIR/workspace-${AGENT}"
  info "${AGENT} 에이전트 등록 중..."
  openclaw agents add "$AGENT" \
    --workspace "$WS_DIR" \
    --model "ollama/${OLLAMA_MODEL}" \
    --non-interactive \
    2>/dev/null \
    || warn "  ${AGENT}: 이미 등록됨 (건너뜀)"
done

info "에이전트 등록 완료"

# ── 5. 오케스트레이터 → Telegram 바인딩 ──────────────────
# 사용자 메시지는 모두 orchestrator 에이전트가 수신
# orchestrator 가 내부적으로 mail/calendar/drive 에 위임
section "Telegram 바인딩"

info "orchestrator ↔ Telegram 연결 중..."
openclaw agents bind --agent orchestrator --bind telegram \
  2>/dev/null \
  || warn "바인딩이 이미 존재합니다 (건너뜀)"
info "바인딩 완료"

# ── 6. 등록 결과 확인 ─────────────────────────────────────
section "등록 결과 확인"

echo ""
info "등록된 에이전트:"
openclaw agents list

echo ""
info "라우팅 바인딩:"
openclaw agents bindings

echo ""
info "게이트웨이 상태:"
openclaw status

# ── 완료 ──────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  에이전트 등록 완료!"
echo ""
echo "  Telegram 봇에 메시지를 보내보세요."
echo "  오케스트레이터가 요청을 분석해서 자동으로 처리합니다."
echo ""
echo "  복합 요청 예시:"
echo "    '김팀장 메일 확인하고 다음 주 미팅 잡아줘'"
echo "    → 메일 에이전트로 메일 조회"
echo "    → 일정 에이전트로 미팅 등록"
echo ""
echo "  에이전트 지침 커스터마이징:"
echo "    agents/orchestrator/AGENTS.md  ← 위임 로직"
echo "    agents/mail/AGENTS.md          ← 메일 에이전트 지침"
echo "    agents/calendar/AGENTS.md      ← 일정 에이전트 지침"
echo "    agents/drive/AGENTS.md         ← 문서 에이전트 지침"
echo ""
echo "  지침 수정 후: openclaw gateway restart"
echo ""
echo "  ── 런타임 모니터링 ──────────────────────────────"
echo "  openclaw tui                    터미널 대시보드 (전체 현황)"
echo "  openclaw gateway logs --follow  실시간 처리 로그"
echo "  openclaw status                 게이트웨이·채널 상태 요약"
echo "  openclaw agents list            등록 에이전트 확인"
echo "  openclaw agents bindings        봇↔에이전트 연결 확인"
echo ""
echo "  처리 중 로그 예시 (gateway logs --follow):"
echo "    [orchestrator] 요청 분석 → mail 에이전트 위임"
echo "    [mail] Gmail API 호출 중..."
echo "    [mail] 응답 수신 → orchestrator 반환"
echo "    [orchestrator] Telegram 전송 완료"
echo "=================================================="
echo ""