# Release Checklist

릴리즈 후보를 만들기 전에 아래 항목을 확인한다. 이 문서는 현재 Flutter MVP 상태를 기준으로 하며, DB schema와 백업 JSON 포맷은 릴리즈 직전에 임의 변경하지 않는다.

Current release candidate:

- Version: `1.0.0-rc.1+1`
- Target: Windows desktop MVP, Android release candidate
- Last automated check: 2026-06-06

## 0. 자동 검증 결과

완료:

- [x] `flutter analyze` 통과: No issues found.
- [x] `flutter test` 통과: 134 tests passed.

미완료:

- [ ] `flutter build windows --release` 통과
  - 현재 결과: 실패
  - 원인: 로컬 Visual Studio Windows 빌드 툴체인에 필요한 C++ 컴포넌트가 없음
  - `flutter doctor -v` 요구 컴포넌트:
    - Desktop development with C++ workload
    - MSVC v142 - VS 2019 C++ x64/x86 build tools 또는 사용 가능한 최신 MSVC 빌드 도구
    - C++ CMake tools for Windows
    - Windows 10 SDK

Windows release build 산출물 경로:

```text
build\windows\x64\runner\Release
```

현재 상태:

- [ ] 위 경로의 release build 산출물 확인 필요
- [ ] `my_little_budget.exe` 실행 확인 필요

## 0-A. Android 자동 검증 결과

완료:

- [x] `flutter analyze` 통과: No issues found.
- [x] `flutter test` 통과: 134 tests passed.
- [x] Android backup export 경로 점검: `file_picker` Android/iOS `saveFile` 요구사항에 맞춰 JSON bytes를 직접 전달한다.
- [x] Theme/settings persistence 경로 점검: theme mode와 theme colors는 `SharedPreferences` 기반이며 release/profile 조건 분기가 없다.
- [x] DB 초기화 경로 점검: `drift_flutter`의 `driftDatabase(name: 'budget')`를 사용하며 Android 앱 문서 영역에 DB를 생성하는 구조다.

미완료:

- [ ] `flutter build appbundle --release` 통과
  - 현재 결과: 실패
  - 원인: 로컬 환경에서 Android SDK를 찾지 못함
  - 현재 `android/local.properties`의 `sdk.dir`: `C:\Users\di020\AppData\Local\Android\sdk`
  - `flutter doctor -v` 결과: `Android toolchain - develop for Android devices` 실패

Android release 산출물 경로:

```text
build\app\outputs\bundle\release\app-release.aab
```

현재 상태:

- [ ] 위 경로의 AAB 산출물 확인 필요
- [ ] AAB에서 APK를 생성하거나 Play/Internal testing 경로로 설치 확인 필요
- [ ] 설치 후 앱 실행 확인 필요

Android manifest/package/app label 점검:

- [x] Namespace: `com.dijung.my_little_budget`
- [x] Application ID: `com.dijung.my_little_budget`
- [x] Main activity: `com.dijung.my_little_budget.MainActivity`
- [x] App label: `나만의 작은 가계부`
- [x] Android launcher icon uses `assets/app_icon/app-icon.png`, generated from the existing Tauri `src-tauri/app-icon.png` reference.
- [x] Android adaptive icon resources are configured through `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`.
- [x] Release build no longer uses debug signing config.
- [x] Release signing is configured through `android/key.properties` when building a Play release.
- [x] Missing `android/key.properties` fails Play release tasks: `assembleRelease`, `bundleRelease`.
- [x] Local test build type exists: `localRelease`, using debug signing for local APK testing only.
- [x] `android/key.properties.example` exists and contains placeholders only.
- [x] `android/key.properties` and keystore files are ignored by `android/.gitignore`.
- [x] Root `.gitignore` also ignores `android/key.properties`, `.jks`, and `.keystore` files.

Android 수동/환경 조치 필요:

- [ ] JDK를 설치하고 `JAVA_HOME`을 설정한다.
- [ ] Android Studio 또는 Android command-line tools로 Android SDK를 설치한다.
- [ ] `ANDROID_HOME` 또는 `flutter config --android-sdk`로 SDK 경로를 설정한다.
- [ ] Android licenses를 승인한다.
- [ ] `flutter doctor -v`에서 Android toolchain이 통과하는지 확인한다.
- [ ] `flutter build appbundle --release`를 다시 실행한다.
- [ ] `build\app\outputs\bundle\release\app-release.aab` 산출물을 확인한다.

Google Play 업로드 전 필수 항목:

- [ ] Play Console 앱 등록용 package name이 `com.dijung.my_little_budget`로 확정되어 있는지 확인한다. 이 값은 업로드 후 변경할 수 없다.
- [ ] 본인 Google 계정을 Internal testing 테스터로 등록할 준비가 되어 있다.
- [ ] upload keystore를 로컬 보안 위치에 준비한다. 실제 keystore는 저장소에 포함하지 않는다.
- [ ] `android/key.properties`를 로컬에 생성한다. 이 파일은 git에 포함하지 않는다.
- [ ] `android/key.properties.example`을 참고하되, example 파일에는 실제 비밀값을 쓰지 않는다.
- [ ] `android/key.properties`에 아래 키만 로컬 비밀값으로 채운다.

