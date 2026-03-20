# TOOLS.md — drive
# ref: https://docs.openclaw.ai/concepts/agent-workspace
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수가 설정된 상태에서 gog 명령어를 실행한다.
run.sh가 기동 시 발급하고 55분마다 자동 갱신한다.

## gog drive 명령어

### 파일 검색
```bash
gog drive ls
# 예: gog drive ls
# 예: gog drive ls --max 20
```

### 파일 업로드
```bash
gog drive upload <file>
# 예: gog drive upload ./report.pdf
```

### 파일 다운로드
```bash
gog drive download <fileId>
```
