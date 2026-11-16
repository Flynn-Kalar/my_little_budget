# 백업 공통 처리 및 화면 파일 위치 정리

Status: ready-for-human

## 요청과 범위

- PC·모바일 데이터 관리 화면의 백업·복원·초기화·Supabase 처리 중복을 제거한다.
- PC·모바일 화면 레이아웃은 별도 파일로 유지한다.
- PC 설정 화면과 공통 화면 선택 코드를 역할에 맞는 디렉터리로 옮긴다.
- 배포 자동화·버전·DB 스키마·백업 포맷은 변경하지 않는다.

## 구현

- `features/settings/data_management_controller.dart`: 데이터 작업, 설정 저장, 상태 기록, 복원 전 안전 백업, 완료 후 provider 갱신과 알림 재등록.
- `ui/shared/data_management_actions.dart`: 폼 수명주기, 파일 선택, 사용자 확인, 진행률, 중복 요청 방지, 화면이 닫힌 뒤 UI 접근 방지.
- 자동 로컬 복구 지점도 동일한 복원 컨트롤러 사용.
- PC 설정 화면: `ui/desktop/settings/settings_screen.dart`.
- 공통 화면 선택: `shell/responsive_shell.dart`, `shell/responsive_page.dart`.
- `ui/mobile/shell/mobile_shell.dart`는 모바일 하단 내비게이션만 담당.
- 사용하지 않던 예전 복원 확인창 제거; 테스트는 실제 복원 미리보기 확인창으로 변경.
- 처리 중 백업 모드 전환을 막아 로컬 패널이 사라지면서 작업 완료 상태가 전달되지 않는 문제 방지.
- 초기화 확인창도 공통 작업 잠금 안에서 관리하고, 로컬 패널 중복 실행과 화면 이탈 후 파일 선택창 호출 방지.

## 검증

- `dart analyze lib test`: 2026-11-16 최종 변경 기준 통과.
- `git diff --check`: 통과.
- 안전 백업 실패·손상된 백업·성공 기록 시점·초기화·화면 이탈·실패 후 재시도·중복 요청·작업 중 모드 변경·원격 복원 취소를 검사하는 회귀 테스트 16개 추가.
- 관련 Flutter 테스트 실행은 실행 환경의 localhost 통신 제한(`127.0.0.1`, SocketException 10057)으로 테스트 본문 실행 전에 차단됨. 테스트 통과로 간주하지 않는다.
- Flutter 테스트용 SDK 복사본과 해시가 일치하는 SQLite DLL로 컴파일 단계까지 진행했으며, 임시 `pubspec.yaml` 설정은 복구했다. 의존성·버전 변경 없음.
- 기존 `recurring_form.dart`의 미커밋 수정은 보존.

일반 개발 환경에서 실행할 검증 명령:

```powershell
flutter test test/features/settings/data_management_controller_test.dart test/ui/data_management_actions_test.dart test/ui/supabase_settings_screen_test.dart test/ui/compact_desktop_test.dart test/ui/mvp_stabilization_test.dart test/ui/bulk_management_test.dart test/ui/update_check_screen_test.dart
```
