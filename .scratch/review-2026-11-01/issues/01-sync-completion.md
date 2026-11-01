# P1 전체 동기화 요청이 진행 중 업로드 결과를 반환
Status: ready-for-agent

근거: lib/data/supabase_sync_coordinator.dart:98-105 및 lib/app.dart:98-100.

진행 중 작업이 있으면 fullSync 요청을 큐에 넣지만 반환값은 현재 active Future다. 진행 중 작업이 push인 경우 synchronizeNow 호출자는 원격 pull 완료 전에 성공을 받는다. 앱 복귀 시 이 결과로 반복 거래를 생성하므로 다른 기기의 lastGeneratedOn을 받기 전에 중복 생성할 위험이 있다. 중복 거래 자체는 이번 점검에서 재현하지 않았다.

재현: flutter test --no-pub .scratch/review-2026-11-01/sync_probe_test.dart --plain-name audit:
결과: 원격 fetch를 보류한 상태에서도 fullCompleted=true. sync-probe-retry.log 참조.

수용 기준: 전체 동기화 호출자는 요청한 pull까지 완료된 Future를 받아야 한다. push 중 full 요청, full 중 full 요청, 실패 결과 전달을 검증한다.

## Comments
2026-11-01: 수정 구현 완료. 전체 597개 테스트 및 정적 분석 통과. 상세 변경은 ../REPORT.md의 수정 결과 참조. Status는 기존 트리아지 분류를 유지하며 구현 완료는 이 기록으로 관리한다.
