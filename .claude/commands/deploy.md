---
description: GCube 컨테이너 배포 가이드
---

## 목적

openclaw-ollama-dev를 gcube GPU 클라우드 컨테이너에 배포하고 실행한다.

## 사전 조건

- gcube 워크로드에 환경변수 7개 설정 완료
- GPU 인스턴스 접속 가능 (SSH)
- Node.js 18 이상 설치됨

## 실행 절차

### 1단계: 저장소 클론

```bash
git clone <REPO_URL> openclaw-ollama-dev
cd openclaw-ollama-dev
```

### 2단계: 환경변수 확인

gcube 워크로드 환경변수로 주입되는 경우 `.env` 파일 생성이 불필요하다.
환경변수가 shell에 있는지 확인:

```bash
for VAR in TELEGRAM_BOT_TOKEN GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN OLLAMA_MODEL OLLAMA_SUBAGENT_MODEL OLLAMA_FALLBACK_MODEL; do
  [ -n "${!VAR}" ] && echo "$VAR: 설정됨" || echo "$VAR: 미설정 (워크로드 환경변수 확인 필요)"
done
```

환경변수가 없으면:
```bash
cp .env.example .env
# .env 파일에 값 채우기
```

### 3단계: 설치 실행

```bash
chmod +x setup.sh setup-agent.sh
./setup.sh
```

완료 후 `~/.openclaw/openclaw.json`이 생성됐는지 확인:
```bash
[ -f ~/.openclaw/openclaw.json ] && echo "openclaw.json 생성됨" || echo "생성 실패"
```

### 4단계: 에이전트 등록 및 게이트웨이 기동

```bash
./setup-agent.sh
```

### 5단계: 동작 확인

```bash
openclaw status
openclaw agents list
openclaw agents bindings
```

### 6단계: 백그라운드 유지 (컨테이너 재시작 대비)

게이트웨이와 Ollama는 재시작 시 자동으로 기동되지 않는다.
컨테이너 시작 스크립트 또는 systemd 서비스로 등록 필요:

```bash
# 수동 기동 (세션 종료 후에도 유지)
nohup ollama serve > /tmp/ollama.log 2>&1 &
nohup openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
```

## 예상 결과 및 확인 방법

```
openclaw status 출력:
  Gateway: running
  Channels: telegram (connected)

openclaw agents list:
  orchestrator, mail, calendar, drive (4개)

openclaw agents bindings:
  orchestrator ↔ telegram
```

Telegram 봇에 "안녕"을 보내면 orchestrator가 응답.

## 배포 후 유지보수

| 작업 | 명령어 |
|---|---|
| 에이전트 지침 수정 후 반영 | `./setup-agent.sh` 또는 `openclaw gateway restart` |
| 게이트웨이 로그 확인 | `tail -f /tmp/openclaw-gateway.log` |
| 실시간 처리 로그 | `openclaw gateway logs --follow` |
| 전체 현황 대시보드 | `openclaw tui` |
| 모델 추가 | `ollama pull <모델명>` 후 `openclaw.json` 수정 + 재시작 |

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| `npm install -g openclaw` 권한 오류 | 시스템 npm 권한 | `sudo npm install -g openclaw` 또는 nvm 사용 |
| Ollama GPU 미인식 | NVIDIA 드라이버 문제 | `nvidia-smi` 확인, gcube GPU 인스턴스 타입 확인 |
| 모델 다운로드 타임아웃 | 네트워크 속도 또는 모델 크기 | `OLLAMA_FALLBACK_MODEL`로 대체, 이후 재시도 |
| 게이트웨이 포트 충돌 | 이전 프로세스 잔존 | `pkill -f openclaw-gateway && sleep 3 && openclaw gateway &` |
