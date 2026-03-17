---
description: 레포 구조 및 현재 서비스 상태 분석
---

## 목적

openclaw-ollama-dev 레포의 현재 상태를 빠르게 파악한다.
에이전트 등록 상태, 게이트웨이 동작 여부, 환경변수 설정 여부를 한 번에 점검한다.

## 사전 조건

- `setup.sh`와 `setup-agent.sh`가 한 번 이상 실행된 상태
- `openclaw` CLI가 설치되어 있어야 함 (`which openclaw`)

## 실행 절차

### 1. 레포 파일 구조 확인

```bash
find . -not -path './.git/*' | sort
```

### 2. 환경변수 설정 여부 확인

```bash
# 프로젝트 루트 .env
[ -f .env ] && echo ".env 존재" || echo ".env 없음 (cp .env.example .env 필요)"

# 런타임 .env
[ -f ~/.openclaw/.env ] && echo "~/.openclaw/.env 존재" || echo "~/.openclaw/.env 없음 (setup.sh 미실행)"

# 핵심 변수 설정 여부 (값 노출 없이)
for VAR in TELEGRAM_BOT_TOKEN GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN OLLAMA_MODEL OLLAMA_SUBAGENT_MODEL; do
  source ~/.openclaw/.env 2>/dev/null
  [ -n "${!VAR}" ] && echo "$VAR: 설정됨" || echo "$VAR: 미설정"
done
```

### 3. Ollama 상태 확인

```bash
# 서비스 실행 여부
pgrep -x ollama && echo "ollama 실행 중" || echo "ollama 미실행"

# 다운로드된 모델 목록
ollama list
```

### 4. OpenClaw 게이트웨이 상태 확인

```bash
openclaw status
openclaw agents list
openclaw agents bindings
```

### 5. 에이전트 워크스페이스 확인

```bash
for AGENT in orchestrator mail calendar drive; do
  WS=~/.openclaw/workspace-${AGENT}
  echo "=== $AGENT ==="
  [ -f "$WS/AGENTS.md" ] && echo "  AGENTS.md: 존재" || echo "  AGENTS.md: 없음"
  ls "$WS/skills/" 2>/dev/null && echo "  skills: 위 목록" || echo "  skills: 없음"
done
```

### 6. openclaw.json 구조 확인 (시크릿 마스킹)

```bash
cat ~/.openclaw/openclaw.json | \
  sed 's/"botToken": "[^"]*"/"botToken": "***"/g' | \
  sed 's/"GOOGLE_[A-Z_]*": "[^"]*"/"GOOGLE_...": "***"/g' | \
  sed 's/"token": "[^"]*"/"token": "***"/g'
```

## 예상 결과 및 확인 방법

정상 상태:
- `.env` 파일 2개 모두 존재
- 환경변수 7개 모두 설정됨
- `ollama list`에 3개 모델 출력 (`$OLLAMA_MODEL`, `$OLLAMA_SUBAGENT_MODEL`, `$OLLAMA_FALLBACK_MODEL`)
- `openclaw agents list`에 4개 에이전트 출력
- `openclaw agents bindings`에 `orchestrator ↔ telegram` 출력

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| `openclaw: command not found` | OpenClaw 미설치 | `npm install -g openclaw` |
| 에이전트 목록 비어있음 | 게이트웨이 미기동 | `openclaw gateway &` |
| `~/.openclaw/.env` 없음 | setup.sh 미실행 | `./setup.sh` 실행 |
| 모델 없음 | Ollama pull 실패 | `ollama pull <모델명>` |
