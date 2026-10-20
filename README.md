# My Little Budget

**나만의 작은 가계부** — Flutter로 만든 한국어 개인 가계부 앱입니다. 데이터는 로컬 SQLite에 저장하며 Windows 데스크톱과 Android 모바일에 각각 맞춘 화면을 제공합니다. 거래·예산·통계·자산·투자·메모·캘린더를 관리하고, JSON 백업과 Supabase 동기화를 사용할 수 있습니다.

## 공개 버전과 개발 상태

- 최신 GitHub 공개 버전: **`1.0.0-rc.9+58`** ([릴리스와 변경 내역](https://github.com/Flynn-Kalar/my_little_budget/releases/tag/v1.0.0-rc.9))
- 아래의 일반 기능·설치 안내는 공개된 rc.9을 기준으로 합니다.
- GitHub의 Android AAB 공개와 Google Play 배포는 별개입니다. Play 스토어에서 제공하는 버전은 배포 트랙에 따라 다를 수 있습니다.

| 구분 | 상태 |
| --- | --- |
| 민트 테마·홈 화면·거래 내역 정렬·통계 디자인 | rc.9 포함 |
| 태그별 카테고리 지정·다양한 카테고리 아이콘 | rc.9 포함 |
| 캘린더 날짜별 일정 추가·목록·D-day 모아보기 | rc.9 포함 |
| 다중 선택·일괄 작업·자산 거래 월 구분·반복 거래 순서 변경 | rc.9 포함 |
| 일정 상세를 먼저 읽고 ‘수정’ 버튼으로 편집 | rc.9 포함 |
| 메모 내용 동기화·기기별 알람 설정 분리 | rc.9 포함, 서버에 최신 SQL 적용 필요 |

**기존 Supabase 사용자는 rc.9로 업데이트한 뒤 [최신 SQL 전체](supabase/table_sync_v2_schema.sql)를 다시 실행하고 `11 / 11`을 확인하세요.** 이전 10개 테이블 구성에는 메모 동기화 테이블이 없습니다.

## Windows 버전 설치

**[Windows Setup 다운로드](https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.9/MyLittleBudget-Setup-1.0.0-rc.9.exe)** · **[Windows Update 다운로드](https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.9/MyLittleBudget-Update-1.0.0-rc.9.exe)** · **[Android AAB 다운로드](https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.9/MyLittleBudget-Android-1.0.0-rc.9.aab)**

1. 처음 설치할 때는 `MyLittleBudget-Setup-1.0.0-rc.9.exe`, 기존 앱을 업데이트할 때는 `MyLittleBudget-Update-1.0.0-rc.9.exe`를 내려받습니다.
2. Setup 파일을 실행하고 설치 안내를 따릅니다.
3. 설치가 끝나면 시작 메뉴의 `나만의 작은 가계부`를 실행합니다.

사용자별 `%LOCALAPPDATA%\Programs\MyLittleBudget`에 설치되므로 관리자 권한이 필요하지 않습니다. 기존 설치와 같은 AppId 및 데이터 저장 위치를 사용해 업그레이드합니다. 두 EXE는 파일명만 다른 동일한 전체 설치 패키지이며 [SHA256SUMS.txt](https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.9/SHA256SUMS.txt)로 검증할 수 있습니다.

Android AAB는 Google Play 업로드용 번들입니다. 휴대전화에서 직접 설치하는 APK 파일과는 다릅니다.

## 주요 기능

- 수입·지출·이체 거래 입력, 수정, 복제, 삭제, 검색 및 상세 필터
- 월별 잔액·예산·최근 거래를 확인하는 홈 화면
- 월별 예산, 예산 그룹, 이월 예산 관리
- 월간·연간 통계, 카테고리·태그 분석, 최근 12개월 수입·지출·순액 추세
- 계좌 생성, 보관, 복원 및 계좌별 거래 조회
- 투자 `BUY`·`SELL`·`DIVIDEND` 기록, 보유 종목과 실현 손익 조회
- 캘린더 일정과 메모 일정 표시, 빈 날짜에서 일정 추가, 일정이 있는 날짜의 목록 보기
- 일정별 D-day 설정과 전체 D-day 모아보기
- 일반 일정·반복 일정·D-day 상세를 읽기 전용 화면으로 열고, ‘수정’ 버튼으로 편집
- 토요일 파란색, 일요일·공휴일 빨간색 표시와 대한민국 공휴일 이름 제공
- 리치 텍스트 노트, 체크리스트, 반복 노트 및 알림
- 카테고리, 태그, 월간·주간·매일 반복 거래와 테마 관리
- 사용자 카테고리의 아이콘 선택, 태그별 여러 카테고리 연결과 사용 빈도에 따른 추천 정렬
- 반복 거래 순서를 드래그 또는 위·아래 버튼으로 변경하고 저장
- 매일 반복 거래의 주말·대한민국 공휴일 포함/제외 설정
- 월간 반복 거래의 N일·N주차 N요일 설정과 휴일 전후 영업일 조정
- 로컬 JSON 백업/복원
- Supabase Storage 기반 JSON 백업/복원
- Supabase Auth와 RLS로 보호되는 DB 증분 동기화
- 메모·체크리스트 동기화와 기기별 메모 알람 설정 유지
- 설정 화면에서 GitHub Releases 기반 최신 버전 수동 확인

## 입력과 데이터 관리 편의 기능

- 다중 선택: 카테고리 삭제, 태그 카테고리 일괄 지정·삭제, 자산 보관, 메모 고정·해제·삭제, 일정 삭제, 반복 거래 활성·비활성·삭제, 프리셋·예산 그룹·투자 내역 삭제를 지원합니다. 태그 카테고리는 추가·교체·해제를 선택할 수 있습니다.
- 태그 추천: 거래 카테고리를 고르지 않으면 많이 사용한 태그를 먼저 보여줍니다. 카테고리를 고르면 해당 카테고리를 지정한 태그를 먼저, 나머지 태그를 뒤에 보여주고 각 그룹은 사용 빈도순으로 정렬합니다.
- 자산 거래내역: PC와 모바일에 월 구분 헤더를 표시하며, 모바일에도 거래내역 제목을 제공합니다.
- 최근 입력 추천: PC의 메모 자동완성 또는 모바일의 최근 입력 제안을 선택하면 같은 유형의 거래에서 계좌·카테고리·태그를 불러옵니다. 입력 중인 금액·날짜·시간은 유지하며, 보관된 계좌나 카테고리는 추천하지 않습니다.
- 일괄 수정: 내역 화면의 체크리스트 버튼에서 현재 조회 결과의 거래를 선택해 카테고리와 태그를 함께 수정합니다. 카테고리는 같은 유형의 수입 또는 지출끼리만 변경할 수 있고, 태그 교체에서 입력을 비우면 선택한 거래의 태그를 제거합니다.
- 하루 예산: 예산 화면에서 그룹별 남은 예산을 오늘 포함 남은 날짜로 나누어 표시합니다. 등록된 예정 지출도 차감하며, 중복 계산을 피하기 위해 그룹별 하루 금액은 합산하지 않습니다.
- 월말 예상 순수입: 해당 월에 등록된 예정 거래를 포함해 수입에서 지출을 뺀 값이며 계좌 간 이체는 제외합니다. 좁은 PC에서는 월말 예상 순수입과 남은 예정 지출을 접이식 카드로 표시합니다. 펼치면 오늘 지출과 가까운 예정 거래 3건을 확인할 수 있습니다.
- 통계에서 내역 정리: PC와 모바일의 월간 통계 및 카테고리·태그 상세에서 `내역 정리`를 누르면 해당 월·지출 유형·카테고리·태그 조건을 적용한 내역 화면으로 이동합니다. 기존 거래 편집과 일괄 수정으로 분류를 정리할 수 있으며, `예산 조정`은 통계에서 보고 있던 월의 예산 화면을 엽니다.
- 거래 CSV: `설정 > 데이터 백업/복원 > 로컬`에서 전체 거래를 UTF-8 CSV로 내보내거나 CSV 열을 연결해 가져옵니다. 계좌·카테고리는 기존 활성 항목 이름과 일치해야 하며, 유형은 `수입/지출/이체/조정` 또는 `income/expense/transfer/adjustment`를 사용합니다. 태그는 세미콜론 구분 또는 내보낸 파일의 JSON 배열을 지원합니다. 미리보기에서 오류가 있으면 가져오기를 막고, 기존 데이터와 파일 안의 완전히 같은 거래는 건너뜁니다. 한 파일은 최대 10MB·10,000건이며 CSV는 전체 백업을 대신하지 않습니다.
- 자동 로컬 백업: 설치형 앱에서 기본으로 활성화됩니다. 앱 시작과 사용 중 데이터 변경 후 하루 한 번 저장하고, 최근 7개 복구 지점을 앱 내부 폴더에 보관합니다. 로컬 파일 탭에서 설정 변경·즉시 생성·파일 내보내기·복원을 할 수 있습니다. 앱 삭제나 기기 고장에 대비하려면 별도 파일도 내보내세요.
- 복원 미리보기: JSON·원격 백업·로컬 복구 지점 모두 백업 날짜와 데이터 건수를 확인한 뒤 전체 교체합니다. 설치형 앱은 복원 직전 현재 데이터의 안전 백업을 생성하며, 안전 백업이 실패하면 복원하지 않습니다.

## 기술 스택

- Flutter / Dart `^3.11.5`
- Riverpod `3.x`, GoRouter
- Drift + SQLite
- Flutter Quill, Flutter Local Notifications
- Supabase Dart SDK + Flutter Secure Storage
- `http`, `package_info_plus`, `pub_semver`
- `korean_lunar_utils`

## UI 구조

데스크톱/태블릿 UI와 모바일 UI는 별도 화면으로 유지합니다. 네이티브 데스크톱과 모바일·웹의 화면 선택 정책은 다음과 같습니다.

- Windows/Linux/macOS 네이티브: 창 폭과 관계없이 데스크톱 shell + 사이드바 유지. 폭이 1200 미만이면 compact desktop 사용
- Android/iOS/Web: 폭이 900 이상이면 데스크톱 shell + 사이드바, 900 미만이면 모바일 shell + 하단 내비게이션
- 모바일: 앱 시작 시 홈 화면을 표시하고, 각 탭에서 뒤로가기를 누르면 홈으로 이동합니다. 홈에서 뒤로가기를 한 번 누르면 앱을 종료합니다. 모바일 하단 내비게이션에는 홈 버튼을 두지 않습니다.
- PC: 사이드바에서 홈 화면으로 이동할 수 있습니다.
- 데스크톱 화면: `lib/ui/desktop/**`
- 모바일 화면: `lib/ui/mobile/**`
- 공용 UI: `lib/ui/shared/**`
- 플랫폼·공통 breakpoint 정책: `lib/shell/layout_policy.dart`
- shell 및 화면 연결: `lib/shell/**`, `lib/router/app_router.dart`, `lib/ui/mobile/responsive_page.dart`

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

먼저 `flutter devices`로 연결된 Android 기기의 ID를 확인한 뒤 실행합니다.

```powershell
flutter run -d DEVICE_ID
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

설치·업데이트 산출물:

```text
installer\output\MyLittleBudget-Setup-1.0.0-rc.9.exe
installer\output\MyLittleBudget-Update-1.0.0-rc.9.exe
installer\output\SHA256SUMS.txt
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

Windows 릴리스에는 항상 `MyLittleBudget-Setup-<version>.exe`, `MyLittleBudget-Update-<version>.exe`, `SHA256SUMS.txt`를 함께 첨부합니다. 두 EXE는 같은 전체 패키지이며 기존 설치를 유지하며 업그레이드할 수 있습니다. 앱은 Update 파일을 우선 사용하고, 이전 릴리스의 Setup도 지원합니다.

소스 변경을 커밋한 뒤 다음 명령으로 Windows 빌드, 소스·태그 푸시, 두 EXE 업로드 및 검증, 릴리스 공개까지 진행합니다. 인증은 기존 GitHub 로그인 또는 `GH_TOKEN`/`GITHUB_TOKEN` 환경변수를 사용하며 비밀값을 파일이나 로그에 저장하지 않습니다.

```powershell
.\scripts\publish_windows_release.ps1 -NotesFile .scratch/release-rc9/RELEASE_NOTES.md
```

같은 버전으로 빌드하고 서명을 확인한 Android AAB를 함께 올릴 때는 `-AndroidBundle build/app/outputs/bundle/release/app-release.aab`를 추가합니다. 릴리스에 버전이 붙은 AAB와 검증값이 함께 게시됩니다.

업데이트 확인은 앱 시작 시 자동으로 실행하지 않습니다. 사용자가 설정 메인 화면의 `최신 버전 확인`을 눌렀을 때만 GitHub Releases API를 조회합니다.

- Windows: 새 버전이 있으면 확인 후 Update 파일을 내려받고, 없는 이전 릴리스는 Setup으로 대체합니다. GitHub가 제공하는 SHA-256 검증에 성공한 경우에만 설치하고 앱을 다시 실행합니다.
- Android: 새 버전이 있으면 Google Play 앱 페이지를 열고, Play 스토어 앱을 열 수 없으면 웹 주소를 사용합니다.
- draft release는 제외하며 prerelease를 포함해 semantic version 기준으로 비교합니다.

새 버전을 배포할 때는 `pubspec.yaml`의 버전을 이전 공개 버전보다 높이고 소스 커밋·태그·파일명을 맞춥니다. 앱은 설치된 버전보다 높은 GitHub Release를 감지합니다. Git 태그만 만들고 Release를 생성하지 않으면 앱에서 감지하지 않습니다.

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

DB 동기화는 사용자가 입력한 Supabase Auth 이메일 계정으로 로그인하며, 비밀번호는 저장하지 않고 refresh token만 운영체제 보안 저장소에 보관합니다. 로컬 변경은 짧은 debounce 후 업로드되고, 앱 시작·복귀 시 마지막 revision 이후의 변경분을 내려받습니다. 실패한 작업은 로컬 outbox에 유지하고 제한된 backoff로 재시도합니다.

현재 동기화는 Realtime이나 여러 기기의 동시 편집을 목표로 하지 않습니다. 단일 사용자가 한 번에 한 기기를 사용하는 흐름을 기준으로 합니다.

설정 순서:

1. Supabase 프로젝트와 Email Auth 사용자를 생성합니다.
2. 앱의 `설정 > 데이터 백업/복원`에서 URL, publishable/anon key, Auth 이메일과 비밀번호를 입력해 저장합니다.
3. Supabase SQL Editor에서 [supabase/table_sync_v2_schema.sql](supabase/table_sync_v2_schema.sql)을 전체 실행합니다.
4. SQL 실행 결과의 설치 테이블 수가 `11 / 11`인지 확인하고, 앱에서 DB 테이블 테스트를 실행합니다.

rc.9에서 동기화하는 11개 테이블:

- `mlb_accounts`
- `mlb_categories`
- `mlb_transactions`
- `mlb_budget_groups`
- `mlb_monthly_income`
- `mlb_investments`
- `mlb_recurring_transactions`
- `mlb_transaction_presets`
- `mlb_tags`
- `mlb_calendar_events`
- `mlb_notes`

### 메모 동기화와 기기별 알람

rc.9부터 메모가 DB 증분 동기화에 포함됩니다. 메모와 체크리스트는 기존처럼 JSON 백업에도 포함됩니다.

- 제목·본문·서식·체크리스트 및 완료 상태·고정·목표·캘린더 표시·반복 일정을 동기화
- 알림 켜기·알림 시각·사전 알림·소리·진동·다시 알림·전체 화면 알람 모드는 각 기기에 유지
- 다른 기기에서 받은 새 메모는 알람 기본 꺼짐, 기존 메모의 기기별 알람 설정은 유지
- 알람 예약·발송 이력과 편집 중 임시 저장은 기기별로 유지

모든 기기를 rc.9 이상으로 업데이트하고, 최신 Supabase SQL 전체를 다시 실행해야 합니다. 기존 서버 데이터는 유지하며 `mlb_notes`를 추가합니다. 이전 rc.8 앱이나 기존 10개 테이블 SQL만으로는 메모 증분 동기화를 사용할 수 없습니다.

이미 기기에 설정된 메모 알람은 유지됩니다. 여러 기기에서 알람을 사용 중이라면, 알람이 필요 없는 기기에서만 꺼주세요. 다른 기기의 알람 설정에는 영향을 주지 않습니다.

RLS, 사용자 이전, tombstone 삭제와 revision 처리에 대한 자세한 내용은 [supabase/README.md](supabase/README.md)를 참고합니다.

## 주요 디렉터리

- `lib/app.dart`: 앱 초기화, 테마, 라우터, 알림과 동기화 시작
- `lib/router/app_router.dart`: GoRouter 라우팅과 반응형 화면 분기
- `lib/shell/**`: 홈·사이드바·모바일 내비게이션과 플랫폼별 레이아웃 정책
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
- Windows 업데이트는 확인 후 설치 파일을 내려받아 검증하고 실행합니다. Android는 Play 스토어로 이동합니다.
- 모바일과 데스크톱 화면은 별도 구현으로 유지합니다.
