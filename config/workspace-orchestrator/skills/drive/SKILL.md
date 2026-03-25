---
name: gog-drive
description: Google Drive CLI
---

# === Drive Skills ===
# ref: https://github.com/steipete/gogcli

## 인증

`GOG_ACCESS_TOKEN` 환경변수로 인증한다. run.sh가 발급 및 자동 갱신을 담당한다.

---

## 주의사항

- `--folder` 플래그는 존재하지 않음 — 절대 사용 금지
- 폴더에 파일을 올리려면 먼저 폴더 ID를 구한 뒤 `--parent <folderID>` 사용

## gog drive

```bash
# 파일 검색
gog drive search "<query>"

# 폴더 검색 (JSON 출력)
# 결과: .files[].id (mimeType: application/vnd.google-apps.folder 필터링)
gog drive search "<folderName>" -j

# 폴더 생성 (JSON 출력)
# 결과: .folder.id
gog drive mkdir <name> -j

# 폴더에 파일 업로드
# --parent <folderID> 로 업로드 위치 지정
gog drive upload <file> --parent <folderID>

# 파일 업로드 (루트)
gog drive upload <file>

# 파일 다운로드
gog drive download <fileId>

# 문서 내용 읽기 (Docs, Sheets, Slides → 텍스트)
gog drive read <fileId>
```
