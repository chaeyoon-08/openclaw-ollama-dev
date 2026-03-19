# /validate

작성된 스크립트들이 스펙에 맞게 구현됐는지 검토한다.

스펙 참조: @spec/SPEC.md

## 확인 항목

### 로그 스타일
- [ ] 이모지 없음
- [ ] ANSI 색상 함수 사용 (`log_start`, `log_doing`, `log_ok`, `log_warn`, `log_error`, `log_stop`, `log_done`, `log_next`)
- [ ] 함수 미선언 시 지적

### 포트 구조
- [ ] proxy.js: `0.0.0.0:8080` 바인딩
- [ ] proxy.js: `127.0.0.1:18789` 로 포워딩
- [ ] openclaw gateway: port `18789`, bind `loopback`
- [ ] `trustedProxies: ["127.0.0.1"]` 설정 존재

### Google 인증 방식
- [ ] `GOG_ACCESS_TOKEN` 환경변수 방식 사용
- [ ] Refresh Token → curl → Access Token 발급 로직
- [ ] 55분 갱신 주기
- [ ] 최대 3회 재시도 로직

### 에러 처리
- [ ] 필수 환경변수 미설정 시 `log_stop` 종료
- [ ] 각 설치 단계 실패 시 처리 (설치 재시도 또는 warn)
- [ ] Access Token 발급 실패 시 처리

### 워크스페이스 구조 (setup-agent.sh)
- [ ] orchestrator: AGENTS.md, SOUL.md, TOOLS.md, IDENTITY.md, USER.md, HEARTBEAT.md, skills/gog/SKILL.md
- [ ] mail/calendar/drive: AGENTS.md, TOOLS.md, skills/gog/SKILL.md

### proxy.js
- [ ] `http` + `net` 내장 모듈만 사용 (npm 패키지 없음)
- [ ] HTTP 일반 요청 프록시 처리
- [ ] WebSocket Upgrade 요청 터널 처리

## 출력 형식

각 항목을 순서대로 검토하고 결과를 출력한다.
문제 발견 시 해당 파일과 줄 번호를 명시하고 수정 방법을 제안한다.
