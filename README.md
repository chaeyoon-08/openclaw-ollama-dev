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

## 환경변수

gcube 워크로드 배포 시 컨테이너 환경변수로 입력:

| 변수명 | 필수 | 기본값 | 설명 |
|--------|------|--------|------|
| `TELEGRAM_BOT_TOKEN` | ✅ | - | BotFather에서 발급한 봇 토큰 |
| `OLLAMA_MODEL` | ❌ | `qwen3:14b` | Ollama 모델명 |
| `ANTHROPIC_API_KEY` | ❌ | - | Claude API 키 |

## 설치 및 실행

```bash
git clone [repo]
cd openclaw-ollama-dev
bash setup.sh
bash setup-agent.sh
bash run.sh
```

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
