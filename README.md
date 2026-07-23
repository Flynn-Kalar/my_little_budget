# My Little Budget

## Windows 버전 설치

**[Windows Setup 바로 다운로드](https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.1/MyLittleBudget-Setup-1.0.0-rc.1.exe)**

1. 위 링크에서 `MyLittleBudget-Setup-1.0.0-rc.1.exe`를 내려받습니다.
2. Setup 파일을 실행하고 설치 안내를 따릅니다.
3. 설치가 끝나면 시작 메뉴의 `나만의 작은 가계부`를 실행합니다.

사용자별 `%LOCALAPPDATA%\Programs\MyLittleBudget`에 설치되므로 관리자 권한이 필요하지 않습니다. Windows SmartScreen 경고가 표시되면 게시자와 파일 출처가 이 저장소인지 확인한 뒤 실행 여부를 결정하세요.

Flutter로 만든 한국어 개인 가계부 앱입니다. 데이터는 로컬 SQLite에 저장되며 Windows 데스크톱과 Android 모바일에 각각 최적화된 UI를 제공합니다. 필요하면 JSON 파일이나 Supabase를 이용해 데이터를 백업하고 동기화할 수 있습니다.

- 현재 버전: `1.0.0-rc.1+43`
- 지원 UI: Windows 데스크톱/태블릿, Android 모바일
- 저장소: [Flynn-Kalar/my_little_budget](https://github.com/Flynn-Kalar/my_little_budget)

## 주요 기능

- 수입·지출·이체 거래 입력, 수정, 복제, 삭제, 검색 및 상세 필터
- 월별 예산, 예산 그룹, 이월 예산 관리
- 월간·연간 통계와 인사이트 조회
- 계좌 생성, 보관, 복원 및 계좌별 거래 조회
- 투자 `BUY`·`SELL`·`DIVIDEND` 기록, 보유 종목과 실현 손익 조회
- 캘린더 일정과 노트 일정 표시
- 토요일 파란색, 일요일·공휴일 빨간색 표시와 대한민국 공휴일 이름 제공
- 리치 텍스트 노트, 체크리스트, 반복 노트 및 알림
- 카테고리, 태그, 반복 거래와 테마 관리
- 로컬 JSON 백업/복원
- Supabase Storage 기반 JSON 백업/복원
- Supabase Auth와 RLS로 보호되는 DB 증분 동기화
- 설정 화면에서 GitHub Releases 기반 최신 버전 수동 확인

## 기술 스택

- Flutter / Dart `^3.11.5`
- Riverpod `3.x`, GoRouter
- Drift + SQLite
- Flutter Quill, Flutter Local Notifications
- Supabase Dart SDK + Flutter Secure Storage
- `http`, `package_info_plus`, `pub_semver`
- `korean_lunar_utils`

## UI 구조

데스크톱/태블릿 UI와 모바일 UI는 별도 화면으로 유지합니다.

- `width >= 900`: 데스크톱 shell + 사이드바
- `width < 900`: 모바일 shell + 하단 내비게이션
- 데스크톱 화면: `lib/ui/desktop/**`
- 모바일 화면: `lib/ui/mobile/**`
- 공용 UI: `lib/ui/shared/**`
- 플랫폼 분기: `lib/router/app_router.dart`, `lib/ui/mobile/responsive_page.dart`

모바일 대응을 위해 데스크톱 화면을 변형하지 않습니다. 모바일 기능은 `lib/ui/mobile/**` 아래에 별도로 구현합니다.

## 개발 환경 실행

필요 조건:

- Flutter SDK
- Windows 데스크톱 빌드 도구
- Android 빌드 시 Android SDK와 JDK 17 호환 환경

의존성 설치:

```powershell
flutter pub get
```

Windows 실행:

```powershell
flutter run -d windows
```

Android 기기 또는 에뮬레이터 실행:

```powershell
flutter run -d android
```

## 코드 생성과 검증

Drift DAO와 데이터베이스 생성 파일 갱신:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

정적 분석과 테스트:

```powershell
flutter analyze
flutter test
```

## Windows 빌드와 Setup 생성

Windows release 빌드:

```powershell
flutter build windows --release
```

기본 산출물:

```text
build\windows\x64\runner\Release
```

설치 프로그램은 Inno Setup 6으로 생성합니다. 설치되어 있지 않다면 먼저 다음 명령을 실행합니다.

```powershell
winget install --id JRSoftware.InnoSetup -e
```

release 빌드와 Setup 생성을 한 번에 실행:

```powershell
.\scripts\build_windows_installer.ps1
```

기존 Windows release 산출물을 재사용해 Setup만 생성:

```powershell
.\scripts\build_windows_installer.ps1 -SkipFlutterBuild
```

Setup 산출물:

```text
installer\output\MyLittleBudget-Setup-1.0.0-rc.1.exe
```

설치 경로는 사용자별 `%LOCALAPPDATA%\Programs\MyLittleBudget`이며 관리자 권한이 필요하지 않습니다. 시작 메뉴 바로가기가 생성되고, 바탕 화면 바로가기는 설치 과정에서 선택할 수 있습니다.

## Android 빌드와 서명

로컬 테스트용 debug 서명 release-like APK:

```powershell
cd android
.\gradlew assembleLocalRelease
```

Google Play 업로드용 AAB:

```powershell
flutter build appbundle --release
```

기본 AAB 산출물:

```text
build\app\outputs\bundle\release\app-release.aab
```

Play 업로드용 release 빌드는 `android/key.properties`가 필요합니다. 형식은 [android/key.properties.example](android/key.properties.example)을 참고합니다.

```properties
storeFile=<absolute-or-relative-path-to-upload-keystore.jks>
keyAlias=<upload-key-alias>
storePassword=<upload-keystore-password>
keyPassword=<upload-key-password>
```

보안 주의 사항:

- `android/key.properties`, `.jks`, `.keystore` 파일은 Git에 포함하지 않습니다.
- 앱에는 Supabase `service_role` 또는 secret key를 저장하지 않습니다.
- Supabase 연결에는 publishable key를 권장하며 legacy anon key도 사용할 수 있습니다.

## 최신 버전 확인

업데이트 확인은 앱 시작 시 자동으로 실행하지 않습니다. 사용자가 설정 메인 화면의 `최신 버전 확인`을 눌렀을 때만 GitHub Releases API를 조회합니다.

- Windows: 새 버전이 있으면 사용자에게 한 번 확인한 뒤 Setup을 직접 다운로드합니다. GitHub가 제공하는 SHA-256 검증에 성공한 경우에만 자동 설치하고 앱을 다시 실행합니다.
- Android: 새 버전이 있으면 Google Play 앱 페이지를 열고, Play 스토어 앱을 열 수 없으면 웹 주소를 사용합니다.
- draft release는 제외하며 prerelease를 포함해 semantic version 기준으로 비교합니다.

새 버전을 배포하려면 앱 버전보다 높은 버전 태그(예: `v1.0.0-rc.2`)로 GitHub Release를 생성해야 합니다. Git 태그만 만들고 Release를 생성하지 않으면 앱에서 감지하지 않습니다.

## 백업과 복원

설정의 `데이터 백업/복원`에서 로컬 JSON 백업 파일을 내보내거나 복원할 수 있습니다.

백업 파일명:

```text
my_little_budget-backup-yyyyMMdd-HHmmss.json
```

복원은 기존 데이터와 병합하지 않고 백업 시점의 데이터로 전체 교체합니다. 중요한 변경 전에는 먼저 백업 파일을 만들어 두는 것이 좋습니다.

백업 대상:

- 계좌, 카테고리, 거래
- 예산 그룹, 월별 수입
- 투자, 태그, 반복 거래
- 노트, 체크리스트, 캘린더 일정

## Supabase 백업과 증분 동기화

Supabase 기능은 서로 독립적인 두 방식으로 제공됩니다.

1. Storage에 JSON 백업 파일 업로드/복원
2. Postgres 테이블을 이용한 자동 증분 동기화

DB 동기화는 사용자가 입력한 Supabase Auth 이메일 계정으로 로그인하며, 비밀번호는 저장하지 않고 refresh token만 운영체제 보안 저장소에 보관합니다. 로컬 변경은 짧은 debounce 후 업로드되고, 앱 시작 시 마지막 revision 이후의 변경분을 내려받습니다. 실패한 작업은 로컬 outbox에 유지하고 제한된 backoff로 재시도합니다.

현재 동기화는 Realtime이나 여러 기기의 동시 편집을 목표로 하지 않습니다. 단일 사용자가 한 번에 한 기기를 사용하는 흐름을 기준으로 합니다.

설정 순서:

1. Supabase 프로젝트와 Email Auth 사용자를 생성합니다.
2. 앱의 `설정 > 데이터 백업/복원`에서 URL, publishable/anon key, Auth 이메일과 비밀번호를 입력해 저장합니다.
3. Supabase SQL Editor에서 [supabase/table_sync_v2_schema.sql](supabase/table_sync_v2_schema.sql)을 전체 실행합니다.
4. 앱에서 DB 테이블 테스트를 실행합니다.

동기화 테이블:

- `mlb_accounts`
- `mlb_categories`
- `mlb_transactions`
- `mlb_budget_groups`
- `mlb_monthly_income`
- `mlb_investments`
- `mlb_recurring_transactions`
- `mlb_tags`
- `mlb_calendar_events`

RLS, 사용자 이전, tombstone 삭제와 revision 처리에 대한 자세한 내용은 [supabase/README.md](supabase/README.md)를 참고합니다.

## 주요 디렉터리

- `lib/app.dart`: 앱 초기화, 테마, 라우터, 알림과 동기화 시작
- `lib/router/app_router.dart`: GoRouter 라우팅과 반응형 화면 분기
- `lib/data/**`: Drift 테이블, DAO, 백업과 Supabase 동기화
- `lib/features/**`: 도메인 로직, 검증, 공휴일과 업데이트 확인
- `lib/ui/desktop/**`: 데스크톱/태블릿 UI
- `lib/ui/mobile/**`: 모바일 UI
- `lib/ui/shared/**`: 공용 UI와 provider
- `installer/**`: Inno Setup 설정과 로컬 산출물
- `scripts/**`: 빌드 자동화 스크립트
- `supabase/**`: 동기화 스키마와 운영 문서
- `test/**`: 데이터, 기능, UI 테스트
- `.scratch/<feature-slug>/`: 로컬 이슈와 PRD

## 프로젝트 문서

- [SPEC.md](SPEC.md): 제품, 데이터와 동작 기준
- [MVP_CHECKLIST.md](MVP_CHECKLIST.md): MVP 상태 체크리스트
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md): 구현 계획과 현재 구조
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md): 릴리스 준비 체크리스트
- [docs/agents/domain.md](docs/agents/domain.md): 도메인 문서 운영 규칙
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md): 로컬 이슈와 PRD 운영 규칙
- [docs/agents/triage-labels.md](docs/agents/triage-labels.md): 트리아지 라벨 규칙

## 알려진 제약

- 투자 기능은 수동 입력 기준이며 실시간 시세나 증권사 API 연동은 없습니다.
- JSON 복원은 전체 교체 방식이며 부분 병합은 지원하지 않습니다.
- Supabase DB 동기화는 Realtime 및 여러 기기의 동시 편집을 지원하지 않습니다.
- Google Play release 빌드는 로컬 release keystore 설정이 필요합니다.
- 업데이트 확인은 새 버전을 내려받거나 자동 설치하지 않고 배포 페이지로만 이동합니다.
- 모바일과 데스크톱 화면은 별도 구현으로 유지합니다.
