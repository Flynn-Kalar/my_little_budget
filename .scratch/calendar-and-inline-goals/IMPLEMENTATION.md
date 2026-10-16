# 적용 결과

Status: ready-for-human

## 메모 본문 금액 목표

작성·편집 화면의 서식 도구 모음에서 저금통 아이콘(금액 목표 삽입)을 누른다. 커서 위치에 목표 블록을 삽입하고 앞뒤에 일반 텍스트·불릿·체크리스트를 이어 쓸 수 있다. 여러 목표를 따로 관리하며 이름, 목표/현재 금액, 시작/목표일, 빠른 금액 추가와 직접 입력을 지원한다. 각 블록의 편집 버튼에서 수정·삭제한다. 메모 저장 시 함께 저장된다.

기존 상단 금액 목표와 일반 메모는 변환하거나 삭제하지 않는다. 본문 목표는 기존 richContent의 Quill embed로 저장하고 검색·목록용 평문에는 목표 이름과 금액을 포함한다. 기존 초안·복구·실행 취소·다시 실행·백업을 재사용한다.

주요 파일:
- `lib/features/notes/note_goal_block.dart`
- `lib/features/notes/rich_note.dart`
- `lib/ui/shared/note_goal_embed.dart`
- `lib/ui/shared/rich_note_editor.dart`
- `lib/ui/shared/note_amount_goal.dart`

## 캘린더

캘린더 알림 설정이 실제 Android 예약 엔진에 연결된다. 일반 알림의 확인과 다시 알림은 해당 일정 회차만 처리하며 거래와 잔액은 변경하지 않는다. 알림을 탭하면 해당 일정의 편집 화면으로 이동한다.

반복 일정을 누르면 이번 일정만 수정/전체 일정 수정/이번 일정 건너뛰기를 선택한다. 이번 회차의 제목·날짜·시각을 변경하거나 건너뛸 수 있다. 전체 일정 편집의 변경·건너뛴 회차 목록에서 원래대로 복원한다. 회차를 다른 달로 옮겨도 원래 날짜로 식별하며 다음 정기 회차를 밀지 않는다.

반복 간격·종료일·시간대와 다음 3회 미리보기를 추가했다. 종일 날짜는 달력 날짜로 보존하고 알림은 저장 시간대 오전 9시를 사용한다. 이 기본 시각은 화면에 안내한다. 긴 반복 간격과 먼 미래의 일회성 일정도 예약 후보에 포함한다.

기기 저장/서버 동기화와 알림 예약 상태를 구분한다. 서버에서 일정이 변경되면 알림도 다시 조정한다. 기존 배경색·테마·shell 구조는 유지한다.

주요 파일:
- `lib/features/calendar/calendar_schedule.dart`, `calendar_reminder_store.dart`
- `lib/ui/shared/calendar_entries.dart`, `calendar_schedule_options.dart`, `calendar_occurrence_actions.dart`, `calendar_event_status.dart`
- `lib/ui/mobile/calendar/mobile_calendar_screen.dart`
- `lib/ui/desktop/calendar/calendar_screen.dart`
- `lib/features/notes/reminder_store.dart`, `note_notification_service.dart`
- `lib/app.dart`, `lib/router/app_router.dart`
- Android `ReminderRepository.kt`, `ReminderNotification.kt`, `MainActivity.kt`

## 저장·호환성

DB v22는 calendar_events.schedule_data 기본값 `{}`를 추가한다. 기존 일정·메모·회차·알림 ID는 유지하며 일정 회차/작업 테이블과 통합 조회 view를 별도로 추가한다. 기존 종일 일정은 최초 업그레이드 시 기기의 현지 날짜로 고정한다. 예전 데이터만으로 원래 생성 기기의 시간대를 복원할 수는 없다.

설정/예외는 기존 Supabase JSON payload로 동기화하므로 별도 서버 테이블 변경은 없다. 이전 payload·백업에 새 필드가 없으면 기본값을 사용한다. 일정 확인 상태는 백업에 보존하고 기기별 OS 작업·미루기는 복원하지 않는다.

주요 파일: `lib/data/{database.dart,database.g.dart,calendar_reminder_schema.dart,backup.dart,local_sync_store.dart}`, `lib/data/tables/calendar_events.dart`, `lib/data/daos/{calendar_events_dao.dart,backup_dao.dart}`.

## 검증 결과

- 변경 Dart 파일 `dart format` 적용.
- `flutter analyze --no-pub`: 이상 없음.
- Flutter 전체 테스트: **414개 통과**.
- Android 15 / Galaxy S21 네이티브 테스트: **11개 통과**, 실패 0. 별도 `.remindertest` 패키지를 사용했으며 사용자의 가계부 설치/DB를 테스트하지 않았다.
- Android 디버그 APK 빌드 성공.
- Windows release 빌드 성공.
- Android release AAB 빌드 성공: `build/app/outputs/bundle/release/app-release.aab` 약 57.2 MB.
- Git diff 공백 검사 통과.

추가 테스트는 본문 목표 삽입/여러 목표/금액 추가/저장·재열기/체크리스트 혼합/실행 취소, 회차 이동·건너뛰기·복원, DST, 종일 날짜, 긴 반복 간격, 백업·이전 payload·DB v21 마이그레이션, 미루기 보존, 일정·메모 알림 ID 분리와 네이티브 확인·미루기·삭제 억제를 다룬다.

범위 밖: 외부 Samsung/Google 캘린더 연동, 음력, 기기 간 알림 중복/회차 확인 상태 동기화. 장시간 절전·전원 꺼짐·사용자 강제 중지 등의 알림 도착을 이번 테스트로 보장하지 않는다.
