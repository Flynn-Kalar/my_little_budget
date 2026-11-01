# P2 자동 동기화 재시도 성공 후 반복 거래 생성 누락
Status: ready-for-agent

근거: lib/app.dart:77-81, 97-101, 108-112; lib/data/supabase_sync_coordinator.dart의 _scheduleRetry.

앱 시작/복귀 동기화가 실패하면 backfill을 건너뛴다. 이후 coordinator 자동 재시도가 성공해도 onResult는 캐시 무효화와 메모 동기화만 실행하며 반복 거래 생성을 하지 않는다. 원격 변경이 없으면 changedLocalData 검사에서 즉시 반환한다. 앱이 열린 상태에서는 다음 복귀/기간 전환 등까지 예정 거래가 누락될 수 있다.

검증 수준: 코드 경로 확인, 네트워크 장애 실기기 재현은 미실시.
수용 기준: 성공한 전체 pull 뒤에 반복 거래 생성을 한 번 실행하고, push 결과로 재귀 실행하지 않는다. 실패→자동 복구 시 원격 변경 유무 모두 검사한다.

## Comments
2026-11-01: 수정 구현 완료. 전체 597개 테스트 및 정적 분석 통과. 상세 변경은 ../REPORT.md의 수정 결과 참조. Status는 기존 트리아지 분류를 유지하며 구현 완료는 이 기록으로 관리한다.
