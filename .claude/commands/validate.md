---
description: 전체 서비스 연동 상태 검증
---

## 목적

설치 완료 후 또는 문제 발생 시 전체 서비스 연동 상태를 빠르게 점검한다.
`validate.md` (루트)의 상세 curl 테스트와 함께 사용한다.

## 사전 조건

- `./setup.sh`와 `./setup-agent.sh` 완료
- 환경변수 7개 모두 설정됨

## 실행 절차

### 체크리스트 실행

```bash
# 환경변수 로드
source ~/.openclaw/.env

echo "=== 인프라 점검 ==="
pgrep -x ollama && echo "[OK] Ollama 실행 중" || echo "[FAIL] Ollama 미실행"
openclaw status 2>/dev/null && echo "[OK] OpenClaw 게이트웨이 실행 중" || echo "[FAIL] 게이트웨이 미실행"
ollama list | grep -q "${OLLAMA_MODEL}" && echo "[OK] 오케스트레이터 모델 존재" || echo "[FAIL] $OLLAMA_MODEL 없음"
ollama list | grep -q "${OLLAMA_SUBAGENT_MODEL}" && echo "[OK] 서브에이전트 모델 존재" || echo "[FAIL] $OLLAMA_SUBAGENT_MODEL 없음"

echo ""
echo "=== 에이전트 점검 ==="
for AGENT in orchestrator mail calendar drive; do
  openclaw agents list 2>/dev/null | grep -q "$AGENT" \
    && echo "[OK] $AGENT 등록됨" \
    || echo "[FAIL] $AGENT 미등록"
done
openclaw agents bindings 2>/dev/null | grep -q "orchestrator" \
  && echo "[OK] orchestrator ↔ Telegram 바인딩" \
  || echo "[FAIL] Telegram 바인딩 없음"

echo ""
echo "=== Google OAuth 점검 ==="
RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${GOOGLE_REFRESH_TOKEN}&grant_type=refresh_token")
echo "$RESPONSE" | grep -q "access_token" \
  && echo "[OK] Refresh Token → Access Token 교환 성공" \
  || echo "[FAIL] OAuth 인증 실패: $(echo $RESPONSE | grep -o '"error":"[^"]*"')"
```

루트의 `validate.md`에서 개별 API 호출 테스트를 진행한다.

## 예상 결과 및 확인 방법

모든 항목이 `[OK]`이면 정상. `[FAIL]` 항목은 아래 트러블슈팅 참고.

## 트러블슈팅

| 증상 | 조치 |
|---|---|
| Ollama 미실행 | `ollama serve &` |
| 게이트웨이 미실행 | `openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &` |
| 에이전트 미등록 | `./setup-agent.sh` 재실행 |
| OAuth 실패 | `.claude/commands/fix-google-auth.md` 실행 |
