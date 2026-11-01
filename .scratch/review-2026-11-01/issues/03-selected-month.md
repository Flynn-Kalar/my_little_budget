# P2 집계 시작일 변경 시 사용자가 선택한 월 초기화
Status: ready-for-agent

근거: lib/features/transactions/providers.dart:19-21; test/features/statement_period_test.dart:106.

selectedMonthProvider가 currentStatementMonthProvider를 watch하므로 현재 기간 키가 바뀌면 선택 월을 덮어쓴다. 2026-11-01 기준 10월 선택 후 집계일 25일→1일 변경 시 기대한 10월 대신 11월 내역을 조회했다. 예산/홈/통계도 같은 초기화 패턴이므로 함께 확인해야 한다.

수용 기준: 수동 선택한 월과 기본 현재 월 이동 정책을 분리한다. 저장 월 키를 보존하는 기존 설계에 맞춰 설정 변경 전후 선택 월/예산을 검증한다. 재현 테스트는 오늘을 명시적으로 고정한다.

## Comments
2026-11-01: 수정 구현 완료. 전체 597개 테스트 및 정적 분석 통과. 상세 변경은 ../REPORT.md의 수정 결과 참조. Status는 기존 트리아지 분류를 유지하며 구현 완료는 이 기록으로 관리한다.
