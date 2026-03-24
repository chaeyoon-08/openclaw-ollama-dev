# /agent

setup-agent.sh 와 config/workspace-*/ 파일들을 작성 또는 수정한다.

스펙 참조: @spec/SPEC.md @spec/FEATURE.md @spec/HANDOVER.md

## 작업 순서

1. **~/.openclaw/.env 로드**
   - 파일 없으면 `log_stop` ("먼저 setup.sh 를 실행해 주세요.")
   - `OLLAMA_MODEL`, `OLLAMA_SUBAGENT_MODEL` 필수 검증

2. **워크스페이스 파일 복사**
   - `config/workspace-{agent}/` → `~/.openclaw/workspace-{agent}/` 전체 복사
   - orchestrator는 gog를 직접 실행하지 않으므로 `skills/gog/` 디렉토리가 없음.
     `config/workspace-orchestrator/`에 해당 디렉토리가 존재하지 않으며 복사하지 않는다.
   - mail / calendar / drive는 각자 담당 서비스 명령어만 담긴 `skills/gog/SKILL.md` 포함
   - 파일 없으면 `log_warn`

3. **USER.md 주입** (orchestrator 전용)
   - `~/.openclaw/workspace-orchestrator/USER.md` 생성
   - 내용: `GOOGLE_ACCOUNT` 환경변수로부터 사용자 이메일 기록

4. **DRIVE_MEMORY_FOLDER 확인**
   - `~/.openclaw/.env`에 `DRIVE_MEMORY_FOLDER` 값 존재 여부 확인
   - 없으면 기본값 `openclaw-memory`로 설정 안내

5. **Access Token 테스트**
   - Refresh Token으로 Access Token 발급 시도 (SPEC.md 인증 방식 참조)
   - 성공 시 `log_ok`, 실패 시 `log_warn` (스크립트는 계속 진행)

6. **gog 연동 확인**
   - `GOG_ACCESS_TOKEN` 설정 후 `gog` 명령 실행 가능 여부 확인

7. **openclaw.json 설정 확인**
   - `~/.openclaw/openclaw.json`을 읽어 아래 항목이 올바른지 검증:
     - `agents.list`에 orchestrator, mail, calendar, drive 4개 존재 여부
     - orchestrator의 `subagents.allowAgents`: ["mail", "calendar", "drive"]
     - `channels.telegram.botToken` 값 존재 여부
   - 문제 있으면 `log_warn` 후 수정 방법 안내
   - **gateway 기동은 run.sh에서만 담당** — 이 스크립트에서 gateway를 직접 기동하지 않음

8. **등록 결과 출력**
   - `openclaw agents list`
   - `openclaw agents bindings`

## 로그 스타일

CLAUDE.md의 로그 함수를 사용한다.
