# openclaw-ollama-dev

Telegram으로 Gmail / Calendar / Drive를 AI가 자동 처리하는 개인 업무 비서.

OpenClaw + Ollama 로컬 모델 기반으로 동작한다. API 비용 없음.

---

## 특징

- OpenClaw 에이전트 — orchestrator가 Gmail / Calendar / Drive 작업을 직접 처리
- Ollama 로컬 모델 — 외부 API 호출 없음, GPU 성능에 따라 모델 선택 가능
- gcube GPU 컨테이너 — gcube 워크로드 환경에서 동작
- Google Workspace 완전 연동 — Gmail, Calendar, Drive 읽기/쓰기 모두 지원

---

## 아키텍처

```
사용자 (Telegram)
    ↓
gcube 외부 HTTPS (자동 매핑)
    ↓
openclaw gateway (127.0.0.1:18789)
    ↓
orchestrator (ORCHESTRATOR_MODEL)
    → Gmail / Google Calendar / Google Drive
```

---

## 주요 기능

### Gmail
- 메일 조회 / 검색
- 메일 전송 / 답장 / 초안 작성
- 라벨 지정 / 보관 / 휴지통 처리

### Google Calendar
- 일정 조회 / 등록 / 수정 / 삭제

### Google Drive
- 파일 검색 / 업로드 / 다운로드
- 문서 내용 읽기 (Docs, Sheets, Slides)
- MEMORY.md 자동 백업 / 복원

### 자동화 (30분 주기 HEARTBEAT)
- 미읽은 중요 메일 알림
- 오늘 남은 일정 알림
- MEMORY.md → Drive 자동 백업
- Telegram에서 자동화 목록 확인 / 추가 / 제거

### 기타
- 웹 검색 (duckduckgo 플러그인)
- 실행 전 계획 확인 패턴 (모든 요청에 사용자 확인 후 실행)
- 컨테이너 재배포 후 기억 복원

---

## 시작하기

### 사전 준비

- gcube 계정 및 GPU 워크로드
- Telegram Bot Token (BotFather에서 발급)
- Google Cloud Console OAuth 2.0 설정 (아래 Google OAuth 설정 방법 참조)

### setup.sh 실행 주의사항

- root 권한 필요 (gcube 컨테이너는 기본 root이므로 별도 sudo 불필요)
- 실행 전 .env 파일 필수 (.env.example 복사 후 편집)
- qwen3.5:35b 모델 pull에 시간 소요 (약 24GB)

### 설치 및 실행

```bash
git clone <repo>
cp .env.example .env
# .env 파일 편집 (필수 환경변수 입력)

bash setup.sh        # 설치 및 초기 설정 (Ollama, gogcli, OpenClaw, 모델 pull 포함)
bash setup-agent.sh  # 에이전트 워크스페이스 구성 및 Google 연동 확인
bash run.sh          # 서비스 기동
```

---

## 환경변수

| 변수 | 필수 | 설명 |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | 필수 | BotFather에서 발급한 봇 토큰 |
| `GOOGLE_CLIENT_ID` | 필수 | Google Cloud Console OAuth 2.0 클라이언트 ID |
| `GOOGLE_CLIENT_SECRET` | 필수 | Google Cloud Console OAuth 2.0 클라이언트 시크릿 |
| `GOOGLE_REFRESH_TOKEN` | 필수 | Google OAuth Refresh Token |
| `GOOGLE_ACCOUNT` | 필수 | Google 계정 이메일 |
| `ORCHESTRATOR_MODEL` | 필수 | orchestrator용 모델 (모든 Google 작업 직접 처리) |
| `FALLBACK_MODEL` | 필수 | orchestrator 실패 시 대체 모델 |
| `DRIVE_MEMORY_FOLDER` | 선택 | MEMORY.md 백업 Drive 폴더명 (기본값: `openclaw-memory`) |

---

## 모델 설정 가이드

**공통 참고사항**
- OpenClaw는 최소 64k 토큰 컨텍스트를 권장함 (공식 문서 기준)
- 14B 미만 모델은 tool calling 불안정 및 hallucination 문제가 발생할 수 있음
- 아래 모델 추천은 커뮤니티 벤치마크 기반이며 공식 권장 목록은 아님

| VRAM | ORCHESTRATOR_MODEL | FALLBACK_MODEL |
|---|---|---|
| 48GB 이상 | `qwen3.5:35b` | `qwen3:4b` |
| 32GB (RTX 5090 등) | `qwen3.5:27b` | `qwen3:4b` |
| 24GB (RTX 4090 등) | `qwen3:32b-q4_K_M` | `qwen3:4b` |
| 16GB | `qwen3:14b-q4_K_M` | `qwen3:4b` |
| 8GB | `qwen3:8b` | `qwen3:4b` |

**예시 (.env)**

