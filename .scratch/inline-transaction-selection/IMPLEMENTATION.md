# 구현 및 검증

2026-10-19 코드 반영 완료. 이번 작업에서는 빌드·설치·배포하지 않았다.

- PC와 모바일 모두 기존 내역을 길게 눌러 선택 모드에 진입한다. 평상시 및 종료 후에는 체크박스가 없다.
- PC는 마우스 길게 누르기와 Shift 범위 선택을 지원한다. 접힌 예정 거래는 Shift 범위에서 제외한다.
- 기존 별도 선택 팝업과 진입 버튼을 제거했다. 같은 목록의 작업바에서 조회 결과 전체 선택/선택 해제/종료, 카테고리·태그 일괄 수정을 제공한다.
- 선택 합계에서 이체는 수입·지출에 포함하지 않는다.
- 적용할 ID를 저장 시작 시 복사하고 처리 중 선택 조작을 잠근다. 적용 후 현재 결과에 남는 선택은 유지한다.
- 월/검색/필터 변경 시 선택을 초기화하고 결과에서 사라진 ID를 제외한다.
- PC 작업바 높이를 목록 영역에 맞춰 제한하고 내부 스크롤을 제공해 작은 창에서도 목록이 남는다. 모바일 목록은 별도 모바일 파일에서 수정했다.

검증:

- `flutter analyze --no-pub`: 문제 없음.
- `flutter test --no-pub test/ui/transaction_selection_test.dart test/ui/daily_convenience_test.dart test/ui/transactions_screen_test.dart test/ui/mobile_transactions_daily_totals_test.dart test/ui/stats_to_action_test.dart`: 27개 통과.
- 마우스 길게 누르기 전후 체크박스, Shift 범위, 필터 경계, 선택 행에만 카테고리/태그 적용, 갱신 후 선택 유지, 모바일 길게 누르기와 선택 토글, 작은 PC 창의 편집 확장을 확인했다.
- 작업 시작 전부터 있던 노트 편집 관련 3개 파일은 변경하지 않았다.
