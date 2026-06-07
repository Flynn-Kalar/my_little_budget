# My Little Budget

한국어 데스크톱 가계부 앱입니다. Flutter, Drift, SQLite, Riverpod 기반으로 거래내역, 자산, 예산, 통계, 투자, 설정 관리를 제공합니다.

## 주요 기능

- 거래내역 입력, 수정, 복제, 삭제, 검색, 필터
- 자산 생성, 수정, 보관, 복원, 삭제, 상세 거래 필터
- 월별 예산 관리, 예상 수입, 예산 그룹, 이전 달 예산 복사
- 월간/연간 통계 조회
- 투자 BUY/SELL/DIVIDEND 입력, 수정, 삭제, 보유종목, 실현손익 조회
- 카테고리, 태그, 반복 거래, 테마 설정
- JSON 백업 내보내기와 전체 복원

## 설치

### 사용자 설치

현재 MVP는 Windows 데스크톱 실행을 기준으로 준비합니다.

1. 릴리즈에서 제공되는 Windows 빌드 파일을 받습니다.
2. 압축 배포인 경우 원하는 폴더에 압축을 풉니다.
3. `my_little_budget.exe`를 실행합니다.
4. Windows 보안 경고가 표시되면 배포 출처를 확인한 뒤 실행합니다.

데이터는 앱 내부 SQLite DB에 저장됩니다. 앱 삭제 또는 PC 이동 전에 반드시 백업 파일을 만들어 두세요.

### 개발 환경 실행

필요 도구:

- Flutter SDK
- Windows 데스크톱 빌드 환경

명령:

```powershell
flutter pub get
flutter run -d windows
```

릴리즈 빌드:

```powershell
flutter build windows --release
```

Windows release build 산출물 기본 경로:

```text
build\windows\x64\runner\Release
```

이 폴더 안의 `my_little_budget.exe`와 함께 생성된 DLL/data 파일을 같은 폴더 구조로 배포합니다.

Android 로컬 테스트 APK:

```powershell
flutter build apk --debug
cd android
.\gradlew assembleLocalRelease
```

`assembleLocalRelease`는 로컬 테스트 전용 debug-signed release-like APK입니다. Google Play 업로드용 AAB는 반드시 `android/key.properties` 기반 release signing으로 `flutter build appbundle --release`를 사용합니다.

### Android Internal Testing

Google Play Internal testing으로 본인 계정만 설치할 때도 Play 업로드용 AAB는 release/upload key로 서명해야 합니다. Debug APK 또는 `localRelease` APK는 Play Console에 업로드하지 않습니다.

1. Android SDK와 JDK를 설치하고 `flutter doctor -v`에서 Android toolchain을 통과시킵니다.
2. upload keystore를 안전한 로컬 위치에 준비합니다.
3. [android/key.properties.example](android/key.properties.example)을 `android/key.properties`로 복사합니다.
4. `android/key.properties`에 로컬 비밀값을 채웁니다.

```properties
storeFile=<absolute-or-relative-path-to-upload-keystore.jks>
keyAlias=<upload-key-alias>
storePassword=<upload-keystore-password>
keyPassword=<upload-key-password>
```

5. AAB를 빌드합니다.

```powershell
flutter build appbundle --release
```

AAB 산출물:

```text
build/app/outputs/bundle/release/app-release.aab
```

6. Play Console의 Internal testing 트랙에 AAB를 업로드합니다.
7. 본인 Google 계정을 테스터로 등록하고 설치 링크로 설치합니다.
8. 실기기에서 앱 실행, 주요 화면 진입, 앱 재시작 후 설정 유지, 백업 export/import를 확인합니다.

민감정보 주의:

- `android/key.properties`는 git에 포함하지 않습니다.
- `.jks`, `.keystore` 파일은 git에 포함하지 않습니다.
- 실제 비밀번호나 key alias를 문서나 코드에 하드코딩하지 않습니다.

검증:

```powershell
flutter analyze
flutter test
```

## 백업

백업은 설정 화면에서 수행합니다.

1. 앱에서 `설정`으로 이동합니다.
2. `데이터 백업/복원`을 엽니다.
3. `Create backup file` 버튼을 누릅니다.
4. 저장 위치를 선택합니다.

백업 파일명 형식:

```text
my_little_budget-backup-yyyyMMdd-HHmmss.json
```

백업 파일에는 현재 앱 데이터가 단일 JSON 파일로 저장됩니다. 릴리즈 전후, 다른 PC로 이동하기 전, 대량 import를 하기 전에는 백업을 먼저 만드는 것을 권장합니다.

## 복원

복원은 기존 데이터와 병합하지 않고, 현재 데이터를 백업 시점 데이터로 완전히 교체합니다.

1. 앱에서 `설정`으로 이동합니다.
2. `데이터 백업/복원`을 엽니다.
3. `Choose backup file` 버튼을 누릅니다.
4. 백업 JSON 파일을 선택합니다.
5. 확인 문구를 읽고 복원을 승인합니다.

복원 확인 문구:

```text
현재 데이터를 모두 덮어쓰고 백업 데이터를 복원합니다. 되돌릴 수 없습니다.
```

복원 실패 시 기존 데이터는 유지되어야 합니다. 복원 성공 후에는 앱을 재시작하지 않아도 주요 화면 데이터가 갱신됩니다.

## 알려진 제한

- 현재 MVP는 Windows 데스크톱 사용 흐름을 우선합니다.
- 백업 복원은 전체 교체 방식이며 부분 병합을 지원하지 않습니다.
- 투자 기능은 수동 입력 기준입니다. 환율, 실시간 시세, 외부 증권사 API 연동은 없습니다.
- 투자 수량은 소수점 4자리까지 지원하고, 금액/단가/수수료는 원화 정수 기준입니다.
- 통계 화면은 표와 목록 중심입니다. 차트 시각화는 후속 작업입니다.
- 설정의 reset UI는 MVP 필수가 아닌 post-MVP polish로 남아 있습니다.
- 백업/복원 파일 선택 흐름은 플랫폼 파일 선택기에 의존합니다.

## 향후 계획

- 릴리즈 패키징과 설치 경험 정리
- 백업/복원 플랫폼 통합 테스트 보강
- 예산, 투자, 계좌 edge case 테스트 확대
- 통계 차트 시각화 검토
- 모바일 대응 가능성 검토
- 설정 reset UX 검토

## 프로젝트 문서

- [SPEC.md](SPEC.md): 제품/데이터/동작 기준
- [MVP_CHECKLIST.md](MVP_CHECKLIST.md): MVP 상태판
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md): 구현 계획과 현재 구조
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md): 릴리즈 준비 체크리스트
