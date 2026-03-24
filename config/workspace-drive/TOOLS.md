# TOOLS.md — drive
# ref: https://docs.openclaw.ai/concepts/agent-workspace
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수가 설정된 상태에서 gog 명령어를 실행한다.
run.sh가 기동 시 발급하고 55분마다 자동 갱신한다.

## gog drive 명령어

### 파일 검색
```bash
gog drive search "<query>"
# 예: gog drive search "회의록"
# 예: gog drive search "name:보고서 type:document"
```

### 파일 업로드
```bash
gog drive upload <file>
# 예: gog drive upload ./report.pdf
```

### MEMORY.md 백업 업로드
```bash
gog drive upload ~/.openclaw/workspace-orchestrator/MEMORY.md \
  --folder <folderName>
# folderName이 없으면 먼저 생성 후 업로드
```

### MEMORY.md 내용 읽기 (복원용)
```bash
gog drive read <fileId>
# 파일 ID는 search로 먼저 찾은 후 사용
```

### 파일 다운로드
```bash
gog drive download <fileId>
```

### 문서 내용 읽기
```bash
gog drive read <fileId>
# Docs, Sheets, Slides 문서 내용을 텍스트로 읽기
# 예: gog drive read abc123
```
