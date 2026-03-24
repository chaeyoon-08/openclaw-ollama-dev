# /deploy

gcube 배포 전 체크리스트를 확인한다.

## 체크리스트

### .env 항목 누락 여부
프로젝트 루트 `.env` 파일을 읽고 아래 항목이 모두 설정되어 있는지 확인:
- [ ] `TELEGRAM_BOT_TOKEN` — 값 있음
- [ ] `GOOGLE_CLIENT_ID` — 값 있음
- [ ] `GOOGLE_CLIENT_SECRET` — 값 있음
- [ ] `GOOGLE_REFRESH_TOKEN` — 값 있음
- [ ] `GOOGLE_ACCOUNT` — 값 있음
- [ ] `ORCHESTRATOR_MODEL` — 값 있음
- [ ] `MAIL_MODEL` — 값 있음
- [ ] `CALENDAR_MODEL` — 값 있음
- [ ] `DRIVE_MODEL` — 값 있음
- [ ] `FALLBACK_MODEL` — 값 있음
- [ ] `DRIVE_MEMORY_FOLDER` — 값 있음 (없으면 기본값 `openclaw-memory` 사용)

### 포트 설정
- [ ] `proxy.js` 존재 여부
- [ ] proxy.js 내 `0.0.0.0:8080` → `127.0.0.1:18789` 포워딩 설정
- [ ] `~/.openclaw/openclaw.json` gateway.port가 `18789`인지 확인

### 모델 이름
- [ ] `ORCHESTRATOR_MODEL` 값이 `ollama list` 출력에 존재하는지 확인
- [ ] `MAIL_MODEL` 값이 `ollama list` 출력에 존재하는지 확인
- [ ] `CALENDAR_MODEL` 값이 `ollama list` 출력에 존재하는지 확인
- [ ] `DRIVE_MODEL` 값이 `ollama list` 출력에 존재하는지 확인
- [ ] `FALLBACK_MODEL` 값이 `ollama list` 출력에 존재하는지 확인

### Google OAuth 상태
- [ ] Refresh Token으로 Access Token 발급 테스트
- [ ] Google Cloud Console OAuth Consent Screen 상태 확인 안내
  - Testing 모드: Refresh Token 7일마다 만료 (spec/HANDOVER.md 참조)
  - Production 전환 권장

### 스크립트 파일
- [ ] `setup.sh` 존재 및 실행 권한 (`chmod +x`)
- [ ] `setup-agent.sh` 존재 및 실행 권한
- [ ] `run.sh` 존재 및 실행 권한

## 출력 형식

각 항목을 순서대로 확인하고 결과를 출력한다.
실패 항목은 수정 방법을 함께 안내한다.
모든 항목 통과 시 배포 준비 완료 메시지를 출력한다.
