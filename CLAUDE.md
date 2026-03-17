# CLAUDE.md — openclaw-ollama-dev

## 프로젝트 개요

Telegram 봇 하나로 Gmail, Google Calendar, Google Drive를 제어하는 AI 업무 비서 시스템.
OpenClaw + Ollama 기반 오케스트레이션 멀티 에이전트 구조. 별도 API 비용 없음.

**핵심 특성: 코드 없는 LLM 지침 레포**
Python/JS 소스코드가 없다. 모든 실행 로직은 npm 글로벌 패키지 `openclaw`가 담당하며,
이 레포는 에이전트 지침(AGENTS.md), 페르소나(IDENTITY.md), API 사용 가이드(SKILL.md),
그리고 설치 스크립트(setup.sh, setup-agent.sh)만 포함한다.

---

## 아키텍처

```
사용자
  └─ Telegram 봇
        └─ orchestrator (클로, qwen3:32b)
              ├─ mail      (메일로, qwen3:8b)  → Gmail API
              ├─ calendar  (캘리,  qwen3:8b)  → Google Calendar API
              └─ drive     (드라이브, qwen3:8b) → Google Drive/Docs API
                                  ↓
                         Ollama (로컬 모델, http://127.0.0.1:11434)
```

에이전트 간 통신: OpenClaw 내장 `sessions_spawn` 도구로 orchestrator → 전문 에이전트 위임.
전문 에이전트끼리는 직접 통신하지 않는다.

---

## 에이전트 역할표

| ID | 페르소나 | 모델 | 역할 |
|---|---|---|---|
| `orchestrator` | 클로 (Claw) | `$OLLAMA_MODEL` (32b) | 요청 분석, 에이전트 위임, 결과 종합, Telegram 수신 |
| `mail` | 메일로 (Mailo) | `$OLLAMA_SUBAGENT_MODEL` (8b) | Gmail 전담 (조회·검색·초안) |
| `calendar` | 캘리 (Cali) | `$OLLAMA_SUBAGENT_MODEL` (8b) | Google Calendar 전담 (조회·등록·수정·삭제) |
| `drive` | 드라이브 (Drive) | `$OLLAMA_SUBAGENT_MODEL` (8b) | Google Drive/Docs/Sheets/Slides 전담 |

---

## OpenClaw 동작 원리

에이전트는 LLM이 SKILL.md를 읽고 직접 REST 요청을 구성하는 방식으로 동작한다.
별도 Google 클라이언트 라이브러리(google-api-python-client 등)를 사용하지 않는다.

```
에이전트 워크스페이스 (예: ~/.openclaw/workspace-mail/)
  ├── AGENTS.md       ← 에이전트 지침 (역할, 제약, 보안 규칙)
  └── skills/
      └── gmail/
          └── SKILL.md ← REST API 엔드포인트 가이드 (LLM이 읽고 HTTP 요청 생성)
```

Google API 호출 순서:
1. `POST https://oauth2.googleapis.com/token` (Refresh Token → Access Token 교환)
2. `Authorization: Bearer <access_token>` 헤더로 실제 API 호출

이 흐름을 LLM이 SKILL.md를 참고해 직접 수행한다.

---

## 환경변수 목록

| 변수 | 필수 | 설명 |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | 필수 | BotFather에서 발급한 Telegram 봇 토큰 |
| `GOOGLE_CLIENT_ID` | 필수 | Google Cloud Console OAuth 2.0 클라이언트 ID |
| `GOOGLE_CLIENT_SECRET` | 필수 | Google Cloud Console OAuth 2.0 클라이언트 시크릿 |
| `GOOGLE_REFRESH_TOKEN` | 필수 | Google OAuth 인증 후 발급된 Refresh Token |
| `OLLAMA_MODEL` | 필수 | 오케스트레이터용 모델 (예: `qwen3:32b-q4_K_M`) |
| `OLLAMA_SUBAGENT_MODEL` | 필수 | 서브에이전트용 모델 (예: `qwen3:8b`) |
| `OLLAMA_FALLBACK_MODEL` | 필수 | 기본 모델 실패 시 대체 모델 (예: `glm-4.7-flash`) |

설정 방법: 프로젝트 루트에 `.env` 파일 생성 (`.env.example` 참고).

---

## 실행 순서

```bash
# 1. 환경변수 설정
cp .env.example .env
# .env 파일에 값 채우기

# 2. 기본 설치 (Ollama + OpenClaw + 모델 다운로드 + openclaw.json 생성)
chmod +x setup.sh setup-agent.sh
./setup.sh

# 3. 에이전트 등록 + 게이트웨이 기동 + Telegram 바인딩
./setup-agent.sh
```

런타임 파일은 `~/.openclaw/`에 생성된다. 이 디렉터리는 git에 포함되지 않는다.

---

## Claude Code 작업 시 주의사항

- **소스코드 없음**: Python/JS 파일이 없으므로 코드 수정 작업은 해당 없음.
- **수정 대상**: `agents/*/AGENTS.md`, `agents/*/IDENTITY.md`, `skills/*/SKILL.md`, `setup.sh`, `setup-agent.sh`.
- **재배포 필요**: 지침 파일 수정 후에는 `setup-agent.sh`를 다시 실행하거나 `openclaw gateway restart`로 반영.
- **시크릿 노출 금지**: `.env` 파일은 git에 커밋하지 않는다. `.gitignore` 확인 필수.
- **Google 인증 미작동**: 현재 Google API 연동이 미완성 상태. `SPEC.md`의 OAuth 플로우 및 `validate.md`의 테스트 절차 참고.
- **openclaw.json 직접 수정 금지**: `~/.openclaw/openclaw.json`은 `setup.sh`가 생성하는 파일. 직접 수정보다는 스크립트를 수정해서 재실행할 것.
