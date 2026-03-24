# openclaw-ollama-dev

Telegram으로 Gmail / Calendar / Drive를 AI가 자동 처리하는 개인 업무 비서.

OpenClaw 멀티에이전트 구조 + Ollama 로컬 모델 기반으로 동작한다. API 비용 없음.

---

## 특징

- **OpenClaw 멀티에이전트** — orchestrator가 요청을 분석하고 전담 서브에이전트에 위임
- **Ollama 로컬 모델** — 외부 API 호출 없음, GPU 성능에 따라 모델 선택 가능
- **gcube GPU 컨테이너** — gcube 워크로드 환경에서 동작
- **Google Workspace 완전 연동** — Gmail, Calendar, Drive 읽기/쓰기 모두 지원

---

## 아키텍처

```
사용자 (Telegram)
    ↓
gcube 외부 HTTPS
    ↓
proxy.js (0.0.0.0:8080)          ← Node.js 내장 http + net, WebSocket 터널 포함
    ↓
openclaw gateway (127.0.0.1:18789)
    ↓
orchestrator (ORCHESTRATOR_MODEL)
  ├── mail      (MAIL_MODEL)      → Gmail
  ├── calendar  (CALENDAR_MODEL)  → Google Calendar
  └── drive     (DRIVE_MODEL)     → Google Drive / Docs / Sheets
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
- 웹 검색 (web-search 플러그인)
- 브라우저 자동화 (Chromium 헤드리스)
- 실행 전 계획 확인 패턴 (모든 요청에 사용자 확인 후 실행)
- 컨테이너 재배포 후 기억 복원

---

## 시작하기

### 사전 준비

- gcube 계정 및 GPU 워크로드 (GPU 메모리 확인 필수 → 아래 모델 가이드 참조)
- Telegram Bot Token (BotFather에서 발급)
- Google Cloud Console OAuth 2.0 설정
  - 필요한 스코프: Gmail, Calendar, Drive
  - OAuth Playground에서 Refresh Token 발급
  - **주의**: Testing 모드에서는 Refresh Token이 **7일마다 만료**됨
    → Google Cloud Console에서 Production 전환 권장

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
| `ORCHESTRATOR_MODEL` | 필수 | orchestrator용 모델 (계획·판단·종합 담당) |
| `MAIL_MODEL` | 필수 | mail 에이전트용 모델 (Gmail 전담) |
| `CALENDAR_MODEL` | 필수 | calendar 에이전트용 모델 (Calendar 전담) |
| `DRIVE_MODEL` | 필수 | drive 에이전트용 모델 (Drive 전담) |
| `FALLBACK_MODEL` | 필수 | 위 모델 실패 시 대체 모델 |
| `DRIVE_MEMORY_FOLDER` | 선택 | MEMORY.md 백업 Drive 폴더명 (기본값: `openclaw-memory`) |

---

## 에이전트별 모델 설정 가이드

**공통 참고사항**
- OpenClaw는 최소 64k 토큰 컨텍스트를 권장함 (공식 문서 기준)
- 14B 미만 모델은 tool calling 불안정 및 hallucination 문제가 발생할 수 있음
- 아래 모델 추천은 커뮤니티 벤치마크 기반이며 공식 권장 목록은 아님

| VRAM | ORCHESTRATOR_MODEL | MAIL/CALENDAR/DRIVE_MODEL | FALLBACK_MODEL |
|---|---|---|---|
| 32GB (RTX 5090 등) | `qwen3.5:27b` | `qwen3:8b` | `qwen3:4b` |
| 24GB (RTX 4090 등) | `qwen3:32b-q4_K_M` | `qwen3:8b` | `qwen3:4b` |
| 16GB | `qwen3:14b-q4_K_M` | `qwen3:8b-q4_K_M` | `qwen3:4b` |
| 8GB | `qwen3:8b` | `qwen3:4b` | `qwen3:4b` |

**예시 (.env)**

```bash
# 24GB VRAM 기준
ORCHESTRATOR_MODEL=qwen3:32b-q4_K_M
MAIL_MODEL=qwen3:8b
CALENDAR_MODEL=qwen3:8b
DRIVE_MODEL=qwen3:8b
FALLBACK_MODEL=qwen3:4b
```

---

## 포트 구조

```
gcube 외부 HTTPS (443)
    → proxy.js (0.0.0.0:8080)
    → openclaw gateway (127.0.0.1:18789)
