# rc.17 배포

사용자의 2026-11-17 배포 요청. 대상은 1.0.0-rc.17+66, Windows x64 Setup/Update/SHA256SUMS 및 Android AAB, GitHub 소스/태그/Release와 Google Play internal이다.

직전 GitHub 공개 버전 v1.0.0-rc.16 및 Play internal completed 65를 원격에서 확인했다. 최고 업로드 versionCode도 65. 신규 태그/버전과 빌드 번호를 각각 17/66으로 증가한다.

포함: 입력 중 예산 미리보기·태그 접기, 백업 공통 처리, 역할별 파일 위치 정리, PC 반복거래 태그 배치, 관련 문서/테스트. DB schema 26, 백업 version 1, AppId/applicationId/서명키는 유지한다.

최종 lib/test 전체 분석 및 테스트 후 소스를 커밋한다. 동일 커밋에서 새 AAB를 빌드하고 내부 버전·서명을 검사한 뒤 Windows 게시 스크립트로 빌드/업로드/해시 검증/공개한다. Play에도 같은 AAB를 게시하고 별도 조회로 검증한다. 실행 결과는 이 디렉터리의 로그와 installer/output/release-result.json에 기록한다.

설치·실기기 수동 검증은 이번 자동 검증과 별개이며 수행하지 않은 검증은 완료로 표기하지 않는다.

## 배포 전 검증 결과

- 1.0.0-rc.17+66 소스에서 전체 Flutter 테스트 626개 통과, lib/test 정적 분석 통과. 의존성 잠금 파일 변경 없음.
- 기존 백업 UI 테스트의 확인창 대기 중 무한 진행 애니메이션 대기, 모바일 화면 밖/지연 생성된 버튼 탐색을 수정했다. 백업 구현은 바꾸지 않았다. 10개 UI 동작 및 전체 테스트에서 확인했다.
- Windows C++/SDK와 Flutter 빌드 도구 확인. Android doctor의 cmdline-tools/라이선스 상태 경고는 별도 환경 경고이며 실제 release 빌드 결과를 따로 확인한다.
- 게시 스크립트의 사전 검증 누락은 이번 실행에서 원격 버전/Play 코드 확인, 분석/전체 테스트, 고정된 HEAD 확인, 새 AAB 메타데이터/서명 확인으로 보완한다. 모의 검증 보고서의 스크립트 개선 자체는 이번 기능 배포 범위에 추가하지 않는다.
