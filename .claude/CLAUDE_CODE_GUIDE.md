# CLAUDE_CODE_GUIDE.md — Claude Code 사용 가이드

이 repo에서 Claude Code를 사용하는 개발자를 위한 가이드.

---

## 1. 이 파일의 목적

이 repo는 Claude Code 커맨드(`/setup`, `/agent`, `/run`, `/deploy`, `/validate`)로
스크립트를 작성하고 관리한다.

- `CLAUDE.md`에 정의된 규칙을 Claude Code가 자동으로 따른다
- 개발자는 직접 스크립트를 수정하지 않고 커맨드로 요청한다
- 커맨드 내용은 `.claude/commands/*.md`에 정의되어 있다

---

## 2. 시작 전 필수 확인

```bash
# .env 파일이 없으면 먼저 생성
cp .env.example .env
# .env 파일을 열고 필수 값을 모두 채울 것

# 스크립트 실행 권한 부여
chmod +x setup.sh setup-agent.sh run.sh

# 배포 전 반드시 체크리스트 실행
/deploy
```

---

## 3. 커맨드 목록

| 커맨드 | 역할 | 수정 대상 파일 | 참조 스펙 |
|---|---|---|---|
| `/setup` | `setup.sh` 작성 또는 수정 | `setup.sh` | `spec/SPEC.md` |
| `/agent` | `setup-agent.sh`와 `config/workspace-*/` 파일 작성 또는 수정 | `setup-agent.sh`, `config/workspace-*/` | `spec/SPEC.md`, `spec/FEATURE.md`, `spec/HANDOVER.md` |
| `/run` | `run.sh`와 `proxy.js` 작성 또는 수정 | `run.sh`, `proxy.js` | `spec/SPEC.md`, `spec/HANDOVER.md` |
| `/deploy` | 배포 전 체크리스트 실행 | 없음 (검증만) | `.env`, 스크립트 파일들 |
| `/validate` | 스크립트들이 스펙에 맞게 구현됐는지 검토 | 없음 (검증만) | `spec/SPEC.md` |

---

## 4. 배포 순서

1. `/deploy` 실행 → 체크리스트 확인
2. `.env` 파일 작성 및 `chmod +x` 부여
3. `bash setup.sh` — 의존성 설치 및 openclaw.json 생성
4. `bash setup-agent.sh` — 에이전트 워크스페이스 구성 및 Google 연동 확인
5. `bash run.sh` — 서비스 기동 (Ollama, openclaw gateway, proxy.js)
6. Telegram 봇에 메시지 전송으로 동작 확인

---

## 5. 기능 추가 방법

- **기존 에이전트 기능 확장**: `spec/FEATURE.md` 1번 섹션 참고 후 `/agent` 커맨드로 요청
- **새 에이전트 추가**: `spec/FEATURE.md` 2번 섹션 참고 후 `/agent` + `/setup` 커맨드로 요청
- **수정 후 스펙 준수 여부 확인**: `/validate` 커맨드 실행

예시:
```
/agent calendar 에이전트에 gog calendar delete 명령어를 추가해줘
/validate
```

---

## 6. 문서 동기화 규칙

스크립트를 수정한 경우 아래 문서도 함께 업데이트해야 한다.

| 상황 | 업데이트 대상 |
|---|---|
| 기술 스펙 변경 | `spec/SPEC.md` |
| 검증 완료 사항 추가 | `spec/HANDOVER.md` |
| 커맨드 작업 순서 변경 | `.claude/commands/*.md` |
| 환경변수 추가/변경 | `spec/SPEC.md` 환경변수 테이블, `.env.example` |

---

## 7. CLAUDE.md 핵심 규칙 요약

- **공식 문서 확인 필수** — openclaw(`https://docs.openclaw.ai`), gogcli(`https://github.com/steipete/gogcli`)
- **이모지 금지** — 스크립트 출력에 이모지 사용 금지. ANSI 색상만 사용
- **sh 파일 무단 수정 금지** — 커맨드(`/setup`, `/agent`, `/run`)로 명시적으로 요청된 경우에만 수정
- **로그 함수** — `CLAUDE.md`에 정의된 함수(`log_start`, `log_doing`, `log_ok` 등)만 사용

---

## 8. 로그 확인 명령어

배포 후 문제 발생 시 아래 명령어로 로그를 확인한다.

```bash
tail -f ~/.openclaw/gateway.log
tail -f ~/.openclaw/ollama.log
tail -f ~/.openclaw/proxy.log
```

---

## 9. 자주 겪는 문제

**Q: `.env`를 채웠는데 `setup.sh`가 환경변수를 못 읽어요**

A: `.env` 파일이 repo 루트에 있어야 한다. 파일 권한도 확인한다.
```bash
ls -la .env       # 파일 위치 확인
chmod 600 .env    # 권한 설정
```

---

**Q: openclaw gateway가 안 뜨면?**

A: 로그를 확인하고 포트가 점유 중이면 프로세스를 종료 후 재시도한다.
```bash
tail -f ~/.openclaw/gateway.log
pkill -f openclaw   # 포트 18789 점유 시
bash run.sh
```

---

**Q: Telegram 봇이 응답을 안 하면?**

A: `dmPolicy`가 `open`인지 확인하고 에이전트 등록 여부를 확인한다.
```bash
openclaw agents list
openclaw agents bindings
```
`orchestrator`가 목록에 없으면 `bash setup-agent.sh` 재실행.

---

**Q: MEMORY.md 백업이 안 되면?**

A: `GOG_ACCESS_TOKEN`이 만료됐을 가능성이 높다.
`run.sh`를 재실행하면 토큰이 새로 발급된다.
```bash
bash run.sh
```

---

**Q: 서브에이전트가 호출되지 않으면?**

A: `openclaw.json`에서 orchestrator의 `subagents.allowAgents` 항목을 확인한다.
```bash
cat ~/.openclaw/openclaw.json | python3 -c \
  "import sys,json; c=json.load(sys.stdin); \
   o=next(a for a in c['agents']['list'] if a['id']=='orchestrator'); \
   print(o.get('subagents',{}).get('allowAgents'))"
# 출력: ['mail', 'calendar', 'drive']
```
항목이 없으면 `bash setup.sh` 재실행.