```properties
storePassword=<release-keystore-password>
keyPassword=<release-key-password>
keyAlias=<release-key-alias>
storeFile=<relative-or-absolute-keystore-path>
```

- [ ] `storeFile`이 가리키는 keystore 파일을 안전한 위치에 보관하고 git에 포함하지 않는다.
- [ ] `flutter build appbundle --release`가 release signing으로 성공하는지 확인한다.
- [ ] AAB 산출물을 확인한다: `build/app/outputs/bundle/release/app-release.aab`
- [ ] debug-signed local APK 산출물은 Play Console에 업로드하지 않는다.
- [ ] Play Console Internal testing 트랙에 AAB를 업로드한다.
- [ ] 본인 Google 계정을 테스터로 등록한다.
- [ ] Play 설치 링크가 열리고 본인 계정으로 설치 가능한지 확인한다.
- [ ] Internal testing 설치 후 앱 최초 실행, 주요 route 진입, 앱 재시작 후 설정 유지, 백업 export/import를 실기기에서 확인한다.
- [ ] Play Console pre-launch report 결과를 확인한다.

Android release 설치 후 수동 확인:

- [ ] 앱 최초 실행이 crash 없이 완료된다.
- [ ] 주요 route에 진입할 수 있다: transactions, accounts, budget, stats, stats/yearly, investments, settings.
- [ ] 앱 재시작 후 theme mode와 theme color 설정이 유지된다.
- [ ] 앱 재시작 후 DB 데이터가 유지된다.
- [ ] `/settings/backup`에서 JSON export가 Android 파일 저장 플로우와 충돌하지 않는다.
- [ ] `/settings/backup`에서 JSON import가 Android 파일 선택 플로우와 충돌하지 않는다.
- [ ] import confirmation 문구가 표시되고, 복원 후 앱 재시작 없이 주요 화면 데이터가 갱신된다.
- [ ] 잘못된 JSON/import 실패 후 기존 데이터가 유지된다.

## 1. 릴리즈 범위 확인

- [ ] `MVP_CHECKLIST.md`의 DONE/READ_ONLY/TECH_DEBT 상태가 현재 코드와 일치한다.
- [ ] `IMPLEMENTATION_PLAN.md`의 active route 목록이 `lib/router/app_router.dart`와 일치한다.
- [ ] `PlaceholderScaffold` 또는 legacy placeholder 화면이 active route에서 사용되지 않는다.
- [ ] 새 기능이 릴리즈 범위에 끼어들지 않았는지 확인한다.
- [x] `pubspec.yaml`의 `version` 값을 MVP 릴리즈 후보 번호 `1.0.0-rc.1+1`로 확정한다.

## 2. 설치 및 실행 확인

개발 실행:

```powershell
flutter pub get
flutter run -d windows
```

릴리즈 빌드:

```powershell
flutter build windows --release
```

예상 산출물:

```text
build\windows\x64\runner\Release\my_little_budget.exe
```

확인 항목:

- [ ] Windows release build가 생성된다. 현재 로컬 환경에서는 Visual Studio C++ 컴포넌트 부족으로 미완료.
- [ ] release build에서 앱이 실행된다. build 완료 후 수동 확인 필요.
- [ ] 최초 실행 시 기본 자산/카테고리 seed가 생성된다.
- [ ] 앱 재시작 후 데이터와 테마 설정이 유지된다.

Android release build:

```powershell
flutter build appbundle --release
```

예상 산출물:

```text
build\app\outputs\bundle\release\app-release.aab
```

확인 항목:

- [ ] Android AAB release build가 생성된다. 현재 로컬 환경에서는 Android SDK 부재로 미완료.
- [ ] AAB 설치 경로를 통해 앱을 기기에 설치할 수 있다. build 완료 후 수동 확인 필요.
- [ ] 설치 후 앱이 crash 없이 실행된다.
- [ ] 앱 재시작 후 데이터와 테마 설정이 유지된다.
- [ ] Play Console Internal testing 트랙에서 설치 및 실행을 확인한다.

Android local test APK:

```powershell
flutter build apk --debug
cd android
.\gradlew assembleLocalRelease
```

예상 산출물:

```text
build\app\outputs\flutter-apk\app-debug.apk
android\app\build\outputs\apk\localRelease\app-localRelease.apk
```

확인 항목:

- [ ] `app-debug.apk`는 개발/디버깅용으로만 사용한다.
- [ ] `app-localRelease.apk`는 release-like 로컬 테스트용으로만 사용한다.
- [ ] `localRelease`는 debug signing을 사용하므로 Play Console 업로드 금지.
- [ ] Play 업로드용 산출물은 오직 release keystore로 서명된 `app-release.aab`를 사용한다.

