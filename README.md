# openclaw-ollama-dev

Ollama + OpenClaw 기반 리서치 & 자료 제작 AI 비서 **Clari**

Telegram으로 메시지를 보내면 Clari가 웹 검색, Word/Excel/PPT 파일 생성 후 Telegram으로 전송한다.
외부 API 비용 없음 — 로컬 LLM(Ollama)만 사용.

---

## 기능

| 기능 | 설명 |
|---|---|
| 웹 검색 | DuckDuckGo로 최신 정보 검색 후 요약 |
| Word 문서 | `.docx` 보고서 생성 + Telegram 전송 |
| Excel | `.xlsx` 스프레드시트 생성 + Telegram 전송 |
| PPT | 다크/라이트 테마 `.pptx` 생성 + Telegram 전송 |

---

## 사전 준비

### 1. Telegram 봇 토큰 발급

1. Telegram에서 **@BotFather** 검색
2. `/newbot` 입력 → 봇 이름 설정
3. 발급된 토큰 복사 (예: `7123456789:AAF...`)

### 2. gcube 워크로드 설정

gcube 대시보드에서 워크로드 배포 시 아래 이미지와 환경변수를 설정한다.

**이미지**: `unsloth/unsloth` (CUDA 지원 포함)

**권장 GPU**:

| GPU | VRAM | 권장 모델 |
|---|---|---|
| RTX 5090 | 32GB | `qwen3:14b` (기본값) 또는 `qwen3:32b` |
| RTX 4090 | 24GB | `qwen3:14b` |
| RTX 3090 | 24GB | `qwen3:14b` |
| A100 | 40/80GB | `qwen3:32b` |

**컨테이너 환경변수** (gcube 워크로드 배포 화면에서 입력):

| 변수명 | 필수 | 기본값 | 설명 |
|--------|------|--------|------|
| `TELEGRAM_BOT_TOKEN` | ✅ | - | BotFather에서 발급한 봇 토큰 |
| `OLLAMA_MODEL` | ❌ | `qwen3:14b` | 사용할 Ollama 모델명 |
| `ANTHROPIC_API_KEY` | ❌ | - | Claude API 키 (선택사항) |

### 3. (선택) 파인튜닝 모델 사용 시

Ollama 공개 모델이 아닌 커스텀 gguf 파일을 사용하는 경우:

```bash
# 컨테이너 접속 후 실행
ollama create qwen-agent -f Modelfile
```

`Modelfile`의 `FROM` 경로가 실제 gguf 파일 경로와 일치하는지 확인할 것.

---

## 설치 및 실행

gcube 워크로드 컨테이너 접속 후 아래 순서로 실행한다.

```bash
# 1. 레포 클론
git clone -b feat/qwen3-14b-agent https://github.com/chaeyoon-08/openclaw-ollama-dev.git
cd openclaw-ollama-dev

# 2. 인프라 설치 (Node.js + Ollama + OpenClaw + Python 패키지)
bash setup.sh

# 3. 에이전트 워크스페이스 구성 + 스킬 설치
bash setup-agent.sh

# 4. 서비스 기동
bash run.sh
```

각 단계별 소요 시간 (최초 실행 기준):
- `setup.sh`: 5~10분 (Node.js/Ollama 다운로드 + Ollama 모델 pull 포함)
- `setup-agent.sh`: 1~3분
- `run.sh`: 30초 이내

---

## 실행 흐름

```
[setup.sh]
  Node.js 22 설치 (/workspace/node)
  Ollama 설치 (/workspace/ollama/bin)
  OpenClaw 설치 (npm -g)
  Python 패키지 설치 (python-docx, openpyxl, python-pptx)
  ~/.openclaw/openclaw.json 생성

[setup-agent.sh]
  워크스페이스 파일 복사 → ~/.openclaw/workspace/
  스킬 파일 복사 → ~/.openclaw/workspace/skills/
  pip 패키지 확인
  openclaw gateway 임시 기동 → 스킬 설치 (felo-slides, office-document-specialist-suite)
  gateway 종료
  예시 파일 생성 (/workspace/work/)

[run.sh]
  기존 프로세스 정리
  PATH 설정 (/workspace/node/bin, /workspace/ollama/bin)
  ollama serve 기동
  openclaw gateway 기동
  Gateway Token 출력
```

---

## Telegram 사용 예시

봇에 아래처럼 메시지를 보내면 된다.

```
"AI 트렌드 2025 검색해줘"
"월별 매출 현황 엑셀 파일 만들어줘"
"생성형 AI 시장 현황 PPT 5장 만들어줘"
"ESG 경영 보고서 초안 작성해줘"
```

PPT 요청 시 Clari가 테마를 먼저 물어본다:
```
PPT 테마를 선택해 주세요:
1. 다크 (Dark) - 네이비/퍼플 계열
2. 라이트 (Light) - 흰 배경/퍼플 포인트
```

---

## Control UI 접속

openclaw gateway의 웹 관리 콘솔에 접속할 수 있다.

1. gcube 대시보드에서 워크로드 서비스 URL 확인
2. `https://[서비스URL]/__openclaw__/canvas/` 접속
3. `run.sh` 실행 후 출력된 **Gateway Token** 입력

로컬에서 직접 접속하는 경우: `http://127.0.0.1:18789/__openclaw__/canvas/`

> Control UI와 Telegram은 같은 에이전트 세션을 공유한다.
> 동시에 사용하면 대화 흐름이 섞일 수 있으므로 하나씩 사용 권장.

---

## 로그 확인

```bash
tail -f ~/.openclaw/gateway.log   # gateway 오류 확인
tail -f ~/.openclaw/ollama.log    # Ollama 모델 로딩 확인
```

## 서비스 재시작

```bash
# 프로세스 종료
pkill -f openclaw; pkill -f 'ollama serve'

# 포트 해제 대기 후 재기동
sleep 5 && bash run.sh
```

## 프로젝트 구조

```
openclaw-ollama-dev/
├── setup.sh                        # 인프라 설치
├── setup-agent.sh                  # 에이전트 구성
├── run.sh                          # 서비스 기동
├── Modelfile                       # Ollama 커스텀 모델 정의
└── config/
    └── workspace/                  # 에이전트 워크스페이스 소스
        ├── SOUL.md                 # 페르소나 + 작업 절차
        ├── IDENTITY.md             # 에이전트 자기소개
        ├── MEMORY.md               # 사용자 선호사항
        ├── docs/
        │   ├── ROUTING.md          # 트리거별 라우팅 규칙
        │   └── GATES.md            # 강제 게이트 규칙
        └── skills/
            └── office-document-specialist-suite/
                ├── ods.py          # Word 문서 생성
                ├── make_ppt.py     # PPT 생성
                ├── make_template.py# PPT 템플릿 생성
                ├── make_examples.py# 예시 파일 생성
                ├── SKILL.md        # 스킬 메타데이터
                └── requirements.txt
```

---

## 참고 문서

- OpenClaw: https://docs.openclaw.ai
- Ollama: https://github.com/ollama/ollama
