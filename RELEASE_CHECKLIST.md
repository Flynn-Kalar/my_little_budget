# 릴리스 체크리스트

최종 갱신: **2026-11-17 (한국 시간)**

이번 배포 대상은 **1.0.0-rc.17+66**이다. [rc.17 작업 기록](.scratch/release-rc17/PRD.md)에 포함 범위와 실제 검증 결과를 기록한다. 아래 rc.16/미커밋 상태 및 2026-11-16 테스트 환경 제한은 당시 준비 점검 이력이며, rc.17의 최종 판정은 새 검증 기록과 게시 결과를 따른다.

다음 릴리스를 준비하기 위한 점검표다. 완료 표시는 검증한 소스와 산출물에만 적용하며, 소스나 버전이 바뀌면 해당 검증을 다시 수행한다. 문서 갱신 자체는 빌드·배포 완료를 의미하지 않는다.

## 1. 기준 버전과 현재 상태

| 항목 | 확인 내용 |
| --- | --- |
| 현재 `pubspec.yaml` | `1.0.0-rc.16+65` |
| 저장소에 기록된 직전 배포 | `v1.0.0-rc.16`, 커밋 `2ea38a8c7ea170c5fbcdec41927359b4587be513` |
| 직전 배포 기록 | Windows Setup·Update·해시·Android AAB의 GitHub 게시 및 Google Play `internal` 완료 기록 있음 |
| 현재 작업 트리 | 백업 공통화·파일 역할 정리 등 미커밋 변경 있음. 기존 rc.16 태그에 포함되지 않음 |
| 다음 배포 버전·커밋 | 미정. 이전 공개 버전보다 높은 새 버전과 최종 소스 커밋 확정 필요 |
| DB / JSON 백업 | DB schema `26`, JSON backup version `1` |
| 배포 대상 | Windows x64 설치·업데이트, Android release AAB |
| 현재 판정 | **배포 전 검증 미완료** |

위 배포 이력은 로컬 [rc.16 작업 기록](.scratch/release-rc16/PRD.md), `publish.log`, `play-release.log`와 태그 기준이다. 이번 갱신에서는 GitHub·Google Play의 현재 원격 상태를 다시 조회하지 않았다. 실제 배포 직전에 공개 버전과 트랙 상태를 확인한다.

### 현재 변경의 검증 결과

| 검증 | 결과 / 적용 범위 |
| --- | --- |
| `dart analyze lib test` | 2026-11-16 백업·파일 정리 변경 기준 통과 |
| `git diff --check` | 통과 |
| 배포 스크립트 검증 | 3개 구문 오류 0건. 오프라인 모의 시나리오 25개에서 정상·보호 동작 19개 확인, 검증 누락 6개 재현. 실제 빌드·배포 검증 아님 |
| 파일 이동 검증 | 이동 파일 5개와 분리한 일정 알림 provider·위젯의 실행 코드 동일성 확인, 로컬 Dart 참조 누락 0건 |
| UI 경계 | `core/data/features -> ui`, `desktop -> mobile`, `mobile -> desktop` 직접 의존 위반 0건 |
| 백업 회귀 테스트 | 16개 작성. 테스트 실행 통과를 뜻하지 않음 |
| 관련 Flutter 테스트 | 컴파일 후 실행기와의 `127.0.0.1` 연결 오류(`SocketException 10057`)로 본문 실행 전 차단 |
| 현재 변경의 전체 `flutter test` | 통과 여부 미확인 |
| 현재 변경의 Windows·Android release 빌드 | 미검증. 기존 산출물의 존재로 완료 처리하지 않음 |
| 신규 설치·기존 버전 업그레이드·실기기 | 미검증 |

상세 근거: [백업 정리 기록](.scratch/backup-controller-layout/PRD.md), [파일 역할 정리 기록](.scratch/file-role-layout/PRD.md), [배포 스크립트 검증 결과](.scratch/release-script-validation/REPORT.md).

rc.16 작업 기록의 **598개 테스트 통과는 당시 소스에 대한 과거 결과**다. 현재 미커밋 변경의 통과 근거로 사용하지 않는다. 이전 문서의 rc.1·134개 테스트·Windows C++ 도구 부재·Android SDK 부재 기록은 현재 상태에서 제외했다. 도구 설치 필요 여부는 배포 환경의 `flutter doctor -v` 결과로 판단한다.