## 3. 필수 검증

```powershell
flutter analyze
flutter test
```

- [x] `flutter analyze` 통과
- [x] `flutter test` 통과
- [x] route smoke test 통과
- [x] backup DAO round-trip test 통과
- [x] MVP stabilization widget test 통과

수동/환경 조치 필요:

- [ ] Visual Studio Build Tools에 Windows desktop C++ 빌드 필수 컴포넌트를 설치한다.
- [ ] `flutter doctor -v`에서 Visual Studio 항목이 Windows desktop build 가능 상태인지 확인한다.
- [ ] `flutter build windows --release`를 다시 실행한다.
- [ ] `build\windows\x64\runner\Release` 산출물을 확인한다.
- [ ] Android SDK를 설치/설정하고 `flutter build appbundle --release`를 다시 실행한다.
- [ ] JDK/JAVA_HOME을 설정하고 `cd android && .\gradlew assembleLocalRelease`를 확인한다.
- [ ] `build\app\outputs\bundle\release\app-release.aab` 산출물을 확인한다.

## 4. 주요 화면 스모크 테스트

아래 항목은 release build 생성 후 수동 확인한다.

- [ ] `/transactions`: 거래 생성, 검색, 필터, 수정, 삭제
- [ ] `/accounts`: 자산 생성, 수정, 보관, 복원, 상세 거래 필터
- [ ] `/budget`: 예상 수입 편집, 예산 그룹 생성/수정/삭제, 이전 달 복사
- [ ] `/stats`: 월간 breakdown, 카테고리 상세 패널, 12개월 trend
- [ ] `/stats/yearly`: 연도 선택, 월별 수입/지출/순액, 연간 카테고리 합계
- [ ] `/investments`: BUY 생성, 보유종목 inline SELL/DIVIDEND, 거래 수정/삭제, 실현손익
- [ ] `/settings`: categories, tags, recurring, theme, backup 진입

## 5. 백업 확인

경로:

- 앱: `설정` -> `데이터 백업/복원`
- 라우트: `/settings/backup`

확인 항목:

- [ ] `Create backup file` 버튼으로 JSON 백업 파일을 만들 수 있다.
- [ ] 파일명 형식이 `my_little_budget-backup-yyyyMMdd-HHmmss.json`이다.
- [ ] 생성된 JSON 파일이 비어 있지 않다.
- [ ] 백업 전후 앱 데이터가 유지된다.
- [ ] 사용자가 저장 위치를 직접 선택할 수 있다.

## 6. 복원 확인

복원 정책:

- 현재 데이터를 모두 삭제하고 백업 상태로 완전히 교체한다.
- 기존 데이터와 merge하지 않는다.
- 실패 시 기존 데이터가 유지되어야 한다.

확인 항목:

- [ ] `Choose backup file` 버튼으로 JSON 파일을 선택할 수 있다.
- [ ] 잘못된 JSON 또는 잘못된 backup 구조는 거부된다.
- [ ] 복원 전 확인 dialog가 표시된다.
- [ ] 확인 문구가 표시된다.

```text
현재 데이터를 모두 덮어쓰고 백업 데이터를 복원합니다. 되돌릴 수 없습니다.
```

- [ ] 확인 후 복원이 완료된다.
- [ ] 복원 성공 후 앱 재시작 없이 주요 화면 데이터가 갱신된다.
- [ ] 복원 실패 시 기존 데이터가 유지된다.

## 7. 알려진 제한

- Windows 데스크톱 MVP를 우선한다.
- 백업 복원은 전체 교체만 지원하며 부분 병합은 지원하지 않는다.
- 투자 가격/환율/시세 API 연동은 없다.
- 투자 수량은 소수점 4자리까지 지원한다.
- 금액, 단가, 수수료는 원화 정수 기준이다.
- 통계는 표/목록 중심이며 차트 시각화는 후속 작업이다.
- 설정 reset UI는 post-MVP polish로 남아 있다.
- 백업/복원 platform file picker 통합 테스트는 추가 보강 대상이다.

## 8. 향후 계획

- Windows 배포 패키징 방식 확정
- 백업/복원 end-to-end 테스트와 플랫폼 파일 선택기 harness 보강
- 예산/투자/계좌 edge case widget test 추가
- 통계 차트 시각화 검토
- 모바일/태블릿 레이아웃 대응 가능성 검토
- 설정 reset UX와 destructive confirmation 정책 검토

## 9. 릴리즈 직전 금지 사항

- [ ] DB schema 임의 변경 금지
- [ ] 백업 JSON 포맷 임의 변경 금지
- [ ] 라우팅 대규모 변경 금지
- [ ] AppTokens 전체 리디자인 금지
- [ ] quantity precision 정책 변경 금지
- [ ] 테스트 없이 generated file 갱신 금지
