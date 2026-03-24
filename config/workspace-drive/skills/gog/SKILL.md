---
name: gog
description: Google Workspace CLI (Drive)
---

# gog — Google Workspace CLI
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수로 인증한다. run.sh가 발급 및 자동 갱신을 담당한다.

```bash
export GOG_ACCESS_TOKEN=<access_token>
```

---

## gog drive

```bash
# 파일 검색
gog drive search "<query>"

# 파일 업로드
gog drive upload <file>

# 폴더 지정 업로드 (폴더가 없으면 자동 생성)
gog drive upload <file> --folder <folderName>
# 예: gog drive upload ./MEMORY.md --folder openclaw-memory

# 파일 다운로드
gog drive download <fileId>

# 문서 내용 읽기 (Docs, Sheets, Slides → 텍스트)
gog drive read <fileId>
```
