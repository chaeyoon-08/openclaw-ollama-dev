# TOOLS.md — orchestrator
# ref: https://docs.openclaw.ai/tools/exec

## 사용 가능한 도구

orchestrator는 Gmail / Calendar / Drive 작업을 직접 수행한다.
각 작업은 아래 스킬 파일을 참조해서 gog 명령어를 exec 도구로 직접 실행한다.

- Gmail: `skills/gmail/SKILL.md`
- Calendar: `skills/calendar/SKILL.md`
- Drive: `skills/drive/SKILL.md`

## HEARTBEAT 자동화 관리

### 목록 확인
exec 도구로 HEARTBEAT.md 내용 읽기:
```bash
cat ~/.openclaw/workspace-orchestrator/HEARTBEAT.md
```

### 자동화 추가
1. 사용자에게 추가할 자동화 내용 확인
2. exec 도구로 HEARTBEAT.md에 내용 추가
3. 추가 완료 후 전체 목록 다시 보여주기

### 자동화 제거
1. 현재 목록 보여주고 제거할 항목 번호 확인
2. exec 도구로 해당 섹션 제거
3. 제거 완료 후 전체 목록 다시 보여주기

## MEMORY.md 복원 플로우

사용자가 Drive의 MEMORY.md로 봇 기억을 복원 요청 시 아래 순서로 처리한다.

1. 사용자에게 확인:
   "Google Drive의 MEMORY.md로 현재 기억을 덮어씁니다.
    현재 기억은 모두 사라집니다. 진행할까요?"

2. 사용자 확인 후 exec 도구로 Drive에서 MEMORY.md 검색 및 내용 읽기:
   ```bash
   # Drive에서 MEMORY.md 파일 ID 검색
   gog drive search "MEMORY.md" -j
   # 파일 ID로 내용 읽기
   gog drive read <fileId>
   ```

3. 반환된 내용으로 `~/.openclaw/workspace-orchestrator/MEMORY.md` 덮어쓰기:
   exec 도구로 아래 명령 실행:
   ```bash
   cat > ~/.openclaw/workspace-orchestrator/MEMORY.md << 'EOF'
   {drive에서 받은 내용}
   EOF
   ```

4. 사용자에게 완료 보고:
   "복원 완료. /new 명령어를 입력해 새 세션을 시작하면
    복원된 기억이 반영됩니다."
