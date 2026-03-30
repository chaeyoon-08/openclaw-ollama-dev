# openclaw-ollama-dev

Ollama(qwen3:14b) + OpenClaw 기반 리서치 & 자료 제작 AI 비서 Clari

## 기능

- 웹 검색 (DuckDuckGo)
- Word 문서 생성 + Telegram 전송
- Excel 생성 + Telegram 전송
- PPT 생성 (다크/라이트 테마) + Telegram 전송

## 환경

- gcube GPU 컨테이너 (unsloth/unsloth 이미지)
- apt 권한 없음 → Node.js/Ollama 바이너리 직접 설치
- Telegram 봇으로 사용자와 소통

## 사전 준비

1. Telegram 봇 토큰 발급 (@BotFather)
2. Ollama 모델 등록 (파인튜닝 gguf 사용 시):
   ```bash
   ollama create qwen-agent -f Modelfile
   # 또는 공개 모델 사용 시:
   # OLLAMA_MODEL=qwen3:14b 로 설정하면 자동으로 pull
   ```

## 설치 및 실행

```bash
cp .env.example .env
vi .env  # TELEGRAM_BOT_TOKEN, OLLAMA_MODEL 입력
bash setup.sh        # Node.js + Ollama + OpenClaw + Python 패키지 설치
bash setup-agent.sh  # 워크스페이스 + 스킬 설치
bash run.sh          # 서비스 기동
```

## 환경변수

| 변수 | 필수 | 설명 |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | 필수 | BotFather에서 발급한 봇 토큰 |
| `OLLAMA_MODEL` | 필수 | Ollama 모델명 (기본값: `qwen3:14b`) |
| `ANTHROPIC_API_KEY` | 선택 | Claude API 키 |

## Control UI 접속

gateway 실행 후 아래 URL로 Control UI 접속 가능:
- 로컬: http://127.0.0.1:18789/__openclaw__/canvas/
- gcube 서비스 URL: https://[서비스URL]/__openclaw__/canvas/
- 토큰: run.sh 실행 후 출력되는 Gateway Token 사용

## 로그 확인

```bash
tail -f ~/.openclaw/gateway.log
tail -f ~/.openclaw/ollama.log
```

## 서비스 종료

```bash
pkill -f openclaw; pkill -f 'ollama serve'
```

## 참고 문서

- OpenClaw: https://docs.openclaw.ai
- Ollama: https://github.com/ollama/ollama
