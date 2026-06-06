# Release Checklist

릴리즈 후보를 만들기 전에 아래 항목을 확인한다. 이 문서는 현재 Flutter MVP 상태를 기준으로 하며, DB schema와 백업 JSON 포맷은 릴리즈 직전에 임의 변경하지 않는다.

Current release candidate:

- Version: `1.0.0-rc.1+1`
- Target: Windows desktop MVP
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
