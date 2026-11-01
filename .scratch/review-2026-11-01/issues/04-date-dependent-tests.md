# P2 월초에 UI 테스트 3개 실패
Status: ready-for-agent

실패: mobile_transactions_daily_totals_test, transactions_screen_test의 날짜 합계, mvp_stabilization_test의 검색 해제.

앞 두 테스트는 오늘이 1일이면 두 번째 날짜를 2일로 만든다. 검색 테스트도 매월 1일/2일을 사용한다. 11월 1일에는 2일 거래가 미래이며 기본 접힘인 예정 거래 영역에 들어가서 텍스트를 찾지 못한다. 따라서 세 실패를 그대로 일별 합계 계산/검색 기능 버그로 단정하지 않는다.

근거: test/ui/mobile_transactions_daily_totals_test.dart:38, test/ui/transactions_screen_test.dart:470, test/ui/mvp_stabilization_test.dart:805, lib/ui/mobile/transactions/widgets/mobile_transaction_list.dart:36-63.

수용 기준: 테스트 시간을 고정하거나 예정 거래를 명시적으로 펼친다. 일반 날짜·월초·연초에도 동일하게 동작해야 한다.

## Comments
2026-11-01: 수정 구현 완료. 전체 597개 테스트 및 정적 분석 통과. 상세 변경은 ../REPORT.md의 수정 결과 참조. Status는 기존 트리아지 분류를 유지하며 구현 완료는 이 기록으로 관리한다.