```bash
# 기본값
ORCHESTRATOR_MODEL=qwen3.5:35b
FALLBACK_MODEL=qwen3:4b
```

---

## 포트 구조

```
사용자 (Telegram)
    ↓
gcube 외부 HTTPS (자동 매핑)
    ↓
openclaw gateway (127.0.0.1:18789)
```

openclaw gateway는 loopback(`127.0.0.1`)에만 바인딩.
gcube의 포트 포워딩으로 외부에서 접근 가능.

---

## Google OAuth 설정 방법

### 1. Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성

1. Google Cloud Console → APIs & Services → Credentials
2. "Create Credentials" → "OAuth 2.0 Client ID"
3. Application type: Web application

### 2. OAuth Consent Screen Production 전환

**중요**: Testing 모드에서는 Refresh Token이 7일마다 만료된다.
Production 전환을 하지 않으면 매주 재인증이 필요하다.

1. Google Cloud Console → APIs & Services → OAuth consent screen
2. "PUBLISH APP" 클릭 → Production으로 전환
3. 개인 사용 앱은 Google 검수 없이 즉시 통과됨

### 3. 필요한 스코프

- `https://www.googleapis.com/auth/gmail.modify`
- `https://www.googleapis.com/auth/calendar`
- `https://www.googleapis.com/auth/drive`

### 4. OAuth Playground에서 Refresh Token 발급

1. https://developers.google.com/oauthplayground 접속
2. 우측 상단 설정 아이콘 클릭 → "Use your own OAuth credentials" 체크
3. Client ID / Client Secret 입력
4. 위 3개 스코프 선택 후 "Authorize APIs" 클릭
5. "Exchange authorization code for tokens" 클릭
6. Refresh Token 복사 → .env의 `GOOGLE_REFRESH_TOKEN`에 입력

---

## MEMORY.md 백업 / 복원

에이전트 기억(`MEMORY.md`)을 Drive에 자동으로 백업하고, 컨테이너 재배포 후에도 복원할 수 있다.

**자동 백업**
- 30분마다 Drive 루트에 자동 업로드

**수동 복원**
1. Telegram에서 "이전 기억 복원해줘" 입력
2. 복원 계획 확인 후 진행
3. `/new` 명령어로 새 세션 시작 → 복원된 기억 반영

---

## 운영 가이드

### run.sh 재실행 방법

재실행 전 기존 프로세스를 완전히 종료해야 한다.
연속으로 바로 실행하면 포트 충돌이 발생할 수 있다.

포트 충돌 증상: "Address already in use" 에러

```bash
# 프로세스 완전 종료
pkill -9 -f openclaw 2>/dev/null; true
pkill -9 -f 'ollama' 2>/dev/null; true

# 최소 5초 대기 후 재실행
sleep 5
bash run.sh
```

### Telegram 봇 연결 확인

run.sh 실행 후 Telegram에서 봇에 메시지를 보내면 된다.

응답이 없을 경우 확인 순서:
1. `tail -f ~/.openclaw/gateway.log` — gateway 에러 확인
2. `tail -f ~/.openclaw/ollama.log` — 모델 로딩 확인
3. TELEGRAM_BOT_TOKEN이 올바른지 확인

### Gateway Token 확인

Control UI 접속 시 필요한 토큰 확인 방법:

```bash
python3 -c "import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])"
```

### Control UI 안내

Control UI와 Telegram은 같은 에이전트 세션을 공유한다.
Control UI Chat 탭에서 메시지를 보내면 Telegram과 동일 세션으로 들어가 대화 흐름이 섞일 수 있다.

- Control UI: Sessions / Cron / Skills 모니터링 전용으로 사용 권장
- Telegram: 실제 업무 요청 채널

Control UI 연결:
1. gcube 대시보드에서 서비스 URL 확인
2. 브라우저에서 해당 URL 접속
3. Gateway Token 입력 후 Connect
4. 디바이스 승인: `openclaw devices list` → `openclaw devices approve <requestId>`

### 로그 확인

```bash
tail -f ~/.openclaw/gateway.log   # gateway 오류
tail -f ~/.openclaw/ollama.log    # 모델 오류
```

---

## 프로젝트 구조

```
.
├── setup.sh
├── setup-agent.sh
├── run.sh
├── .env.example
├── config/
│   └── workspace-orchestrator/
│       ├── AGENTS.md
│       ├── SOUL.md
│       ├── TOOLS.md
│       ├── HEARTBEAT.md
│       ├── USER.md
│       └── skills/
│           ├── gmail/SKILL.md
│           ├── calendar/SKILL.md
│           └── drive/SKILL.md
└── spec/
    ├── PRD.md
    ├── SPEC.md
    ├── HANDOVER.md
    └── FEATURE.md
```

---

## 참고 문서

- OpenClaw 공식 문서: https://docs.openclaw.ai
- gogcli: https://github.com/steipete/gogcli
- Ollama: https://ollama.ai
