# PRD — openclaw-ollama-dev

## 목표

Telegram 하나로 Gmail, Google Calendar, Google Drive를 AI가 자동 처리하는 개인 업무 비서.
API 비용 없이 로컬 LLM(Ollama)만으로 동작한다.

---

## 배포 환경

- **플랫폼**: gcube GPU 클라우드 컨테이너
- **외부 접근**: gcube가 부여하는 HTTPS URL (배포마다 변경됨) → 내부 포트 8080
- **GPU**: Ollama 모델 추론에 활용

---

## 사용 흐름

```
git clone <repo>
cp .env.example .env && vi .env   # 필수 환경변수 입력
bash setup.sh                     # Ollama + OpenClaw + gogcli 설치, openclaw.json 생성
bash setup-agent.sh               # 에이전트 워크스페이스 구성, Telegram 바인딩
bash run.sh                       # Access Token 갱신 루프 + Ollama + proxy + gateway 기동
```

이후 Telegram 봇에 메시지를 보내면 AI가 자동 처리한다.

---

## 채널

| 채널 | 상태 |
|---|---|
| Telegram | 현재 운영 중 |
| Slack | 추후 추가 예정 |

---

## Google 서비스

| 서비스 | 기능 |
|---|---|
| Gmail | 메일 조회, 검색, 초안 작성 |
| Google Calendar | 일정 조회, 등록, 수정, 삭제 |
| Google Drive / Docs / Sheets / Slides | 문서 조회, 생성, 편집 |

---

## 비기능 요구사항

- 외부 API 비용 없음 (로컬 Ollama만 사용)
- 단일 컨테이너에서 모든 서비스 실행
- Google OAuth Refresh Token 기반 인증 (55분마다 자동 갱신)
- 재시작 시 `bash run.sh` 한 번으로 복구 가능