## 2. 배포 범위·버전·소스 확정

- [ ] 백업 공통화·파일 위치 정리 및 기존 정기거래 폼 수정 등 변경별 포함 범위를 확인한다.
- [ ] `git diff`와 새 파일을 검토하고, 릴리스 노트에 실제 포함되는 변경과 알려진 제한을 기록한다.
- [ ] 배포 직전 GitHub 공개 릴리스와 Google Play 업로드 이력의 버전·빌드 번호를 확인한다.
- [ ] 앱 버전을 이전 공개 버전보다 높이고 Android `versionCode`로 사용할 빌드 번호도 올린다. 빌드 번호만 변경하고 같은 Git 태그를 재사용하지 않는다.
- [ ] 앱 버전·최종 소스 커밋·태그 `v<version>`·Setup/Update/AAB 파일명을 일치시킨다. 파일명의 `<version>`에는 `+<build>`를 제외한다.
- [ ] README의 버전·다운로드 경로와 릴리스 노트를 새 버전에 맞춘다.
- [ ] DB 스키마·백업 포맷·Windows AppId·Android applicationId·서명키를 불필요하게 변경하지 않는다. 필요한 변경은 마이그레이션·호환성 검증을 포함한다.
- [ ] 검증할 변경을 커밋하고 배포 직전 `git status --porcelain` 출력이 비어 있는지 확인한다.
- [ ] 릴리스 노트와 검증 로그에 대상 버전·커밋·날짜·실행 환경을 남긴다.

## 3. 배포 전 필수 자동 검증

