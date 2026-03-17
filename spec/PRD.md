# PRD — openclaw-ollama-dev

## 제품 목표

Telegram 메시지 하나로 Gmail, Google Calendar, Google Drive를 AI가 처리하는 개인 AI 업무 비서.
외부 API 비용 없이 gcube GPU 클라우드에서 로컬 모델(Ollama)로 동작한다.

---

## 현재 상태

### 작동 확인

| 기능 | 상태 | 비고 |
|---|---|---|
| Telegram 메시지 수신 | 작동 | orchestrator 바인딩 완료 |
| OpenClaw 게이트웨이 기동 | 작동 | `openclaw gateway` |
| Ollama 모델 서빙 | 작동 | `http://127.0.0.1:11434` |
| orchestrator → 서브에이전트 위임 | 작동 | `sessions_spawn` |
| Telegram 응답 반환 | 작동 | orchestrator → Telegram |

### 미완성 기능

| 기능 | 상태 | 원인 |
|---|---|---|
| Gmail 조회/검색 | 미작동 | Google OAuth Access Token 교환 로직 누락 |
| Gmail 초안 작성 | 미작동 | 동일 |
| Google Calendar 조회 | 미작동 | 동일 |
| Google Calendar 등록/수정/삭제 | 미작동 | 동일 |
| Google Drive 파일 검색 | 미작동 | 동일 |
| Google Docs 읽기/쓰기 | 미작동 | 동일 |

**근본 원인**: SKILL.md에 Refresh Token → Access Token 교환 절차가 문서화되어 있지 않아 LLM이 인증 단계를 수행하지 못함. `SPEC.md` OAuth 플로우 섹션 참고.

---

## 우선순위 로드맵

### Phase 1: Google 인증 해결 (현재 블로커)

- [ ] SKILL.md 3개에 OAuth2 토큰 교환 절차 추가
  - `POST https://oauth2.googleapis.com/token` 요청 형식
  - `access_token` 추출 및 `Authorization: Bearer` 헤더 사용법
- [ ] Refresh Token 발급 시 필요한 스코프 목록 명시 (README + SPEC.md)
- [ ] `validate.md`의 curl 명령어로 인증 동작 검증

### Phase 2: Slack 채널 추가

- [ ] `openclaw.json`의 `channels` 섹션에 Slack 어댑터 추가
- [ ] `setup.sh`에 `SLACK_BOT_TOKEN` 환경변수 처리 추가
- [ ] orchestrator를 Slack 채널에도 바인딩

### Phase 3: 다중 모델 지원

- [ ] 에이전트별 모델을 태스크 복잡도에 따라 동적으로 선택
- [ ] 모델 성능 비교 (qwen3:32b vs glm-4.7 vs 기타)
- [ ] 비용/속도 트레이드오프 문서화

---

## 사용 시나리오

| 요청 예시 | 처리 흐름 |
|---|---|
| "안 읽은 메일 요약해줘" | orchestrator → mail |
| "오늘 일정 알려줘" | orchestrator → calendar |
| "Q3 보고서 파일 찾아줘" | orchestrator → drive |
| "김팀장 메일 보고 다음 주 미팅 잡아줘" | orchestrator → mail → calendar (순차) |

---

## 비기능 요구사항

| 항목 | 요구사항 |
|---|---|
| 응답 언어 | 한국어 |
| 서브에이전트 타임아웃 | 120초 |
| 되돌릴 수 없는 작업 | 사용자 확인 필수 (발송, 삭제) |
| 보안 | 프롬프트 인젝션 방어 (메일/문서 본문 지시사항 무시) |
| 시크릿 관리 | `~/.openclaw/.env` (chmod 600) |
