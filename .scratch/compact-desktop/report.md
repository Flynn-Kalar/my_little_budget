# 좁은 네이티브 데스크톱 UI 수정 결과

## 원인과 검색 결과

- `lib/ui/mobile/shell/mobile_shell.dart`의 `ResponsiveShell`은 `LayoutBuilder.constraints.maxWidth >= 900`일 때만 `SidebarShell`을 사용했다. 플랫폼 판정이 없어 Windows 500~600px에서도 `MobileShell`과 bottom navigation으로 전환됐다.
- `lib/ui/mobile/responsive_page.dart`의 `ResponsivePage`도 별도로 `constraints.maxWidth < 900`이면 모바일 페이지를 선택했다. 이 폭은 사이드바와 본문 여백을 제외한 폭이다. 기존 사이드바 224 + 좌우 여백 64 때문에 창 폭 900~1188 미만에서는 사이드바 안에 모바일 페이지가 나타날 수도 있었다.
- `lib/router/app_router.dart`에서 주요 화면과 설정 하위 화면이 모두 위 공통 shell/page를 사용한다. 라우터 자체는 수정하지 않았다.
- 프로젝트 Dart 소스의 `MediaQuery`, `LayoutBuilder`, breakpoint, isMobile/isDesktop/isTablet, Platform, TargetPlatform을 검색했다. 추가적인 모바일/데스크톱 화면 선택 분기는 위 두 곳이었다.
- 내역 화면의 720/820px 본문, 340/360px 보조 패널, 1480px wide 판정은 데스크톱 내부 열 배치다. 거래 목록은 최대 1040px 제한이다.
- 캘린더, 예산 읽기 영역, 투자 화면의 LayoutBuilder는 내부 카드/열 크기 조절이다. 색상 선택기의 LayoutBuilder도 내부 배치다. 메모 MediaQuery는 24시간 표기, 데이터 관리 화면은 높이 여백, 투자 대화상자는 최대 폭 계산에 사용된다.
- 업데이트 설치기의 Windows 판정과 메모 알림의 Android 판정은 UI 계열 선택과 무관하다.

## 최종 판정

공통 정책: `lib/shell/layout_policy.dart`.

- `!kIsWeb`이고 `defaultTargetPlatform`이 Windows/Linux/macOS이면 네이티브 데스크톱이다. 해당 플랫폼은 폭과 관계없이 데스크톱 shell과 페이지를 사용한다.
- `usesMobileLayout(width) = !isDesktopPlatform && width < 900`.
- `isCompactDesktop(context) = isDesktopPlatform && 창 폭 < 1200`.
- 기존 모바일 breakpoint 900은 유지했다. Android/iOS/Web은 기존 shell과 페이지의 폭 판정을 그대로 유지한다.
- compact는 데스크톱 UI 내부의 밀도 조절이며 모바일 컴포넌트를 사용하지 않는다.

## 레이아웃 변경

- 사이드바 224 → 104px, 사이드바 여백 16 → 6px, 본문 여백 32 → 12px. 내역·통계·자산·메모·설정의 좌측 메뉴 유지.
- 내역: 월 이동/예산/투자 버튼 축소 및 툴팁 유지. 입력 행과 거래 목록 각각에 필요한 경우만 가로 스크롤(최소 720px). 검색 필터는 긴 검색 상태 문구를 가용 폭 안에서 표시하고, 펼친 필터의 높이를 창 높이의 42%로 제한해 자체 세로 스크롤. 창 크기 변경 시 입력 중인 금액과 화면 상태 유지.
- 통계: 요약 카드 내부와 차트/분류/상세 영역에만 필요한 최소 폭과 개별 가로 스크롤. 페이지 자체의 세로 스크롤 유지.
- 자산: 총액 지표 행(600px) 및 계좌 목록(680px)에만 개별 가로 스크롤. 한도·제외 여부가 표시된 카드 계좌로 검증.
- 메모: 검색 폭/간격/필터 버튼 여백 축소, 같은 검색·필터 행 유지. 좁은 창에서 기존 데스크톱 메모 카드가 지나치게 좁은 여러 열이 되지 않도록 카드 열 폭 조정.
- 설정 메인은 기존 코드 그대로 사용해 검증했다.
- 전체 화면이나 shell을 가로 스크롤로 감싸지 않았다. 개별 스크롤 영역에는 마우스로 조작할 수 있는 스크롤바가 표시된다.

