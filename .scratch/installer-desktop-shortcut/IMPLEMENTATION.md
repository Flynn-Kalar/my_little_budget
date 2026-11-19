# 바탕화면 아이콘 생성 정책 변경

Status: ready-for-human

2026-11-19 구현·검증 완료. 버전 변경/배포 없이 로컬 변경으로 보존한다.

- 첫 설치: 기존 바탕화면 바로가기 체크박스 유지, 기본 미선택. 선택한 경우에만 생성.
- 동일 AppId의 기존 설치가 있으면 체크박스와 바탕화면 아이콘 생성 항목을 모두 제외. 사용자/시스템 및 32/64비트 등록 확인 결과는 InitializeSetup에서 저장한다.
- 앱 내 업데이트에 /MERGETASKS=!desktopicon을 추가하여 이전 설치 파일을 사용하는 경우에도 아이콘 작업을 해제한다.
- 기존 아이콘을 덮어쓰거나 지우지 않고, 사용자가 삭제한 아이콘도 업데이트에서 재생성하지 않는다. Setup/Update 동일 패키지 정책과 실제 AppId는 유지한다.

검증:

- 기존 설치 실행·파일 검증·오류 처리 검사 6개 통과. Setup 대체와 Update 양쪽에 아이콘 작업 해제 인수 확인.
- 수정 Dart 파일 정적 분석 진단 없음, git diff --check 통과.
- 실제 설치 스크립트 Inno Setup 6.7.3 컴파일 통과. 검증 출력은 build/shortcut-policy-check/production-compile에 격리하고 기존 배포 파일은 덮어쓰지 않았다. 이 파일은 기존 rc.19 앱 페이로드로 설치 스크립트만 검증한 후보이며 배포용이 아니다.
- 같은 설치 스크립트에서 시험 AppId·별도 설치/바로가기 경로·더미 페이로드를 사용해 첫 설치 미선택/선택을 실제 실행. 첫 설치 TaskCount=2, 업데이트 TaskCount=0 확인. 기존 선택을 강제 전달하는 업데이트에도 새 바로가기가 생성되지 않음. 기존 바로가기의 해시/수정 시각 유지와 삭제 후 재생성 방지 확인.
- 시험 설치는 자체 제거 프로그램으로 정리했고 사용자 앱·실제 바탕화면은 변경하지 않았다. 시험 도구는 build/shortcut-policy-check/verify.ps1, 로그는 native-check.log/compile.log/updater-tests.log/analyze.log.

공식 동작 근거: [이전 작업 선택](https://jrsoftware.org/ishelp/topic_setup_useprevioustasks.htm), [작업 해제 명령행](https://jrsoftware.org/ishelp/topic_setupcmdline.htm), [Check 조건](https://jrsoftware.org/ishelp/topic_scriptcheck.htm), [AppId 등록](https://jrsoftware.org/ishelp/topic_setup_appid.htm).
