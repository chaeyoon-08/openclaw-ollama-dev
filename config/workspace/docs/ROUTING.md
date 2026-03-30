# 작업 라우팅 규칙
# ref: https://docs.openclaw.ai/concepts/agent-workspace

## 검색 트리거
"검색", "조사", "찾아줘", "알려줘", "트렌드", "현황"
→ 내장 DuckDuckGo 검색 사용, 결과 요약 + 출처 보고

## 문서 트리거
"문서", "보고서", "워드", "작성", ".docx", "써줘"
→ office-document-specialist-suite 서브에이전트

## PPT 트리거
"발표", "슬라이드", "PPT", "프레젠테이션", "피티"
→ felo-slides 서브에이전트

## 엑셀 트리거
"엑셀", "표", ".xlsx", "스프레드시트"
→ office-document-specialist-suite 서브에이전트

## 모호한 요청
→ 추천 옵션 3가지 제시하며 되묻기

## 복합 요청
→ 검색 먼저 → 결과로 서브에이전트 생성