## 이번 작업의 변경 파일

기존 작업 중이던 금액 포맷/알람/반복 거래 등의 변경은 보존했다. 아래 파일은 이번 작업에서 변경하거나 추가한 파일이다.

1. `AGENTS.md` — 네이티브 데스크톱 예외와 compact 정책 문서화
2. `lib/shell/layout_policy.dart` — 공통 플랫폼/폭 판정 추가
3. `lib/shell/sidebar_shell.dart` — compact 사이드바와 여백
4. `lib/ui/mobile/shell/mobile_shell.dart` — 공통 정책으로 shell 선택
5. `lib/ui/mobile/responsive_page.dart` — 공통 정책으로 페이지 선택
6. `lib/ui/desktop/desktop_section.dart` — 상태를 보존하는 영역별 가로 스크롤
7. `lib/ui/desktop/transactions/transactions_screen.dart` — compact 헤더, 입력/표 스크롤, 필터 높이, 상태 보존
8. `lib/ui/desktop/transactions/widgets/month_nav.dart` — compact 월 이동 버튼
9. `lib/ui/desktop/transactions/widgets/filter_panel.dart` — 긴 검색 상태 문구의 폭 제한
10. `lib/ui/desktop/stats/stats_screen.dart` — 분류/상세/차트 영역별 스크롤
11. `lib/ui/desktop/stats/widgets/monthly_insight_card.dart` — 요약 지표의 최소 가독 폭
12. `lib/ui/desktop/accounts/accounts_screen.dart` — 계좌 목록 영역별 스크롤
13. `lib/ui/desktop/accounts/widgets/total_assets_card.dart` — 자산 지표 행의 최소 가독 폭
14. `lib/ui/desktop/notes/notes_screen.dart` — compact 검색/필터/카드 배치
15. `test/ui/compact_desktop_test.dart` — 플랫폼, 폭, 렌더링, 입력 상태 회귀 테스트

## 검증

- 수정 전: `flutter test test/ui/compact_desktop_test.dart`에서 500/600px 모두 SidebarShell 0개로 실패해 사용자 증상을 재현.
- 수정 후: `flutter test --no-pub test/ui` — **90개 통과**.
- 신규 12개 테스트: Windows/Linux/macOS × 500/600px에서 내역·통계·자산·메모·설정, 샘플 수입/지출과 긴 메모, 한도/제외 계좌, 검색 필터 펼치기, 긴 검색어, 900/1199/1200/1600px 왕복 크기 변경과 금액 입력 유지.
- Android/iOS × 390/600/899px에서 동일한 다섯 화면의 bottom navigation 유지 및 렌더링 오류 없음. 기존 모바일 UI 테스트도 포함해 통과.
- 변경 Dart 파일 정적 분석 — **No issues found**.
- 샘플 전용 메모리 DB 진입점으로 Windows debug 빌드 및 실제 실행 성공. 실데이터를 사용하지 않았다. 실제 앱은 넓은 창에서 표시를 확인했고, 500/600px의 판정·overflow 검증은 자동 위젯 렌더링 테스트 기준이다. Linux/macOS 실기 실행과 모든 하위 대화상자 조합의 시각 검증까지 수행한 것은 아니다.
- `preview.dart`는 실제 사용자 DB/앱 시작 동기화를 사용하지 않는 진단용 실행 파일이다. 프로덕션 진입점은 수정하지 않았다.