프로젝트 루트에서 실행한다.

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
git diff --check
```

- [ ] 대상 플랫폼에 필요한 SDK·JDK·Windows C++ 도구·Inno Setup을 확인한다.
- [ ] 최종 릴리스 소스에서 `flutter analyze`가 통과한다.
- [ ] 전체 `flutter test`가 통과하며 실제 실행 건수와 결과를 기록한다.
- [ ] 주요 라우트·백업 DAO round-trip·설정·업데이트·compact desktop 관련 기존 테스트가 통과한다.
- [ ] 백업 컨트롤러의 안전 백업 실패·손상 JSON·복원 성공 기록·초기화 테스트가 통과한다.
- [ ] PC·모바일 화면의 복원 취소·요청 실패 후 재시도·중복 요청 방지·모드 변경 제한·화면 이탈 테스트가 통과한다.
- [ ] `git diff --check`가 통과하고, 검증 중 의도하지 않은 소스·의존성 변경이 생기지 않는다.

현재 환경의 Flutter 테스트 통신 차단은 **테스트 미실행**으로 취급한다. 실행 가능한 개발 환경에서 검증을 마치기 전 위 체크를 완료하지 않는다.

현재 [Windows 게시 스크립트](scripts/publish_windows_release.ps1)는 정적 분석·테스트 실행과 이전 공개 버전 대비 버전 증가를 검사하지 않는다. 첨부 AAB도 확장자만 확인하고 현재 버전의 파일명으로 복사한다. `.github/workflows`도 없으므로 이 항목들은 게시 전에 별도로 검증해야 한다.

- [ ] `git status`의 종료 코드를 검사하여 명령 오류를 배포 중단으로 처리한다.
- [ ] 빌드 전후와 푸시 직전의 HEAD가 검증 대상 커밋과 일치하도록 보완한다.
- [ ] 이전 공개 버전 증가, 첨부 AAB의 내부 메타데이터, 분석·테스트 통과를 게시 조건에 반영한다.
- [ ] Google Play의 기존 배포·업로드 이력과 versionCode를 비교하여 의도하지 않은 낮은 버전 배포 요청을 차단한다.

위 항목은 2026-11-16 모의 검증에서 발견한 보완 사항이며 아직 수정하지 않았다. 재현 방법과 적용 범위는 [검증 보고서](.scratch/release-script-validation/REPORT.md)를 따른다.

## 4. Windows 설치·업데이트 패키지

[빌드 스크립트](scripts/build_windows_installer.ps1)로 Flutter release 빌드와 Inno Setup 패키징을 수행한다.

```powershell
.\scripts\build_windows_installer.ps1
```

| 산출물 | 경로 / 조건 |
| --- | --- |
| 앱 실행 파일 | `build/windows/x64/runner/Release/my_little_budget.exe` |
| 신규 설치용 | `installer/output/MyLittleBudget-Setup-<version>.exe` |
| 앱 내 업데이트용 | `installer/output/MyLittleBudget-Update-<version>.exe` |
| 해시 목록 | `installer/output/SHA256SUMS.txt` |
| 설치 위치 | `%LOCALAPPDATA%\Programs\MyLittleBudget` |
| 유지할 AppId | `{FDD789BA-BF17-471B-8170-63AEE41DFA00}` |

- [ ] 최종 커밋의 Windows release 빌드와 설치 파일 생성이 성공한다.
- [ ] 앱 EXE의 ProductVersion이 `pubspec.yaml`의 `<version>+<build>`와 일치한다. 빌드 스크립트도 이 일치를 검사한다.
- [ ] `.iss`의 기본 버전값에 의존하지 않고 빌드 스크립트가 현재 버전과 Windows 숫자 버전을 전달한다.
- [ ] Setup과 Update가 모두 존재하고 두 파일의 SHA-256이 같다. 두 파일은 이름만 다른 동일한 전체 설치 패키지다.
- [ ] `SHA256SUMS.txt`에 두 EXE의 최종 파일명과 SHA-256이 정확하게 기록되어 있다.
- [ ] 신규 설치 후 시작 메뉴·앱 실행·기본 데이터 생성·재시작을 확인한다.
- [ ] 기존 공개 버전 위에 업그레이드했을 때 거래·자산·예산·메모·설정 데이터가 유지된다.
- [ ] 앱의 `최신 버전 확인`에서 Update 우선 선택, 이전 릴리스의 Setup 대체, 다운로드·SHA-256 검증·설치·재실행을 확인한다.
- [ ] 업데이트 설치 확인 취소·다운로드 네트워크 실패·해시 불일치 시 설치가 진행되지 않는다.

`-SkipFlutterBuild`는 동일한 최종 소스로 만든 산출물임을 확인한 경우에만 사용한다. 버전값이 같다는 이유만으로 오래된 빌드를 재사용하지 않는다.

## 5. Android AAB·서명·설치 확인

| 항목 | 현재 소스 기준 값 / 근거 |
| --- | --- |
| Namespace / applicationId | `com.my_little_budget` — [Gradle 설정](android/app/build.gradle.kts) |
| MainActivity | `com.my_little_budget.MainActivity` |
| 앱 이름 | `나만의 작은 가계부` — [Manifest](android/app/src/main/AndroidManifest.xml) |
| versionName / versionCode | `pubspec.yaml`의 앱 버전 / 빌드 번호 |
| Play API 대상 | `com.my_little_budget`, 트랙 `internal` |

```powershell
flutter build appbundle --release
```

- [ ] SDK·JDK·Android 라이선스 상태를 확인하고 release 빌드가 성공한다.
- [ ] 로컬 `android/key.properties`와 기존 upload keystore를 사용한다. [예시 파일](android/key.properties.example)에 실제 비밀값을 기록하지 않는다.
- [ ] `build/app/outputs/bundle/release/app-release.aab`가 이번 소스에서 새로 생성되었다.
- [ ] **AAB 내부** package name·versionName·versionCode·release 서명을 확인한다. 파일명만 바꾼 오래된 AAB를 첨부하지 않는다.
- [ ] `debug`, `localRelease`, `reminderTest` 빌드를 Play 업로드용 release AAB와 구분한다. `localRelease`와 `reminderTest`는 debug 서명을 사용한다.
- [ ] 서명키·비밀번호·서비스 계정 JSON·토큰이 소스나 로그에 포함되지 않는다.
- [ ] AAB는 직접 설치용 APK가 아니므로 Play 내부 테스트 설치 또는 bundletool 기반 설치로 검증한다.
- [ ] 신규 설치·기존 버전 업데이트·재시작 후 DB와 설정 유지, 파일 선택·저장, 알림 권한과 예약 동작을 실기기에서 확인한다.

## 6. 주요 화면·데이터 회귀 점검

새 release 빌드에서 확인한다. PC·모바일 각각 해당 UI로 검증한다.

- [ ] 홈: 월별 잔액·예산·최근 거래가 정상적으로 표시된다.
- [ ] 거래: 수입·지출·이체 생성, 검색·필터, 수정·복제·삭제, 다중 선택을 확인한다.
- [ ] 자산: 생성·수정·보관·복원, 상세 거래·잔액·월 구분을 확인한다.
- [ ] 예산: 예상 수입, 그룹 생성·편집·삭제, 이전 달 복사, 집계 시작일·월 표기 기준을 확인한다.
- [ ] 통계: 월간·연간·태그별 통계, 그래프, 상세 거래 이동을 확인한다.
- [ ] 투자: 매수·매도·배당, 보유 수량·평가금·실현손익과 수량 소수점 4자리 처리를 확인한다.
- [ ] 메모·일정: 생성·편집·체크리스트·금액 목표·반복·D-day·알림 상태·알림을 통한 화면 진입을 확인한다.
- [ ] 설정: 카테고리·태그·정기거래·프리셋·테마·백업·업데이트 확인에 진입한다.
- [ ] Windows/Linux/macOS 네이티브는 창 폭과 무관하게 desktop shell·사이드바를 유지하며, 1200 미만에서 compact desktop이 동작한다.
- [ ] Android/iOS/Web은 폭 900 이상에서 desktop, 미만에서 mobile을 선택한다. 실제 지원 환경에서 검증하고 미검증 플랫폼은 명시한다.
- [ ] 좁은 화면·큰 글꼴·다중 선택에서 하단 도구와 내비게이션이 겹치지 않는다.

### 백업·복원·초기화

경로: `설정 → 데이터 백업/복원` (`/settings/backup`). JSON 복원은 현재 데이터를 전체 교체하며 부분 병합하지 않는다.

- [ ] `백업 파일 만들기`로 비어 있지 않은 `my_little_budget-backup-yyyyMMdd-HHmmss.json`을 저장할 수 있다.
- [ ] `백업 파일 선택` 후 `백업 복원 미리보기`에 백업 시각·데이터 건수·전체 교체 안내가 표시된다.
- [ ] 취소하면 데이터와 마지막 복원 시각이 바뀌지 않는다.
- [ ] 설치형 앱에서는 JSON 파일·Supabase 백업·로컬 복구 지점 모두 복원 직전 현재 데이터의 안전 백업을 만든다.
- [ ] 잘못된 JSON, 안전 백업 생성 실패, 데이터 교체 트랜잭션 실패 시 기존 데이터가 보존된다.
- [ ] 복원 완료 후 재시작 없이 거래·자산·예산·통계·메모·일정 화면이 갱신되고 알림이 재등록된다.
- [ ] 복원 후 처리 오류를 데이터 교체 전 실패와 혼동하여 기존 데이터가 유지됐다고 안내하지 않는다.
- [ ] 자동 로컬 백업의 생성·최근 7개 보관·내보내기·미리보기·복원을 확인한다.
- [ ] 웹에서는 기기 내부 안전 백업을 지원하지 않는다는 안내와 JSON 내보내기·복원 흐름을 별도 확인한다.
- [ ] 기기 초기화의 확인·취소, 완료 후 기본 자산·카테고리 재생성과 화면 갱신을 확인한다.
- [ ] 백업·복원·초기화 중 중복 클릭과 모드 전환을 막으며, 화면을 떠나도 폐기된 UI에 접근하지 않는다.

### Supabase·기기 알림

- [ ] 연결 설정 저장·인증·연결 해제, DB 테이블 확인·수동 동기화·자동 업로드를 확인한다.
- [ ] Storage JSON 백업·원격 상태 확인·다운로드·복원이 동작하고, 실패를 성공 시각으로 기록하지 않는다.
- [ ] 네트워크·인증 실패 후 재시도와 진행 상태 종료가 정상적이다.
- [ ] 서로 다른 기기의 변경·삭제가 반영되고, 기기별 알림 설정과 서버 동기화 상태가 올바르게 유지된다.
- [ ] 권한 거부·재허용·앱 재시작·기기 재부팅 후 알림 동작을 확인한다.

## 7. 게시 및 게시 후 검증

위 검증을 마치고 배포를 진행할 때 사용한다. 아래 `release-next` 경로는 예시이므로 이번 릴리스 노트의 실제 경로로 바꾼다.

### GitHub Release

Windows만 게시할 때:

```powershell
.\scripts\publish_windows_release.ps1 -NotesFile .scratch/release-next/notes.md
```

같은 버전으로 검증한 Android AAB도 함께 게시할 때:

```powershell
.\scripts\publish_windows_release.ps1 -NotesFile .scratch/release-next/notes.md -AndroidBundle build/app/outputs/bundle/release/app-release.aab
```

스크립트는 Windows 재빌드·소스와 태그 푸시·draft 릴리스 생성·파일 업로드를 수행한다. GitHub의 파일 크기·SHA-256 digest가 로컬 값과 일치한 뒤 릴리스를 공개한다. 검증 실패 시 draft를 유지하며, 다른 내용의 기존 릴리스 파일은 덮어쓰지 않는다.

- [ ] 소스 커밋과 태그가 같은 커밋을 가리키고 원격에 올라갔다.
- [ ] 공개 릴리스에 Setup·Update·`SHA256SUMS.txt`가 모두 있으며 크기·해시가 검증되었다.
- [ ] AAB 포함 시 `MyLittleBudget-Android-<version>.aab`와 해당 SHA-256도 해시 목록에 포함된다.
- [ ] `installer/output/release-result.json`의 버전·커밋·태그·릴리스 URL·파일 해시를 보관한다.
- [ ] 실제 다운로드 링크가 열리고 앱에서 더 높은 새 버전을 감지한다. 태그만 생성한 상태로 완료 처리하지 않는다.

### Google Play 내부 테스트

GitHub AAB 공개와 Google Play 배포는 별개다. [Play 스크립트](scripts/publish_google_play.ps1)는 PowerShell 7 이상에서 사용하며 `internal` 트랙을 대상으로 한다. 인증 파일 경로는 `-CredentialsFile`, `GOOGLE_APPLICATION_CREDENTIALS` 또는 로컬 설정으로 전달한다.

```powershell
.\scripts\publish_google_play.ps1 -Action Check
```

`-Action Upload`는 내부 테스트 **draft**, `-Action Release`는 내부 테스트 **completed** 상태를 반영한다. 별도의 다른 draft가 있는 경우 먼저 배포 범위를 검토한다. 아래는 내부 테스트 배포 명령이다.

```powershell
.\scripts\publish_google_play.ps1 -Action Release -BundlePath build/app/outputs/bundle/release/app-release.aab -NotesFile .scratch/release-next/play-notes.md
```

- [ ] 한국어 Play 릴리스 노트가 1~500자이며 실제 변경과 일치한다.
- [ ] 업로드된 AAB의 versionCode·SHA-256이 로컬 파일과 일치한다.
- [ ] 게시 후 `internal` 트랙의 versionCode·상태를 다시 확인한다. API 반영만으로 실기기 설치까지 완료 처리하지 않는다.
- [ ] 등록된 테스터 계정의 설치·업데이트 링크, 실행 및 주요 기능을 확인한다.
- [ ] Play Console에서 제공되는 사전 출시 보고서와 관련 경고를 검토한다.

## 8. 릴리스 완료 기록

| 항목 | 이번 릴리스 결과 |
| --- | --- |
| 버전 / 빌드 번호 | 미정 |
| 최종 소스 커밋 / 태그 | 미정 |
| 전체 테스트 결과 / 검증 환경 | 미완료 |
| Windows 신규 설치 / 업그레이드 | 미완료 |
| Android AAB / 실기기 확인 | 미완료 |
| GitHub URL / 파일 검증 | 미게시 |
| Google Play 트랙 / versionCode / 상태 | 미배포 |
| 알려진 문제 / 복구 방법 | 릴리스 노트에 기록 필요 |

기존 데이터가 있는 환경에서 검증할 때는 먼저 JSON 백업과 안전 복구 지점을 확보한다. 복구는 검증한 백업을 기준으로 수행하며, DB 스키마가 달라진 앱의 무조건적인 다운그레이드를 복구 방법으로 간주하지 않는다.
