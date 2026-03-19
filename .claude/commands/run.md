# /run

run.sh 와 proxy.js 를 작성 또는 수정한다.

스펙 참조: @spec/SPEC.md, @spec/HANDOVER.md

## proxy.js 스펙

- node 내장 모듈만 사용 (`http`, `net`) — npm install 불필요
- `0.0.0.0:8080` → `127.0.0.1:18789` 프록시
- HTTP 요청 + WebSocket Upgrade 요청 모두 처리 (HANDOVER.md 검증 완료)

## run.sh 작업 순서

1. **기존 프로세스 정리**
   - 포트 8080, 18789, 11434 점유 프로세스 kill
   - openclaw, proxy.js, ollama 프로세스 종료

2. **Access Token 발급** (SPEC.md 인증 방식 참조)
   ```bash
   ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
     -d "grant_type=refresh_token" \
     -d "client_id=$GOOGLE_CLIENT_ID" \
     -d "client_secret=$GOOGLE_CLIENT_SECRET" \
     -d "refresh_token=$GOOGLE_REFRESH_TOKEN" | \
     python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
   export GOG_ACCESS_TOKEN=$ACCESS_TOKEN
   ```

3. **55분마다 자동 갱신하는 백그라운드 루프 시작**
   - 갱신 실패 시 `log_error` + 재시도 (최대 3회)
   - 3회 모두 실패 시 `log_warn` 후 다음 주기 대기 (프로세스 종료 안 함)

4. **Ollama 서버 백그라운드 기동**
   - `ollama serve` 백그라운드 실행, 로그는 `~/.openclaw/ollama.log`

5. **proxy.js 백그라운드 기동**
   - `node proxy.js` 백그라운드 실행

6. **openclaw gateway 백그라운드 기동**
   - `openclaw gateway > ~/.openclaw/gateway.log 2>&1 &` 백그라운드 실행
   - 10초 대기 후 `openclaw gateway status`로 정상 기동 확인
   - 실패 시 `log_error` + `log_stop` 종료

7. **기동 완료 메시지 출력**
   - Telegram 바인딩 확인 방법 안내
   - 로그 확인 명령어 안내

## 로그 스타일

CLAUDE.md의 로그 함수를 사용한다.
