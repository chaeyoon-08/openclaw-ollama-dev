# HANDOVER — 검증된 사항 기록

Claude Code 세션 간 컨텍스트 유지를 위한 핸드오버 문서.
실제 테스트를 통해 확인된 사항만 기록한다.

---

## 검증 완료 항목

### proxy.js WebSocket 터널

- gcube 환경에서 proxy.js WebSocket 터널 실제 테스트 완료
- gcube는 외부 HTTPS → 내부 HTTP로 전달 (`x-forwarded-proto: http`)
- WebSocket Upgrade 요청이 컨테이너까지 정상 전달됨을 확인
- 구현: `http` 모듈로 일반 요청 프록시, `net` 모듈로 CONNECT 터널 처리

### openclaw 페어링

- `openclaw devices approve`로 원격 브라우저 페어링 성공 확인
- gcube URL(배포마다 변경)로 Control UI 접근 후 페어링 정상 동작

### GOG_ACCESS_TOKEN 인증 방식

- gogcli v0.12.0 기준 `GOG_ACCESS_TOKEN` 환경변수가 공식 지원됨을 확인
- Refresh Token → curl → Access Token 발급 방식 동작 확인
- 55분 갱신 주기 정상 동작 확인

### dangerouslyAllowHostHeaderOriginFallback

- gcube URL이 배포마다 바뀌어 `allowedOrigins` 고정 불가
- 개인 사용 환경이므로 `dangerouslyAllowHostHeaderOriginFallback: true` 허용
- 보안 위험 인지 후 의도적으로 설정한 값임

### 응답 품질 개선 (2026-03-24)

- `SOUL.md` 금지 섹션 전면 강화:
  언어 혼용 금지, 반복 금지, 불필요한 설명 금지, 맥락 이탈 금지, 허위 보고 금지
- orchestrator `AGENTS.md`: 서브에이전트 미호출 결과 생성 금지, 빈 결과 처리 규칙 추가
- 서브에이전트 3개 `AGENTS.md`: 허위 보고 방지 규칙 추가
- 주의: 미실행 보고, 없는 내용 브리핑 문제는 로컬 소형 모델의 hallucination 한계이기도 함.
  `ORCHESTRATOR_MODEL`을 32b 이상 또는 API 모델로 설정 시 크게 개선됨.

### Drive MEMORY.md 백업/복원 (2026-03-24)

- HEARTBEAT에 30분마다 MEMORY.md → Drive 자동 백업 추가
- 백업 폴더: `DRIVE_MEMORY_FOLDER` 환경변수 (기본값: `openclaw-memory`)
- 복원 플로우: 사용자 요청 → 확인 → drive 에이전트가 내용 반환
  → exec으로 로컬 MEMORY.md 덮어쓰기 → `/new`로 새 세션 시작
- 컨테이너 재배포 후에도 Drive에서 이전 기억 복원 가능

### 환경변수 세분화 (2026-03-24)

- `OLLAMA_MODEL` → `ORCHESTRATOR_MODEL`
- `OLLAMA_SUBAGENT_MODEL` → `MAIL_MODEL` / `CALENDAR_MODEL` / `DRIVE_MODEL` (에이전트별 분리)
- `OLLAMA_FALLBACK_MODEL` → `FALLBACK_MODEL`
- 중복 모델은 pull 및 json 등록 시 한 번만 처리되도록 중복 제거 로직 추가

### 5단계~6단계 수정 사항 (2026-03-24)

- Chromium 헤드리스 설치 단계 추가 (`setup.sh` step 4-1)
  `chromium-browser` 먼저 시도, 실패 시 `chromium` 재시도
- `plugins`에 `browser: { enabled: true, config: { headless: true } }` 추가
- orchestrator `SOUL.md`: 확인 원칙 섹션 추가
  모든 요청에 대해 실행 전 계획 보고 및 사용자 확인 필수
- orchestrator `AGENTS.md`: 작업 처리 순서 2번 항목 수정
  기존 "불가역적·복합적인 경우에만" → "모든 요청에 예외 없이 적용"으로 변경

### 1단계~4단계 수정 사항 (2026-03-24)

- 모델 ID: `models.providers.ollama.models`의 `id`에서 `ollama/` prefix 제거
  (`agents.list`의 `model.primary` / `model.fallbacks` 참조값은 `ollama/` prefix 유지)
- `contextWindow: 32768`, `maxTokens: 8192` 세 모델 모두 추가
- `setup.sh`에 Ollama 모델 pull 단계 추가 (모델 존재 시 건너뜀)
- `SKILL.md`: 각 서브에이전트가 담당 서비스 명령어만 포함하도록 분리.
  `orchestrator`의 `skills/gog/` 디렉토리 삭제
- `plugins`: `telegram`, `web-search` 활성화 추가
- `orchestrator` AGENTS.md: "작업 처리 순서" 섹션 추가
  (분석 → 계획 수립 및 사용자 확인 → 순차 실행 → 결과 종합 및 보고)

---

## 미해결 / 주의 사항

### OAuth Consent Screen — Testing 모드

- 현재 Google Cloud Console에서 OAuth Consent Screen이 **Testing** 상태
- Testing 모드에서는 Refresh Token이 **7일마다 만료**됨
- 7일마다 재인증(새 Refresh Token 발급) 필요
- 해결 방법: Google Cloud Console → OAuth Consent Screen → **Production** 전환
  - Production 전환 시 Google 검수 필요 (개인 사용 앱은 보통 통과)

---

## 주요 설정값 요약

| 항목 | 값 | 비고 |
|---|---|---|
| openclaw gateway 포트 | 18789 | loopback only |
| proxy.js 포트 | 8080 | 0.0.0.0 바인딩 |
| Access Token 갱신 주기 | 55분 | Google 토큰 1시간 만료 기준 |
| 재시도 횟수 | 최대 3회 | 갱신 실패 시 |