```

- `proxy.js`는 Node.js 내장 모듈(`http` + `net`)만 사용 — npm install 불필요
- HTTP 일반 요청과 WebSocket Upgrade 요청 모두 처리
- openclaw gateway는 loopback(`127.0.0.1`)에만 바인딩

---

## Google OAuth 설정 방법

1. Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성
2. 필요한 스코프 추가:
   - `https://www.googleapis.com/auth/gmail.modify`
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/drive`
3. OAuth Playground에서 위 스코프로 Refresh Token 발급
4. **주의**: OAuth Consent Screen이 Testing 모드이면 Refresh Token이 7일마다 만료됨
   → Google Cloud Console에서 Production 전환 권장 (개인 사용 앱은 검수 없이 통과)

---

## MEMORY.md 백업 / 복원

에이전트 기억(`MEMORY.md`)을 Drive에 자동으로 백업하고, 컨테이너 재배포 후에도 복원할 수 있다.

**자동 백업**
- 30분마다 HEARTBEAT 실행 시 `DRIVE_MEMORY_FOLDER` 폴더에 자동 업로드

**수동 복원**
1. Telegram에서 "이전 기억 복원해줘" 입력
2. 복원 계획 확인 후 진행
3. `/new` 명령어로 새 세션 시작 → 복원된 기억 반영

컨테이너 재배포 후에도 Drive에서 이전 대화 맥락을 복원할 수 있다.

---

## 프로젝트 구조

```
.
├── setup.sh              # 설치 및 초기 설정 (Ollama, gogcli, OpenClaw, 모델 pull)
├── setup-agent.sh        # 에이전트 워크스페이스 구성 및 Google 연동 확인
├── run.sh                # 서비스 기동
├── proxy.js              # HTTP + WebSocket 프록시 (Node.js 내장 모듈)
├── .env.example          # 환경변수 템플릿
├── config/
│   ├── workspace-orchestrator/  # 오케스트레이터 설정 (AGENTS, SOUL, TOOLS, HEARTBEAT 등)
│   ├── workspace-mail/          # Gmail 에이전트 설정
│   ├── workspace-calendar/      # Calendar 에이전트 설정
│   └── workspace-drive/         # Drive 에이전트 설정
└── spec/
    ├── PRD.md            # 프로젝트 목표
    ├── SPEC.md           # 기술 스펙
    ├── HANDOVER.md       # 검증된 사항 기록
    └── FEATURE.md        # 기능 추가 가이드
```

---

## 운영 가이드

### run.sh 재실행 방법

run.sh를 재실행할 때는 기존 프로세스가 완전히 종료된 후 실행해야 함.
연속으로 바로 실행하면 포트 충돌이 발생할 수 있음.

```bash
# 프로세스 완전 종료
pkill -9 -f openclaw 2>/dev/null; true
pkill -9 -f 'node.*proxy' 2>/dev/null; true
pkill -9 -f 'ollama' 2>/dev/null; true
sleep 5

# 재실행
bash run.sh
```

### Gateway Token 확인

Control UI 접속 시 필요한 토큰 확인 방법:

```bash
# 토큰 확인
python3 -c "import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])"

# alias 등록해두면 편함 (한 번만 설정)
echo "alias octoken=\"python3 -c \\\"import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])\\\"\"" >> ~/.bashrc
source ~/.bashrc
# 이후로는 octoken 입력
```

### Control UI 연결 및 해제

Control UI와 Telegram은 같은 세션을 공유하므로
Control UI Chat 탭에서 메시지를 보내면 Telegram 응답에 영향을 줌.

- **Telegram**: 실제 사용 채널
- **Control UI**: Sessions/Agents/Cron Jobs 모니터링 전용

**Control UI 연결:**
1. gcube 대시보드에서 서비스 URL 확인
2. 브라우저에서 해당 URL 접속
3. Gateway Token 입력 후 Connect
4. 디바이스 승인 확인: `openclaw devices list`

**Control UI 연결 해제:**
```bash
# 연결된 디바이스 목록 확인
openclaw devices list

# 특정 디바이스 해제
openclaw devices revoke --device <deviceId> --role operator
```

**Telegram 연결:**
- run.sh 실행 시 자동으로 연결 유지
- device revoke와 무관하게 동작
- 연결 확인: `openclaw agents bindings`

### 로그 확인

```bash
tail -f ~/.openclaw/gateway.log   # gateway 오류
tail -f ~/.openclaw/ollama.log    # 모델 오류
tail -f ~/.openclaw/proxy.log     # 프록시 오류
```

---

## 참고 문서

- OpenClaw 공식 문서: https://docs.openclaw.ai
- gogcli: https://github.com/steipete/gogcli
- Ollama: https://ollama.ai
