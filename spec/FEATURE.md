# FEATURE.md — 기능 추가 가이드

기능을 추가하거나 확장할 때 수정이 필요한 파일과 절차를 안내한다.

---

## 1. 기존 에이전트에 명령어 추가

### 수정 대상 파일

| 파일 | 위치 | 역할 |
|---|---|---|
| `TOOLS.md` | `config/workspace-{agent}/TOOLS.md` | 에이전트가 실제 참조하는 명령어 레퍼런스 |
| `SKILL.md` | `config/workspace-{agent}/skills/gog/SKILL.md` | 에이전트에게 주입되는 gog CLI 사용법 |

두 파일 모두 수정해야 한다. `TOOLS.md`는 에이전트의 행동 지침, `SKILL.md`는 명령어 문법을 담는다.

### 수정 예시: `gog calendar delete` 추가

**`config/workspace-calendar/TOOLS.md`** — 명령어 섹션에 추가:

```markdown
### 일정 삭제
```bash
gog calendar delete <eventId>
```
```

**`config/workspace-calendar/skills/gog/SKILL.md`** — `## gog calendar` 섹션에 추가:

```markdown
# 일정 삭제
gog calendar delete <eventId>
```

### 반영 방법

파일 수정 후 `setup-agent.sh`를 재실행하면 `config/workspace-{agent}/` 전체를
`~/.openclaw/workspace-{agent}/`로 복사해 반영한다.

```bash
bash setup-agent.sh
```

openclaw가 이미 실행 중이라면 재시작해야 새 워크스페이스가 적용된다:

```bash
bash run.sh
```

---

## 2. 새로운 에이전트 추가

### 필요한 파일과 역할

```
config/workspace-{새에이전트}/
  ├── AGENTS.md      # 역할 정의, 사용 도구, 응답 규칙
  └── TOOLS.md       # 사용 가능한 명령어 레퍼런스
```

gog를 사용하는 에이전트라면 SKILL.md도 추가한다:

```
config/workspace-{새에이전트}/
  └── skills/
      └── gog/
          └── SKILL.md   # 해당 에이전트가 쓰는 gog 명령어만 포함
```

### AGENTS.md 작성 예시 (`workspace-contacts`)

```markdown
# AGENTS.md — contacts
# ref: https://docs.openclaw.ai/concepts/agent-workspace

## 역할

Google Contacts 조회 및 관리를 전담한다.
orchestrator로부터 위임받은 작업만 처리한다.

## 사용 도구

`gog contacts` 명령어만 사용한다.
자세한 명령어는 TOOLS.md 참조.

## 응답 규칙

- 응답은 항상 한국어로 작성
- 오류 발생 시 오류 내용과 함께 시도한 명령어를 명시
```

### setup.sh — `agents.list`에 항목 추가

`setup.sh`의 openclaw.json `agents.list` 배열에 아래 항목을 추가한다:

```json
{
  "id": "contacts",
  "workspace": "${OPENCLAW_DIR}/workspace-contacts",
  "model": {
    "primary": "ollama/${OLLAMA_SUBAGENT_MODEL}",
    "fallbacks": ["ollama/${OLLAMA_FALLBACK_MODEL}"]
  }
}
```

### orchestrator 파일 수정

**`config/workspace-orchestrator/AGENTS.md`** — 위임 대상 테이블에 추가:

```markdown
| `contacts` | Google Contacts 조회, 등록, 수정 |
```

위임 규칙에도 추가:

```markdown
- 요청이 연락처에 관한 것이면 → `contacts` 서브에이전트에 위임
```

**`config/workspace-orchestrator/TOOLS.md`** — sessions_spawn 목록에 추가:

```markdown
| `contacts` | Google Contacts 전담 |
```

위임 예시도 추가:

```
sessions_spawn(task="김철수 연락처 찾아줘", agentId="contacts")
```

또한 `setup.sh`의 orchestrator `subagents.allowAgents` 배열에 새 에이전트 ID를 추가해야 한다:

```json
"allowAgents": ["mail", "calendar", "drive", "contacts"]
```

---

## 3. 브라우저 자동화 기능 추가

### setup.sh — Chromium 헤드리스 설치 단계 추가

gogcli 설치(step 4) 이후, OpenClaw 설치(step 5) 이전에 아래 단계를 추가한다:

```bash
# ── 4-1. Chromium 헤드리스 설치 ───────────────────────────
log_doing "Chromium 헤드리스 확인"

if ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null; then
  log_doing "Chromium 설치 중..."
  apt-get install -y chromium-browser -qq \
    || apt-get install -y chromium -qq \
    || log_stop "Chromium 설치 실패"
  log_ok "Chromium 설치 완료"
else
  CHROMIUM_BIN=$(command -v chromium-browser || command -v chromium)
  log_ok "Chromium 이미 설치됨: $($CHROMIUM_BIN --version 2>/dev/null | head -1)"
fi
```

### setup.sh — openclaw.json에 browser 설정 추가

`plugins` 섹션의 `entries`에 아래 항목을 추가한다:

```json
"browser": {
  "enabled": true,
  "headless": true
}
```

결과:

```json
"plugins": {
  "entries": {
    "telegram": { "enabled": true },
    "web-search": { "enabled": true },
    "browser": { "enabled": true, "headless": true }
  }
}
```

### 브라우저 자동화 활용 예시

| 에이전트 | 활용 예 |
|---|---|
| `web` (신규) | URL 입력 → 페이지 내용 추출 → Telegram으로 요약 전달 |
| `mail` | 링크가 포함된 메일 → 링크 페이지 내용을 함께 요약 |
| orchestrator | 뉴스 URL 수집 → 브라우저로 본문 추출 → 브리핑 생성 |

---

## 4. 추가 가능한 기능 아이디어

### 일정 삭제

- 수정 대상: `config/workspace-calendar/TOOLS.md`, `config/workspace-calendar/skills/gog/SKILL.md`
- 추가할 명령어: `gog calendar delete <eventId>`
- 주의: orchestrator AGENTS.md의 "작업 처리 순서 2번"에 따라 삭제 전 사용자 확인 필수

### 메일 라벨 / 보관 처리

- 수정 대상: `config/workspace-mail/TOOLS.md`, `config/workspace-mail/skills/gog/SKILL.md`
- 추가할 명령어: `gog gmail label`, `gog gmail archive`
- gogcli 공식 문서(https://github.com/steipete/gogcli)에서 지원 여부 먼저 확인

### Drive 문서 내용 읽기

- 수정 대상: `config/workspace-drive/TOOLS.md`, `config/workspace-drive/skills/gog/SKILL.md`
- 추가할 명령어: `gog drive read <fileId>` (또는 `gog drive export`)
- Docs/Sheets/Slides 각 포맷별 지원 명령어를 gogcli 문서에서 확인

### 웹 페이지 내용 요약 (web-search 활용)

- `plugins.entries.web-search`가 이미 활성화되어 있으므로 별도 설정 불필요
- orchestrator AGENTS.md에 웹 검색 사용 지침 추가
- 활용 예: "요즘 LLM 동향 요약해줘" → orchestrator가 web-search 도구로 직접 처리

### 뉴스 브리핑 자동화 (HEARTBEAT 활용)

- 수정 대상: `config/workspace-orchestrator/HEARTBEAT.md`
- 현재 HEARTBEAT는 30분 주기로 메일·일정만 체크함
- 아래 단계를 추가하면 뉴스 브리핑 자동화 가능:

```markdown
3. web-search로 관심 키워드(예: "AI 뉴스", "오늘의 날씨") 검색
   - 헤드라인 3개를 요약해서 Telegram으로 전송
   - 실행 주기가 너무 잦으면 검색 API 제한에 걸릴 수 있으므로 1일 1회로 제한
```

- run.sh에서 HEARTBEAT 실행 주기를 조정해 아침 특정 시간에만 실행되도록 변경 가능
