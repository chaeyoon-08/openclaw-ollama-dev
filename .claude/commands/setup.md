# /setup

setup.sh 를 작성 또는 수정한다.

스펙 참조: @spec/SPEC.md

## 작업 순서

1. **.env 검증**
   - 프로젝트 루트 `.env` 로드 (있을 경우)
   - 필수 변수 확인: `TELEGRAM_BOT_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
     `GOOGLE_REFRESH_TOKEN`, `OLLAMA_MODEL`, `OLLAMA_SUBAGENT_MODEL`, `OLLAMA_FALLBACK_MODEL`
   - 미설정 변수 목록 출력 후 `log_stop` 종료

2. **Node.js 확인**
   - 미설치 또는 18 미만이면 NodeSource 스크립트로 설치:
     ```bash
     curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
     apt-get install -y nodejs
     ```
   - 설치 후 버전 재확인

3. **Ollama 설치**
   - 미설치 시: `curl -fsSL https://ollama.ai/install.sh | sh`
   - 설치됨 시: 버전 출력

4. **gogcli 설치**
   - 미설치 시:
     1. gogcli go.mod에서 요구 Go 버전 확인 → Ubuntu `golang-go`는 버전이 낮아 사용 불가
     2. 공식 Go 바이너리 설치:
        ```bash
        GO_VERSION="1.25.8"   # gogcli go.mod의 go directive에 맞춰 조정
        curl -OL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        ```
     3. 빌드 의존성: `apt-get install -y make build-essential`
     4. `/tmp`에 `https://github.com/steipete/gogcli.git` clone → `make` → `/usr/local/bin/gog` 복사
   - 설치됨 시: 버전 출력

5. **OpenClaw 설치**
   - 미설치 시: `npm install -g openclaw`
   - 설치됨 시: 버전 출력

6. **openclaw.json 생성** (`~/.openclaw/openclaw.json`)
   - `models.providers.ollama`: baseUrl `http://127.0.0.1:11434`, 3개 모델 등록
   - `agents.defaults`: compaction safeguard, runTimeoutSeconds 120
   - `agents.list`: orchestrator(32b), mail(8b), calendar(8b), drive(8b)
     - orchestrator의 `subagents.allowAgents`: ["mail", "calendar", "drive"]
   - `channels.telegram`: botToken, dmPolicy open, allowFrom ["*"]
   - `env`: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN
   - **gateway**: port **18789**, bind **loopback**, trustedProxies ["127.0.0.1"],
     dangerouslyAllowHostHeaderOriginFallback true

7. **~/.openclaw/.env 생성** (chmod 600)
   - Google 인증 정보 + 봇 토큰 + 모델명 기록
   - `printf '%s\n'` 사용 (특수문자 안전)

## 로그 스타일

CLAUDE.md의 로그 함수를 사용한다.
