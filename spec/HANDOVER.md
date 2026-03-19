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
