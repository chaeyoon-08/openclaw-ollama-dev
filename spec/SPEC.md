# SPEC.md — openclaw-ollama-dev 기술 명세

## 에이전트 스펙

### orchestrator

| 항목 | 값 |
|---|---|
| 모델 | `$OLLAMA_MODEL` (기본: `qwen3:32b-q4_K_M`) |
| Fallback 모델 | `$OLLAMA_FALLBACK_MODEL` (기본: `glm-4.7-flash`) |
| 워크스페이스 | `~/.openclaw/workspace-orchestrator/` |
| 허용 서브에이전트 | `mail`, `calendar`, `drive` |
| Telegram 바인딩 | `dmPolicy: open`, `allowFrom: ["*"]` |
| 지침 파일 | `agents/orchestrator/AGENTS.md` |
| 페르소나 파일 | `agents/orchestrator/IDENTITY.md` |

### mail / calendar / drive

| 항목 | 값 |
|---|---|
| 모델 | `$OLLAMA_SUBAGENT_MODEL` (기본: `qwen3:8b`) |
| Fallback 모델 | `$OLLAMA_FALLBACK_MODEL` |
| 서브에이전트 타임아웃 | 120초 (`runTimeoutSeconds`) |
| 연결 Google 계정 | `cy.lim.da@gmail.com` |

---

## MCP 서브에이전트 위임 패턴

orchestrator는 `sessions_spawn` 도구로 전문 에이전트에게 위임한다.

```
sessions_spawn(
  targetAgent: "mail" | "calendar" | "drive",
  message: "구체적인 작업 지시 (한국어)",
  runTimeoutSeconds: 60
)
```

### 단순 요청 (에이전트 1개)

```
사용자: "오늘 메일 요약해줘"
  └─ orchestrator
       └─ sessions_spawn(targetAgent: "mail", message: "오늘 받은 메일 목록 요약해줘")
            └─ mail → Gmail API 호출 → 결과 반환
       └─ orchestrator → Telegram 응답
```

### 복합 요청 (순차 위임)

```
사용자: "김팀장 메일 보고 다음 주 미팅 잡아줘"
  └─ orchestrator
       ├─ 1단계: sessions_spawn(targetAgent: "mail", message: "김팀장 최근 메일 내용 가져와줘")
       │         └─ mail 결과 수신
       └─ 2단계: sessions_spawn(targetAgent: "calendar",
                   message: "김팀장 메일 내용: [1단계 결과]. 다음 주 미팅 등록해줘")
                  └─ calendar 결과 수신
       └─ orchestrator → Telegram 응답 (종합)
```

---

## Google OAuth2 인증 플로우

### 전제 조건

Refresh Token은 Google Cloud Console에서 OAuth2 클라이언트를 생성하고 아래 스코프를 포함해서 발급해야 한다.

### 필요 OAuth 스코프

| 스코프 | 사용 서비스 |
|---|---|
| `https://www.googleapis.com/auth/gmail.readonly` | Gmail 조회·검색 |
| `https://www.googleapis.com/auth/gmail.compose` | Gmail 초안 작성 |
| `https://www.googleapis.com/auth/gmail.send` | Gmail 발송 |
| `https://www.googleapis.com/auth/calendar` | Calendar 전체 읽기·쓰기 |
| `https://www.googleapis.com/auth/drive` | Drive 전체 |
| `https://www.googleapis.com/auth/documents` | Docs 읽기·쓰기 |

### 인증 플로우 (에이전트가 API 호출 시 수행)

**1단계: Access Token 발급**

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

client_id=<GOOGLE_CLIENT_ID>
&client_secret=<GOOGLE_CLIENT_SECRET>
&refresh_token=<GOOGLE_REFRESH_TOKEN>
&grant_type=refresh_token
```

응답:
```json
{
  "access_token": "ya29.xxxx",
  "expires_in": 3599,
  "token_type": "Bearer"
}
```

**2단계: API 호출**

```
GET https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread
Authorization: Bearer ya29.xxxx
```

Access Token은 약 1시간 유효. 에이전트는 API 호출 직전 매번 1단계를 수행해야 한다.

---

## openclaw.json 구조

`setup.sh`가 `~/.openclaw/openclaw.json`에 생성하는 파일의 구조:

```jsonc
{
  "models": {
    "mode": "merge",
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434",
        "apiKey": "ollama-local",
        "api": "ollama",
        "models": [
          // orchestrator 모델, 서브에이전트 모델, fallback 모델 3개 등록
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "compaction": { "mode": "safeguard" },
      "subagents": { "runTimeoutSeconds": 120 }
    },
    "list": [
      {
        "id": "orchestrator",
        "workspace": "~/.openclaw/workspace-orchestrator",
        "model": { "primary": "ollama/<MODEL>", "fallbacks": ["ollama/<FALLBACK>"] },
        "subagents": { "allowAgents": ["mail", "calendar", "drive"] }
      },
      // mail, calendar, drive — 동일 구조, allowAgents 없음
    ]
  },
  "channels": {
    "telegram": {
      "botToken": "<TELEGRAM_BOT_TOKEN>",
      "dmPolicy": "open",
      "allowFrom": ["*"]
    }
  },
  "env": {
    // 모든 에이전트에 주입될 환경변수
    "GOOGLE_CLIENT_ID": "<값>",
    "GOOGLE_CLIENT_SECRET": "<값>",
    "GOOGLE_REFRESH_TOKEN": "<값>"
  },
  "gateway": {
    "mode": "local",
    "auth": { "mode": "token", "token": "<openssl rand -hex 24>" }
  }
}
```

---

## Telegram 봇 동작 스펙

| 항목 | 값 |
|---|---|
| 채널 어댑터 | OpenClaw 내장 Telegram 어댑터 |
| 토큰 저장 위치 | `~/.openclaw/openclaw.json` channels.telegram.botToken |
| DM 정책 | `open` (모든 사용자 허용) |
| allowFrom | `["*"]` |
| 바인딩 에이전트 | `orchestrator` |
| polling/webhook | OpenClaw 내부 처리 (방식 설정 불가) |

---

## 스킬 파일 포맷

`skills/*/SKILL.md`는 YAML frontmatter + Markdown 본문으로 구성된다.

```yaml
---
name: gmail
description: Gmail 읽기·검색·답장 초안 작성 (Google OAuth 필요)
metadata:
  openclaw:
    requires:
      env: [GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN]
    emoji: "📬"
---
```

본문에는 REST 엔드포인트, 요청 형식, 파라미터, 주의사항을 기술한다.
에이전트(LLM)가 이 파일을 읽고 HTTP 요청을 직접 구성한다.
