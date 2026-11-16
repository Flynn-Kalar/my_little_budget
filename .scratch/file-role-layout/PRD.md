# 역할별 파일 위치 정리

Status: ready-for-human

## 범위

기존 백업 공통화와 설정 화면·공통 화면 분기 이동을 보존하고, 남아 있는 역할·위치 불일치를 정리한다. 파일 위치와 의존 경로를 수정하며 화면·계산·저장 동작은 유지한다.

## 변경

| 기존 위치 | 최종 위치 | 역할 |
| --- | --- | --- |
| `lib/shell/sidebar_shell.dart` | `lib/ui/desktop/shell/sidebar_shell.dart` | 데스크톱 사이드바 UI |
| `lib/ui/desktop/color_hex.dart` | `lib/core/color_hex.dart` | 공통 색상 변환 |
| `lib/ui/desktop/accounts/account_refresh.dart` | `lib/features/accounts/account_refresh.dart` | 자산 변경 후 기능별 상태 갱신 |
| `lib/ui/shared/calendar_entries.dart` | `lib/features/calendar/calendar_entries.dart` | 일정 회차·달력 집계 |
| `lib/ui/shared/notes_calendar.dart` | `lib/features/notes/notes_calendar.dart` | 메모의 달력 항목 집계 |
| `lib/ui/shared/calendar_event_status.dart`의 provider | `lib/features/calendar/providers.dart` | 일정 알림 상태 조회 |

- `CalendarEventStatus` 위젯은 공용 UI에 유지한다.
- 모든 사용처와 기존 테스트의 import 경로를 갱신한다.
- 자산 provider에 남아 있던 과도한 상위 디렉터리 참조를 올바른 상대 경로로 정리한다.
- README에 역할별 배치 기준을 기록하고 IMPLEMENTATION_PLAN의 오래된 화면·provider 경로를 정정한다.
- 폼·입력 포맷터·선택 상태 등 화면 상호작용 코드는 UI에 유지한다.

## 검증

- `dart analyze lib test`: 통과.
- 이동한 5개 파일의 import 이외 본문 동일성 확인.
- 분리한 일정 알림 provider와 상태 위젯 본문 동일성 확인.
- 로컬 Dart 참조 누락 0건.
- `core/data/features -> ui`, `desktop -> mobile`, `mobile -> desktop` 의존 위반 0건.
- 기존 `recurring_form.dart` 변경의 SHA256 유지 확인.
- `git diff --check`: 통과.
- 기존 테스트 4개 파일(`compact_desktop`, `calendar_events_dao`, `calendar_schedule`, `calendar_occurrence`)은 컴파일 후 실행기와의 localhost 연결 오류(`127.0.0.1`, SocketException 10057)로 본문 실행 전 차단되었다. 테스트 통과로 간주하지 않는다.
- 테스트용 임시 `pubspec.yaml` 설정은 복구했으며 버전·의존성 변경은 없다.
