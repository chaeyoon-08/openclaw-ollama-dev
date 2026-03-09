# openclaw-ollama-dev

**AI 업무 비서팀** — Telegram 봇 하나로 Gmail·Google Calendar·Google Drive를 AI가 처리합니다.

OpenClaw + Ollama 기반 오케스트레이션 멀티 에이전트 구조.  
별도 API 비용 없이 gcube GPU 클라우드에서 로컬 AI 모델을 실행합니다.

---

## 아키텍처

```
사용자
  └→ Telegram 봇 (1개)
        └→ 오케스트레이터 에이전트
              ├→ 메일 에이전트    → Gmail API
              ├→ 일정 에이전트    → Google Calendar API
              └→ 문서 에이전트    → Google Drive/Docs API
                        ↓
               Ollama (로컬 모델)
              qwen3-coder:32b
```

오케스트레이터가 요청을 분석하고, 필요한 전문가 에이전트에게 `sessions_spawn`으로 위임합니다.  
복합 요청도 단일 대화로 처리됩니다.

---

## 파일 구조

```
├── setup.sh                         # 1단계: Ollama + OpenClaw 설치
├── setup-agent.sh                   # 2단계: 에이전트 4개 등록
│
├── agents/
│   ├── orchestrator/AGENTS.md       # 오케스트레이터 지침 (위임 로직)
│   ├── mail/AGENTS.md               # 메일 에이전트 지침
│   ├── calendar/AGENTS.md           # 일정 에이전트 지침
│   └── drive/AGENTS.md              # 문서 에이전트 지침
│
└── skills/
    ├── gmail/SKILL.md               # Gmail API 사용법
    ├── calendar/SKILL.md            # Calendar API 사용법
    └── drive/SKILL.md               # Drive/Docs API 사용법
```

---

## 사전 준비

### 1. Telegram 봇 생성 (1개)

[@BotFather](https://t.me/BotFather)에서 봇 1개를 생성하고 토큰을 발급받으세요.

### 2. Google OAuth 설정

Google Cloud Console에서 OAuth 2.0 클라이언트를 생성하고 아래 API를 활성화하세요:
- Gmail API
- Google Calendar API
- Google Drive API
- Google Docs API

Refresh Token 발급: [구글 OAuth 2.0 가이드](https://developers.google.com/identity/protocols/oauth2)

### 3. 필수 환경변수

| 변수명 | 설명 |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram BotFather에서 발급 |
| `GOOGLE_CLIENT_ID` | Google Cloud Console에서 발급 |
| `GOOGLE_CLIENT_SECRET` | Google Cloud Console에서 발급 |
| `GOOGLE_REFRESH_TOKEN` | OAuth 인증 후 발급 |
| `GITHUB_TOKEN` | GitHub Personal Access Token |
| `GITHUB_USER_EMAIL` | GitHub 계정 이메일 |
| `GITHUB_USER_NAME` | GitHub 계정 이름 (실명, `git log`에 표시됨) |
| `GITHUB_LOGIN` | GitHub 로그인 아이디 (공백 없음, 예: `johndoe`) |
| `OLLAMA_MODEL` | (선택) 기본값: `qwen3-coder:32b` |
| `OLLAMA_FALLBACK_MODEL` | (선택) 기본값: `glm-4.7` |

---

## 설치 및 실행

```bash
# 1. 저장소 클론
git clone https://github.com/your-org/openclaw-ollama-dev.git
cd openclaw-ollama-dev

# 2. 환경변수 설정
export TELEGRAM_BOT_TOKEN="your-bot-token"
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export GOOGLE_REFRESH_TOKEN="your-refresh-token"
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER_EMAIL="your@email.com"
export GITHUB_USER_NAME="Your Name"
export GITHUB_LOGIN="your-github-id"

# 3. 실행 권한 부여
chmod +x setup.sh setup-agent.sh

# 4. 기본 설치 (Ollama + OpenClaw + 모델 다운로드)
./setup.sh

# 5. 에이전트 등록
./setup-agent.sh
```

---

## 사용법

Telegram 봇에 자연어로 메시지를 보내면 됩니다.

| 요청 예시 | 처리 흐름 |
|---|---|
| "안 읽은 메일 요약해줘" | → 메일 에이전트 |
| "오늘 일정 알려줘" | → 일정 에이전트 |
| "Q3 보고서 파일 찾아줘" | → 문서 에이전트 |
| "김팀장 메일 보고 다음 주 미팅 잡아줘" | → 메일 → 일정 순차 처리 |

---

## 런타임 모니터링

```bash
openclaw tui                    # 터미널 대시보드 (전체 현황)
openclaw gateway logs --follow  # 실시간 처리 로그
openclaw status                 # 게이트웨이·채널 상태 요약
openclaw agents list            # 등록된 에이전트 확인
openclaw agents bindings        # 봇↔에이전트 연결 확인
```

> 에이전트가 API를 호출하는 과정은 화면에 별도 창이 뜨지 않습니다.  
> Gmail·Calendar·Drive는 백그라운드에서 REST API로 처리되며,  
> `gateway logs --follow`로 실시간 처리 흐름을 텍스트 로그로 확인할 수 있습니다.

---

## 에이전트 커스터마이징

`agents/<이름>/AGENTS.md` 파일을 수정해서 각 에이전트의 동작 방식을 변경할 수 있습니다.

```bash
# 수정 후 게이트웨이 재시작
openclaw gateway restart
```

---

## 권장 모델

| 모델 | VRAM | 특징 |
|---|---|---|
| `qwen3-coder:32b` | 24~32GB | Tool calling 안정성 최고, 기본값 |
| `glm-4.7` | 24~32GB | 범용성 우수, fallback용 |

---

## 관련 레포

| 레포 | 설명 |
|---|---|
| openclaw-ollama-dev | 이 레포 — Ollama 로컬 모델 스크립트 설치 버전 |
| [openclaw-ollama-image](https://github.com/your-org/openclaw-ollama-image) | Ollama 버전 Docker 이미지 |
| [openclaw-api-dev](https://github.com/your-org/openclaw-api-dev) | 외부 API(Claude/GPT-4o/Gemini) 버전 스크립트 설치 |
| [openclaw-api-image](https://github.com/your-org/openclaw-api-image) | 외부 API 버전 Docker 이미지 |

---

## 라이선스

MIT