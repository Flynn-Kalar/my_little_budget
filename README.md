# My Little Budget

로컬 SQLite 기반 개인 가계부 앱입니다. Flutter, Drift, SQLite, Riverpod, GoRouter로 구현되어 있으며 거래, 예산, 통계, 계좌, 투자, 캘린더, 노트, 설정, 백업/복원을 관리합니다.

## 주요 기능

- 수입/지출/이체 거래 입력, 수정, 복제, 삭제, 검색, 필터
- 월별 예산, 예산 그룹, 이월 예산 관리
- 월간/연간 통계 조회
- 계좌 생성, 보관, 복원, 상세 거래 조회
- 투자 BUY/SELL/DIVIDEND 기록, 보유 종목, 실현 손익 조회
- 캘린더 일정과 노트 일정 표시
- 리치 텍스트 노트, 체크리스트, 반복 노트, 알림
- 카테고리, 태그, 반복 거래, 테마 설정
- 로컬 JSON 백업/복원
- Supabase Storage 기반 JSON 백업/복원 설정
- Supabase table sync v2 스키마 준비 및 연결 테스트

## 기술 스택

- Flutter SDK, Dart `^3.11.5`
- Riverpod `3.x`
- GoRouter
- Drift + SQLite
- SharedPreferences
- Flutter Local Notifications
- Flutter Quill
- Supabase Dart SDK

## UI 구조

이 프로젝트는 데스크톱/태블릿 UI와 모바일 UI를 분리합니다.

- `width >= 900`: 데스크톱 shell + 사이드바
- `width < 900`: 모바일 shell + 하단 내비게이션
- 데스크톱 전용 화면: `lib/ui/desktop/**`
- 모바일 전용 화면: `lib/ui/mobile/**`
- 공용 provider/widget: `lib/ui/shared/**`
- 플랫폼 분기: `lib/router/app_router.dart`, `lib/ui/mobile/responsive_page.dart`, `lib/ui/mobile/shell/mobile_shell.dart`

모바일 대응을 위해 `lib/ui/desktop/**` 화면에 `Wrap`, `Padding` 등을 추가하지 않습니다. 모바일 대응은 `lib/ui/mobile/**`에 별도 화면을 추가해서 처리합니다.

## 실행

필요 조건:

- Flutter SDK
- Windows 데스크톱 빌드 환경
- Android 빌드 시 Android SDK와 JDK 17 호환 환경

의존성 설치:

```powershell
flutter pub get
```

Windows 실행:

```powershell
flutter run -d windows
```

Android 기기/에뮬레이터 실행:

```powershell
flutter run -d android
```

## 코드 생성

Drift DAO와 데이터베이스 생성 파일을 갱신할 때 사용합니다.

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## 검증

```powershell
flutter analyze
flutter test
```

## 빌드

Windows release:

```powershell
flutter build windows --release
```

기본 산출물 경로:

```text
build\windows\x64\runner\Release
```

Android 로컬 테스트용 release-like APK:

```powershell
cd android
.\gradlew assembleLocalRelease
```

Google Play 업로드용 AAB:

```powershell
flutter build appbundle --release
```

기본 산출물 경로:

```text
build\app\outputs\bundle\release\app-release.aab
```

## Android 서명

Play 업로드용 release 빌드는 `android/key.properties`가 필요합니다. 예시는 [android/key.properties.example](android/key.properties.example)을 참고합니다.

```properties
storeFile=<absolute-or-relative-path-to-upload-keystore.jks>
keyAlias=<upload-key-alias>
storePassword=<upload-keystore-password>
keyPassword=<upload-key-password>
```

주의 사항:

- `android/key.properties`는 Git에 포함하지 않습니다.
- `.jks`, `.keystore` 파일은 Git에 포함하지 않습니다.
- 앱에는 `service_role` key를 저장하지 않습니다. Supabase 설정에는 anon/publishable key만 사용합니다.

## 백업과 복원

설정 화면의 데이터 관리에서 로컬 JSON 백업/복원을 실행합니다.

백업 파일명 형식:

```text
my_little_budget-backup-yyyyMMdd-HHmmss.json
```

복원은 기존 데이터를 병합하지 않고 백업 시점의 데이터로 교체합니다. 중요한 변경 전에는 먼저 백업 파일을 만들어 둡니다.

백업에는 다음 데이터가 포함됩니다.

- 계좌, 카테고리, 거래
- 예산 그룹, 월별 수입
- 투자, 태그, 반복 거래
- 노트, 체크리스트, 캘린더 일정

## Supabase

앱은 두 종류의 Supabase 관련 기능을 가집니다.

- Supabase Storage JSON 백업/복원
- Supabase table sync v2 연결 준비와 테이블 접근 테스트

Storage 백업/복원은 앱 설정에서 Supabase URL, anon/publishable key, bucket, path prefix를 입력해서 사용합니다.

Table sync v2 준비:

1. Supabase 프로젝트를 생성합니다.
2. SQL Editor에서 [supabase/table_sync_v2_schema.sql](supabase/table_sync_v2_schema.sql)을 실행합니다.
3. 앱의 설정 > 데이터 관리에서 Supabase URL과 anon/publishable key를 입력합니다.
4. DB 테이블 테스트를 실행합니다.

현재 table sync v2 스키마는 다음 테이블을 준비합니다.

- `mlb_accounts`
- `mlb_categories`
- `mlb_transactions`
- `mlb_budget_groups`
- `mlb_monthly_income`
- `mlb_investments`
- `mlb_recurring_transactions`
- `mlb_tags`
- `mlb_calendar_events`

## 주요 디렉터리

- `lib/app.dart`: 앱 초기화, 테마, 라우터, 알림 동기화
- `lib/router/app_router.dart`: GoRouter 라우팅과 화면 분기
- `lib/data/**`: Drift 테이블, DAO, 백업, Supabase 연동
- `lib/features/**`: 도메인 로직과 검증
- `lib/ui/desktop/**`: 데스크톱/태블릿 UI
- `lib/ui/mobile/**`: 모바일 UI
- `lib/ui/shared/**`: 공용 provider와 widget
- `test/**`: 데이터, 기능, UI 테스트
- `docs/agents/**`: 로컬 이슈/도메인 문서 운영 규칙
- `.scratch/<feature-slug>/`: 로컬 이슈와 PRD 작성 위치

## 프로젝트 문서

- [SPEC.md](SPEC.md): 제품/데이터/동작 기준
- [MVP_CHECKLIST.md](MVP_CHECKLIST.md): MVP 상태 체크리스트
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md): 구현 계획과 현재 구조
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md): 릴리스 준비 체크리스트

도메인 컨텍스트 문서는 루트 `CONTEXT.md`, 아키텍처 결정 기록은 `docs/adr/` 아래에 둡니다.

## 알려진 제약

- 투자 기능은 수동 입력 기준입니다. 실시간 시세나 외부 증권사 API 연동은 없습니다.
- 백업/복원은 전체 교체 방식입니다. 부분 병합 복원은 지원하지 않습니다.
- Android Play release 빌드는 로컬 release keystore 설정이 있어야 합니다.
- 모바일과 데스크톱 화면은 별도 구현으로 유지합니다.
